extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var sim: Economy = Economy.new()
	_check(sim.initialize(42, 2022), "initialize", failures)
	if failures.is_empty():
		_check(sim.cities.size() == 3, "three cities", failures)
		_check(sim.city == sim.cities["metro"] and sim.real_estate == sim.real_estates["metro"], "primary aliases", failures)
		for city_id: String in sim.cities:
			_check(sim.cities[city_id].valid_port(), "port " + city_id, failures)
			_check(sim.cities[city_id].generation.seed == str(42 + int(sim.city_definition(city_id).seed_offset)), "seed " + city_id, failures)
		var first: SimFacility = sim.facilities[0]
		var metro: CityMap = sim.cities["metro"]
		var harbor: CityMap = sim.cities["harbor"]
		_check(metro != harbor and sim.real_estates["metro"] != sim.real_estates["harbor"], "independent state", failures)
		var local_quote: Dictionary = sim.logistics.quote(sim, first.id, sim.facilities[1].id, 1)
		_check(local_quote.mode == "local", "local quote", failures)
		var candidate: SimFacility = null
		for f: SimFacility in sim.facilities:
			if f.city_id == "metro" and sim.regional_trade.quote(sim, f.id, f.product_id, 1, "export").size() > 0 and f.inventory.quantity(f.product_id) > 0:
				candidate = f
				break
		if candidate != null:
			var product: String = candidate.product_id
			var q: Dictionary = sim.regional_trade.quote(sim, candidate.id, product, 1, "export")
			_check(q.price == int(sim.catalog.products[product].reference_price) * 110 / 100, "export price", failures)
			var revenue_before: int = sim.companies[candidate.company_id].export_revenue
			var cmd: Dictionary = {"type": "export_goods", "company": candidate.company_id, "facility": candidate.id, "product": product, "quantity": 1}
			_check(sim.command_error(cmd).is_empty(), "export command", failures)
			if sim.command_error(cmd).is_empty():
				sim.queue_command(cmd)
				sim.process_commands()
				_check(sim.companies[candidate.company_id].export_revenue == revenue_before + q.price, "export accounting", failures)
		_check(sim.invariant_errors().is_empty(), "initial invariants " + str(sim.invariant_errors()), failures)
		for day: int in range(3): sim.step()
		_check(sim.invariant_errors().is_empty(), "daily invariants " + str(sim.invariant_errors()), failures)
		var smartphone_units: int = 0
		var smartphone_local: int = 0
		var smartphone_revenue: int = 0
		for city_id: String in sim.cities:
			var city_market: Dictionary = sim.market_by_city[city_id].smartphone
			_check(int(city_market.local_units) > 0, "independent Local: " + city_id, failures)
			_check(sim.market_history_by_city[city_id].size() == 3, "isolated history: " + city_id, failures)
			smartphone_units += int(city_market.units)
			smartphone_local += int(city_market.local_units)
			smartphone_revenue += int(city_market.revenue)
		_check(sim.market.smartphone.units == smartphone_units and sim.market.smartphone.local_units == smartphone_local and sim.market.smartphone.revenue == smartphone_revenue, "regional product sums", failures)
		_check(is_equal_approx(float(sim.market.smartphone.average_price), float(smartphone_revenue) / maxi(1, smartphone_units)), "weighted regional price", failures)
		_check(sim.strategic_ai.market_opportunity(sim, "player", "smartphone", "metro") != sim.strategic_ai.market_opportunity(sim, "player", "smartphone", "harbor"), "city opportunity", failures)
		var store: SaveStore = SaveStore.new()
		var restored: Economy = store.restore(sim.snapshot())
		_check(restored != null, "restore: " + store.error, failures)
		if restored != null:
			_check(restored.snapshot() == sim.snapshot(), "exact state", failures)
			for day: int in range(2):
				sim.step()
				restored.step()
			_check(restored.snapshot() == sim.snapshot(), "continuation", failures)
		var session: GameSession = GameSession.new()
		_check(session.start(), "session start", failures)
		_check(session.select_city("harbor") and session.active_city == "harbor", "city selector", failures)
		_check(not session.select_city("unknown"), "unknown city rejected", failures)
		var legacy: Economy = Economy.new()
		_check(legacy.initialize(42, 2022, "res://data/example_economy.json", {"preset": "legacy"}), "legacy initialize", failures)
		_check(legacy.cities.size() == 1 and legacy.city.port.is_empty(), "legacy one city", failures)
		_regional_checks(failures)
	if failures.is_empty():
		print("Milestone 11 focused core: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("Milestone 11 focused core: FAIL (%d)" % failures.size())
		quit(1)

func _check(condition: bool, name: String, failures: Array[String]) -> void:
	if not condition: failures.append(name)

func _regional_checks(failures: Array[String]) -> void:
	var sim: Economy = Economy.new()
	if not sim.initialize(42, 2022):
		failures.append("regional fixture")
		return
	var harbor_site: Vector2i = sim.cities["harbor"].valid_sites(3, 2)[0]
	var harbor_id: String = "built_%06d" % sim.next_facility_id
	var build: Dictionary = {"type": "build_facility", "company": "player", "city": "harbor", "archetype": "electronics_store", "product": "smartphone", "x": harbor_site.x, "y": harbor_site.y}
	_check(sim.command_error(build).is_empty(), "Harbor construction", failures)
	sim.queue_command(build)
	sim.process_commands()
	var buyer: SimFacility = sim.facility(harbor_id)
	if buyer == null:
		failures.append("Harbor facility created")
		return
	_check(buyer.city_id == "harbor" and sim.cities["harbor"].plots.has(harbor_id), "Harbor footprint", failures)
	var highland_site: Vector2i = sim.cities["highland"].valid_sites(3, 2)[0]
	var second_id: String = "built_%06d" % sim.next_facility_id
	var second_build: Dictionary = {"type": "build_facility", "company": "player", "city": "highland", "archetype": "electronics_store", "product": "smartphone", "x": highland_site.x, "y": highland_site.y}
	_check(sim.command_error(second_build).is_empty(), "Highland construction", failures)
	sim.queue_command(second_build)
	sim.process_commands()
	_check(sim.facility(second_id) != null and second_id != harbor_id, "global facility IDs", failures)
	var seller: SimFacility = sim.facility("10_orion")
	seller.inventory.add("smartphone", 5, 0, 50)
	var q: Dictionary = sim.logistics.quote(sim, seller.id, buyer.id, 3)
	_check(q.mode == "regional" and q.regional_leg == 140 and q.source_leg == sim.city.road_distance_to_port(seller.id) and q.destination_leg == sim.cities["harbor"].road_distance_to_port(buyer.id), "regional legs", failures)
	_check(q.distance == q.source_leg + q.regional_leg + q.destination_leg, "regional total", failures)
	var buyer_cash: int = sim.companies["player"].cash
	var shipped: int = sim.logistics.dispatch(sim, seller, buyer, "smartphone", 3)
	_check(shipped == 3, "regional dispatch", failures)
	_check(sim.logistics.shipments.back().mode == "regional" and sim.logistics.shipments.back().company == "player" and sim.logistics.shipments.back().regional_distance == 140, "regional shipment metadata", failures)
	_check(sim.companies["player"].cash == buyer_cash - 3 * seller.price - q.freight, "regional buyer cash", failures)
	var import_quote: Dictionary = sim.regional_trade.quote(sim, buyer.id, "smartphone", 2, "import")
	_check(import_quote.price == (int(sim.catalog.products.smartphone.reference_price) * 125 + 99) / 100, "import 125 percent", failures)
	var offers: Array[Dictionary] = sim.supplier_offers(buyer.id, "smartphone")
	var import_offer: bool = false
	for offer: Dictionary in offers:
		if offer.id == "import:harbor": import_offer = true
	_check(import_offer, "synthetic import offer", failures)
	var import_command: Dictionary = {"type": "import_goods", "company": "player", "facility": buyer.id, "product": "smartphone", "quantity": 2}
	_check(sim.command_error(import_command).is_empty(), "manual import command", failures)
	var purchases: int = sim.companies["player"].import_purchases
	sim.queue_command(import_command)
	sim.process_commands()
	_check(sim.companies["player"].import_purchases == purchases + 2 * import_quote.price, "import accounting", failures)
	_check(sim.logistics.shipments.back().mode == "import" and sim.logistics.assets("player") >= 2 * import_quote.price, "import asset", failures)
	_check(sim.regional_trade.import_remaining(sim, "harbor", "smartphone") == 98, "shared import capacity", failures)
	_check(not sim.command_error({"type": "import_goods", "company": "player", "facility": buyer.id, "product": "smartphone", "quantity": 99}).is_empty(), "import cap rejects overflow", failures)
	var export_command: Dictionary = {"type": "export_goods", "company": "maker_a", "facility": seller.id, "product": "smartphone", "quantity": 1}
	_check(sim.command_error(export_command).is_empty(), "export command", failures)
	var export_revenue: int = sim.companies["maker_a"].export_revenue
	sim.queue_command(export_command)
	sim.process_commands()
	_check(sim.companies["maker_a"].export_revenue == export_revenue + sim.regional_trade.export_price(sim, "smartphone"), "export revenue", failures)
	_check(sim.logistics.shipments.back().status == "exported", "export nonasset", failures)
	_check(sim.invariant_errors().is_empty(), "regional invariants " + str(sim.invariant_errors()), failures)
	var restored: Economy = SaveStore.new().restore(sim.snapshot())
	_check(restored != null, "regional restore", failures)
	if restored != null: _check(restored.snapshot() == sim.snapshot(), "regional exact restore", failures)
	var bad: Dictionary = sim.snapshot()
	bad.schema_version = 18
	_check(SaveStore.new().restore(bad) == null, "schema 18 rejected", failures)
	bad = sim.snapshot()
	bad.cities.erase("harbor")
	_check(SaveStore.new().restore(bad) == null, "missing city rejected", failures)
	bad = sim.snapshot()
	bad.cities.harbor.port.x = -1
	_check(SaveStore.new().restore(bad) == null, "invalid port rejected", failures)
	bad = sim.snapshot()
	bad.next_facility_id = 1
	_check(SaveStore.new().restore(bad) == null, "nonmonotonic facility counter rejected", failures)
	bad = sim.snapshot()
	bad.real_estates.harbor.city_id = "metro"
	_check(SaveStore.new().restore(bad) == null, "estate city mismatch rejected", failures)
