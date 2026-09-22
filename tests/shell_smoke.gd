extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.save_directory = "res://.godot/8ui-a2-saves"
	check(screen.get_node("ShellMargin/ShellColumn/TopApplicationBar") != null, "Application bar exists")
	check(screen.get_node("ShellMargin/ShellColumn/BottomHudBar") != null, "Bottom HUD exists")
	check(screen.facility_list.get_parent().name == "FacilityContextBar", "Facility selector is contextual")
	check(screen.facility_list.get_item_text(0) == "No facility selected" and screen.facility_list.get_item_text(1).contains(" • "), "Facility selector has neutral state and readable entries")
	screen._show_company()
	check(screen.overview.visible and screen.world_input_blocked(), "Company opens reports and blocks world input")
	screen.overview.hide()
	screen._show_construction()
	check(screen.construction.visible and not screen.inspector.visible and not screen.city.build_type.is_empty(), "Build enters construction and hides inspector")
	screen.city.cancel_placement()
	screen._show_settings()
	check(screen.settings.visible and screen.world_input_blocked() and screen.application_pause, "Settings blocks world input and pauses advancement")
	screen._return_to_menu()
	screen._resume_game()
	for speed: int in GameTime.SPEEDS:
		screen.speed_buttons[speed].pressed.emit()
		check(screen.session.time.speed == speed and screen.speed_buttons[speed].button_pressed, "Speed %d is active" % speed)
	for key_and_speed: Array in [[KEY_1, 1], [KEY_2, 2], [KEY_3, 4], [KEY_4, 16]]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key_and_speed[0]
		event.pressed = true
		screen._input(event)
		check(screen.session.time.speed == key_and_speed[1], "Keyboard speed %d works" % key_and_speed[1])
	var pause: InputEventKey = InputEventKey.new()
	pause.keycode = KEY_SPACE
	pause.pressed = true
	screen._input(pause)
	check(screen.session.time.speed == 0, "Space toggles pause")
	screen._save(1)
	check(FileAccess.file_exists(screen.slot_path(1)), "Save browser slot path writes")
	screen._load(1)
	check(screen.session.message.contains("Loaded"), "Dedicated slot load restores")
	var definition: Dictionary = screen.session.sim.catalog.facility_types.corporate_headquarters
	var site: Vector2i = screen.session.sim.city.valid_sites(definition.width, definition.depth)[0]
	check(screen.session.submit({"type": "build_facility", "archetype": "corporate_headquarters", "product": "", "x": site.x, "y": site.y}), "Build representative headquarters")
	var hq: SimFacility = screen.session.sim.headquarters("player")
	check(screen.session.submit({"type": "hire_staff", "facility": hq.id, "role": "operations_manager", "quantity": 2}), "Staff representative headquarters")
	screen.city.sync(screen.session.sim.snapshot())
	screen._refresh_facility_list()
	screen.select_facility(hq.id)
	screen.refresh()
	check(screen.facility_list.get_item_metadata(screen.facility_list.selected) == hq.id and screen.city.selected == hq.id, "Selector and city selection stay synchronized")
	check(screen.inspector.visible and screen.inspector.size.y >= screen.inspector.tabs.get_combined_minimum_size().y, "Selected facility inspector remains visible")
	await process_frame
	var hud: Control = screen.get_node("ShellMargin/ShellColumn/BottomHudBar")
	var inspector_scroll: Control = screen.get_node("ShellMargin/ShellColumn/MainWorkspace/WorkspaceInspectorScroll")
	check(hud.get_global_rect().end.y <= 800.0 and inspector_scroll.get_global_rect().end.x <= 1280.0, "Shell fits 1280 by 800")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory := "res://.godot/8ui-a2-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join("01-game-shell.png")) == OK, "Capture representative shell")
	print("8UI-A2 SHELL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
