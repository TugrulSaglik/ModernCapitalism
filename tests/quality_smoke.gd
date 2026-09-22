extends SceneTree

var screen: Control
var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func capture(filename: String) -> void:
	screen.refresh()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/7b1-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(filename + ".png")) == OK, "Capture " + filename)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	var sim: Economy = screen.session.sim
	for f: SimFacility in sim.facilities:
		if sim._behavior(f) == "retail":
			sim.queue_command({"type": "set_stock_days", "company": f.company_id, "facility": f.id, "days": 7})
	for day: int in range(45): sim.step()
	screen.select_facility("20_player")
	var store: SimFacility = sim.facility("20_player")
	check(store.inventory.quantity("smartphone") > 0 and store.inventory.quantity("laptop") > 0, "Naturally supplied retail lines stocked")
	check(store.inventory.quality("smartphone") != store.inventory.quality("laptop"), "Different manufactured qualities at same retailer")
	for index: int in range(screen.inspector.line.item_count):
		if screen.inspector.line.get_item_metadata(index) == "smartphone":
			screen.inspector.line.select(index)
			screen.inspector.line.item_selected.emit(index)
	check(screen.inspector.retail_line_metrics.quality.text == store.inventory.quality_text("smartphone"), "Inspector exposes actual goods quality")
	await capture("01-retail-quality")
	screen._show_company()
	screen.reports.tabs.current_tab = 3
	screen.reports.refresh()
	for index: int in range(screen.reports.products.item_count):
		if screen.reports.products.get_item_metadata(index) == "smartphone": screen.reports.products.select(index)
	await capture("02-market-quality")
	check(screen.overview.size.y <= 700, "Market report fits viewport")
	check(sim.invariant_errors().is_empty(), "Rendered economy accounting and quality reconcile")
	print("M7B1 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
