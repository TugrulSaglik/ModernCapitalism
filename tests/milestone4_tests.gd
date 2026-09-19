extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a), "", true, true) == JSON.stringify(SaveStore.encode(b), "", true, true)

func fresh(era: int = 2022) -> GameSession:
	var session: GameSession = GameSession.new()
	check(session.start(era, 42, "sandbox", {"preset": "legacy"}), "Start logistics session")
	session.time.set_speed(0)
	return session

func build(s: GameSession, kind: String, x: int, y: int) -> SimFacility:
	var id: String = "built_%06d" % s.sim.city.next_facility
	check(s.submit({"type": "build_facility", "archetype": kind, "product": "smartphone", "x": x, "y": y}), "Build " + kind)
	return s.sim.facility(id)

func seed_stock(sim: Economy, f: SimFacility, product: String, quantity: int, value: int) -> void:
	f.inventory.add(product, quantity, value)
	sim.companies[f.company_id].spend(value)

func _initialize() -> void:
	_routes_shipments()
	_warehouses()
	_replenishment_sourcing()
	_finance()
	_replay()
	print("M4 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _routes_shipments() -> void:
	var s: GameSession = fresh()
	var sim: Economy = s.sim
	var source: SimFacility = sim.facility("10_orion")
	var destination: SimFacility = sim.facility("20_player")
	var quote: Dictionary = sim.logistics.quote(sim, source.id, destination.id, 4)
	check(quote.distance == 13, "Road BFS includes two facility access legs")
	check(quote.freight == 100 + quote.distance * 8 and quote.lead_days == 1, "Transparent freight and nonzero lead")
	check(same(quote, sim.logistics.quote(sim, source.id, destination.id, 4)), "Repeatable route quote")
	seed_stock(sim, source, "smartphone", 10, 10000)
	var cash: int = sim.companies.player.cash
	check(sim.trade(source, destination, "smartphone", 4) == 4, "Shipment created")
	check(source.inventory.quantity("smartphone") == 6 and destination.inventory.quantity("smartphone") == 0, "Departure removes source only")
	check(sim.logistics.assets("player") == 96000 and sim.inventory_assets("player") == 96000, "In-transit asset is buyer purchase value")
	check(sim.companies.player.cash == cash - 96000 - quote.freight and sim.companies.player.freight == quote.freight, "Purchase plus freight paid")
	check(sim.companies.maker_a.revenue == 96000 and sim.companies.maker_a.cogs == 4000, "Seller sale recognized at departure")
	sim.logistics.deliver(sim)
	check(destination.inventory.quantity("smartphone") == 0, "No instantaneous delivery")
	sim.clock.advance()
	sim.logistics.deliver(sim)
	check(destination.inventory.quantity("smartphone") == 4 and sim.logistics.shipments[0].status == "delivered", "Arrival at exact promised tick")
	sim.logistics.deliver(sim)
	check(destination.inventory.quantity("smartphone") == 4 and sim.invariant_errors().is_empty(), "Delivery idempotence and balance")
	sim.city.roads.clear()
	var before: Dictionary = sim.snapshot()
	check(sim.trade(source, destination, "smartphone", 1) == 0 and same(before, sim.snapshot()), "Unreachable route rejects atomically")

func _warehouses() -> void:
	var s: GameSession = fresh()
	var factory: SimFacility = build(s, "assembly_plant", 24, 10)
	var warehouse: SimFacility = build(s, "warehouse", 24, 3)
	var store: SimFacility = s.sim.facility("20_player")
	seed_stock(s.sim, factory, "smartphone", 150, 150000)
	var revenue: int = s.sim.companies.player.revenue
	var order: Dictionary = {"type": "transfer", "facility": factory.id, "destination": warehouse.id, "product": "smartphone", "quantity": 100}
	check(s.submit(order), "Owned warehouse inbound transfer")
	check(s.sim.logistics.free_capacity(s.sim, warehouse) == 0, "Inbound stock reserves capacity")
	order.quantity = 1
	check(not s.submit(order), "Reserved capacity prevents overfill")
	check(not s.submit({"type": "demolish_facility", "facility": warehouse.id}), "Active shipment protects destination")
	check(s.sim.companies.player.revenue == revenue and s.sim.logistics.assets("player") == 100000, "Internal transfer retains cost without revenue")
	for day: int in range(3):
		s.sim.clock.advance()
		s.sim.logistics.deliver(s.sim)
	check(s.sim.logistics.used(warehouse) == 100 and warehouse.inventory.quantity("smartphone") == 100, "Warehouse receives inbound stock")
	check(s.submit({"type": "transfer", "facility": warehouse.id, "destination": store.id, "product": "smartphone", "quantity": 40}), "Warehouse outbound transfer")
	check(warehouse.inventory.quantity("smartphone") == 60, "Outbound removes exact stock")
	check(not s.submit({"type": "transfer", "facility": warehouse.id, "destination": store.id, "product": "smartphone", "quantity": 61}), "No inventory overdraw")
	check(not s.submit({"type": "transfer", "facility": warehouse.id, "destination": "21_rival", "product": "smartphone", "quantity": 1}), "Manual internal orders enforce ownership")
	check(s.sim.invariant_errors().is_empty(), "Warehouse accounting invariants")
	seed_stock(s.sim, warehouse, "battery", 5, 500)
	check(s.sim.logistics.used(warehouse) == 65, "Multi-product capacity counts all goods")

func _replenishment_sourcing() -> void:
	var s: GameSession = fresh()
	var sim: Economy = s.sim
	var buyer: SimFacility = sim.facility("20_player")
	var a: SimFacility = sim.facility("10_orion")
	var b: SimFacility = sim.facility("11_nova")
	seed_stock(sim, a, "smartphone", 100, 10000)
	seed_stock(sim, b, "smartphone", 100, 10000)
	a.quality = 50
	b.quality = 50
	a.price = 24000
	b.price = 24000
	var offers: Array[Dictionary] = sim.supplier_offers(buyer.id, "smartphone")
	check(offers[0].id == a.id and offers[0].landed < offers[1].landed, "Freight influences equal-price quality ranking")
	sim.city.plots[b.id] = sim.city.plots[a.id].duplicate(true)
	check(sim.supplier_offers(buyer.id, "smartphone")[0].id == a.id, "True ties use stable ID")
	b.quality = 90
	check(sim.supplier_offers(buyer.id, "smartphone")[0].id == b.id, "Quality remains influential")
	buyer.suppliers.smartphone = a.id
	sim._source(buyer, "smartphone", 48)
	check(sim.logistics.shipments.back().source == a.id, "Manual override survives ranking")
	var count: int = sim.logistics.shipments.size()
	sim._source(buyer, "smartphone", 48)
	check(sim.logistics.shipments.size() == count and sim.logistics.incoming(buyer.id) == 48, "Incoming inventory prevents repeated orders")
	var inputs: GameSession = fresh()
	inputs.sim.step()
	check(inputs.sim.logistics.incoming("10_orion", "processor") > 0 and inputs.sim.facility("10_orion").produced_today == 0, "Factories wait for input delivery")
	for day: int in range(8): inputs.sim.step()
	check(inputs.sim.facility("10_orion").produced_today > 0, "Factory production resumes after input arrival")
	var warehouse: SimFacility = build(inputs, "warehouse", 24, 3)
	check(inputs.submit({"type": "set_warehouse_target", "facility": warehouse.id, "product": "smartphone", "quantity": 30}), "Warehouse automatic target command")
	inputs.sim.step()
	check(inputs.sim.logistics.incoming(warehouse.id) + inputs.sim.logistics.used(warehouse) <= 30, "Warehouse automatic target bounded")

func _finance() -> void:
	var s: GameSession = fresh()
	var owner: SimCompany = s.sim.companies.player
	var cash: int = owner.cash
	var f: SimFacility = build(s, "warehouse", 24, 3)
	check(owner.cash == cash - f.asset_cost and owner.profit() == 0 and s.sim.fixed_assets("player") == f.asset_cost, "Construction capitalized without operating loss")
	s.sim.step()
	check(f.accumulated_depreciation == f.asset_cost / 3650 and owner.depreciation == f.accumulated_depreciation, "Daily straight-line depreciation")
	check(s.sim.invariant_errors().is_empty(), "Fixed-asset balance")
	var company: SimCompany = SimCompany.new({"id": "test", "name": "Test", "ai": false, "cash": 1000000})
	var clock: SimClock = SimClock.new(2022)
	for day: int in range(31):
		company.record_sale(100, 0)
		company.record_history(clock)
		clock.advance()
	company.record_history(clock)
	check(company.monthly_history.size() == 2 and company.monthly_history[0].profit == 3100 and company.monthly_history[1].profit == 0, "Month rollover retains completed and starts zero current bar")
	company.pay_expense(200)
	company.record_history(clock)
	check(company.monthly_history[1].profit == -200 and company.ttm_profit(clock) == 2900, "Incomplete month updates daily and negative profit preserved")
	while clock.year == 2022:
		clock.advance()
		company.record_history(clock)
	check(company.ttm_profit(clock) == 2800, "TTM drops same date prior year at daily boundary")
	var leap: SimClock = SimClock.new(2024)
	for day: int in range(59): leap.advance()
	check(leap.date_string() == "2024-02-29", "Leap boundary fixture")
	company.daily_history = [{"date": "2023-02-28", "profit": 100}, {"date": "2023-03-01", "profit": 200}]
	check(company.ttm_profit(leap) == 200, "Leap TTM cutoff clamps to February 28")

func _replay() -> void:
	for era: int in [2012, 2022]:
		var a: GameSession = fresh(era)
		build(a, "warehouse", 24, 3)
		build(a, "assembly_plant", 24, 10)
		for day: int in range(20): a.sim.step()
		check(a.sim.logistics.shipments.any(func(s: Dictionary) -> bool: return s.status == "in_transit"), "Replay fixture has active shipments")
		check(a.save_game("res://.godot/m4-replay.json"), "Save in transit")
		var b: GameSession = fresh(era)
		check(b.load_game("res://.godot/m4-replay.json"), "Load in transit: " + b.message)
		check(same(a.snapshot(), b.snapshot()), "Exact logistics/history/asset roundtrip")
		var saved: Dictionary = a.sim.snapshot()
		for field: String in ["quantity", "arrival", "company"]:
			var corrupt: Dictionary = saved.duplicate(true)
			var active: Dictionary = corrupt.logistics.shipments.filter(func(s: Dictionary) -> bool: return s.status == "in_transit")[0]
			if field == "company": active.company = "missing"
			else: active[field] = -1
			check(SaveStore.new().restore(corrupt) == null, "Reject corrupt shipment " + field)
		for day: int in range(3650):
			a.sim.step()
			b.sim.step()
			check(a.sim.invariant_errors().is_empty() and b.sim.invariant_errors().is_empty(), "M4 daily invariants")
			if day % 365 == 0: check(same(a.sim.snapshot(), b.sim.snapshot()), "M4 replay yearly checkpoint")
		check(same(a.sim.snapshot(), b.sim.snapshot()), "M4 exact final replay")
		print("M4 SOAK era=%d days=3650 units=%d freight=%d" % [era, a.sim.cumulative_consumer_units, a.sim.companies.player.freight])
