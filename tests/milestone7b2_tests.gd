extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func _initialize() -> void:
	_catalog()
	_demand()
	_market()
	_persistence()
	print("M7B2 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, 2012), "Initialize 2012")
	var count: int = 0
	for product: String in sim.catalog.products:
		var local: Dictionary = ConsumerMarket.local_offer(sim, product)
		check(not local.is_empty() == (sim.catalog.consumer_product(product) and sim.product_public(product)), "Eligibility " + product)
		if sim.catalog.consumer_product(product):
			count += 1
			var values: Dictionary = sim.catalog.local_values(product)
			check(values.price > 0 and values.quality >= 1 and values.quality <= 100 and values.brand >= 0 and values.brand <= 100, "Valid Local " + product)
			check(sim.companies.player.brand(product) == 20 and sim.companies.rival.brand(product) == 20, "Shared corporate brand defaults " + product)
	check(count == 17, "Consumer products only")
	check(ConsumerMarket.local_offer(sim, "advanced_phone").is_empty(), "Locked Local absent")
	sim.clock.year = 2022
	check(not ConsumerMarket.local_offer(sim, "advanced_phone").is_empty() and not sim.can_manufacture("player", "advanced_phone"), "Local public gate independent of knowledge")
	check(ConsumerMarket.local_offer(sim, "processor").is_empty(), "No intermediate Local")
	sim.catalog.categories.smartphones["market"] = {"local_quality": 45}
	sim.catalog.products.smartphone["market"] = {"local_brand": 70}
	check(sim.catalog.local_values("smartphone").quality == 45 and sim.catalog.local_values("smartphone").brand == 70, "Category and product overrides")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for field: String in ["local_price_multiplier", "local_quality", "local_brand", "corporate_brand"]:
		var data: Dictionary = raw.duplicate(true)
		data.market_defaults[field] = -1
		var file: FileAccess = FileAccess.open("res://.godot/7b2-invalid.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data("res://.godot/7b2-invalid.json"), "Reject invalid " + field)

func _demand() -> void:
	var offers: Array[Dictionary] = [
		{"price": 115, "reference_price": 100, "quality": 50, "brand": 60, "stock": 10000},
		{"price": 200, "reference_price": 100, "quality": 30, "brand": 20, "stock": 10000}]
	var weak: Array[int] = ConsumerDemand.allocate(1000, offers)
	check(weak[0] > weak[1] and weak[1] > 0, "Weak corporate offer loses to Local but can sell")
	check(weak[0] + weak[1] < 1000, "Outside option remains separate")
	offers[1].price = 60
	offers[1].quality = 90
	offers[1].brand = 100
	var strong: Array[int] = ConsumerDemand.allocate(1000, offers)
	check(strong[1] > strong[0] and strong[1] > weak[1], "Better price quality brand win share")
	offers[1].brand = 0
	check(ConsumerDemand.allocate(1000, offers)[1] > 0, "Zero brand positive demand")
	offers[1] = offers[0].duplicate()
	offers[1].brand = 0
	var branded: Array[int] = ConsumerDemand.allocate(1000, offers)
	check(branded[0] > branded[1], "Identical physical goods compete differently by seller brand")
	offers[1].stock = 1
	check(ConsumerDemand.allocate(1000, offers)[1] <= 1, "Corporate stock constraint")
	check(ConsumerDemand.overall(100, 100, 50, 50) == 50 and ConsumerDemand.overall(1, 100, 100, 100) == 100, "Bounded transparent Overall")

func _market() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize market")
	var before: Array = []
	for f: SimFacility in sim.facilities: before.append(f.snapshot())
	var accounts: Array = []
	for owner: SimCompany in sim.companies.values(): accounts.append(owner.snapshot())
	var companies: int = sim.companies.size()
	ConsumerMarket.clear(sim)
	var after: Array = []
	for f: SimFacility in sim.facilities: after.append(f.snapshot())
	var after_accounts: Array = []
	for owner: SimCompany in sim.companies.values(): after_accounts.append(owner.snapshot())
	check(same(before, after) and same(accounts, after_accounts) and sim.companies.size() == companies, "Local-only sales create no facilities inventory companies accounts")
	check(sim.market.smartphone.local_units > 0 and sim.market.smartphone.local_share == 1.0, "Local-only realized share")
	check(sim.category_market.smartphones.units < sim.category_market.smartphones.potential, "Local does not replace outside")
	# Isolated corporate retail clearing; purchase fixture inventory at exact book value.
	var store: SimFacility = sim.facility("20_player")
	for f: SimFacility in sim.facilities: f.active = f == store
	store.inventory.add("smartphone", 100, 10000, 90)
	sim.companies.player.spend(10000)
	sim.companies.player.purchases += 10000
	store.price = 10000
	sim.companies.player.product_brands.smartphone = 80
	var stock: Dictionary = store.inventory.snapshot()
	sim.companies.player.product_brands.smartphone = 90
	check(same(stock, store.inventory.snapshot()) and not store.inventory.snapshot().has("brand"), "Brand does not travel with inventory")
	ConsumerMarket.clear(sim)
	var m: Dictionary = sim.market.smartphone
	var sold: int = store.line_today.smartphone.units
	var local: Dictionary = sim.catalog.local_values("smartphone")
	check(sold > 0 and m.local_units > 0 and m.market_share.player < 1.0, "No AI does not imply 100 percent player share")
	check(m.units == sold + m.local_units, "Realized denominator includes Local")
	check(is_equal_approx(m.local_share + m.market_share.player, 1.0), "All realized shares sum to one")
	check(is_equal_approx(m.market_share.player, float(sold) / m.units), "Outside excluded from shares")
	check(is_equal_approx(m.average_price, float(sold * store.price + m.local_units * local.price) / m.units), "Weighted price includes Local")
	check(is_equal_approx(m.average_quality, float(sold * 90 + m.local_units * local.quality) / m.units), "Weighted quality includes Local")
	check(is_equal_approx(m.average_brand, float(sold * 90 + m.local_units * local.brand) / m.units), "Weighted brand includes Local")
	check(sim.companies.player.retail_revenue == sold * store.price and sim.invariant_errors().is_empty(), "Only corporate sales reach exact accounts")
	check(sim.market_history.back().categories.smartphones.local_units > 0, "Local included in retained history")
	var empty: Dictionary = ConsumerMarket.empty_report()
	ConsumerMarket.finish_report(empty, 100)
	check(empty.average_price == 0 and empty.average_overall == 0 and empty.local_share == 0, "Deterministic zero-sales fallback")

func _persistence() -> void:
	for era: int in [2012, 2022]:
		var sim: Economy = Economy.new()
		check(sim.initialize(42, era), "Replay era")
		sim.companies.player.product_brands.smartphone = 37
		for day: int in range(20): sim.step()
		var store: SaveStore = SaveStore.new()
		var path: String = "res://.godot/7b2-save.json"
		check(store.write_file(path, sim.snapshot()), "Write exact disk save")
		var restored: Economy = store.restore(store.read_file(path))
		check(restored != null and same(sim.snapshot(), restored.snapshot()), "Exact brand/report restore")
		if restored == null: continue
		for day: int in range(30):
			sim.step()
			restored.step()
			check(same(sim.snapshot(), restored.snapshot()), "Exact continuation")
			check(sim.invariant_errors().is_empty(), "Accounting invariants")
		for owner: SimCompany in sim.companies.values():
			var flow: Dictionary = FinancialReports.period(owner, sim.clock)
			check(flow.opening_cash + flow.net_cash == flow.closing_cash, "Exact cash flow")
		for corruption: String in ["missing", "fraction", "range", "unknown", "share", "average"]:
			var state: Dictionary = sim.snapshot()
			match corruption:
				"missing": state.companies[0].product_brands.erase("smartphone")
				"fraction": state.companies[0].product_brands.smartphone = 2.5
				"range": state.companies[0].product_brands.smartphone = 101
				"unknown": state.companies[0].product_brands.missing = 10
				"share": state.market.smartphone.local_share = 0.123456
				"average": state.market.smartphone.average_quality += 1.0
			check(SaveStore.new().restore(state) == null, "Reject invalid " + corruption)
