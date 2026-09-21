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

func build_headquarters() -> SimFacility:
	var sim: Economy = screen.session.sim
	var definition: Dictionary = sim.catalog.facility_types.corporate_headquarters
	var sites: Array[Vector2i] = sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "HQ visual construction site")
	var id: String = "built_%06d" % sim.city.next_facility
	check(screen.session.submit({"type": "build_facility", "archetype": "corporate_headquarters", "product": "", "x": sites[0].x, "y": sites[0].y}), "Construct visual HQ")
	screen._build_city()
	return sim.facility(id)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	var hq: SimFacility = build_headquarters()
	var owner: SimCompany = screen.session.sim.companies.player
	owner.staff_counts.operations_manager = 2
	owner.staff_counts.marketing_manager = 1
	owner.staff_counts.research_manager = 2
	owner.staff_counts.finance_manager = 1
	owner.staff_payroll_funded = true
	screen.select_facility(hq.id)
	screen.inspector.refresh()
	await process_frame
	await process_frame
	var panel: FacilityPanel = screen.inspector
	check(panel.staff_info.text.contains("Management effects: ACTIVE"), "Active management state rendered")
	check(panel.staff_info.text.contains("+20% production/retail capacity") and panel.staff_info.text.contains("-5% facility overhead"), "Role effects rendered")
	check(panel.staff_info.get_content_height() <= panel.staff_info.size.y + 1.0, "HQ staff effect text does not clip")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m8b3-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join("01-staffed-hq-inspector.png")) == OK, "Capture staffed HQ inspector")
	print("M8B3 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
