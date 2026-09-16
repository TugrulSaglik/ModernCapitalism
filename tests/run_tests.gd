extends SceneTree

const Simulation = preload("res://src/sim/economy.gd")
const Inventory = preload("res://src/sim/inventory.gd")
const Demand = preload("res://src/sim/demand.gd")
const Clock = preload("res://src/sim/sim_clock.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func fresh(era: int = 2022, seed_value: int = 42) -> Economy:
	var sim: Economy = Simulation.new()
	check(sim.initialize(seed_value, era), "Initialize economy")
	return sim

func _initialize() -> void:
	var startup: Economy = Simulation.new()
	if not startup.initialize():
		printerr("FAIL: Economy startup; aborting dependent tests")
		quit(1)
		return
	_test_inventory()
	_test_production()
	_test_trade_and_sales()
	_test_demand()
	_test_eras_and_clock()
	_test_commands()
	_test_determinism_and_soak()
	print("TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_inventory() -> void:
	var stock: SimInventory = Inventory.new()
	check(not stock.add("processor", -1, 100), "Reject negative inventory addition")
	check(stock.add("processor", 3, 100), "Add inventory")
	check(stock.remove("processor", 4) == -1 and stock.quantity("processor") == 3, "Overdraw is atomic")
	check(stock.remove("processor", -1) == -1, "Reject negative removal")
	check(stock.remove("processor", 1) == 33, "Proportional cost removal")
	check(stock.remove("processor", 2) == 67 and stock.total_value() == 0, "Final removal preserves rounding cents")

func _test_production() -> void:
	var sim: Economy = fresh()
	var factory: SimFacility = sim.facility("10_orion")
	var owner: SimCompany = sim.companies[factory.company_id]
	check(sim.produce(factory) == 0, "Missing inputs prevent output")
	# Opening stock is purchased externally at its book value for this unit fixture.
	for product: String in ["processor", "display", "battery"]:
		factory.inventory.add(product, 3, 300)
		owner.spend(300)
	var cash_before: int = owner.cash
	check(sim.produce(factory) == 3, "Input-limited batch produced")
	check(factory.inventory.quantity("processor") == 0 and factory.inventory.quantity("display") == 0 and factory.inventory.quantity("battery") == 0, "Recipe inputs consumed exactly")
	check(factory.inventory.quantity("smartphone") == 3, "Output units correct")
	check(owner.cash == cash_before - 9000 and factory.inventory.value("smartphone") == 9900, "Conversion cost capitalized")
	check(owner.profit() == 0 and sim.invariant_errors().is_empty(), "Production preserves balance and does not double expense inputs")
	owner.cash = 0
	check(sim.produce(factory) == 0, "No unfunded production")
	var source_sim: Economy = fresh()
	var source: SimFacility = source_sim.facility("01_processors")
	check(source_sim.produce(source) == 55 and source_sim.produce(source) == 0, "Repeated calls cannot exceed daily capacity")

func _test_trade_and_sales() -> void:
	var sim: Economy = fresh()
	var seller: SimFacility = sim.facility("10_orion")
	var buyer: SimFacility = sim.facility("20_player")
	var source_owner: SimCompany = sim.companies[seller.company_id]
	var retail_owner: SimCompany = sim.companies[buyer.company_id]
	seller.inventory.add("smartphone", 10, 150000)
	source_owner.spend(150000)
	var total_cash: int = source_owner.cash + retail_owner.cash
	check(sim.trade(seller, buyer, "smartphone", 4) == 4, "Wholesale quantity")
	check(seller.inventory.quantity("smartphone") == 6 and buyer.inventory.quantity("smartphone") == 0 and sim.logistics.incoming(buyer.id, "smartphone") == 4, "Wholesale inventory transfer")
	check(source_owner.cash + retail_owner.cash == total_cash - retail_owner.freight, "Wholesale cash conservation")
	check(source_owner.revenue == 96000 and source_owner.cogs == 60000 and source_owner.profit() == 36000, "Wholesale revenue and COGS")
	for day: int in range(sim.logistics.shipments[0].arrival): sim.clock.advance()
	sim.logistics.deliver(sim)
	var cash_before: int = retail_owner.cash
	check(sim.consumer_sale(buyer, 2) == 2, "Consumer sale quantity")
	check(buyer.inventory.quantity("smartphone") == 2 and retail_owner.cash == cash_before + 62000, "Retail transfers goods and consumer money")
	check(retail_owner.revenue == 62000 and retail_owner.cogs == 48000 and retail_owner.profit() == 14000 - retail_owner.freight, "Retail accounting")
	check(retail_owner.pay_expense(1000) and retail_owner.profit() == 13000 - retail_owner.freight, "Overhead reduces profit and cash")
	check(sim.invariant_errors().is_empty(), "Trade and retail balance sheets")
	check(sim.consumer_sale(buyer, 100) == 2 and sim.consumer_sale(buyer, 1) == 0, "Sales cannot exceed stock")
	check(not retail_owner.pay_expense(retail_owner.cash + 1), "No cash overdraft")
	buyer.city_id = "elsewhere"
	check(sim.trade(seller, buyer, "smartphone", 1) == 0, "Cross-city instant trade rejected")
	buyer.city_id = seller.city_id
	retail_owner.cash = 100
	check(sim.trade(seller, buyer, "smartphone", 1) == 0, "Unaffordable trade rejected")
	var internal: Economy = fresh()
	var internal_seller: SimFacility = internal.facility("10_orion")
	var internal_buyer: SimFacility = internal.facility("11_nova")
	internal_buyer.company_id = internal_seller.company_id
	internal_seller.inventory.add("smartphone", 2, 100)
	var internal_owner: SimCompany = internal.companies[internal_seller.company_id]
	internal_owner.spend(100)
	check(internal.trade(internal_seller, internal_buyer, "smartphone", 2) == 2 and internal_owner.revenue == 0 and internal.logistics.assets(internal_owner.id) == 100 and internal_buyer.inventory.value("smartphone") == 0, "Internal transfer preserves book cost without revenue")
	check(internal.invariant_errors().is_empty(), "Internal transfer balance")

func _units(price: int, quality: int) -> int:
	var offers: Array[Dictionary] = [{"price": price, "reference_price": 24000, "quality": quality, "stock": 10000}]
	return Demand.allocate(1000, offers)[0]

func _test_demand() -> void:
	check(_units(20000, 50) > _units(40000, 50), "Demand falls with price")
	check(_units(30000, 80) > _units(30000, 30), "Demand rises with quality")
	var offers: Array[Dictionary] = [
		{"price": 30000, "reference_price": 24000, "quality": 50, "stock": 1000},
		{"price": 30000, "reference_price": 24000, "quality": 50, "stock": 1000}]
	var allocated: Array[int] = Demand.allocate(100, offers)
	check(absi(allocated[0] - allocated[1]) <= 1 and allocated[0] + allocated[1] <= 100, "Finite demand and symmetric competition")
	offers[0].stock = 0
	check(Demand.allocate(100, offers)[0] == 0, "Stockouts receive no sales")

func _test_eras_and_clock() -> void:
	var early: Economy = fresh(2012)
	var late: Economy = fresh(2022)
	check(early.catalog.available("smartphone", 2012), "Baseline phone available in 2012")
	check(not early.catalog.available("advanced_phone", 2012) and late.catalog.available("advanced_phone", 2022), "Era gates differ")
	check(not early.catalog.available("advanced_phone", 2019) and early.catalog.available("advanced_phone", 2020), "Availability progresses with year")
	for tick: int in range(30):
		early.step()
		late.step()
	check(early.facility("12_advanced").inventory.quantity("advanced_phone") == 0, "Locked product not produced")
	check(late.market.advanced_phone.units > 0, "Later-era product reaches consumers")
	var calendar: SimClock = Clock.new(2012)
	for day: int in range(59):
		calendar.advance()
	check(calendar.date_string() == "2012-02-29", "Gregorian leap day")
	for day: int in range(307):
		calendar.advance()
	check(calendar.date_string() == "2013-01-01", "Gregorian year rollover")
	check(not late.initialize(42, 2018), "Unsupported starting era rejected")

func _test_commands() -> void:
	var sim: Economy = fresh()
	sim.queue_command({"type": "set_price", "company": "player", "facility": "20_player", "price": 33000})
	check(sim.facility("20_player").price == 31000, "Commands wait for tick")
	sim.step()
	check(sim.facility("20_player").price == 33000 and sim.command_results[0].accepted, "Command applied at boundary")
	sim.queue_command({"type": "set_price", "company": "rival", "facility": "20_player", "price": 1})
	sim.queue_command({"type": "set_price", "company": "player", "facility": "20_player", "price": -1})
	sim.step()
	check(sim.facility("20_player").price == 33000 and not sim.command_results[0].accepted and not sim.command_results[1].accepted, "Reject wrong owner and invalid price")
	var detached: Dictionary = sim.snapshot()
	detached.companies[0].cash = -1
	check(sim.invariant_errors().is_empty(), "Snapshot is detached")

func _test_determinism_and_soak() -> void:
	for era: int in [2012, 2022]:
		var a: Economy = fresh(era, 73)
		var b: Economy = fresh(era, 73)
		var c: Economy = fresh(era, 74)
		var demand_differs: bool = false
		for tick: int in range(365):
			if tick == 80:
				var command: Dictionary = {"type": "set_price", "company": "player", "facility": "20_player", "price": 32000}
				a.queue_command(command)
				b.queue_command(command)
				c.queue_command(command)
			a.step()
			b.step()
			c.step()
			check(JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()), "Same seed/actions identical at tick %d era %d" % [tick, era])
			check(a.invariant_errors().is_empty() and c.invariant_errors().is_empty(), "Daily solvency and inventory invariants")
			if a.market.smartphone.potential != c.market.smartphone.potential:
				demand_differs = true
		check(demand_differs, "Different seeds change demand")
		check(a.cumulative_consumer_units > 1000, "Sustained consumer activity")
		check(a.facility("21_rival").price != 30000, "AI participates through price decisions")
		print("SOAK era=%d date=%s consumer_units=%d consumer_revenue_cents=%d" % [era, a.clock.date_string(), a.cumulative_consumer_units, a.cumulative_consumer_revenue])
		for owner: SimCompany in a.companies.values():
			print("  %s cash=%d profit=%d assets=%d" % [owner.id, owner.cash, owner.profit(), a.inventory_assets(owner.id)])
