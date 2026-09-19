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

func capture(name_value: String) -> void:
	screen.refresh()
	await process_frame
	await process_frame
	if screen.overview.visible: check(screen.overview.size.y <= 700, "Report dialog fits viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m6-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Capture " + name_value)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var session: GameSession = screen.session
	session.time.set_speed(0)
	screen.save_directory = "res://.godot/m6-ui-saves"
	check(ConsumerMarket.populations(session.sim).size() == 3, "Inspect consumer segments")
	await capture("01-city")
	screen.select_facility("20_player")
	var panel: FacilityPanel = screen.inspector
	for index: int in range(panel.choices.item_count):
		if panel.choices.get_item_text(index) == "tablet": panel.choices.select(index)
	panel.configure.pressed.emit()
	session.sim.step()
	panel.refresh()
	check(session.sim.facility("20_player").assortment.has("tablet"), "UI adds line")
	for index: int in range(panel.line.item_count):
		if panel.line.get_item_text(index) == "laptop":
			panel.line.select(index)
			panel.line.item_selected.emit(index)
	panel.price.value = 680
	panel.apply_price.pressed.emit()
	for index: int in range(panel.product.item_count):
		if panel.product.get_item_text(index) == "laptop":
			panel.product.select(index)
			panel.product.item_selected.emit(index)
	for index: int in range(panel.suppliers.item_count):
		if panel.suppliers.get_item_metadata(index) == "13_laptops": panel.suppliers.select(index)
	panel.apply_supplier.pressed.emit()
	for day: int in range(45): session.sim.step()
	check(session.sim.facility("20_player").line_price("laptop") == 68000, "Per-product UI price")
	check(session.sim.facility("20_player").line_sales.size() >= 3, "Multiple products sold")
	await capture("02-electronics")
	screen.select_facility("23_department")
	await capture("03-department")
	var sites: Array[Vector2i] = session.sim.city.valid_sites(4, 3)
	check(not sites.is_empty(), "Factory site available")
	if not sites.is_empty():
		check(session.submit({"type": "build_facility", "archetype": "assembly_plant", "product": "smartphone", "x": sites[0].x, "y": sites[0].y}), "Build factory")
		screen.refresh()
		screen.select_facility("built_000001")
		for index: int in range(panel.choices.item_count):
			if panel.choices.get_item_text(index) == "tablet": panel.choices.select(index)
		panel.configure.pressed.emit()
		session.sim.step()
		check(session.sim.facility("built_000001").product_id == "tablet", "UI switches factory")
		check(session.submit({"type": "set_supplier", "facility": "20_player", "product": "tablet", "supplier": "built_000001"}), "Retail sources owned factory")
		for day: int in range(30): session.sim.step()
		check(session.sim.facility("built_000001").inventory.quantity("tablet") > 0, "Inputs arrive and output manufactured")
		check(int(session.sim.facility("20_player").line_sales.get("tablet", {}).get("units", 0)) > 0, "Owned output reaches retail consumers")
		await capture("04-factory")
	screen._show_company()
	screen.reports.tabs.current_tab = 3
	screen.reports.refresh()
	for index: int in range(screen.reports.products.item_count):
		if screen.reports.products.get_item_metadata(index) == "smartphone": screen.reports.products.select(index)
	await capture("05-market")
	for tab: int in range(3):
		screen.reports.tabs.current_tab = tab
		await capture(["06-income", "07-balance", "08-cash-flow"][tab])
	var b: Dictionary = FinancialReports.balance(session.sim, "player")
	check(b.assets == b.equity, "UI balance reconciles")
	screen.overview.hide()
	screen.inspector.hide()
	await capture("09-hud")
	check(session.sim.companies.player.monthly_history.size() >= 3, "Monthly rollover history")
	screen._save()
	var expected: Economy = SaveStore.new().restore(session.sim.snapshot())
	check(expected != null, "Saved expanded session validates")
	for day: int in range(12): session.sim.step()
	screen._load()
	if expected != null:
		for day: int in range(12):
			session.sim.step()
			expected.step()
		check(JSON.stringify(SaveStore.encode(expected.snapshot())) == JSON.stringify(SaveStore.encode(session.sim.snapshot())), "Exact UI save/load replay")
	screen._new_session(2012)
	session.time.set_speed(0)
	check(not session.sim.product_public("earbuds") and not session.sim.product_public("advanced_phone"), "2012 gates")
	for day: int in range(35): session.sim.step()
	check(session.sim.facility("20_player").line_sales.size() >= 3 and session.sim.invariant_errors().is_empty(), "2012 multi-product economy")
	print("M6 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
