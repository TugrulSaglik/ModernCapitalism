extends SceneTree

func _initialize() -> void:
	var sim: Economy = Economy.new()
	var ok: bool = sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"})
	if not ok:
		quit(1)
		return
	var map: CityMap = sim.city
	ok = ok and map.width == 32 and map.depth == 24 and map.profile.is_empty() and map.population.total == 5000
	var expected: Array[String] = []
	for y: int in range(24):
		for x: int in range(32):
			if y in [6, 13, 20] or x in [1, 30]: expected.append(CityMap.key(x, y))
	ok = ok and map.roads == expected
	# Compare the new derived index to a brute-force oracle on the small fixture.
	for footprint: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3)]:
		var oracle: Array[Vector2i] = []
		for y: int in range(map.depth - footprint.y + 1):
			for x: int in range(map.width - footprint.x + 1):
				if map.placement_error(x, y, footprint.x, footprint.y).is_empty(): oracle.append(Vector2i(x, y))
		ok = ok and map.valid_sites(footprint.x, footprint.y) == oracle
		for p: Vector2i in map.bounded_sites(footprint.x, footprint.y, Vector2i(16, 12)):
			ok = ok and p in oracle
	var saved: Dictionary = sim.snapshot()
	var restored: Economy = SaveStore.new().restore(saved)
	ok = ok and restored != null
	if restored != null: ok = ok and restored.snapshot() == saved
	print("11R2 legacy and frontage compatibility: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
