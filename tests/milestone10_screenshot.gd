extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var sim: Economy = screen.session.sim
	var sites: Array[Vector2i] = sim.city.valid_sites(2, 2)
	var site: Vector2i = sites[0]
	var best_distance: int = 1000000
	for candidate: Vector2i in sites:
		var distance: int = absi(candidate.x - sim.city.width / 2) + absi(candidate.y - sim.city.depth / 2)
		if distance < best_distance:
			best_distance = distance
			site = candidate
	if not screen.session.submit({"type": "develop_property", "property_type": "apartments", "x": site.x, "y": site.y}):
		printerr("FAIL: screenshot property development")
		quit(1)
		return
	for day: int in range(35): sim.step()
	screen.city.sync(sim.snapshot())
	screen.select_property("property_000001")
	screen.city.focus_cell(site.x, site.y)
	screen.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = "res://.godot/m10-screenshot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join("property-inspector.png")
	var result: Error = root.get_texture().get_image().save_png(path)
	print("M10 SCREENSHOT: ", ProjectSettings.globalize_path(path), " result ", result)
	quit(0 if result == OK else 1)
