extends SceneTree

var checks: int = 0
var failures: int = 0
var screen: Control
var panel: FacilityPanel
var commands: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://scenes/game.tscn").instantiate()
	screen.city_settings = {"preset": "legacy"}
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	check(screen.session.start(2012, 42, "sandbox", {"preset": "legacy"}), "2012 B3 fixture starts")
	screen.session.time.set_speed(0)
	screen._build_city()
	panel = screen.inspector
	panel.command_requested.connect(func(command: Dictionary) -> void: commands.append(command.duplicate(true)))
	var lab: SimFacility = _build("research_center", "")
	var hq: SimFacility = _build("corporate_headquarters", "")
	var warehouse: SimFacility = _build("warehouse", "smartphone")
	var factory: SimFacility = _build("assembly_plant", "smartphone")
	check(lab != null and hq != null and warehouse != null and factory != null, "B3 facility fixtures built")
	screen.session.unlock_debug(DebugConfig.PASSWORD)
	screen.session.debug_action("unlock")
	for item: Array in [["operations_manager", 2], ["marketing_manager", 2], ["research_manager", 2], ["finance_manager", 1]]:
		check(screen.session.submit({"type": "hire_staff", "facility": hq.id, "role": item[0], "quantity": item[1]}), "Hire " + str(item[0]))
	screen.session.sim.step()
	screen.city.sync(screen.session.sim.snapshot())
	_test_research(lab)
	_test_headquarters(hq)
	_test_rivals(lab, hq)
	await _test_transitions_and_layout(warehouse, lab, hq, factory)
	if DisplayServer.get_name() != "headless": await _capture(hq)
	print("8UI-B3 FACILITY PANEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _build(type_id: String, product_id: String) -> SimFacility:
	var definition: Dictionary = screen.session.sim.catalog.facility_types[type_id]
	var sites: Array[Vector2i] = screen.session.sim.city.valid_sites(definition.width, definition.depth)
	if sites.is_empty(): return null
	var next_id: String = "built_%06d" % screen.session.sim.city.next_facility
	if not screen.session.submit({"type": "build_facility", "archetype": type_id, "product": product_id, "x": sites[0].x, "y": sites[0].y}): return null
	return screen.session.sim.facility(next_id)

func _test_research(lab: SimFacility) -> void:
	var sim: Economy = screen.session.sim
	var owner: SimCompany = sim.companies.player
	var technology: Dictionary = sim.technology_project("modern_wearables")
	owner.research_progress["modern_wearables"] = 120
	lab.research_project = technology.duplicate(true)
	screen.select_facility(lab.id)
	panel.refresh()
	check(panel.tabs.get_tab_title(0) == "Overview" and panel.tabs.get_tab_title(1) == "Research" and panel.tabs.is_tab_hidden(2) and panel.tabs.is_tab_hidden(3), "R&D exposes only Overview and Research")
	check(panel.header_title.text == "R&D center" and panel.header_meta.text.contains(lab.id) and panel.header_status.text == "OPERATING", "R&D persistent header is correct")
	check((panel.research_overview_metrics.rate as Label).text == "10 base · 12 effective points/day", "R&D Overview base/effective rate exact")
	check((panel.research_overview_metrics.overhead as Label).text == "%s/day" % panel._base_effective_money(500, sim.effective_overhead(lab)), "R&D Overview overhead exact")
	check((panel.research_project_metrics.name as Label).text == "Modern Wearables" and (panel.research_project_metrics.kind as Label).text == "Technology", "R&D active project identity exact")
	check((panel.research_project_metrics.progress as Label).text.contains("120 / 600") and (panel.research_project_metrics.remaining as Label).text == "40 days" and (panel.research_project_metrics.expense as Label).text == "$25.00/day", "R&D project progress, ETA and cost exact")
	check((panel.research_overview_metrics.known as Label).text == "%d / %d" % [owner.known_technologies.size(), sim.catalog.technologies.size()], "Company knowledge count exact")
	panel.tabs.current_tab = 1
	_select_project(technology)
	panel.refresh()
	check((panel.research_detail_metrics.public_year as Label).text == "2015" and (panel.research_detail_metrics.knowledge as Label).text == "Unknown", "Technology detail year and knowledge exact")
	check(_all_text(panel.research_prerequisites).contains("Electronics") and _all_text(panel.research_prerequisites).contains("KNOWN"), "Technology prerequisites show known state")
	check(panel.research_progress.value == 120 and panel.research_progress.max_value == 600 and panel.research_progress_text.text == "120 / 600 points · 20.0%", "Technology progress visual is exact")
	check((panel.research_detail_metrics.facility as Label).text.contains(lab.id) and panel.assign_research.disabled and not panel.stop_research.disabled, "Assigned facility and active actions are exact")
	commands.clear()
	panel.stop_research.pressed.emit()
	check(_last_command("stop_research", lab.id) and commands.back().size() == 2, "Stop research command is exact")
	lab.research_project = {}
	var quality: Dictionary = sim.product_quality_project(owner.id, "smartphone")
	owner.product_quality_progress["smartphone"] = {"target_level": 1, "progress": 90}
	_select_project(quality)
	panel.refresh()
	check((panel.research_detail_metrics.levels as Label).text == "0 current · 1 target · 5 maximum" and panel.research_progress_text.text == "90 / 300 points · 30.0%", "Product-quality level and retained progress exact")
	check(panel.research_status.text == "Each completed level improves process quality for newly manufactured goods.", "Product-quality effect is scoped to newly manufactured goods")
	commands.clear()
	panel.assign_research.pressed.emit()
	check(_last_command("assign_research", lab.id) and sim.project_equal(commands.back().project, quality), "Assign research command preserves exact project dictionary")
	var process: Dictionary = sim.process_efficiency_project(owner.id, "smartphone")
	owner.process_efficiency_progress["smartphone"] = {"target_level": 1, "progress": 75}
	_select_project(process)
	panel.refresh()
	check((panel.research_detail_metrics.levels as Label).text == "0 current · 1 target · 5 maximum" and panel.research_progress_text.text == "75 / 300 points · 25.0%", "Process-efficiency level and retained progress exact")
	check(_all_text(panel.research_prerequisites).contains("5%") and _all_text(panel.research_prerequisites).contains("$30.00") and _all_text(panel.research_prerequisites).contains("$28.50"), "Process reduction and conversion costs exact")
	check(panel.research_status.text == "Applies to conversion cost of newly produced goods.", "Process effect is scoped to newly produced goods")
	var known: Dictionary = sim.technology_project("electronics")
	_select_project(known)
	panel.refresh()
	check((panel.research_detail_metrics.status as Label).text == "Known" and panel.assign_research.disabled and panel.research_progress_text.text.ends_with("100.0%"), "Known technology is explicit and cannot be redundantly assigned")

func _test_headquarters(hq: SimFacility) -> void:
	var sim: Economy = screen.session.sim
	var owner: SimCompany = sim.companies.player
	screen.select_facility(hq.id)
	panel.refresh()
	check(panel.tabs.get_tab_title(0) == "Overview" and panel.tabs.get_tab_title(1) == "Staffing" and panel.tabs.is_tab_hidden(2) and panel.tabs.is_tab_hidden(3), "HQ exposes only Overview and Staffing")
	check((panel.headquarters_finance_metrics.asset_cost as Label).text == CompanyReports.money(hq.asset_cost) and (panel.headquarters_finance_metrics.depreciation as Label).text == CompanyReports.money(hq.accumulated_depreciation) and (panel.headquarters_finance_metrics.book_value as Label).text == CompanyReports.money(hq.asset_cost - hq.accumulated_depreciation), "HQ fixed asset values exact")
	check((panel.headquarters_finance_metrics.overhead as Label).text == "%s/day" % panel._base_effective_money(int(sim.catalog.facility_types[hq.type_id].overhead), sim.effective_overhead(hq)), "HQ overhead exact")
	check((panel.headquarters_staff_metrics.staff as Label).text == "7 / 8 employed" and (panel.headquarters_staff_metrics.payroll as Label).text == "$375.00/day", "HQ staff and configured payroll exact")
	check((panel.headquarters_staff_metrics.status as Label).text == "ACTIVE", "HQ management effect activation exact")
	check((panel.headquarters_effect_metrics.operations as Label).text.begins_with("+20%") and (panel.headquarters_effect_metrics.marketing as Label).text.begins_with("+20%") and (panel.headquarters_effect_metrics.research as Label).text.begins_with("+20%") and (panel.headquarters_effect_metrics.finance as Label).text.begins_with("−5%"), "All four configured effects exact")
	check(panel.demolish.disabled and panel.demolition_note.visible, "Staffed HQ demolition stays disabled with explanation")
	panel.tabs.current_tab = 1
	panel.refresh()
	check(panel.staffing_roles.get_child_count() == 4 and _all_text(panel.staffing_roles).contains("Operations manager") and _all_text(panel.staffing_roles).contains("Finance manager"), "All four staffing roles are structured")
	check((panel.staffing_metrics.capacity as Label).text == "7 / 8 employed" and (panel.staffing_metrics.payroll as Label).text == "$375.00/day" and panel.staffing_status.text.contains("ACTIVE"), "Staffing capacity, payroll and status exact")
	_select_role("finance_manager")
	panel.refresh()
	check((panel.staffing_role_metrics.count as Label).text == "1" and (panel.staffing_role_metrics.salary as Label).text == "$55.00/day" and (panel.staffing_role_metrics.effect as Label).text.contains("−5%") and (panel.staffing_role_metrics.cap as Label).text == "−15%", "Selected Finance role values exact")
	commands.clear()
	panel.hire_staff.pressed.emit()
	check(_last_command("hire_staff", hq.id) and commands.back().role == "finance_manager" and commands.back().quantity == 1, "Hire command is exact")
	commands.clear()
	panel.dismiss_staff.pressed.emit()
	check(_last_command("dismiss_staff", hq.id) and commands.back().role == "finance_manager" and commands.back().quantity == 1, "Dismiss command is exact")
	owner.staff_payroll_funded = false
	panel.refresh()
	check(panel.staffing_status.text.contains("INACTIVE — payroll not funded"), "Unfunded payroll reason exact")
	hq.operating = false
	panel.refresh()
	check(panel.hire_staff.disabled and not panel.dismiss_staff.disabled and panel.staffing_status.text.contains("headquarters suspended"), "Suspended HQ blocks hiring, permits dismissal, and explains inactive effects")
	check(panel.staffing_note.text.contains("Payroll remains due") and panel.staffing_note.text.contains("overhead is paused") and panel.staffing_note.text.contains("depreciation continues"), "Suspension consequences are concise and complete")
	hq.operating = true
	owner.staff_payroll_funded = true

func _test_rivals(lab: SimFacility, hq: SimFacility) -> void:
	screen.select_facility("30_research")
	panel.tabs.current_tab = 1
	panel.refresh()
	check(panel.assign_research.disabled and panel.stop_research.disabled, "Rival R&D controls are read-only")
	var original_company: String = hq.company_id
	hq.company_id = "rival"
	screen.select_facility(hq.id)
	panel.tabs.current_tab = 1
	panel.refresh()
	check(panel.hire_staff.disabled and panel.dismiss_staff.disabled and panel.staff_role.disabled and panel.operating.disabled and panel.demolish.disabled, "Rival HQ controls are read-only")
	hq.company_id = original_company

func _test_transitions_and_layout(warehouse: SimFacility, lab: SimFacility, hq: SimFacility, factory: SimFacility) -> void:
	screen.select_facility(warehouse.id)
	check(panel.tabs.get_tab_title(1) == "Replenishment" and panel.replenishment_section.visible, "Warehouse remains unchanged before transition")
	screen.select_facility(lab.id)
	check(panel.research_overview_sections[0].visible and not panel.headquarters_overview_sections[0].visible and panel.tabs.get_tab_title(1) == "Research", "Warehouse to R&D clears stale content")
	screen.select_facility(hq.id)
	check(panel.headquarters_overview_sections[0].visible and not panel.research_overview_sections[0].visible and panel.tabs.get_tab_title(1) == "Staffing", "R&D to HQ clears stale content")
	screen.select_facility(factory.id)
	check(panel.production_sections[0].visible and not panel.headquarters_overview_sections[0].visible and panel.tabs.get_tab_title(1) == "Operations" and not panel.tabs.is_tab_hidden(3), "HQ to production restores B1 tabs without stale content")
	screen.select_facility(hq.id)
	panel.tabs.current_tab = 1
	panel.refresh()
	await process_frame
	var scroll: ScrollContainer = screen.get_node("ShellMargin/ShellColumn/MainWorkspace/WorkspaceInspectorScroll")
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and panel.get_combined_minimum_size().x <= scroll.size.x + 1.0, "B3 inspector has no horizontal overflow at 1280x800")
	check(panel.tabs.get_tab_bar().get_combined_minimum_size().x <= panel.tabs.size.x + 1.0 and panel.hire_staff.is_visible_in_tree() and panel.dismiss_staff.is_visible_in_tree(), "B3 tab bar and staffing actions are reachable")

func _capture(hq: SimFacility) -> void:
	screen.select_facility(hq.id)
	panel.tabs.current_tab = 1
	panel.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.godot/8ui-b3-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(root.get_texture().get_image().save_png(directory.path_join("01-headquarters-staffing.png")) == OK, "Capture representative staffed HQ frame")

func _select_project(project: Dictionary) -> void:
	for index: int in range(panel.research_choices.item_count):
		var candidate: Variant = panel.research_choices.get_item_metadata(index)
		if candidate is Dictionary and screen.session.sim.project_equal(candidate, project):
			panel.research_choices.select(index)
			panel.research_selections[panel.selected_id] = project.duplicate(true)
			return

func _select_role(role_id: String) -> void:
	for index: int in range(panel.staff_role.item_count):
		if panel.staff_role.get_item_metadata(index) == role_id:
			panel.staff_role.select(index)
			return

func _last_command(type_id: String, facility_id: String) -> bool:
	return not commands.is_empty() and commands.back().type == type_id and commands.back().facility == facility_id

func _all_text(node: Node) -> String:
	var result: PackedStringArray = []
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append(_all_text(child))
	return " ".join(result)
