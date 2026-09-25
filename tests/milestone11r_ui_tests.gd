extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	var map: CityMap = screen.session.sim.city
	var matched: int = 0
	for b: Dictionary in map.ambient.values():
		var center: Vector3 = screen.city.cell_position(b.x + (b.width - 1) / 2.0, b.y + (b.depth - 1) / 2.0)
		var h: float = 0.65 + int(b.height) * 0.65
		var screen_point: Vector2 = screen.city.camera.unproject_position(center + Vector3(0, h * 0.5, 0))
		var origin: Vector3 = screen.city.camera.project_ray_origin(screen_point)
		var direction: Vector3 = screen.city.camera.project_ray_normal(screen_point)
		if screen.city._property_at_ray(origin, direction) == str(b.id): matched += 1
	var ok: bool = matched >= 10 and screen.city.camera.size == 50.0
	print("11R UI selection: ", "PASS" if ok else "FAIL", " matched=", matched, " ambient=", map.ambient.size(), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	quit(0 if ok else 1)
