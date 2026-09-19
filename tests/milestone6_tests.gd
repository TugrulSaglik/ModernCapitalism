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

func command(sim: Economy, f: SimFacility, kind: String, product: String, extra: Dictionary = {}) -> bool:
	var request: Dictionary = {"type": kind, "company": f.company_id, "facility": f.id, "product": product}
	request.merge(extra)
	if not sim.command_error(request).is_empty(): return false
	sim.queue_command(request)
	sim.process_commands()
	return sim.command_results.back().accepted

func _initialize() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Start generated expanded economy")
	_catalog_segments(sim)
	_operations(sim)
	_finance(sim)
	_period_boundaries()
	for era: int in [2012, 2022]: _replay(era)
	print("M6 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog_segments(sim: Economy) -> void:
	check(sim.catalog.products.size() == 26 and sim.catalog.errors.is_empty(), "26 validated products")
	check(not sim.catalog.product_public("earbuds", 2012) and sim.catalog.product_public("earbuds", 2022), "Wearable era gate")
	check(not sim.catalog.product_public("robot_vacuum", 2012) and sim.catalog.product_public("robot_vacuum", 2022), "Smart home era gate")
	var counts: Dictionary = ConsumerMarket.populations(sim)
	var total: int = 0
	for n: int in counts.values(): total += n
	check(total == sim.city.population.total and counts == ConsumerMarket.populations(sim), "Deterministic segment counts reconcile")
	var poor: Dictionary = ConsumerMarket.district_segments(sim.catalog, 10000, 70)
	var rich: Dictionary = ConsumerMarket.district_segments(sim.catalog, 10000, 140)
	check(poor.budget > rich.budget and rich.premium > poor.premium and rich.budget > 0 and poor.premium > 0, "Income changes heterogeneous composition")
	var category: Dictionary = sim.catalog.categories.smartphones
	var segment: Dictionary = sim.catalog.segments.mainstream
	check(ConsumerMarket.potential(category, segment, 10000, 100, 100) > ConsumerMarket.potential(category, segment, 5000, 100, 100), "Population scales category demand")
	check(ConsumerMarket.potential(category, segment, 0, 100, 100) == 0, "Zero population no demand")
	var offers: Array[Dictionary] = [{"price": 30000, "reference_price": 24000, "quality": 50, "stock": 10000, "price_sensitivity": 2.0, "quality_sensitivity": 0.5}]
	var base: int = ConsumerDemand.allocate(1000, offers)[0]
	offers[0].price = 60000
	var budget: int = ConsumerDemand.allocate(1000, offers)[0]
	check(budget < base, "Higher price reduces budget demand")
	offers[0].price_sensitivity = 0.7
	check(ConsumerDemand.allocate(1000, offers)[0] > budget, "Affluent segment less price sensitive")
	offers[0].quality_sensitivity = 2.0
	var ordinary: int = ConsumerDemand.allocate(1000, offers)[0]
	offers[0].quality = 90
	check(ConsumerDemand.allocate(1000, offers)[0] > ordinary, "Quality increases premium demand")
	offers[0].stock = 0
	check(ConsumerDemand.allocate(1000, offers)[0] == 0, "Zero stock gets no allocation")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for corruption: String in ["duplicate", "category", "cycle", "year"]:
		var data: Dictionary = raw.duplicate(true)
		match corruption:
			"duplicate": data.products.append(data.products[0])
			"category": data.products[0].category = "missing"
			"cycle":
				data.products[0].inputs = {"display": 1}
				data.products[1].inputs = {"processor": 1}
			"year": data.technologies[0].year = -1
		var file: FileAccess = FileAccess.open("res://.godot/m6-invalid.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data("res://.godot/m6-invalid.json"), "Reject invalid catalog " + corruption)

func _operations(sim: Economy) -> void:
	var store: SimFacility = sim.facility("20_player")
	check(store.assortment.size() == 4, "Starting electronics assortment")
	check(not command(sim, store, "add_line", "detergent"), "Electronics rejects household category")
	check(command(sim, store, "add_line", "tablet") and command(sim, store, "add_line", "desktop"), "Fill assortment slots")
	check(not command(sim, store, "add_line", "smartwatch"), "Slot limit enforced")
	check(command(sim, store, "remove_line", "desktop"), "Remove line")
	check(command(sim, store, "set_price", "laptop", {"price": 67000}), "Set laptop price")
	check(store.price == 31000 and store.line_price("laptop") == 67000, "Independent prices")
	check(command(sim, store, "set_supplier", "laptop", {"supplier": "13_laptops"}), "Per-line supplier")
	for day: int in range(45): sim.step()
	check(int(store.line_sales.get("laptop", {}).get("units", 0)) > 0 and int(store.line_sales.get("smartphone", {}).get("units", 0)) > 0, "Independent replenishment and sales")
	check(sim.facility("21_rival").line_sales.size() >= 3, "AI operates several lines")
	var factory: SimFacility = sim.facility("13_laptops")
	check(not command(sim, factory, "set_price", "missing", {"price": 100}), "Factory price cannot create an invalid product line")
	var stock: Dictionary = factory.inventory.snapshot()
	check(not command(sim, factory, "set_production", "processor"), "Incompatible factory production rejected")
	check(command(sim, factory, "set_production", "tablet"), "Factory switches recipe")
	check(factory.inventory.snapshot() == stock, "Switch preserves every existing input/output")
	check(command(sim, store, "set_supplier", "tablet", {"supplier": factory.id}), "Source new factory output")
	# Switching must clear stale pins in other buyers as well as its own inputs.
	check(not store.suppliers.has("laptop"), "Supplier switch clears incompatible downstream pin")
	for day: int in range(30): sim.step()
	check(factory.inventory.quantity("tablet") > 0 and int(store.line_sales.get("tablet", {}).get("units", 0)) > 0, "Logistics feeds switched production and retail sells it")
	check(sim.invariant_errors().is_empty(), "Multi-product operations conserve accounting")
	var saved: Dictionary = sim.snapshot()
	var restored: Economy = SaveStore.new().restore(saved)
	check(restored != null and same(saved, restored.snapshot()), "Exact save with changed production and assortment")
	for corruption: String in ["slots", "price", "accounts", "history"]:
		var bad: Dictionary = saved.duplicate(true)
		match corruption:
			"slots":
				for f: Dictionary in bad.facilities:
					if f.id == store.id:
						for product: String in sim.catalog.facility_types.electronics_store.products: f.assortment[product] = 10
			"price": bad.facilities[0].assortment[bad.facilities[0].product] = -1
			"accounts": bad.companies[0].recorded_accounts.cash += 1
			"history": bad.companies[0].monthly_history.back().profit += 1
		check(SaveStore.new().restore(bad) == null, "Reject corrupt M6 " + corruption)

func _finance(sim: Economy) -> void:
	for owner: SimCompany in sim.companies.values():
		for period: String in ["current_month", "previous_month", "ttm", "year"]:
			var p: Dictionary = FinancialReports.period(owner, sim.clock, period)
			check(p.opening_cash + p.net_cash == p.closing_cash, "Cash reconciliation " + period)
			check(p.revenue - p.cogs == p.gross_profit and p.gross_profit - p.expenses == p.profit, "Income subtotals " + period)
		var b: Dictionary = FinancialReports.balance(sim, owner.id)
		check(b.assets == b.liabilities + b.equity and b.retained_earnings == owner.profit(), "Accounting equation and retained earnings")
	var session: GameSession = GameSession.new()
	session.sim = sim
	check(session.unlock_debug(DebugConfig.PASSWORD) and session.debug_action("cash", 1000000), "Debug capital adjustment")
	var owner: SimCompany = sim.companies.player
	var before: int = owner.profit()
	var sites: Array[Vector2i] = sim.city.valid_sites(2, 2)
	check(not sites.is_empty(), "Construction site")
	if not sites.is_empty():
		check(session.submit({"type": "build_facility", "archetype": "convenience_store", "product": "detergent", "x": sites[0].x, "y": sites[0].y}), "Build multi-category shop")
		check(owner.profit() == before, "Construction capitalized")
		sim.step()
		var p: Dictionary = FinancialReports.period(owner, sim.clock)
		check(p.investing_cash == -1000000 and p.financing_cash == 1000000, "Investing and financing classification")
		check(p.depreciation > 0 and p.opening_cash + p.net_cash == p.closing_cash, "Depreciation noncash reconciliation")
	check(sim.invariant_errors().is_empty(), "Balance after construction and capital adjustment")

func _replay(era: int) -> void:
	var a: Economy = Economy.new()
	check(a.initialize(42, era), "Era initialization")
	for day: int in range(90): a.step()
	var b: Economy = SaveStore.new().restore(a.snapshot())
	check(b != null, "Restore expanded era")
	if b == null: return
	var category_units: Dictionary = {}
	for day: int in range(1100):
		a.step()
		b.step()
		check(a.invariant_errors().is_empty(), "Daily long-run accounting")
		for category: String in a.category_market: category_units[category] = int(category_units.get(category, 0)) + int(a.category_market[category].units)
		if day % 100 == 0:
			check(same(a.snapshot(), b.snapshot()), "Exact deterministic continuation")
			for owner: SimCompany in a.companies.values():
				var p: Dictionary = FinancialReports.period(owner, a.clock, "ttm")
				check(p.profit == owner.ttm_profit(a.clock), "HUD TTM authoritative")
				check(p.opening_cash + p.net_cash == p.closing_cash, "Long-run rolling cash reconciliation")
	check(not a.companies.player.archived_months.is_empty(), "Older monthly financial history retained")
	check(same(a.snapshot(), b.snapshot()), "Final exact replay")
	print("M6 SOAK era=%d population=%d category_units=%s" % [era, a.city.population.total, category_units])
	for owner: SimCompany in a.companies.values(): print("M6 COMPANY ", owner.id, " revenue=", owner.revenue, " profit=", owner.profit(), " balance=", FinancialReports.balance(a, owner.id))
	var stock: Dictionary = {}
	for f: SimFacility in a.facilities:
		for product: String in f.inventory.quantities: stock[product] = int(stock.get(product, 0)) + f.inventory.quantity(product)
	print("M6 STOCK ", stock, " MARKET ", a.market)

func _period_boundaries() -> void:
	var owner: SimCompany = SimCompany.new({"id": "fixture", "name": "Fixture", "ai": false, "cash": 100000})
	var clock: SimClock = SimClock.new(2022)
	for day: int in range(364): clock.advance()
	owner.record_history(clock)
	owner.record_sale(10000, 4000)
	owner.retail_revenue += 10000
	owner.pay_expense(1000)
	owner.freight += 200
	owner.spend(2000)
	owner.production_cash += 2000
	owner.spend(3000)
	owner.capex += 3000
	owner.cash += 500
	owner.capital += 500
	owner.record_history(clock)
	var p: Dictionary = FinancialReports.period(owner, clock)
	check(p.revenue == 10000 and p.cogs == 4000 and p.gross_profit == 6000 and p.profit == 5000, "Known income statement amounts")
	check(p.operating_cash == 7000 and p.investing_cash == -3000 and p.financing_cash == 500 and p.net_cash == 4500, "Known cash flow classifications")
	check(p.opening_cash == 100000 and p.closing_cash == 104500, "Known cash opening and closing")
	clock.advance()
	owner.record_history(clock)
	check(owner.monthly_history.size() == 2 and owner.monthly_history.back().revenue == 0 and owner.monthly_history.back().opening_cash == 104500, "Year rollover opens zero current month at correct cash")
	check(FinancialReports.period(owner, clock, "previous_month").profit == 5000 and FinancialReports.period(owner, clock, "year").profit == 0, "Previous month and current year boundaries")
	owner.pay_expense(200)
	owner.record_history(clock)
	check(FinancialReports.period(owner, clock).profit == -200 and owner.ttm_profit(clock) == 4800, "Current month loss and TTM share history")
