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
	_advertising_and_accounting()
	_separation_and_market()
	_persistence()
	_ui()
	print("M8A1 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _advertising_and_accounting() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize advertising economy")
	var owner: SimCompany = sim.companies.player
	var product: String = "smartphone"
	var start_cash: int = owner.cash
	sim._advertise()
	check(owner.cash == start_cash and owner.advertising_expense == 0 and owner.advertising_progress[product] == 0, "Zero budget spends nothing")
	var request: Dictionary = {"type": "set_advertising_budget", "company": "player", "product": product, "budget": 1234}
	check(sim.command_error(request).is_empty(), "Valid advertising command")
	check(not sim.command_error({"type": "set_advertising_budget", "company": "missing", "product": product, "budget": 1}).is_empty(), "Unknown company rejected")
	check(not sim.command_error({"type": "set_advertising_budget", "company": "player", "product": "processor", "budget": 1}).is_empty(), "Nonconsumer rejected")
	check(not sim.command_error({"type": "set_advertising_budget", "company": "player", "product": product, "budget": -1}).is_empty(), "Negative budget rejected")
	sim.queue_command(request)
	sim.process_commands()
	check(owner.advertising_budgets[product] == 1234, "Budget command applies")
	sim._advertise()
	check(start_cash - owner.cash == 1234 and owner.advertising_expense == 1234 and owner.cash_expenses == 1234 and owner.expenses == 1234, "Funded budget is separate cash operating expense")
	check(owner.advertising_progress[product] == 1234, "Progress accumulates")
	owner.cash = 1233
	owner.capital = owner.cash - owner.profit()
	sim._advertise()
	check(owner.cash == 1233 and owner.advertising_progress[product] == 1234, "Insufficient cash spends nothing")
	owner.cash = 100000000
	owner.capital = owner.cash - owner.profit()
	var threshold: int = sim.advertising_threshold(product, owner.brand(product))
	owner.advertising_progress[product] = threshold - 10
	owner.advertising_budgets[product] = 15
	var brand: int = owner.brand(product)
	sim._advertise()
	check(owner.brand(product) == brand + 1 and owner.advertising_progress[product] == 5, "Threshold grows brand and retains excess")
	owner.product_brands[product] = 99
	threshold = sim.advertising_threshold(product, 99)
	owner.advertising_progress[product] = threshold * 3
	owner.advertising_budgets[product] = 1
	sim._advertise()
	check(owner.brand(product) == 100 and owner.advertising_progress[product] >= 0, "Brand cannot exceed 100")
	owner.advertising_budgets[product] = 0
	var stopped_cash: int = owner.cash
	sim._advertise()
	check(owner.cash == stopped_cash, "Budget can be stopped")
	check(sim.invariant_errors().is_empty(), "Advertising accounting identity")
	var accounting: Economy = Economy.new()
	check(accounting.initialize(), "Initialize reporting economy")
	accounting.companies.player.advertising_budgets[product] = 100
	accounting.step()
	var period: Dictionary = FinancialReports.period(accounting.companies.player, accounting.clock)
	check(period.advertising_expense == 100 and period.operating_cash == period.revenue - period.purchases - period.production_cash - period.cash_expenses, "Advertising appears separately in operating cash flow")
	check(period.profit == period.revenue - period.cogs - period.expenses and FinancialReports.balance(accounting, "player").retained_earnings == accounting.companies.player.profit(), "Profit and retained earnings reconcile")

func _separation_and_market() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize separation economy")
	var owner: SimCompany = sim.companies.player
	var product: String = "smartphone"
	var inventory: Array = []
	for f: SimFacility in sim.facilities: inventory.append(f.inventory.snapshot())
	var quality_levels: Dictionary = owner.product_quality_levels.duplicate(true)
	var process_levels: Dictionary = owner.process_efficiency_levels.duplicate(true)
	var local: Dictionary = sim.catalog.local_values(product).duplicate(true)
	owner.advertising_budgets[product] = sim.advertising_threshold(product, owner.brand(product))
	sim._advertise()
	var after_inventory: Array = []
	for f: SimFacility in sim.facilities: after_inventory.append(f.inventory.snapshot())
	check(same(inventory, after_inventory), "Advertising leaves physical quality unchanged")
	check(same(quality_levels, owner.product_quality_levels) and same(process_levels, owner.process_efficiency_levels), "Advertising leaves R&D levels unchanged")
	check(same(local, sim.catalog.local_values(product)), "Advertising leaves Local values unchanged")
	var low: Array[int] = ConsumerDemand.allocate(1000, [{"price": 100, "reference_price": 100, "quality": 50, "brand": 20, "stock": 1000}, {"price": 100, "reference_price": 100, "quality": 50, "brand": 50, "stock": 1000}])
	var high: Array[int] = ConsumerDemand.allocate(1000, [{"price": 100, "reference_price": 100, "quality": 50, "brand": 80, "stock": 1000}, {"price": 100, "reference_price": 100, "quality": 50, "brand": 50, "stock": 1000}])
	check(high[0] > low[0], "Higher corporate brand increases share")
	check(low[0] + low[1] < 1000 and high[0] + high[1] < 1000, "Outside option semantics unchanged")

func _persistence() -> void:
	var a: Economy = Economy.new()
	check(a.initialize(), "Initialize persistence economy")
	var owner: SimCompany = a.companies.player
	var product: String = "smartphone"
	var threshold: int = a.advertising_threshold(product, owner.brand(product))
	owner.advertising_budgets[product] = maxi(1, threshold / 4)
	owner.advertising_progress[product] = 7
	var store: SaveStore = SaveStore.new()
	var b: Economy = store.restore(a.snapshot())
	check(b != null and same(a.snapshot(), b.snapshot()), "Budget and partial progress restore exactly")
	if b != null:
		var increase_day_a: int = -1
		var increase_day_b: int = -1
		var initial_brand: int = owner.brand(product)
		for day: int in range(10):
			a.step()
			b.step()
			if increase_day_a < 0 and a.companies.player.brand(product) > initial_brand: increase_day_a = day
			if increase_day_b < 0 and b.companies.player.brand(product) > initial_brand: increase_day_b = day
		check(increase_day_a >= 0 and increase_day_a == increase_day_b and same(a.snapshot(), b.snapshot()), "Continuation reaches brand point on same day")
	for field: String in ["advertising_budgets", "advertising_progress"]:
		var bad: Dictionary = a.snapshot()
		bad.companies[0][field].smartphone = -1
		check(SaveStore.new().restore(bad) == null, "Reject negative " + field)
	var unknown: Dictionary = a.snapshot()
	unknown.companies[0].advertising_budgets.missing = 1
	check(SaveStore.new().restore(unknown) == null, "Reject unknown advertising product")

func _ui() -> void:
	var session: GameSession = GameSession.new()
	check(session.start(), "Initialize UI session")
	var reports: CompanyReports = CompanyReports.new()
	reports._ready()
	reports.session = session
	reports.tabs.current_tab = 3
	reports.refresh()
	check(reports.advertising_budget.visible and reports.apply_advertising.visible and reports.products.item_count > 0, "Markets exposes advertising controls")
	reports.free()
