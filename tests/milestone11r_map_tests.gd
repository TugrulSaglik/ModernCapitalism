extends SceneTree

func _initialize() -> void:
	var catalog: SimCatalog = SimCatalog.new()
	var ok: bool = catalog.load_data("res://data/example_economy.json")
	var empty: Array[SimFacility] = []
	for dimensions: Vector2i in [Vector2i(96, 72), Vector2i(192, 144)]:
		var map: CityMap = CityMap.new()
		ok = ok and map.initialize(empty, catalog, 43, {"width": dimensions.x, "depth": dimensions.y})
		ok = ok and map.width == dimensions.x and map.depth == dimensions.y and map.roads_connected() and map.valid_port()
		ok = ok and not map.valid_sites(4, 3).is_empty()
		var saved: Dictionary = map.snapshot()
		var restored: CityMap = CityMap.new()
		ok = ok and restored.restore(saved, empty, catalog)
		ok = ok and restored.snapshot() == saved
		if not map.bridges.is_empty():
			var bad: Dictionary = saved.duplicate(true)
			bad.bridges[0] = "0,0"
			var rejected: CityMap = CityMap.new()
			ok = ok and not rejected.restore(bad, empty, catalog)
		print("11R map ", dimensions, " roads=", map.roads.size(), " bridges=", map.bridges.size(), " ambient=", map.ambient.size(), " valid=", ok)
	var a: CityMap = CityMap.new()
	var b: CityMap = CityMap.new()
	ok = ok and a.initialize(empty, catalog, 42) and b.initialize(empty, catalog, 42)
	ok = ok and a.snapshot() == b.snapshot()
	var arrangements: Dictionary = {}
	for seed_value: int in [42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53]:
		var sample: CityMap = CityMap.new()
		ok = ok and sample.initialize(empty, catalog, seed_value)
		var center: Dictionary = sample.generation.centers[0]
		arrangements["%d,%d" % [int(center.x) / 8, int(center.y) / 8]] = true
	ok = ok and arrangements.size() >= 4
	print("11R center arrangements: ", arrangements.size())
	print("11R map tests: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
