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
	screen.session.time.set_speed(0)
	panel = screen.inspector
	panel.command_requested.connect(func(command: Dictionary) -> void: commands.append(command.duplicate(true)))
	var factory: SimFacility = _build("assembly_plant", "smartphone")
	var headquarters: SimFacility = _build("corporate_headquarters", "")
	var research: SimFacility = _build("research_center", "")
	var warehouse: SimFacility = _build("warehouse", "smartphone")
	check(factory != null and headquarters != null and research != null and warehouse != null, "Owned production, corporate and warehouse fixtures built")
	check(screen.session.submit({"type": "hire_staff", "facility": headquarters.id, "role": "operations_manager", "quantity": 1}), "Operations staff fixture hired")
	check(screen.session.submit({"type": "hire_staff", "facility": headquarters.id, "role": "finance_manager", "quantity": 1}), "Finance staff fixture hired")
	screen.session.sim.companies.player.process_efficiency_levels["smartphone"] = 1
	screen.session.sim.step()
	screen.city.sync(screen.session.sim.snapshot())
	_test_production(factory)
	_test_retail()
	_test_transitions(headquarters, research, warehouse)
	_test_rival()
	await _test_layout(factory)
	if DisplayServer.get_name() != "headless":
		screen._refresh_facility_list()
		screen.select_facility(factory.id)
		panel.tabs.current_tab = 1
		screen.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var directory := "res://.godot/8ui-b1-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join("01-production-operations.png")) == OK, "Capture representative facility management frame")
	print("8UI-B1 FACILITY PANEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _build(type_id: String, product_id: String) -> SimFacility:
	var definition: Dictionary = screen.session.sim.catalog.facility_types[type_id]
	var sites: Array[Vector2i] = screen.session.sim.city.valid_sites(definition.width, definition.depth)
	if sites.is_empty(): return null
	var next_id: String = "built_%06d" % screen.session.sim.city.next_facility
	if not screen.session.submit({"type": "build_facility", "archetype": type_id, "product": product_id, "x": sites[0].x, "y": sites[0].y}): return null
	return screen.session.sim.facility(next_id)

func _test_production(factory: SimFacility) -> void:
	screen.select_facility(factory.id)
	panel.refresh()
	check(panel.header_title.text == "Assembly factory" and panel.header_meta.text.contains("Player Electronics") and panel.header_meta.text.contains(factory.id), "Production header uses catalog name, owner and facility ID")
	check(panel.header_status.text == "OPERATING" and panel.tabs.get_tab_title(0) == "Overview" and panel.tabs.get_tab_title(1) == "Operations", "Production header status and intent tabs shown")
	check((panel.production_metrics.product_name as Label).text == "Smartphone" and (panel.production_metrics.product_state as Label).text == "Available", "Production Overview shows current product and availability")
	check((panel.production_metrics.capacity as Label).text.contains("base") and (panel.production_metrics.capacity as Label).text.contains("effective"), "Production Overview shows effective staffed capacity")
	check((panel.production_metrics.overhead as Label).text.contains("base") and (panel.production_metrics.overhead as Label).text.contains("effective"), "Production Overview shows effective finance overhead")
	check((panel.production_metrics.conversion as Label).text.contains("base") and (panel.production_metrics.conversion as Label).text.contains("effective"), "Production Overview shows effective process conversion cost")
	check((panel.production_metrics.process_quality as Label).text == str(factory.quality) and (panel.production_metrics.effective_quality as Label).text.length() > 0 and (panel.production_metrics.quality_level as Label).text.contains("Level"), "Production Overview shows process and R&D capability values")
	check((panel.production_operation_metrics.effective_cost as Label).text.contains("/unit") and (panel.production_operation_metrics.efficiency_level as Label).text.contains("Level 1"), "Production Operations shows effective quality and efficiency summary")
	check(_all_text(panel.recipe_rows).contains("Mobile processor") and _all_text(panel.recipe_rows).contains("Device display") and _all_text(panel.recipe_rows).contains("Battery pack"), "Production recipe renders catalog inputs as readable rows")
	var alternative: int = _find_metadata(panel.choices, "tablet")
	check(alternative >= 0, "Compatible production alternative is available")
	panel.choices.select(alternative)
	commands.clear()
	panel.change_production.pressed.emit()
	check(_last_command("set_production", factory.id, "tablet"), "Change production emits existing set_production command")
	commands.clear()
	panel.price.value = 777.0
	panel.apply_price.pressed.emit()
	check(_last_command("set_price", factory.id, "smartphone") and int(commands.back().price) == 77700, "Wholesale price emits existing set_price command")
	commands.clear()
	panel.stock.value = 4
	panel.apply_stock.pressed.emit()
	check(not commands.is_empty() and commands.back().type == "set_stock_days" and commands.back().facility == factory.id and commands.back().days == 4, "Production stock target emits existing command")
	check(panel.tabs.get_tab_title(2) == "Sourcing" and panel.tabs.get_tab_title(3) == "Logistics" and not panel.tabs.is_tab_hidden(2) and not panel.tabs.is_tab_hidden(3), "Production sourcing and logistics remain accessible")
	commands.clear()
	panel.apply_supplier.pressed.emit()
	check(not commands.is_empty() and commands.back().type == "set_supplier", "Sourcing control retains set_supplier command")

func _test_retail() -> void:
	screen.select_facility("20_player")
	panel.refresh()
	var store: SimFacility = screen.session.sim.facility("20_player")
	check(panel.header_title.text == "Electronics store" and panel.header_meta.text.contains("20_player"), "Retail header uses catalog display name and identity")
	check((panel.retail_metrics.assortment as Label).text == "%d / 6 lines" % store.assortment.size() and panel.assortment_summary.text == "Lines %d / 6" % store.assortment.size(), "Retail assortment count and slot maximum shown")
	check((panel.retail_line_metrics.product as Label).text == "Smartphone" and (panel.retail_line_metrics.current_price as Label).text == CompanyReports.money(store.line_price("smartphone")), "Selected retail line shows product and selling price")
	check((panel.retail_line_metrics.stock as Label).text.contains(str(store.inventory.quantity("smartphone"))) and (panel.retail_line_metrics.supplier as Label).text.length() > 0, "Selected retail line shows stock and supplier policy")
	commands.clear()
	panel.price.value = 399.0
	panel.apply_price.pressed.emit()
	check(_last_command("set_price", "20_player", "smartphone") and int(commands.back().price) == 39900, "Retail price emits product-specific set_price command")
	commands.clear()
	panel.stock.value = 5
	panel.apply_stock.pressed.emit()
	check(not commands.is_empty() and commands.back().type == "set_stock_days" and commands.back().days == 5, "Retail stock target emits existing command")
	var add_index: int = _find_metadata(panel.choices, "tablet")
	panel.choices.select(add_index)
	commands.clear()
	panel.configure.pressed.emit()
	check(_last_command("add_line", "20_player", "tablet"), "Add product line emits existing add_line command")
	commands.clear()
	panel.remove_line.pressed.emit()
	check(_last_command("remove_line", "20_player", "smartphone"), "Remove selected line emits existing remove_line command")

func _test_transitions(headquarters: SimFacility, research: SimFacility, warehouse: SimFacility) -> void:
	screen.select_facility("20_player")
	check(panel.retail_line_section.visible and not panel.production_line_section.visible, "Retail selection hides production-only controls")
	screen.select_facility(research.id)
	check(panel.research_choices.visible and panel.legacy_content.visible and panel.tabs.get_tab_title(0) == "R&D" and panel.tabs.is_tab_hidden(1), "Retail to R&D transition shows only research management")
	screen.select_facility(headquarters.id)
	check(panel.staff_info.visible and not panel.research_choices.visible and panel.tabs.get_tab_title(0) == "Headquarters", "R&D to headquarters transition clears research controls")
	screen.select_facility(warehouse.id)
	check(panel.tabs.get_tab_title(0) == "Warehouse" and panel.tabs.is_tab_hidden(1) and not panel.tabs.is_tab_hidden(2) and not panel.tabs.is_tab_hidden(3), "Warehouse remains functional with sourcing and logistics access")
	check(panel.warehouse_target.visible and panel.product.item_count > 0 and panel.transfer_product.item_count > 0, "Warehouse replenishment and transfer controls remain available")
	commands.clear()
	panel.transfer_quantity.value = 1
	panel.transfer_button.pressed.emit()
	check(not commands.is_empty() and commands.back().type == "transfer", "Logistics transfer control retains its command")
	commands.clear()
	panel.warehouse_target.pressed.emit()
	check(not commands.is_empty() and commands.back().type == "set_warehouse_target", "Warehouse target control retains its command")

func _test_rival() -> void:
	screen.select_facility("21_rival")
	check(panel.header_title.text == "Electronics store" and (panel.retail_line_metrics.product as Label).text.length() > 0, "Rival retail information remains visible")
	check(panel.operating.disabled and panel.demolish.disabled and panel.configure.disabled and panel.remove_line.disabled and panel.apply_price.disabled and panel.apply_stock.disabled and panel.apply_supplier.disabled, "Rival facility management actions are read-only")

func _test_layout(factory: SimFacility) -> void:
	screen.select_facility(factory.id)
	panel.tabs.current_tab = 1
	screen.refresh()
	await process_frame
	var inspector_scroll: ScrollContainer = screen.get_node("ShellMargin/ShellColumn/MainWorkspace/WorkspaceInspectorScroll")
	check(inspector_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Inspector has no horizontal scrolling")
	check(inspector_scroll.get_global_rect().end.x <= 1280.0 and panel.get_combined_minimum_size().x <= inspector_scroll.size.x + 1.0, "Inspector fits the 1280-wide workspace")
	check(panel.tabs.get_tab_bar().get_combined_minimum_size().x <= panel.tabs.size.x + 1.0, "All four management tabs fit without clipping")
	check(panel.operating.is_visible_in_tree() and panel.change_production.is_visible_in_tree() and panel.apply_price.is_visible_in_tree(), "Header and production actions remain reachable")
	screen.select_facility("20_player")
	panel.tabs.current_tab = 1
	screen.refresh()
	await process_frame
	check(panel.get_combined_minimum_size().x <= inspector_scroll.size.x + 1.0 and panel.line.is_visible_in_tree() and panel.configure.is_visible_in_tree(), "Retail operations fit horizontally and remain reachable")

func _find_metadata(option: OptionButton, value: String) -> int:
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == value: return index
	return -1

func _last_command(type_id: String, facility_id: String, product_id: String) -> bool:
	return not commands.is_empty() and commands.back().type == type_id and commands.back().facility == facility_id and commands.back().product == product_id

func _all_text(node: Node) -> String:
	var result: PackedStringArray = []
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append(_all_text(child))
	return " ".join(result)
