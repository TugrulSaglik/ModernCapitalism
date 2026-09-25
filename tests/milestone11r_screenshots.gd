extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var directory: String = "res://.godot/m11r-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var cases: Array[Dictionary] = [
		{"seed": 42, "name": "bay-north"},
		{"seed": 43, "name": "estuary-bridge-west"},
		{"seed": 49, "name": "coast-downtown"}
	]
	for item: Dictionary in cases:
		if not screen.session.start(2022, int(item.seed), "sandbox"):
			printerr("11R screenshot failed to initialize seed ", item.seed)
			quit(1)
			return
		screen.session.time.set_speed(0)
		screen._build_city()
		var map: CityMap = screen.session.sim.city
		if item.name == "bay-north": screen.city.focus_cell(int(map.port.x), int(map.port.y) + 12)
		elif item.name == "estuary-bridge-west" and not map.bridges.is_empty():
			var parts: PackedStringArray = map.bridges[0].split(",")
			screen.city.focus_cell(int(parts[0]), int(parts[1]))
		else:
			var center: Dictionary = map.generation.centers[0]
			screen.city.focus_cell(int(center.x), int(center.y))
		screen.refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = directory.path_join(str(item.name) + ".png")
		var result: Error = root.get_texture().get_image().save_png(path)
		print("11R screenshot: ", ProjectSettings.globalize_path(path), " result=", result, " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if result != OK:
			quit(1)
			return
	quit(0)
