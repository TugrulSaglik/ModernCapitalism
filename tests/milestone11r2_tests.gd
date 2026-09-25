extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	var catalog: SimCatalog = SimCatalog.new()
	check(catalog.load_data(), "catalog")
	check(catalog.city_profiles.size() >= 30, "pool size")
	var regions: Dictionary = {}
	var tiers: Dictionary = {}
	for p: Dictionary in catalog.city_profiles.values():
		regions[p.region] = true
		var n: int = int(p.reference_population_2025)
		tiers[0 if n < 3000000 else 1 if n < 7000000 else 2 if n < 15000000 else 3 if n < 25000000 else 4] = true
	check(regions.size() >= 6 and tiers.size() == 5, "regions and tiers")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CityProfiles.PATH))
	for field: String in ["id", "population_source", "population_year", "latitude", "longitude", "compactness", "terrain_bias", "reference_population_2025"]:
		var invalid: Dictionary = raw.duplicate(true)
		invalid.profiles[0][field] = "" if field in ["id", "population_source", "terrain_bias"] else -999
		check(not SimCatalog.new().load_profiles(invalid), "reject invalid " + field)
	var duplicate: Dictionary = raw.duplicate(true)
	duplicate.profiles.append(duplicate.profiles[0].duplicate(true))
	check(not SimCatalog.new().load_profiles(duplicate), "duplicate ID")
	duplicate.profiles.back().id = "duplicate_name"
	check(not SimCatalog.new().load_profiles(duplicate), "duplicate name/country")
	var selections: Dictionary = {}
	for seed_value: int in range(24):
		var a: Array[Dictionary] = CityProfiles.select(catalog.city_profiles, seed_value)
		check(a == CityProfiles.select(catalog.city_profiles, seed_value), "selection repeat")
		check(a.size() == 3 and a[0].id != a[1].id and a[1].id != a[2].id and a[0].id != a[2].id, "unique selection")
		selections[str(a)] = true
	check(selections.size() >= 20, "seed variation")
	var areas: Array[int] = []
	for pop: int in [3000000, 15000000, 30000000]:
		var profile: Dictionary = catalog.city_profiles.istanbul.duplicate(true)
		profile.reference_population_2025 = pop
		var size: Vector2i = CityProfiles.dimensions(profile, 42)
		areas.append(size.x * size.y)
	check(areas[0] < areas[1] and areas[1] < areas[2], "population dimensions")
	var empty: Array[SimFacility] = []
	var samples: Array[String] = ["vancouver", "sydney", "istanbul", "tokyo", "barcelona", "los_angeles", "shanghai", "jakarta", "naples", "manila", "mumbai", "auckland"]
	for index: int in range(samples.size()):
		var city: CityMap = CityMap.new()
		var seed_value: int = 42 + index
		var settings: Dictionary = {"profile_id": samples[index], "archetype": ["coast", "bay", "estuary", "river_city"][index % 4]}
		# One exact base maximum tier, including ordinary scenario placement.
		var facilities: Array[SimFacility] = []
		if index == 7:
			settings.width = 384
			settings.depth = 288
			for definition: Dictionary in catalog.scenario.facilities: facilities.append(SimFacility.new(definition))
		check(city.initialize(facilities, catalog, seed_value, settings), "generate " + samples[index])
		if city.ambient.is_empty(): continue
		var land: int = city.width * city.depth - city.water.size()
		var coverage: float = 100.0 * city.roads.size() / land
		var target: int = int(city.profile.reference_population_2025) / 1000
		check(coverage >= 4.5 and coverage <= 12.0, "coverage " + samples[index])
		check(city.roads_connected() and city.road_structure_valid(), "road graph " + samples[index])
		# Independently inspect every road, not just the generator's check.
		for key: String in city.roads:
			var parts: PackedStringArray = key.split(",")
			var x: int = int(parts[0])
			var y: int = int(parts[1])
			check(not (city.is_road(x + 1, y) and city.is_road(x, y + 1) and city.is_road(x + 1, y + 1)), "no road square")
			check(x % 8 == 4 or y % 8 == 4, "spaced corridor")
			if city.is_road(x - 1, y) and city.is_road(x + 1, y):
				for offset: int in range(1, 4):
					check(not (city.is_road(x - 1, y + offset) and city.is_road(x, y + offset) and city.is_road(x + 1, y + offset)), "parallel block spacing")
		for key: String in city.bridges:
			check(key in city.water and key in city.roads, "bridge deck")
		check(city.valid_port(), "port " + samples[index])
		check(absf(float(city.population.total) / target - 1.0) <= 0.15, "population " + samples[index])
		check(city.valid_sites(4, 3).size() > 100, "construction space")
		check(city.generation.centers.size() >= 4 and city.districts.size() >= 7, "centers/districts")
		var jobs: int = 0
		for b: Dictionary in city.ambient.values(): jobs += int(catalog.property_types[b.kind].job_capacity)
		check(jobs >= int(city.population.total) * 0.45, "explicit employment")
		for f: SimFacility in facilities: check(city.road_distance_to_port(f.id) >= 0, "facility port route")
		var before_snapshot: int = Time.get_ticks_msec()
		var saved: Dictionary = city.snapshot()
		var snapshot_ms: int = Time.get_ticks_msec() - before_snapshot
		var restored: CityMap = CityMap.new()
		check(restored.restore(saved, facilities, catalog), "restore " + samples[index])
		check(restored.snapshot() == saved, "exact map " + samples[index])
		if index == 0:
			var repeated: CityMap = CityMap.new()
			check(repeated.initialize(empty, catalog, seed_value, settings) and repeated.snapshot() == saved, "deterministic complete map")
			var bad: Dictionary = saved.duplicate(true)
			bad.profile.id = "unknown"
			check(not CityMap.new().restore(bad, empty, catalog), "unknown profile restore")
			bad = saved.duplicate(true)
			bad.profile.reference_population_2025 += 100000
			check(not CityMap.new().restore(bad, empty, catalog), "changed metadata restore")
		if samples[index] == "istanbul":
			var sim: Economy = Economy.new()
			sim.catalog = catalog
			sim.cities["metro"] = city
			var counts: Dictionary = ConsumerMarket.populations(sim)
			var total: int = 0
			for value: int in counts.values(): total += value
			check(total == city.population.total and total > 13000 and total < 18000, "15M demand uses simulation units")
		print("PROFILE ", samples[index], " seed=", seed_value, " size=", city.width, "x", city.depth, " roads=", city.roads.size(), " land=", land, " coverage=%.2f%%" % coverage, " residents=", city.population.total, "/", target, " buildings=", city.ambient.size(), " centers=", city.generation.centers.size(), " districts=", city.districts.size(), " bridges=", city.bridges.size(), " timing=", CityGenerator.last_timings, " snapshot_ms=", snapshot_ms)
	print("11R2 profile tests: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
