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
	if not screen.session.select_city("harbor"):
		printerr("M11 SCREENSHOT: cannot select Harbor")
		quit(1)
		return
	screen._build_city()
	var sim: Economy = screen.session.sim
	var site: Vector2i = sim.cities["harbor"].valid_sites(3, 2)[0]
	if not screen.session.submit({"type": "build_facility", "archetype": "electronics_store", "product": "smartphone", "x": site.x, "y": site.y}):
		printerr("M11 SCREENSHOT: Harbor build failed")
		quit(1)
		return
	screen.city.sync(screen._active_snapshot())
	if not screen.session.submit({"type": "import_goods", "facility": "built_000001", "product": "smartphone", "quantity": 3}):
		printerr("M11 SCREENSHOT: Harbor import failed")
		quit(1)
		return
	screen._select_port()
	screen.city.focus_cell(int(sim.cities["harbor"].port.x), int(sim.cities["harbor"].port.y))
	screen.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = "res://.godot/m11-screenshot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join("harbor-port.png")
	var result: Error = root.get_texture().get_image().save_png(path)
	print("M11 SCREENSHOT: ", ProjectSettings.globalize_path(path), " result ", result)
	quit(0 if result == OK else 1)
