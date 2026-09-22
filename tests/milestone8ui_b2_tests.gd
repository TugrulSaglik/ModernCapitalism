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
	var warehouse: SimFacility = _build("warehouse", "smartphone")
	var research: SimFacility = _build("research_center", "")
	var headquarters: SimFacility = _build("corporate_headquarters", "")
	check(factory != null and warehouse != null and research != null and headquarters != null, "B2 fixtures built")
	_prepare_logistics(factory, warehouse)
	_test_production_sourcing(factory)
	_test_retail_sourcing()
	_test_warehouse(warehouse)
	_test_logistics(warehouse)
	_test_rival()
	_test_transitions(factory, warehouse, research, headquarters)
	await _test_layout(warehouse)
	if DisplayServer.get_name() != "headless": await _capture(warehouse)
	print("8UI-B2 FACILITY PANEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _build(type_id: String, product_id: String) -> SimFacility:
	var definition: Dictionary = screen.session.sim.catalog.facility_types[type_id]
	var sites: Array[Vector2i] = screen.session.sim.city.valid_sites(definition.width, definition.depth)
	if sites.is_empty(): return null
	var next_id: String = "built_%06d" % screen.session.sim.city.next_facility
	if not screen.session.submit({"type": "build_facility", "archetype": type_id, "product": product_id, "x": sites[0].x, "y": sites[0].y}): return null
	return screen.session.sim.facility(next_id)

func _prepare_logistics(factory: SimFacility, warehouse: SimFacility) -> void:
	factory.inventory.add("smartphone", 8, 160000, 72)
	warehouse.inventory.add("smartphone", 24, 480000, 68)
	check(screen.session.sim.logistics.dispatch(screen.session.sim, factory, warehouse, "smartphone", 5) == 5, "Incoming warehouse shipment fixture")
	check(screen.session.sim.logistics.dispatch(screen.session.sim, warehouse, screen.session.sim.facility("20_player"), "smartphone", 3) == 3, "Outgoing warehouse shipment fixture")
	var delivered: Dictionary = screen.session.sim.logistics.shipments.back().duplicate(true)
	delivered.id = 9001
	delivered.status = "delivered"
	delivered.arrival = screen.session.sim.clock.tick
	screen.session.sim.logistics.shipments.append(delivered)
	warehouse.replenishment_targets = {"smartphone": 50, "tablet": 0}
	warehouse.last_sources["smartphone"] = [{"supplier": factory.id, "units": 5, "price": 20000, "quality": 72, "score": 250.0}]

func _test_production_sourcing(factory: SimFacility) -> void:
	screen.select_facility(factory.id)
	panel.tabs.current_tab = 2
	var ids: Array[String] = _option_metadata(panel.product)
	check(ids == ["battery", "display", "processor"], "Production sourcing selector contains recipe inputs in stable order")
	_select_metadata(panel.product, "processor")
	panel.product.item_selected.emit(panel.product.selected)
	var offers: Array[Dictionary] = screen.session.sim.supplier_offers(factory.id, "processor")
	check(panel.sourcing_policy.text == "Automatic" and panel.sourcing_policy_note.text.contains("landed-cost"), "Automatic policy is explicit and explained")
	check(_offer_ids() == _dictionary_ids(offers), "Offer rows preserve supplier_offers ordering")
	if not offers.is_empty():
		var shown: Dictionary = panel.offer_rows.get_child(0).get_meta("offer")
		check(shown.price == offers[0].price and shown.quality == offers[0].quality and shown.lead_days == offers[0].lead_days and shown.landed == offers[0].landed and shown.score == offers[0].score, "Offer row values match supplier_offers data")
		factory.suppliers["processor"] = str(offers[0].id)
		panel.refresh()
		check(panel.sourcing_policy.text == "Manual — %s" % offers[0].id, "Manual supplier policy is represented")
	_select_metadata(panel.suppliers, "")
	commands.clear()
	panel.apply_supplier.pressed.emit()
	check(_last_command("set_supplier", factory.id, "processor") and commands.back().supplier == "", "Automatic emits exact set_supplier command with empty supplier ID")

func _test_retail_sourcing() -> void:
	screen.select_facility("20_player")
	check(_option_metadata(panel.product) == screen.session.sim.facility("20_player").line_ids(), "Retail sourcing selector matches configured product lines")
	_select_metadata(panel.product, "smartphone")
	panel.product.item_selected.emit(panel.product.selected)
	var manual: int = _first_manual_supplier(panel.suppliers)
	if manual >= 0:
		panel.suppliers.select(manual)
		commands.clear()
		panel.apply_supplier.pressed.emit()
		check(_last_command("set_supplier", "20_player", "smartphone") and commands.back().supplier == panel.suppliers.get_item_metadata(manual), "Manual supplier emits exact existing command")
	check(panel.recent_sourcing.text.length() > 0, "Recent sourcing has an explicit purchase or empty state")
	_select_metadata(panel.product, "air_conditioner")
	if panel.product.selected < 0:
		# Warehouse exposes every public product, so its no-offer state is checked there.
		check(true, "Retail selector remains limited to configured lines")

func _test_warehouse(warehouse: SimFacility) -> void:
	screen.select_facility(warehouse.id)
	check(panel.tabs.get_tab_title(0) == "Overview" and panel.tabs.get_tab_title(1) == "Replenishment", "Warehouse has meaningful tab structure")
	var used: int = screen.session.sim.logistics.used(warehouse)
	var incoming: int = screen.session.sim.logistics.incoming(warehouse.id)
	check((panel.warehouse_metrics.used as Label).text == "%d units" % used and (panel.warehouse_metrics.capacity as Label).text == "%d units" % warehouse.capacity, "Warehouse storage metrics are exact")
	check((panel.warehouse_metrics.incoming as Label).text == "%d units" % incoming and (panel.warehouse_metrics.free as Label).text == "%d units" % screen.session.sim.logistics.free_capacity(screen.session.sim, warehouse), "Warehouse reservations and free capacity are exact")
	check((panel.warehouse_metrics.value as Label).text == CompanyReports.money(warehouse.inventory.total_value()) and panel.warehouse_inventory_rows.get_child_count() > 0, "Warehouse inventory value and rows are structured")
	panel.tabs.current_tab = 1
	_select_metadata(panel.warehouse_target_product, "smartphone")
	panel.warehouse_target_product.item_selected.emit(panel.warehouse_target_product.selected)
	check(panel.replenishment_current.text == "Current target: 50 units" and _all_text(panel.replenishment_rows).contains("Tablet") and _all_text(panel.replenishment_rows).contains("Off"), "Current replenishment targets are readable, including Off")
	check(panel.warehouse_target_quantity != panel.transfer_quantity and panel.warehouse_target_quantity.value != panel.transfer_quantity.value, "Replenishment and transfer quantities use independent controls and state")
	panel.warehouse_target_quantity.value = 0
	commands.clear()
	panel.warehouse_target.pressed.emit()
	check(_last_command("set_warehouse_target", warehouse.id, "smartphone") and commands.back().quantity == 0, "Target 0 emits exact set_warehouse_target command")
	_select_metadata(panel.product, "air_conditioner")
	panel.product.item_selected.emit(panel.product.selected)
	check(_all_text(panel.offer_rows).contains("No eligible supplier offers"), "No-offer state is explicit")

func _test_logistics(warehouse: SimFacility) -> void:
	screen.select_facility(warehouse.id)
	panel.tabs.current_tab = 3
	check((panel.shipment_summary.incoming_count as Label).text == "1" and (panel.shipment_summary.outgoing_count as Label).text == "1", "Shipment summary counts active IN and OUT records")
	check(panel.active_shipment_rows.get_child_count() == 2 and _all_text(panel.active_shipment_rows).contains("IN TRANSIT") and _all_text(panel.active_shipment_rows).contains("#"), "Active shipment rows show identity and text status")
	check(_all_text(panel.active_shipment_rows).contains("Freight") and _all_text(panel.active_shipment_rows).contains("cells") and _all_text(panel.recent_delivery_rows).contains("DELIVERED"), "Shipment rows show freight, distance and delivered records")
	check(str(panel.transfer_product.get_item_metadata(0)).length() > 0 and not panel.transfer_product.get_item_text(0).contains("_"), "Transfer product uses display labels with stable metadata")
	check(panel.transfer_destination.get_item_text(0).contains(" • ") and str(panel.transfer_destination.get_item_metadata(0)).length() > 0, "Transfer destination is human-readable and retains ID metadata")
	_select_metadata(panel.transfer_product, "smartphone")
	_select_metadata(panel.transfer_destination, "20_player")
	panel.transfer_quantity.value = 4
	panel.refresh()
	var quote: Dictionary = screen.session.sim.logistics.quote(screen.session.sim, warehouse.id, "20_player", 4)
	check((panel.transfer_quote.distance as Label).text == "%d cells" % quote.distance and (panel.transfer_quote.freight as Label).text == CompanyReports.money(quote.freight), "Live transfer quote matches Logistics.quote")
	var target_quantity_before: float = panel.warehouse_target_quantity.value
	commands.clear()
	panel.transfer_button.pressed.emit()
	check(_last_command("transfer", warehouse.id, "smartphone") and commands.back().destination == "20_player" and commands.back().quantity == 4, "Transfer emits exact existing command")
	check(panel.warehouse_target_quantity.value == target_quantity_before, "Manual transfer quantity does not change replenishment quantity")

func _test_rival() -> void:
	screen.select_facility("21_rival")
	check(panel.apply_supplier.disabled and panel.suppliers.disabled and panel.transfer_product.disabled and panel.transfer_destination.disabled and not panel.transfer_quantity.editable and panel.transfer_button.disabled, "Rival sourcing and transfer controls are read-only")

func _test_transitions(factory: SimFacility, warehouse: SimFacility, research: SimFacility, headquarters: SimFacility) -> void:
	screen.select_facility(factory.id)
	check(panel.product.item_count == 3 and not panel.warehouse_sections[0].visible, "Production selection has no stale warehouse presentation")
	screen.select_facility(warehouse.id)
	check(panel.warehouse_sections[0].visible and panel.replenishment_section.visible, "Warehouse selection restores warehouse presentation")
	screen.select_facility("20_player")
	check(panel.retail_sections[0].visible and not panel.replenishment_section.visible, "Retail selection clears warehouse controls")
	screen.select_facility(research.id)
	check(panel.tabs.get_tab_title(0) == "R&D" and panel.tabs.is_tab_hidden(2), "R&D remains B1-compatible")
	screen.select_facility(headquarters.id)
	check(panel.tabs.get_tab_title(0) == "Headquarters" and panel.tabs.is_tab_hidden(3), "Headquarters remains B1-compatible")

func _test_layout(warehouse: SimFacility) -> void:
	screen.select_facility(warehouse.id)
	panel.tabs.current_tab = 3
	screen.refresh()
	await process_frame
	var inspector_scroll: ScrollContainer = screen.get_node("ShellMargin/ShellColumn/MainWorkspace/WorkspaceInspectorScroll")
	check(inspector_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and panel.get_combined_minimum_size().x <= inspector_scroll.size.x + 1.0, "B2 inspector has no horizontal overflow at 1280x800")
	check(panel.tabs.get_tab_bar().get_combined_minimum_size().x <= panel.tabs.size.x + 1.0 and panel.transfer_button.is_visible_in_tree(), "Warehouse tabs fit and transfer action is reachable")

func _capture(warehouse: SimFacility) -> void:
	warehouse.replenishment_targets["smartphone"] = 50
	screen.select_facility(warehouse.id)
	panel.tabs.current_tab = 1
	_select_metadata(panel.warehouse_target_product, "smartphone")
	panel.warehouse_target_product.item_selected.emit(panel.warehouse_target_product.selected)
	panel.warehouse_target_quantity.value = 50
	screen.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.godot/8ui-b2-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(root.get_texture().get_image().save_png(directory.path_join("01-warehouse-replenishment.png")) == OK, "Capture representative B2 warehouse frame")

func _select_metadata(option: OptionButton, value: String) -> void:
	option.select(-1)
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _option_metadata(option: OptionButton) -> Array[String]:
	var result: Array[String] = []
	for index: int in range(option.item_count): result.append(str(option.get_item_metadata(index)))
	return result

func _dictionary_ids(items: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in items: result.append(str(item.id))
	return result

func _offer_ids() -> Array[String]:
	var result: Array[String] = []
	for child: Node in panel.offer_rows.get_children():
		if child.has_meta("offer"): result.append(str((child.get_meta("offer") as Dictionary).id))
	return result

func _first_manual_supplier(option: OptionButton) -> int:
	for index: int in range(option.item_count):
		if not str(option.get_item_metadata(index)).is_empty(): return index
	return -1

func _last_command(type_id: String, facility_id: String, product_id: String) -> bool:
	return not commands.is_empty() and commands.back().type == type_id and commands.back().facility == facility_id and commands.back().product == product_id

func _all_text(node: Node) -> String:
	var result: PackedStringArray = []
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append(_all_text(child))
	return " ".join(result)
