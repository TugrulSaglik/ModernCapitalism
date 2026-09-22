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
	for day: int in range(5):
		screen.session.sim.step()
	screen._show_company()
	screen.reports.tabs.current_tab = 0
	screen.reports.periods.select(0)
	screen.reports.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = "res://.godot/8ui-b4a-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var result: Error = root.get_texture().get_image().save_png(directory.path_join("01-income-statement.png"))
	print("8UI-B4A VISUAL RESULT: ", "saved" if result == OK else "failed")
	quit(0 if result == OK else 1)
