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
	var owner: SimCompany = screen.session.sim.companies.player
	owner.advertising_budgets.smartphone = 2500
	owner.advertising_progress.smartphone = 4200
	for day: int in range(5):
		screen.session.sim.step()
	screen._show_company()
	screen.reports.tabs.current_tab = 3
	for index: int in range(screen.reports.products.item_count):
		if str(screen.reports.products.get_item_metadata(index)) == "smartphone":
			screen.reports.products.select(index)
	screen.reports.refresh()
	await process_frame
	await process_frame
	screen.reports.report_scroll.scroll_vertical = 300
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = "res://.godot/8ui-b4b-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join("01-markets.png")
	var result: Error = root.get_texture().get_image().save_png(path)
	print("8UI-B4B VISUAL RESULT: ", path if result == OK else "failed")
	quit(0 if result == OK else 1)
