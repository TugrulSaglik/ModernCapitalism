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

func fresh(seed_value: int = 42, era: int = 2022, settings: Dictionary = {}) -> GameSession:
	var s: GameSession = GameSession.new()
	check(s.start(era, seed_value, "sandbox", settings), "Generated session starts")
	s.time.set_speed(0)
	return s

func construct(s: GameSession, kind: String, product: String = "smartphone") -> SimFacility:
	var definition: Dictionary = s.sim.catalog.facility_types[kind]
	var sites: Array[Vector2i] = s.sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "Vacant frontage for " + kind)
	if sites.is_empty(): return null
	var p: Vector2i = sites[sites.size() / 2]
	var id: String = "built_%06d" % s.sim.city.next_facility
	var cash: int = s.sim.companies.player.cash
	check(s.submit({"type": "build_facility", "archetype": kind, "product": product, "x": p.x, "y": p.y}), "Build on generated site")
	check(s.sim.companies.player.cash == cash - int(definition.cost), "Construction price; land valuation does not imply purchase")
	return s.sim.facility(id)

func _initialize() -> void:
	_generation()
	_demand()
	_flow_and_replay()
	print("M5 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _generation() -> void:
	var a: GameSession = fresh()
	var b: GameSession = fresh()
	check(same(a.sim.city.snapshot(), b.sim.city.snapshot()), "Same settings/seed exact city")
	var other: GameSession = fresh(9173)
	check(a.sim.city.water != other.sim.city.water and a.sim.city.roads != other.sim.city.roads and a.sim.city.ambient != other.sim.city.ambient, "Seeds change coast, roads and development")
	check(a.sim.city.plots != other.sim.city.plots, "Initial business positions follow seed")
	var catalog_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	catalog_data.scenario.erase("city_layout")
	var file: FileAccess = FileAccess.open("res://.godot/m5-no-layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog_data))
	file.close()
	var without_layout: Economy = Economy.new()
	check(without_layout.initialize(42, 2022, "res://.godot/m5-no-layout.json") and same(a.sim.city.snapshot(), without_layout.city.snapshot()), "Procedural generation has no dependency on old coordinates")
	var water_cell: PackedStringArray = a.sim.city.water[0].split(",")
	var before: Dictionary = a.snapshot()
	check(not a.submit({"type": "build_facility", "archetype": "convenience_store", "product": "smartphone", "x": int(water_cell[0]), "y": int(water_cell[1])}) and same(before, a.snapshot()), "Water construction rejected without state change")
	var bad: GameSession = GameSession.new()
	for settings: Dictionary in [{"width": 1}, {"depth": 1000}, {"width": 40.5}]:
		check(not bad.start(2022, 42, "sandbox", settings), "Invalid dimensions rejected")
	for seed_value: int in [0, 1, 2, 7, 42, 9173, 2147483647]:
		var s: GameSession = fresh(seed_value)
		validate_city(s.sim)
	var sized: GameSession = fresh(73, 2022, {"width": 60, "depth": 42})
	check(sized.sim.city.width == 60 and sized.sim.city.depth == 42, "Configurable dimensions")
	validate_city(sized.sim)
	var saved: Dictionary = a.sim.snapshot()
	var store: SaveStore = SaveStore.new()
	check(store.restore(saved) != null, "Generated city hydrates")
	for corruption: String in ["water", "road", "population", "value", "ambient", "district", "port", "appearance", "dimensions", "plot"]:
		var bad_state: Dictionary = saved.duplicate(true)
		var k: String = bad_state.city.parcels.keys()[0]
		var id: String = bad_state.city.ambient.keys()[0]
		match corruption:
			"water": bad_state.city.water.append(bad_state.city.roads[0])
			"road": bad_state.city.roads.append("999,999")
			"population": bad_state.city.population.total += 1
			"value": bad_state.city.parcels[k].land_value = 99999999
			"ambient": bad_state.city.ambient[id].x = 999
			"district": bad_state.city.parcels[k].district = "missing"
			"port": bad_state.city.parcels[k].port_eligible = true
			"appearance": bad_state.city.ambient[id].tone = 99
			"dimensions": bad_state.city.width = 1
			"plot": bad_state.city.plots["20_player"] = bad_state.city.plots["21_rival"].duplicate(true)
		check(store.restore(bad_state) == null, "Reject corrupt generated " + corruption)
	var detached: Dictionary = a.sim.city.snapshot()
	detached.ambient.clear()
	detached.parcels.clear()
	check(not a.sim.city.ambient.is_empty() and not a.sim.city.parcels.is_empty(), "Detached city snapshot")

func validate_city(sim: Economy) -> void:
	var c: CityMap = sim.city
	check(c.roads_connected(), "All roads form one connected component")
	check(c.water.size() > c.width * c.depth / 10 and c.water.size() < c.width * c.depth / 2, "Meaningful water and mainland")
	var used: Dictionary = {}
	for collection: Dictionary in [c.plots, c.ambient]:
		for id: String in collection:
			var p: Dictionary = collection[id]
			var access: bool = false
			for y: int in range(p.y, p.y + p.depth):
				for x: int in range(p.x, p.x + p.width):
					var k: String = CityMap.key(x, y)
					check(x >= 0 and y >= 0 and x < c.width and y < c.depth and k not in c.water and k not in c.roads and not used.has(k), "Valid non-overlapping footprint " + id)
					used[k] = id
					access = access or c.touches_road(x, y)
			check(access, "Property has road frontage")
			if collection == c.ambient:
				check(id == "ambient_%03d_%03d" % [p.x, p.y] and p.population <= p.capacity, "Stable ambient identity and occupancy")
	var residents: int = 0
	var capacity: int = 0
	for b: Dictionary in c.ambient.values():
		residents += int(b.population)
		capacity += int(b.capacity)
	check(c.population.total == residents and c.population.capacity == capacity and residents > 0, "Population derived from housing")
	var district_population: int = 0
	for d: Dictionary in c.districts.values(): district_population += int(d.population)
	check(district_population == residents, "District totals reconcile")
	var ports: int = 0
	for k: String in c.parcels:
		var p: Dictionary = c.parcels[k]
		check(p.land_value >= 0 and p.land_value <= 50000, "Sane deterministic land value")
		if p.port_eligible:
			ports += 1
			check(p.waterfront and p.road_access and p.terrain == "land", "Port candidate has land/water/road interface")
	check(ports > 0, "Waterfront candidates exist")
	for f: SimFacility in sim.facilities:
		check(c.road_distance("20_player", f.id) >= 2, "Initial businesses connected")
		var q: Dictionary = sim.logistics.quote(sim, "20_player", f.id, 10)
		check(q.freight == 100 + q.distance * 20 and q.lead_days == maxi(1, ceili(q.distance / 20.0)), "Generated distance/freight/lead quote")
	for kind: String in sim.catalog.facility_types:
		var definition: Dictionary = sim.catalog.facility_types[kind]
		check(not c.valid_sites(definition.width, definition.depth).is_empty(), "Room for every facility archetype")

func _demand() -> void:
	check(ConsumerDemand.market_size(44, 10000) > ConsumerDemand.market_size(44, 5000), "Larger population greater potential market")
	check(ConsumerDemand.market_size(44, 0) == 0 and ConsumerDemand.market_size(44, 1) == 0, "No invisible normal market at zero/near-zero population")
	check(ConsumerDemand.market_size(44, 5000, 120) > ConsumerDemand.market_size(44, 5000, 80), "Purchasing power scales market")
	var low: Array[Dictionary] = [{"price": 100, "reference_price": 100, "quality": 50, "stock": 1000}]
	var high: Array[Dictionary] = low.duplicate(true)
	high[0].price = 200
	var quality: Array[Dictionary] = low.duplicate(true)
	quality[0].quality = 90
	var potential: int = ConsumerDemand.market_size(44, 10000)
	check(ConsumerDemand.allocate(potential, low)[0] > ConsumerDemand.allocate(potential, high)[0], "Price response preserved")
	check(ConsumerDemand.allocate(potential, quality)[0] > ConsumerDemand.allocate(potential, low)[0], "Quality response preserved")
	var a: GameSession = fresh()
	var b: GameSession = fresh()
	b.sim.city.population.total = 0
	a.sim.step()
	b.sim.step()
	check(a.sim.market.smartphone.potential > 0 and b.sim.market.smartphone.potential == 0 and b.sim.market.smartphone.units == 0, "Actual daily market reads generated population")

func _flow_and_replay() -> void:
	for era: int in [2012, 2022]:
		var a: GameSession = fresh(42, era)
		a.unlock_debug(DebugConfig.PASSWORD)
		a.debug_action("cash", 20000000)
		var factory: SimFacility = construct(a, "assembly_plant")
		var warehouse: SimFacility = construct(a, "warehouse")
		var shop: SimFacility = construct(a, "electronics_store")
		if factory == null or warehouse == null or shop == null: return
		a.submit({"type": "set_price", "facility": factory.id, "price": 100000000})
		# Keep stock in this warehouse until the explicit outbound order. Automatic
		# owned sourcing is tested separately below.
		a.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": "10_orion"})
		a.submit({"type": "set_supplier", "facility": shop.id, "product": "smartphone", "supplier": "10_orion"})
		for day: int in range(30): a.sim.step()
		check(factory.inventory.quantity("smartphone") > 0, "Generated roads deliver inputs and factory produces")
		# Use produced stock for the warehouse/retail flow.
		var units: int = mini(10, factory.inventory.quantity("smartphone"))
		check(units > 0 and a.submit({"type": "transfer", "facility": factory.id, "destination": warehouse.id, "product": "smartphone", "quantity": units}), "Factory to warehouse dispatch")
		check(a.sim.logistics.incoming(warehouse.id) == units, "Non-instant arrival reserves capacity")
		check(a.save_game("res://.godot/m5-replay.json"), "Save generated city with active shipments")
		var saved: Dictionary = a.snapshot()
		var b: GameSession = fresh(9173, era)
		check(b.load_game("res://.godot/m5-replay.json"), "Load saved city rather than regenerate current seed")
		check(same(saved, b.snapshot()), "Exact city/economy/population/land restoration")
		for s: GameSession in [a, b]:
			for day: int in range(10): s.sim.step()
			check(s.submit({"type": "transfer", "facility": warehouse.id, "destination": shop.id, "product": "smartphone", "quantity": units}), "Warehouse to retail flow")
			check(s.submit({"type": "set_warehouse_target", "facility": warehouse.id, "product": "battery", "quantity": 20}), "Generated warehouse replenishment")
			for day: int in range(10): s.sim.step()
			check(s.sim.facility(warehouse.id).inventory.quantity("battery") + s.sim.logistics.incoming(warehouse.id, "battery") == 20, "Target filled over generated roads")
		check(same(a.snapshot(), b.snapshot()), "Active-shipment continuation exact")
		var temporary: SimFacility = construct(a, "convenience_store")
		check(a.submit({"type": "demolish_facility", "facility": temporary.id}), "Generated site demolition")
		temporary = construct(b, "convenience_store")
		b.submit({"type": "demolish_facility", "facility": temporary.id})
		for day: int in range(3650):
			a.sim.step()
			b.sim.step()
			check(a.sim.invariant_errors().is_empty() and b.sim.invariant_errors().is_empty(), "Generated long-run daily accounts/inventory")
			if day % 365 == 0: check(same(a.sim.snapshot(), b.sim.snapshot()), "Generated yearly exact deterministic continuation")
		check(same(a.sim.snapshot(), b.sim.snapshot()), "Generated final exact continuation")
		check(a.sim.companies.player.monthly_history.size() == 13 and a.sim.companies.player.daily_history.size() > 360, "Monthly/TTM history preserved")
		check(a.sim.cumulative_consumer_units > 0 and a.sim.companies.player.freight > 0, "Sustained commerce on generated city")
		print("M5 SOAK era=%d days=3650 population=%d units=%d freight=%d" % [era, a.sim.city.population.total, a.sim.cumulative_consumer_units, a.sim.companies.player.freight])
