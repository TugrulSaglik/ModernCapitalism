extends SceneTree

var screen: Control
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	for f: SimFacility in screen.session.sim.facilities:
		if screen.session.sim._behavior(f) == "retail": f.stock_days = 7
	for day: int in range(45): screen.session.sim.step()
	screen._show_company()
	screen.reports.tabs.current_tab = 3
	for product: String in ["smartphone", "laptop"]:
		screen.reports.refresh()
		for index: int in range(screen.reports.products.item_count):
			if screen.reports.products.get_item_metadata(index) == product: screen.reports.products.select(index)
		screen.refresh()
		await process_frame
		await process_frame
		check(screen.overview.size.y <= 700 and screen.overview.size.x <= 1000, "Compact market dialog")
		check(screen.reports.table.columns == 3 and screen.reports.table.get_column_title(1) == "Local", "Local comparison columns")
		var rows: Array[TreeItem] = screen.reports.table.get_root().get_children()
		check(rows[2].get_text(1) == "60" and rows[5].get_text(1) == "20", "Local and player brand read model")
		check(not rows[0].get_text(2).is_empty(), "Market average present")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var dir: String = "res://.godot/7b2-screenshots"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			check(root.get_texture().get_image().save_png(dir.path_join(product + ".png")) == OK, "Capture market")
	check(screen.session.sim.invariant_errors().is_empty(), "Accounts reconcile")
	print("M7B2 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
