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
	var panel: FacilityPanel = screen.inspector
	check(panel.size.x <= 440 and panel.research_info.size.x <= 410, "Compact R&D panel")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m7a-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Capture " + name_value)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var s: GameSession = screen.session
	check(s.start(2012), "2012 UI start")
	s.time.set_speed(0)
	screen._build_city()
	screen.refresh()
	screen._show_construction()
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == "research_center": screen.build_choices.select(index)
	screen._choose_build()
	check(not screen.build_products.visible and screen.city.build_type == "research_center" and screen.city.build_product.is_empty(), "Build UI supports no product")
	var site: Vector2i = s.sim.city.valid_sites(3, 2)[0]
	screen._place(site.x, site.y)
	check(s.sim.facility("built_000001") != null, "UI constructs R&D")
	screen.select_facility("built_000001")
	var panel: FacilityPanel = screen.inspector
	for index: int in range(panel.research_choices.item_count):
		var project: Variant = panel.research_choices.get_item_metadata(index)
		if project is Dictionary and project.get("kind") == "technology" and project.get("technology") == "modern_wearables": panel.research_choices.select(index)
	panel.refresh()
	check(panel.assign_research.disabled and panel.research_info.text.contains("Not publicly available"), "Locked status and disabled assignment")
	s.unlock_debug(DebugConfig.PASSWORD)
	s.debug_action("unlock")
	panel.refresh()
	check(not panel.assign_research.disabled and panel.research_info.text.contains("Researchable"), "Public unknown project researchable")
	await capture("01-available-project")
	panel.assign_research.pressed.emit()
	for day: int in range(17): s.sim.step()
	panel.refresh()
	check(panel.research_info.text.contains("28.3%") and panel.research_info.text.contains("built_000001"), "Readable progress and assigned facility")
	await capture("02-active-progress")
	panel.stop_research.pressed.emit()
	s.sim.step()
	check(s.sim.companies.player.research_progress.modern_wearables == 170, "UI stop retains progress")
	panel.refresh()
	panel.assign_research.pressed.emit()
	for day: int in range(43): s.sim.step()
	panel.refresh()
	check(panel.research_info.text.contains("Known") and panel.research_info.text.contains("100.0%") and panel.assign_research.disabled, "Completed known UI")
	await capture("03-known-technology")
	screen.select_facility("30_research")
	check(panel.assign_research.disabled and panel.stop_research.disabled, "Rival R&D read-only")
	check(s.sim.invariant_errors().is_empty(), "UI accounting invariants")
	print("M7A VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
