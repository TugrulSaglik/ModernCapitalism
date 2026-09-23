extends SceneTree

var checks: int = 0
var failures: int = 0
var screen: Control
var save_dir: String = "res://.godot/8ui-c-test-saves"

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.save_directory = save_dir
	for slot_number: int in range(1, 4):
		var path: String = ProjectSettings.globalize_path(screen.slot_path(slot_number))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

	var top: Control = screen.get_node("ShellMargin/ShellColumn/TopApplicationBar")
	check(top.find_child("MenuButton", true, false) != null, "Top bar contains Menu")
	check(_count_type(top, "SpinBox") == 0, "Top bar has no persistent slot SpinBox")
	check(not _all_button_text(top).has("Save") and not _all_button_text(top).has("Load") and not _all_button_text(top).has("Settings"), "Top bar has no persistent Save Load Settings buttons")

	screen.session.time.set_speed(4)
	var tick: int = screen.session.sim.clock.tick
	screen._show_menu()
	check(screen.app_menu.visible and screen.application_pause and screen.world_input_blocked(), "Menu opens as blocking application pause")
	screen._process(4.0)
	check(screen.session.sim.clock.tick == tick and screen.session.time.speed == 4, "Menu suppresses advancement without changing selected speed")
	screen._input(_key(KEY_1))
	check(screen.session.time.speed == 4, "Time hotkeys do not pass through menu")
	screen._input(_key(KEY_ESCAPE))
	check(not screen.application_pause and not screen.app_menu.visible and screen.session.time.speed == 4, "Esc resumes at preserved speed")

	screen._save(1)
	check(FileAccess.file_exists(screen.slot_path(1)), "Existing GameSession save action writes Slot 1")
	var invalid: FileAccess = FileAccess.open(screen.slot_path(3), FileAccess.WRITE)
	invalid.store_string("not json")
	invalid.close()
	var store: SaveStore = SaveStore.new()
	var valid: Dictionary = store.inspect_file(screen.slot_path(1))
	var empty: Dictionary = store.inspect_file(screen.slot_path(2))
	var unreadable: Dictionary = store.inspect_file(screen.slot_path(3))
	check(valid.state == "valid" and valid.company == "Player Electronics" and valid.date == screen.session.sim.clock.date_string() and valid.starting_year == 2022 and valid.mode == "sandbox" and valid.difficulty == "standard" and valid.difficulty_name == "Standard", "Valid slot metadata includes difficulty without mutation")
	check(not str(valid.modified).is_empty(), "Valid slot includes filesystem modified time")
	check(empty.state == "empty" and unreadable.state == "unreadable", "Empty and unreadable slots are distinguished")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(screen.slot_path(1)))
	raw.catalog_hash = "incompatible-test-catalog"
	invalid = FileAccess.open(screen.slot_path(3), FileAccess.WRITE)
	invalid.store_string(JSON.stringify(raw))
	invalid.close()
	var incompatible: Dictionary = store.inspect_file(screen.slot_path(3))
	check(incompatible.state == "incompatible" and str(incompatible.reason).contains("catalog"), "Incompatible slot is unavailable with a concise reason")
	check(SaveStore.FORMAT_VERSION == 2 and screen.session.sim.snapshot().schema_version == 17 and screen.session.sim.catalog.version == 9, "Save format 2 / schema 17 / catalog 9")

	screen._show_menu()
	screen._show_save_browser("load")
	check(screen.save_browser.visible and screen.save_browser.slot_buttons.size() == 3, "Load browser shows three slots")
	check(not screen.save_browser.slot_buttons[1].disabled and screen.save_browser.slot_buttons[2].disabled and screen.save_browser.slot_buttons[3].disabled, "Only valid load slot is selectable")
	screen._on_browser_slot_requested("load", 1, screen.save_browser.summaries[1])
	check(screen.load_confirmation.visible, "Loading requires confirmation")
	screen.session.debug_unlocked = true
	screen.session.sim.step()
	var changed_tick: int = screen.session.sim.clock.tick
	screen.load_confirmation.confirmed.emit()
	check(screen.session.sim.clock.tick < changed_tick and not screen.session.debug_unlocked, "Load restores session and re-locks Debug")
	check(screen.application_pause and screen.session.time.speed == 4, "Loaded speed is authoritative while application pause remains")
	check(screen.session.sim.facility(screen.selected_id) != null or screen.selected_id.is_empty(), "Selection is valid or neutral after load")
	screen._show_save_browser("save")
	screen._on_browser_slot_requested("save", 1, screen.save_browser.summaries[1])
	check(screen.overwrite_confirmation.visible and screen.overwrite_confirmation.dialog_text.contains("cannot be undone"), "Occupied slot requires overwrite confirmation")
	screen.overwrite_confirmation.hide()
	screen._on_browser_slot_requested("save", 2, screen.save_browser.summaries[2])
	check(FileAccess.file_exists(screen.slot_path(2)) and screen.save_browser.summaries[2].state == "valid", "Saving to empty slot refreshes metadata")

	screen._return_to_menu()
	screen._show_settings()
	check(screen.settings.visible and screen.application_pause and not screen.app_menu.visible, "Settings is entered from paused menu flow")
	check(screen.current_difficulty.text == "Standard" and screen.new_sandbox_difficulty.item_count == 3 and screen._selected_difficulty() == "standard", "Settings shows current difficulty and defaults selector to current Standard")
	check(screen.difficulty_description.text.contains("Baseline") and screen.settings.find_child("DifficultyRulesNote", true, false).text.contains("not economic rules or hidden bonuses"), "Settings explains selected policy and no-cheat rule")
	screen.new_sandbox_difficulty.select(2)
	screen.new_sandbox_difficulty.item_selected.emit(2)
	check(screen.session.sim.difficulty == "standard" and screen.difficulty_description.text.contains("assertive"), "Next-sandbox selector cannot mutate current session")
	screen._confirm_new_session(2012)
	check(screen.new_session_confirmation.visible and screen.new_session_confirmation.dialog_text.contains("2012 Competitive") and screen.new_session_confirmation.dialog_text.contains("Unsaved progress"), "New sandbox confirmation includes era and difficulty")
	screen.new_session_confirmation.confirmed.emit()
	check(screen.session.sim.starting_year == 2012 and screen.session.sim.difficulty == "competitive" and screen.application_pause and screen.app_menu.visible, "Confirmed new sandbox stores exact difficulty, rebuilds UI and remains paused")

	screen._resume_game()
	screen._show_construction()
	check(screen.construction.visible and not screen.city.build_type.is_empty(), "Construction selection begins placement")
	check(screen.build_details.text.contains("Cost") and screen.build_details.text.contains("Footprint") and screen.build_details.text.contains("Daily overhead"), "Construction presents structured catalog details")
	check(screen.build_category.text.contains("FACILITY"), "Construction category is visible")
	var research_index: int = _facility_index("research_center")
	screen.build_choices.select(research_index)
	screen._choose_build()
	check(not screen.build_products.visible and screen.build_details.text.contains("Base research rate"), "Productless R&D hides product and shows research rate")
	var hq_index: int = _facility_index("corporate_headquarters")
	screen.build_choices.select(hq_index)
	screen._choose_build()
	check(not screen.build_products.visible and screen.build_details.text.contains("Staff capacity  8 staff"), "Productless HQ shows catalog staff capacity")
	var definition: Dictionary = screen.session.sim.catalog.facility_types.corporate_headquarters
	var site: Vector2i = screen.session.sim.city.valid_sites(definition.width, definition.depth)[0]
	screen.city.update_preview(site.x, site.y)
	check(screen.city.preview_error.is_empty() and screen.build_reason.text.begins_with("VALID SITE"), "Valid placement feedback includes parcel context")
	await process_frame
	var workspace: Control = screen.get_node("ShellMargin/ShellColumn/MainWorkspace")
	check(screen.build_cancel.get_global_rect().end.y <= workspace.get_global_rect().end.y, "Construction actions fit the right workspace")
	screen.city.update_preview(-1, -1)
	check(not screen.city.preview_error.is_empty() and screen.build_reason.text.begins_with("CANNOT BUILD HERE") and screen.build_reason.text.contains(screen.city.preview_error), "Invalid placement preserves specific validation reason")
	screen._input(_key(KEY_ESCAPE))
	check(screen.city.build_type.is_empty() and not screen.construction.visible, "Esc cancels placement before opening menu")
	screen._input(_key(KEY_ESCAPE))
	check(screen.app_menu.visible, "Esc opens application menu during gameplay")
	screen._resume_game()

	screen.select_facility("20_player")
	await physics_frame
	for empty_site: Vector2i in screen.session.sim.city.valid_sites(1, 1):
		var ground_click: InputEventMouseButton = InputEventMouseButton.new()
		ground_click.button_index = MOUSE_BUTTON_LEFT
		ground_click.pressed = true
		ground_click.position = screen.city.camera.unproject_position(screen.city.cell_position(empty_site.x, empty_site.y))
		screen.city._unhandled_input(ground_click)
		if screen.selected_id.is_empty(): break
	check(screen.selected_id.is_empty() and not screen.inspector.visible and screen.facility_list.selected == 0 and screen.facility_list.get_item_text(0) == "No facility selected", "Empty ground selection clears inspector and selector")
	screen.select_facility("20_player")
	check(screen.city.selected == "20_player" and screen.inspector.visible, "Facility selection remains highlighted and synchronized")
	screen._show_menu()
	check(screen.world_input_blocked(), "Application flow blocks world input")
	var old_focus: Vector3 = screen.city.focus
	var map_click: InputEventMouseButton = InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = screen.minimap.size * 0.8
	screen.minimap._gui_input(map_click)
	check(screen.city.focus == old_focus, "Menu blocks minimap navigation")
	screen._resume_game()
	screen.minimap._gui_input(map_click)
	check(screen.city.focus != old_focus, "Minimap navigation remains available in gameplay")
	check(screen.status.text.contains("Pending commands"), "Status retains pending command count")
	check(screen.get_node("ShellMargin/ShellColumn/MainWorkspace").get_global_rect().end.x <= 1280.0, "Main workspace fits 1280 width")

	print("8UI-C RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _facility_index(id: String) -> int:
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == id: return index
	return -1

func _all_button_text(root_node: Node) -> Array[String]:
	var values: Array[String] = []
	for child: Node in root_node.find_children("*", "Button", true, false): values.append(child.text)
	return values

func _count_type(root_node: Node, type_name: String) -> int:
	return root_node.find_children("*", type_name, true, false).size()
