extends SceneTree
var checks: int = 0
var failures: int = 0
var screen: Control
var session: GameSession

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
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m5-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Capture " + name_value)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	session = screen.session
	session.time.set_speed(0)
	screen.save_directory = "res://.godot/m5-ui-saves"
	var original: Dictionary = session.sim.city.snapshot()
	check(session.sim.city.generation.seed == "42" and not session.sim.city.water.is_empty(), "Known seed coastal sandbox")
	check(session.sim.city.population.total > 0 and session.sim.city.ambient.size() > 30, "Inhabited city")
	await capture("01-overview")
	screen.city.focus_cell(36, 18)
	screen.city.camera.size = 35
	await capture("02-coastline")
	screen.city.focus_cell(21, 18)
	screen.city.camera.size = 33
	await capture("03-central-density")
	screen.city.focus_cell(9, 10)
	screen.city.camera.size = 26
	await capture("04-residential")
	for day: int in range(30): session.sim.step()
	check(not session.sim.logistics.shipments.is_empty() and session.sim.cumulative_consumer_units > 0, "Generated logistics and consumer commerce")
	screen.select_facility("20_player")
	var p: Dictionary = session.sim.city.plots["20_player"]
	screen.city.focus_cell(p.x, p.y)
	screen.city.camera.size = 30
	await capture("05-player-selected")
	screen._show_construction()
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == "electronics_store":
			screen.build_choices.select(index)
			screen._choose_build()
			break
	var sites: Array[Vector2i] = session.sim.city.valid_sites(3, 2)
	check(not sites.is_empty(), "Generated construction frontage")
	var site: Vector2i = sites[sites.size() / 2]
	screen.city.focus_cell(site.x + 1, site.y)
	screen.city.camera.size = 30
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = screen.city.camera.unproject_position(screen.city.cell_position(site.x, site.y))
	screen.city._unhandled_input(motion)
	check(screen.city.preview_error.is_empty() and screen.city.preview_cell == site, "Synthetic ground projection on generated dimensions")
	await capture("06-construction-preview")
	var cash: int = session.sim.companies.player.cash
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen.city.camera.unproject_position(screen.city.cell_position(site.x, site.y))
	screen.city._unhandled_input(click)
	var built_id: String = screen.selected_id
	var built: SimFacility = session.sim.facility(built_id)
	check(built != null and built.company_id == "player" and session.sim.companies.player.cash == cash - 2000000, "Click builds at documented cost")
	check(built != null and built_id.begins_with("built_"), "New facility selected")
	if built == null:
		printerr(session.message)
		quit(1)
		return
	screen.inspector.price.value = 350
	screen.inspector.apply_price.pressed.emit()
	session.sim.step()
	check(session.sim.facility(built_id).price == 35000, "Manage generated facility")
	screen._save()
	var saved: Dictionary = session.snapshot()
	for day: int in range(12): session.sim.step()
	screen._load()
	check(JSON.stringify(SaveStore.encode(saved)) == JSON.stringify(SaveStore.encode(session.snapshot())), "Exact rendered city save/load")
	check(not session.sim.companies.player.monthly_history.is_empty(), "Financial history remains available")
	screen._show_settings()
	var zoom: float = screen.city.camera.size
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	screen.city._unhandled_input(wheel)
	check(screen.city.camera.size == zoom, "Modal blocks camera")
	screen.debug_entry.text = DebugConfig.PASSWORD
	screen._unlock_debug()
	await capture("07-city-diagnostics")
	screen.settings.hide()
	screen.city_seed.get_line_edit().text = "42"
	screen._new_session(2022)
	screen._resume_game()
	session.time.set_speed(0)
	check(original == session.sim.city.snapshot(), "Same numeric seed reproduces city in real UI")
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen.minimap.size * 0.75
	var old_focus: Vector3 = screen.city.focus
	screen.minimap._gui_input(event)
	check(screen.city.focus != old_focus, "Minimap click navigation")
	screen.city_seed.get_line_edit().text = "9173"
	screen.city_seed.get_line_edit().text_changed.emit("9173")
	screen._new_session(2022)
	screen._resume_game()
	check(session.sim.city.generation.seed == "9173", "New-session click commits typed seed")
	session.time.set_speed(0)
	screen.inspector.hide()
	check(original.water != session.sim.city.water and original.ambient != session.sim.city.ambient, "Different UI seed changes city structure")
	await capture("08-second-seed")
	screen.city_seed.get_line_edit().text = "42"
	screen._new_session(2012)
	screen._resume_game()
	session.time.set_speed(0)
	check(original == session.sim.city.snapshot() and not session.sim.product_public("advanced_phone"), "2012 shares generated city and keeps era gates")
	for day: int in range(30): session.sim.step()
	screen.inspector.hide()
	await capture("09-city-2012")
	check(session.sim.invariant_errors().is_empty(), "End-to-end accounting invariants")
	print("M5 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
