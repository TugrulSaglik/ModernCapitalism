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

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var session: GameSession = screen.session
	session.time.set_speed(0)
	var definition: Dictionary = session.sim.catalog.facility_types.corporate_headquarters
	var site: Vector2i = session.sim.city.valid_sites(definition.width, definition.depth)[0]
	check(session.submit({"type": "build_facility", "archetype": "corporate_headquarters", "product": "", "x": site.x, "y": site.y}), "Build headquarters")
	var hq: SimFacility = session.sim.headquarters("player")
	check(session.submit({"type": "hire_staff", "facility": hq.id, "role": "operations_manager", "quantity": 2}), "Hire operations staff")
	check(session.submit({"type": "hire_staff", "facility": hq.id, "role": "research_manager", "quantity": 1}), "Hire research staff")
	screen.city.sync(session.sim.snapshot())
	screen.refresh()
	screen.select_facility(hq.id)
	await process_frame
	await process_frame
	var panel: FacilityPanel = screen.inspector
	check(panel.staff_info.text.contains("Total staff: 3 / 8") and panel.staff_info.text.contains("Configured daily payroll: $160.00/day"), "Staff summary is readable")
	check(panel.staff_role.visible and panel.hire_staff.visible and panel.dismiss_staff.visible and panel.size.x <= 440, "Compact staffing controls are visible")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m8b2-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join("01-headquarters-staffing.png")) == OK, "Capture headquarters staffing")
	print("M8B2 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
