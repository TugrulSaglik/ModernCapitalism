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
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m3-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Screenshot " + name_value)

func move_to(x: int, y: int) -> void:
	var city: CityView = screen.city
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = city.camera.unproject_position(city.cell_position(x, y))
	city._unhandled_input(motion)

func click() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen.city.camera.unproject_position(screen.city.cell_position(screen.city.preview_cell.x, screen.city.preview_cell.y))
	screen.city._unhandled_input(event)

func choose(kind: String) -> void:
	screen._show_construction()
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == kind:
			screen.build_choices.select(index)
			screen.build_choices.item_selected.emit(index)
			return

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	screen.city_settings = {"preset": "legacy"}
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	session = screen.session
	session.time.set_speed(0)
	screen.save_directory = "res://.godot/m3-ui-saves"
	screen.refresh()
	await capture("01-overview")
	screen.select_facility("20_player")
	await capture("02-selected-retail")
	screen.select_facility("10_orion")
	await capture("03-selected-factory")
	choose("electronics_store")
	check(screen.construction.visible and screen.city.build_type == "electronics_store", "Build menu selects retail")
	move_to(3, 18)
	check(not screen.city.preview_error.is_empty(), "Cursor projects onto occupied invalid site")
	var cash: int = session.sim.companies.player.cash
	click()
	check(session.sim.companies.player.cash == cash and session.sim.facilities.size() == 9, "Invalid placement click has no effect")
	await capture("04-preview-invalid")
	move_to(24, 18)
	check(screen.city.preview_error.is_empty(), "Cursor projects onto valid site")
	await capture("05-preview-valid")
	click()
	check(session.sim.companies.player.cash == cash - 2000000 and session.sim.clock.tick == 0, "Placement click deducts cash while paused")
	check(screen.city.buildings.has("built_000001") and session.sim.facility("built_000001") != null, "Construction synchronizes scene and economy")
	check(screen.inspector.selected_id == "built_000001" and screen.inspector.visible, "Constructed facility immediately selected")
	await physics_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen.city.camera.unproject_position(screen.city.buildings.built_000001.body.global_position)
	screen.city._unhandled_input(event)
	check(screen.selected_id == "built_000001", "Physics selection maps built ID")
	screen.inspector.price.value = 345.0
	screen.inspector.apply_price.pressed.emit()
	choose("assembly_plant")
	move_to(24, 10)
	click()
	check(session.sim.facility("built_000001").price == 34500 and session.sim.facility("built_000002").type_id == "assembly_plant", "Industrial construction flushes managed retail price")
	choose("warehouse")
	move_to(24, 3)
	click()
	check(session.sim.facility("built_000003").type_id == "warehouse", "Warehouse UI construction")
	await capture("06-expanded-city")
	screen._save()
	var saved: Dictionary = session.snapshot()
	screen.select_facility("built_000001")
	screen.inspector.demolish.pressed.emit()
	check(screen.demolition.visible, "Demolition requires explicit confirmation")
	screen.demolition.confirmed.emit()
	screen.demolition.hide()
	check(not screen.city.buildings.has("built_000001"), "Demolition cleans rendered selection")
	screen._load()
	check(JSON.stringify(SaveStore.encode(saved)) == JSON.stringify(SaveStore.encode(session.snapshot())), "HUD load restores exact constructed city")
	screen.select_facility("built_000001")
	screen.inspector.demolish.pressed.emit()
	screen.demolition.confirmed.emit()
	screen.demolition.hide()
	check(session.sim.facility("built_000001") == null and not screen.city.buildings.has("built_000001"), "Post-load demolition cleans both states")
	screen.select_facility("built_000003")
	await capture("07-after-demolition")
	choose("electronics_store")
	screen.city.cancel_placement()
	check(not screen.construction.visible and screen.city.build_type.is_empty(), "Placement cancellation restores inspector")
	screen._new_session(2012)
	screen._resume_game()
	session.time.set_speed(0)
	choose("electronics_store")
	var early_products: Array[String] = []
	for index: int in range(screen.build_products.item_count): early_products.append(str(screen.build_products.get_item_metadata(index)))
	check(screen.build_products.item_count > 0 and "advanced_phone" not in early_products, "2012 construction excludes advanced product")
	move_to(24, 18)
	click()
	check(session.sim.facility("built_000001") != null, "2012 graphical construction works")
	await capture("08-city-2012")
	check(session.sim.invariant_errors().is_empty(), "Graphical flow preserves accounts")
	print("M3 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
