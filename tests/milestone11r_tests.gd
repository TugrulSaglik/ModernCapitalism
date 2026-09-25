extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var archetypes: Dictionary = {}
	var orientations: Dictionary = {}
	var river_count: int = 0
	for seed_value: int in [42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53]:
		var sim: Economy = Economy.new()
		var initialized: bool = sim.initialize(seed_value)
		check(initialized, "initialize %d" % seed_value)
		if not initialized: continue
		var city: CityMap = sim.city
		check(city.width == 128 and city.depth == 96, "dimensions %d" % seed_value)
		check(city.roads_connected(), "connected roads %d" % seed_value)
		check(city.valid_port(), "port %d" % seed_value)
		check(city.population.total > 0, "population %d" % seed_value)
		check(city.districts.size() >= 5 and city.districts.size() <= 9, "districts %d" % seed_value)
		check(city.valid_sites(4, 3).size() > 30, "vacant sites %d" % seed_value)
		check(city.plots.size() > 10, "initial facilities %d" % seed_value)
		check(city.water.size() < city.width * city.depth / 2, "land %d" % seed_value)
		check(city.ambient.size() > 50, "development %d" % seed_value)
		check(sim.invariant_errors().is_empty(), "invariants %d" % seed_value)
		archetypes[city.generation.archetype] = true
		orientations[city.generation.orientation] = true
		if not city.bridges.is_empty(): river_count += 1
		print("seed=", seed_value, " archetype=", city.generation.archetype, " side=", city.generation.orientation, " water=", city.water.size(), " roads=", city.roads.size(), " bridges=", city.bridges.size(), " ambient=", city.ambient.size(), " population=", city.population.total)
	check(archetypes.size() >= 3, "terrain variety")
	check(orientations.size() >= 3, "coast orientation variety")
	check(river_count >= 2, "bridge variety")
	print("11R generator tests: ", "PASS" if failures.is_empty() else str(failures), " ms=", Time.get_ticks_msec() - started)
	quit(0 if failures.is_empty() else 1)
