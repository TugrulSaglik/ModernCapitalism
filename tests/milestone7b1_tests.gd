extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func fresh() -> GameSession:
	var s: GameSession = GameSession.new()
	check(s.start(2022), "Start unchanged 2022 scenario")
	return s

func seed_stock(sim: Economy, f: SimFacility, product: String, units: int, quality: int) -> void:
	check(f.inventory.add(product, units, units * 100, quality), "Seed quality-bearing stock")
	sim.companies[f.company_id].spend(units * 100)
	sim.companies[f.company_id].purchases += units * 100

func _initialize() -> void:
	_inventory()
	_production()
	_logistics_replay()
	_retail()
	_sourcing()
	print("M7B1 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _inventory() -> void:
	var inv: SimInventory = SimInventory.new()
	check(inv.add("p", 10, 101, 40) and inv.add("p", 10, 103, 40), "Equal-quality additions")
	check(inv.quality("p") == 40 and inv.points("p") == 800, "Equal quality remains unchanged")
	check(inv.add("p", 10, 97, 100), "Add different quality")
	check(inv.quantity("p") == 30 and inv.points("p") == 1800 and inv.quality("p") == 60 and inv.value("p") == 301, "Weighted quality and cost independently pooled")
	var before: Dictionary = inv.snapshot()
	check(not inv.add("p", 1, 0, 101) and not inv.add("p", 1, 0, 0) and not inv.add_pooled("p", 2, 0, 1), "Invalid quality rejected")
	check(inv.remove("p", 31) == -1 and same(before, inv.snapshot()), "Invalid operations are atomic")
	var removed: Dictionary = inv.remove_pooled("p", 7)
	check(removed.cost == 70 and removed.quality_points == 420 and inv.quantity("p") == 23 and inv.value("p") == 231, "Partial removal proportional in both pools")
	check(inv.remove("p", 23) == 231 and inv.points("p") == 0 and inv.quality("p") == 0, "Compatibility removal clears full pool")
	check(inv.quality_text("p") == "no stock", "Empty quality is explicit")
	inv.add("p", 2, 101, 40)
	inv.add("p", 1, 0, 42)
	removed = inv.remove_pooled("p", 1)
	check(removed.quality_points == 40 and inv.points("p") == 82 and inv.value("p") == 68, "Fractional pool retains remainder")
	var destination: SimInventory = SimInventory.new()
	destination.add_pooled("p", 1, removed.cost, removed.quality_points)
	removed = inv.remove_pooled("p", 2)
	destination.add_pooled("p", 2, removed.cost, removed.quality_points)
	check(destination.points("p") == 122 and destination.value("p") == 101, "Split and recombine preserve exact points and cents")
	var reference: SimInventory = SimInventory.new()
	reference.add("p", 2, 101, 50)
	reference.add("p", 1, 0, 50)
	check(destination.remove("p", 2) == reference.remove("p", 2) and destination.value("p") == reference.value("p"), "Changing only quality leaves carrying-cost rounding identical")

func output_quality(component: int, process: int) -> int:
	var s: GameSession = fresh()
	var f: SimFacility = s.sim.facility("10_orion")
	f.quality = process
	for input: String in s.sim.catalog.products.smartphone.inputs:
		seed_stock(s.sim, f, input, 3 * int(s.sim.catalog.products.smartphone.inputs[input]), component)
	check(s.sim.produce(f) == 3, "Atomic batch produced")
	check(s.sim.invariant_errors().is_empty(), "Production accounting reconciles")
	return f.inventory.quality("smartphone")

func _production() -> void:
	var low: int = output_quality(20, 60)
	check(low == 40 and output_quality(20, 60) == low, "Identical process/inputs reproduce formula")
	check(output_quality(80, 60) == 70, "Better components improve output")
	check(output_quality(1, 1) == 1 and output_quality(100, 100) == 100, "Quality range endpoints")
	var s: GameSession = fresh()
	var f: SimFacility = s.sim.facility("01_processors")
	check(s.sim.produce(f) > 0 and f.inventory.quality(f.product_id) == f.quality, "External boundary uses process baseline")
	var mixed: SimFacility = s.sim.facility("12_advanced")
	var expected_points: int = 0
	var expected_units: int = 0
	for input: String in s.sim.catalog.products.advanced_phone.inputs:
		var count: int = int(s.sim.catalog.products.advanced_phone.inputs[input])
		var q: int = 90 if input == "processor" else 20
		seed_stock(s.sim, mixed, input, count, q)
		expected_points += count * q
		expected_units += count
	check(s.sim.produce(mixed) == 1 and mixed.inventory.quality("advanced_phone") == (mixed.quality + expected_points / expected_units) / 2, "Different component types weighted by consumed units")

func _logistics_replay() -> void:
	var s: GameSession = fresh()
	var sim: Economy = s.sim
	for f: SimFacility in sim.facilities: f.operating = false
	var factory: SimFacility = sim.facility("10_orion")
	var warehouse: SimFacility = sim.facility("30_warehouse")
	var store: SimFacility = sim.facility("20_player")
	for input: String in sim.catalog.products.smartphone.inputs:
		seed_stock(sim, factory, input, 18 * int(sim.catalog.products.smartphone.inputs[input]), 90)
	check(sim.produce(factory) == 18, "Produce provenance batch for warehouse")
	var q: int = factory.inventory.quality("smartphone")
	var maker_revenue: int = sim.companies[factory.company_id].revenue
	check(sim.logistics.dispatch(sim, factory, warehouse, "smartphone", 18) == 18, "Inter-company shipment dispatched")
	check(sim.logistics.shipments.back().quality_points == q * 18 and sim.companies[factory.company_id].revenue == maker_revenue + factory.price * 18, "Wholesale settles value without altering quality")
	while sim.logistics.incoming(warehouse.id) > 0: sim.step()
	check(warehouse.inventory.quality("smartphone") == q, "Warehouse receives manufactured quality")
	seed_stock(sim, warehouse, "smartphone", 10, 40)
	check(warehouse.inventory.points("smartphone") == q * 18 + 400, "Warehouse quantity-weighted blend")
	var pooled: int = warehouse.inventory.points("smartphone")
	var book: int = warehouse.inventory.value("smartphone")
	var revenue: int = sim.companies.player.revenue
	check(sim.logistics.dispatch(sim, warehouse, store, "smartphone", 11) == 11, "Same-company outbound transfer")
	var shipment: Dictionary = sim.logistics.shipments.back()
	check(shipment.quality_points + warehouse.inventory.points("smartphone") == pooled, "Outbound pooled points conserved")
	check(shipment.value + warehouse.inventory.value("smartphone") == book and sim.companies.player.revenue == revenue, "Internal transfer preserves carrying value and creates no sale")
	check(sim.invariant_errors().is_empty(), "Mixed quality and freight accounting exact")
	sim.record_history()
	check(s.save_game("res://.godot/7b1-quality-save.json"), "Save quality-bearing transit to disk")
	var restored: GameSession = GameSession.new()
	check(restored.load_game("res://.godot/7b1-quality-save.json"), "Load quality-bearing transit")
	if restored.sim == null: return
	check(same(sim.snapshot(), restored.sim.snapshot()), "Exact restored quality state")
	for day: int in range(20):
		sim.step()
		restored.sim.step()
		check(same(sim.snapshot(), restored.sim.snapshot()), "Exact daily continuation with warehouse shipment")
		check(sim.invariant_errors().is_empty(), "Daily accounting and quality invariants")
	check(store.inventory.points("smartphone") == shipment.quality_points, "Store does not overwrite incoming quality")
	for corruption: String in ["missing", "fraction", "low", "high", "orphan", "shipment", "schema"]:
		var state: Dictionary = sim.snapshot()
		var inv: Dictionary = state.facilities[0].inventory
		if corruption == "schema": state.schema_version = 7
		elif corruption == "shipment":
			state = SaveStore.new().read_file("res://.godot/7b1-quality-save.json").economy
			state.logistics.shipments.back().quality_points = 0
		elif corruption == "missing": inv.erase("quality_points")
		elif corruption == "orphan": inv.quality_points["smartphone"] = 1
		else:
			inv.quantities["processor"] = 1
			inv.costs["processor"] = 0
			inv.quality_points["processor"] = 1.5 if corruption == "fraction" else (0 if corruption == "low" else 101)
		check(SaveStore.new().restore(state) == null, "Reject corrupt quality: " + corruption)

func retail_units(goods_quality: int, store_quality: int) -> int:
	var s: GameSession = fresh()
	for f: SimFacility in s.sim.facilities: f.active = false
	var store: SimFacility = s.sim.facility("20_player")
	store.active = true
	store.quality = store_quality
	store.capacity = 10000
	store.assortment = {"smartphone": store.price, "laptop": 68000}
	seed_stock(s.sim, store, "smartphone", 1000, goods_quality)
	seed_stock(s.sim, store, "laptop", 10, 52)
	check(store.inventory.quality("laptop") == 52 and store.inventory.quality("smartphone") == goods_quality, "Independent retail-line qualities")
	ConsumerMarket.clear(s.sim)
	return int(s.sim.market.smartphone.units)

func _retail() -> void:
	check(retail_units(80, 10) == retail_units(80, 100), "Store capability cannot change consumer appeal")
	check(retail_units(90, 50) > retail_units(20, 50), "Actual goods quality changes consumer sales")
	var offers: Array[Dictionary] = [
		{"price": 30000, "reference_price": 30000, "quality": 30, "stock": 1000, "price_sensitivity": 0.7, "quality_sensitivity": 2.0},
		{"price": 30000, "reference_price": 30000, "quality": 80, "stock": 1000, "price_sensitivity": 0.7, "quality_sensitivity": 2.0}]
	var allocation: Array[int] = ConsumerDemand.allocate(100, offers)
	check(allocation[1] > allocation[0] and allocation[0] + allocation[1] < 100, "Premium consumers favor quality with outside option")

func _sourcing() -> void:
	var s: GameSession = fresh()
	var a: SimFacility = s.sim.facility("10_orion")
	var b: SimFacility = s.sim.facility("11_nova")
	seed_stock(s.sim, a, "smartphone", 20, 20)
	seed_stock(s.sim, b, "smartphone", 20, 90)
	a.price = 20000
	b.price = 30000
	var offers: Array[Dictionary] = s.sim.supplier_offers("20_player", "smartphone")
	check(offers[0].id == b.id and offers[0].quality == 90 and offers[1].quality == 20, "Sourcing ranks actual quality against landed price")
	s.sim.facilities.reverse()
	check(same(offers, s.sim.supplier_offers("20_player", "smartphone")), "Sourcing stable across container order")
