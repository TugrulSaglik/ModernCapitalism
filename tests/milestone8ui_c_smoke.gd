extends SceneTree

var failures: int = 0
var screen: Control
var directory: String = "res://.godot/8ui-c-screenshots"

func _initialize() -> void:
	call_deferred("_run")

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var result: Error = root.get_texture().get_image().save_png(directory.path_join(filename))
	if result != OK:
		failures += 1
		printerr("FAIL: capture ", filename)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(2)
	screen.save_directory = "res://.godot/8ui-c-visual-saves"
	for slot_number: int in range(1, 4):
		var path: String = ProjectSettings.globalize_path(screen.slot_path(slot_number))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	screen._save(1)
	var invalid: FileAccess = FileAccess.open(screen.slot_path(3), FileAccess.WRITE)
	invalid.store_string("incompatible fixture")
	invalid.close()

	screen._show_construction()
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == "electronics_store":
			screen.build_choices.select(index)
			screen._choose_build()
			break
	var definition: Dictionary = screen.session.sim.catalog.facility_types.electronics_store
	var sites: Array[Vector2i] = screen.session.sim.city.valid_sites(definition.width, definition.depth)
	var site: Vector2i = sites[sites.size() / 2]
	screen.city.focus_cell(site.x + 1, site.y)
	screen.city.update_preview(site.x, site.y)
	screen.refresh()
	await capture("01-construction.png")

	screen.city.cancel_placement()
	screen._show_menu()
	screen._show_save_browser("save")
	await capture("02-save-browser.png")
	print("8UI-C VISUAL RESULT: 2 screenshots, %d failures" % failures)
	quit(0 if failures == 0 else 1)
