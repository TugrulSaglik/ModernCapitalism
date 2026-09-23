extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: GameSession = GameSession.new()
	check(session.start(2022, 42), "procedural start")
	if session.sim == null:
		quit(1)
		return
	var sim: Economy = session.sim
	check(sim.catalog.version == 10 and sim.snapshot().schema_version == 18, "versions")
	check(sim.invariant_errors().is_empty(), "opening invariants " + str(sim.invariant_errors()))
	check(sim.real_estate.properties.size() == sim.city.ambient.size(), "ambient property authority")
	check(sim.city.population.total > 0 and sim.city.population.housing_capacity == sim.city.population.capacity, "housing")
	check(sim.city.population.jobs >= sim.city.population.workforce, "baseline jobs")
	var road: PackedStringArray = sim.city.roads[0].split(",")
	check(not session.submit({"type": "buy_land", "x": int(road[0]), "y": int(road[1]), "width": 1, "depth": 1}), "road rejected")
	var water: PackedStringArray = sim.city.water[0].split(",")
	check(not session.submit({"type": "buy_land", "x": int(water[0]), "y": int(water[1]), "width": 1, "depth": 1}), "water rejected")
	var sites: Array[Vector2i] = sim.city.valid_sites(2, 2)
	check(not sites.is_empty(), "available site")
	if sites.is_empty():
		quit(1)
		return
	var site: Vector2i = sites[0]
	var owner: SimCompany = sim.companies.player
	var opening_cash: int = owner.cash
	var land_cost: int = sim.real_estate.land_cost(sim, owner.id, site.x, site.y, 2, 2)
	check(session.submit({"type": "develop_property", "property_type": "apartments", "x": site.x, "y": site.y}), "develop apartments " + session.message)
	var id: String = "property_000001"
	check(owner.cash == opening_cash - land_cost - 12000000, "land and construction cash")
	check(sim.real_estate.land_assets(owner.id) == land_cost, "land asset")
	check(sim.real_estate.building_assets(owner.id) == 12000000, "building asset")
	check(sim.real_estate.land_cost(sim, owner.id, site.x, site.y, 2, 2) == 0, "self-owned land free")
	check(sim.property_command_error({"type": "buy_land", "company": "rival", "x": site.x, "y": site.y, "width": 2, "depth": 2}) != "", "rival land blocked")
	check(session.submit({"type": "buy_land", "x": site.x, "y": site.y, "width": 2, "depth": 2}), "self land buy succeeds")
	check(owner.cash == opening_cash - land_cost - 12000000, "self land buy charges zero")
	check(sim.real_estate.properties[id].population == 0, "new housing empty")
	check(FinancialReports.balance(sim, owner.id).assets == FinancialReports.balance(sim, owner.id).equity, "balance after development")
	check(sim.invariant_errors().is_empty(), "development invariants " + str(sim.invariant_errors()))
	check(sim.real_estate.restore_state(sim, sim.real_estate.snapshot()), "real estate exact self restore")
	var store: SaveStore = SaveStore.new()
	var loaded: Economy = store.restore(sim.snapshot())
	check(loaded != null, "property restore " + store.error)
	if loaded != null: check(loaded.snapshot() == sim.snapshot(), "exact snapshot continuation")
	for day: int in range(32):
		sim.step()
		if loaded != null: loaded.step()
	if loaded != null: check(loaded.snapshot() == sim.snapshot(), "deterministic continuation")
	check(sim.real_estate.properties[id].depreciation > 0, "building depreciation")
	check(sim.real_estate.land_assets(owner.id) == land_cost, "land does not depreciate")
	check(sim.real_estate.properties[id].population > 0, "monthly migration fills housing gradually")
	check(sim.invariant_errors().is_empty(), "post month invariants " + str(sim.invariant_errors()))
	owner.cash += 100000000
	owner.capital += 100000000
	var office_site: Vector2i = sim.city.valid_sites(2, 2)[0]
	var office_land: int = sim.real_estate.land_cost(sim, owner.id, office_site.x, office_site.y, 2, 2)
	var office_cash: int = owner.cash
	check(session.submit({"type": "develop_property", "property_type": "office", "x": office_site.x, "y": office_site.y}), "office development")
	check(owner.cash == office_cash - office_land - 18000000, "office exact cost")
	check(sim.real_estate.properties.property_000002.occupied_jobs <= 100, "office jobs bounded")
	check(sim.city.population.jobs >= sim.real_estate.baseline_jobs + 100, "office adds jobs")
	var population_before_jobs: int = int(sim.city.population.total)
	for day: int in range(32): sim.step()
	check(int(sim.city.population.total) > population_before_jobs, "housing plus employment grows city")
	check(ConsumerDemand.market_size(10000, int(sim.city.population.total), 100) > ConsumerDemand.market_size(10000, population_before_jobs, 100), "larger population raises demand potential")
	check(not session.submit({"type": "develop_property", "property_type": "house", "x": office_site.x, "y": office_site.y}), "property overlap rejected")
	var ambient_ids: Array = sim.real_estate.properties.keys()
	ambient_ids.sort()
	var ambient_id: String = ""
	for candidate: String in ambient_ids:
		var item: Dictionary = sim.real_estate.properties[candidate]
		if item.owner == "" and int(item.population) > 0:
			ambient_id = candidate
			break
	check(not ambient_id.is_empty(), "outside housing exists")
	if not ambient_id.is_empty():
		var ambient: Dictionary = sim.real_estate.properties[ambient_id]
		var original_residents: int = int(ambient.population)
		var acquisition_land: int = sim.real_estate.land_cost(sim, owner.id, int(ambient.x), int(ambient.y), int(ambient.width), int(ambient.depth))
		var acquisition_cash: int = owner.cash
		check(session.submit({"type": "acquire_property", "property": ambient_id}), "acquire outside property " + session.message)
		check(owner.cash == acquisition_cash - acquisition_land - int(sim.catalog.property_types[str(ambient.type)].cost), "acquisition exact allocation")
		check(sim.real_estate.properties[ambient_id].population == original_residents, "acquisition preserves residents")
		check(not session.submit({"type": "acquire_property", "property": ambient_id}), "cannot acquire company property")
		var acquired: Dictionary = sim.real_estate.properties[ambient_id]
		var gross: int = sim.real_estate.gross_rent(sim, acquired)
		var current_value: int = int(sim.catalog.property_types[str(acquired.type)].cost)
		for cell: String in acquired.land_cells: current_value += int(sim.city.parcels[cell].land_value)
		check(gross == (current_value * 12 / 1200) * original_residents / int(sim.catalog.property_types[str(acquired.type)].residential_capacity), "12 percent occupancy rent")
		var rent_before: int = owner.property_revenue
		var maintenance_before: int = owner.property_maintenance
		var expected_gross: int = 0
		var expected_maintenance: int = 0
		for property: Dictionary in sim.real_estate.properties.values():
			if property.owner == owner.id:
				var receipt: int = sim.real_estate.gross_rent(sim, property)
				expected_gross += receipt
				expected_maintenance += receipt * 25 / 100
		sim.real_estate.monthly_rent(sim)
		check(owner.property_revenue - rent_before == expected_gross, "monthly gross rent exact")
		check(owner.property_maintenance - maintenance_before == expected_maintenance, "monthly maintenance exact")
	var old_building: int = int(sim.real_estate.properties[id].building_cost) - int(sim.real_estate.properties[id].depreciation)
	var old_land: int = sim.real_estate.land_assets(owner.id)
	var old_expenses: int = owner.expenses
	check(session.submit({"type": "redevelop_property", "property": id, "property_type": "house"}), "redevelopment")
	check(not sim.real_estate.properties.has(id) and sim.real_estate.properties.has("property_000003"), "new stable redevelopment ID")
	check(owner.expenses - old_expenses == old_building, "old NBV written off")
	check(sim.real_estate.land_assets(owner.id) == old_land, "redevelopment retains land")
	check(sim.real_estate.properties.property_000003.building_cost == 2500000, "new building basis")
	check(sim.real_estate.properties.property_000003.population == 0, "redeveloped housing empty")
	check(sim.city.population.total <= sim.city.population.housing_capacity, "population remains housed")
	var facility_sites: Array[Vector2i] = sim.city.valid_sites(3, 2)
	check(not facility_sites.is_empty(), "facility site exists")
	if not facility_sites.is_empty():
		var facility_site: Vector2i = facility_sites[0]
		var facility_land: int = sim.real_estate.land_cost(sim, owner.id, facility_site.x, facility_site.y, 3, 2)
		var facility_cash: int = owner.cash
		check(session.submit({"type": "build_facility", "archetype": "research_center", "product": "", "x": facility_site.x, "y": facility_site.y}), "facility auto land")
		check(owner.cash == facility_cash - facility_land - 1500000, "facility land + building cost")
		var built_id: String = "built_%06d" % (sim.city.next_facility - 1)
		check(sim.facility(built_id).asset_cost == 1500000, "building basis separate")
		var land_before_demolition: int = sim.real_estate.land_assets(owner.id)
		check(session.submit({"type": "demolish_facility", "facility": built_id}), "facility demolition")
		check(sim.real_estate.land_assets(owner.id) == land_before_demolition, "facility demolition retains land")
	check(sim.invariant_errors().is_empty(), "final invariants " + str(sim.invariant_errors()))
	var final_restore: Economy = store.restore(sim.snapshot())
	check(final_restore != null, "final exact restore " + store.error)
	if final_restore != null: check(final_restore.snapshot() == sim.snapshot(), "final snapshot exact")
	var state: Dictionary = sim.snapshot()
	var malformed: Dictionary = state.duplicate(true)
	malformed.schema_version = 17
	check(store.restore(malformed) == null, "schema 17 rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.next_property = 1
	check(store.restore(malformed) == null, "invalid next property ID rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.land[CityMap.key(site.x, site.y)].owner = "unknown"
	check(store.restore(malformed) == null, "unknown land owner rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.land[CityMap.key(site.x, site.y)].basis = -1
	check(store.restore(malformed) == null, "negative land basis rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.land[sim.city.roads[0]] = {"owner": "player", "basis": 1}
	check(store.restore(malformed) == null, "road ownership rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.properties.property_000003.type = "unknown"
	check(store.restore(malformed) == null, "unknown property type rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.properties.property_000003.population = 100
	check(store.restore(malformed) == null, "residents over capacity rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.properties.property_000003.depreciation = 2500001
	check(store.restore(malformed) == null, "excess depreciation rejected")
	malformed = state.duplicate(true)
	malformed.city.population.jobs += 1
	check(store.restore(malformed) == null, "employment aggregate mismatch rejected")
	malformed = state.duplicate(true)
	malformed.real_estate.properties.property_000003.land_cells = [CityMap.key(site.x, site.y)]
	check(store.restore(malformed) == null, "property footprint mismatch rejected")
	var saved_population: Dictionary = sim.city.population.duplicate(true)
	sim.city.population.total = int(saved_population.housing_capacity) * 92 / 100
	sim.city.population.workforce = int(sim.city.population.total) / 2
	sim.city.population.jobs = int(sim.city.population.workforce) + 100
	var profile: Dictionary = sim.strategic_ai.difficulty_profile("standard")
	var housing_plan: Dictionary = sim.strategic_ai._property_command(sim, "player", {}, profile)
	check(housing_plan.get("property_type") == "apartments", "AI residential pressure chooses apartments")
	if not housing_plan.is_empty():
		var original_cash: int = owner.cash
		var minimum_land: int = 1000000000
		for point: Vector2i in sim.city.valid_sites(2, 2): minimum_land = mini(minimum_land, sim.real_estate.land_cost(sim, "player", point.x, point.y, 2, 2))
		owner.cash = 5000000 + int(sim.catalog.property_types.apartments.cost) + minimum_land - 1
		check(sim.strategic_ai._property_command(sim, "player", {}, profile).is_empty(), "AI reserve includes land and building")
		owner.cash = original_cash
	sim.city.population.total = int(saved_population.housing_capacity) - 100
	sim.city.population.workforce = int(sim.city.population.total) / 2
	sim.city.population.jobs = int(saved_population.housing_capacity) * 40 / 100
	var jobs_plan: Dictionary = sim.strategic_ai._property_command(sim, "player", {}, profile)
	check(jobs_plan.get("property_type") == "commercial", "AI employment pressure chooses commercial")
	sim.city.population = saved_population
	var ai_plan: Dictionary = sim.strategic_ai.evaluate_month(sim)
	var major_per_company: Dictionary = {}
	for command: Dictionary in ai_plan.commands:
		if command.type in ["build_facility", "develop_property"]:
			major_per_company[str(command.company)] = int(major_per_company.get(str(command.company), 0)) + 1
	for company_id: String in major_per_company: check(int(major_per_company[company_id]) <= 1, "one AI major capital action " + company_id)
	print("M10 RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
