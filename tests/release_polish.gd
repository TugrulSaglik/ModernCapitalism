extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var directory: String

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func clean_label(value: String) -> bool:
	for token: String in ["built_", "ambient_", "property_", "district_", "01_processors", "%s", "%d", "%f", "%0.2f", "%.2f"]:
		if token in value: return false
	return true

func run() -> void:
	directory = "res://.godot/release-polish-test-%d" % Time.get_ticks_usec()
	var store: SaveStore = SaveStore.new()
	check(store.discover(directory).is_empty(), "zero saves")
	var session: GameSession = GameSession.new()
	check(session.start(2022, 42, "sandbox", {"preset": "legacy"}), "small save fixture")
	session.time.set_speed(4)
	var state: Dictionary = session.snapshot()
	var filenames: Array[String] = []
	for index: int in range(8):
		var filename: String = store.unique_filename(directory)
		check(not filenames.has(filename), "unique generated filename")
		check(store.save_named(directory, filename, state, "QA save %d / ../ name" % index), "create save")
		filenames.append(filename)
		if index == 0: check(store.discover(directory).size() == 1, "one save")
	var saves: Array[Dictionary] = store.discover(directory)
	check(saves.size() == 8, "eight saves discovered")
	for index: int in range(1, saves.size()): check(saves[index - 1].modified_unix >= saves[index].modified_unix, "newest first")
	var restored: GameSession = GameSession.new()
	check(restored.load_game(directory.path_join(filenames[0])), "load generated save")
	check(restored.snapshot() == state, "exact state and speed preserved")
	check(store.rename_save(directory, filenames[0], "Before expansion"), "rename metadata")
	check(store.read_file(directory.path_join(filenames[0])) == state, "rename preserves authoritative state")
	check(store.inspect_file(directory.path_join(filenames[0])).label == "Before expansion", "renamed label")
	session.time.set_speed(2)
	check(store.save_named(directory, filenames[0], session.snapshot(), "Before expansion"), "overwrite same file")
	check(restored.load_game(directory.path_join(filenames[0])) and restored.time.speed == 2, "overwrite loaded speed")
	for slot: int in range(1, 4):
		check(store.write_file(directory.path_join("slot_%d.json" % slot), state), "write legacy envelope without metadata")
		check(restored.load_game(directory.path_join("slot_%d.json" % slot)), "legacy load")
	var file: FileAccess = FileAccess.open(directory.path_join("incompatible.json"), FileAccess.WRITE)
	file.store_string('{"format":"ModernCapitalism","version":1}')
	file.close()
	file = FileAccess.open(directory.path_join("broken.json"), FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	saves = store.discover(directory)
	check(saves.size() == 13, "legacy and invalid files remain visible")
	for summary: Dictionary in saves:
		if str(summary.filename).begins_with("slot_"): check(str(summary.label).begins_with("Legacy Slot "), "legacy name")
		if summary.filename == "incompatible.json": check(summary.state == "incompatible", "incompatible unloadable")
		if summary.filename == "broken.json": check(summary.state == "unreadable", "unreadable visible")
	check(not store.delete_save(directory, "../escape.json"), "reject traversal deletion")
	check(not store.save_named(directory, "../escape.json", state, "Escape"), "reject traversal save")
	check(store.delete_save(directory, "broken.json"), "delete selected invalid save")
	check(store.discover(directory).size() == 12 and FileAccess.file_exists(directory.path_join(filenames[1])), "delete only selected file")
	var browser: SaveBrowser = SaveBrowser.new()
	root.add_child(browser)
	browser.configure("load", directory)
	check(browser.summaries.size() == 12, "dynamic browser no cap")
	for panel: Node in browser.rows.get_children():
		var label: Label = panel.get_child(0).get_child(0)
		if "Incompatible" in label.text: check(panel.get_child(0).get_child(1).get_child(0).disabled, "invalid Load disabled")
	browser.queue_free()
	await process_frame
	# One bounded generated region for property/UI tests; no economy stepping.
	var game: Control = load("res://scenes/game.tscn").instantiate()
	game.city_settings = {"width": 192, "depth": 144}
	game.save_directory = directory
	root.add_child(game)
	game.session.time.set_speed(0)
	await process_frame
	await process_frame
	for index: int in range(game.facility_list.item_count):
		check(clean_label(game.facility_list.get_item_text(index)), "facility context label")
	var map: CityMap = game.session.sim.cities[game.session.active_city]
	var estate: RealEstate = game.session.sim.real_estates[game.session.active_city]
	var property_id: String = str(estate.properties.keys()[0])
	game.select_property(property_id)
	check(clean_label(game.property_details.text) and clean_label(game.facility_list.get_item_text(0)), "property inspector no raw format tokens or IDs")
	check("Population " + map.population_text() in game.property_details.text, "population real-person units")
	var found: bool = false
	for site: Vector2i in map.valid_sites(2, 2):
		if not estate.land_error(game.session.sim, "player", site.x, site.y, 2, 2, true).is_empty(): continue
		game.select_parcel(site.x, site.y)
		var cost: int = estate.land_cost(game.session.sim, "player", site.x, site.y, 2, 2)
		check("Additional land required: 4 cells • " + CompanyReports.money(cost) in game.property_details.text, "land total reconciles with project footprint")
		check("Selected cell land value: $%.2f" % (int(map.parcels[CityMap.key(site.x, site.y)].land_value) / 100.0) in game.property_details.text, "selected cell value authoritative")
		found = true
		break
	check(found, "vacant project inspected")
	var road: PackedStringArray = str(map.roads[0]).split(",")
	game.select_parcel(int(road[0]), int(road[1]))
	check("Land cannot be purchased" in game.property_details.text and not "Additional land required" in game.property_details.text, "zero-value public road not quoted as development")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	for context: String in ["facility", "property", "parcel", "port"]:
		match context:
			"facility": game.select_facility("20_player")
			"property": game.select_property(property_id)
			"parcel": game.select_parcel(int(road[0]), int(road[1]))
			"port": game._select_port()
		game.city._unhandled_input(right)
		check(game.selected_id.is_empty() and game.selected_property.is_empty() and not game.selected_port and game.selected_parcel == Vector2i(-1, -1), "RMB clears " + context)
		check(not game.inspector.visible and not game.property_panel.visible and game.facility_list.get_item_text(0) == "Select a facility, property or parcel", "neutral context")
	game.select_facility("20_player")
	game._handle_escape()
	check(game.app_menu.visible and game.selected_id == "20_player" and game.application_pause, "Escape opens menu without clearing context")
	game.city._unhandled_input(right)
	check(game.selected_id == "20_player", "modal blocks world RMB")
	game._resume_game()
	game.city.begin_placement("electronics_store", "smartphone")
	game.city._unhandled_input(right)
	check(game.city.build_type.is_empty() and not game.city.preview.visible, "RMB cancels placement")
	var viewport: SubViewport = game.city_viewport
	check(viewport.size.x > 0 and viewport.size.y > 0, "positive viewport dimensions")
	check(game.minimap.get_parent() == game.find_child("CityWorkspace", true, false), "minimap anchored inside workspace")
	check(game.minimap.clip_contents, "minimap drawing clipped")
	# Probe the actual camera transform at every edge and zoom, independently of terrain orientation.
	for dimensions: Vector2i in [Vector2i(192, 144), Vector2i(300, 240), Vector2i(384, 288)]:
		game.city.map_width = dimensions.x
		game.city.map_depth = dimensions.y
		for zoom: float in [18.0, dimensions.x * CityView.CELL * 1.5]:
			game.city.camera.size = zoom
			for corner: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
				game.city.focus_cell(corner.x * dimensions.x, corner.y * dimensions.y)
				for edge: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
					for height: float in [-0.5, 14.0]:
						var point: Vector3 = game.city.cell_position(edge.x * dimensions.x - 0.5, edge.y * dimensions.y - 0.5) + Vector3.UP * height
						var depth: float = -game.city.camera.to_local(point).z
						check(depth > game.city.camera.near and depth < game.city.camera.far, "all map corners within clipping planes")
			game.city.pan(Vector3(1, 0, 1), 100000.0)
			check(absf(game.city.focus.x) <= dimensions.x * CityView.CELL / 2 + 0.001 and absf(game.city.focus.z) <= dimensions.y * CityView.CELL / 2 + 0.001, "extreme pan clamped")
	# The original fixed offset fails the same regression geometry.
	var original_depth: float = Vector3(35, 35, 35).length() - Vector3.ONE.normalized().dot(Vector3(192 * 1.4, 0, 144 * 1.4))
	check(original_depth < 0, "regression confirms original near-plane clipping")
	game.queue_free()
	await process_frame
	print("RELEASE POLISH: %d checks, %d failures. Test saves: %s" % [checks, failures.size(), directory])
	quit(0 if failures.is_empty() else 1)


