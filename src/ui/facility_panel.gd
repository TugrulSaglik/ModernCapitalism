class_name FacilityPanel
extends PanelContainer

signal command_requested(command: Dictionary)
signal demolition_requested

var research_choices: OptionButton
var research_info: RichTextLabel
var assign_research: Button
var stop_research: Button
var tabs: TabContainer
var choices: OptionButton
var line: OptionButton
var configure: Button
var remove_line: Button
var line_info: Label
var layout_key: String = ""
var selected_id: String = ""
var session: GameSession
var info: RichTextLabel
var price: SpinBox
var product: OptionButton
var suppliers: OptionButton
var stock: SpinBox
var operating: Button
var apply_price: Button
var apply_supplier: Button
var apply_stock: Button
var sourcing_info: RichTextLabel
var demolish: Button
var transfer_product: OptionButton
var transfer_destination: OptionButton
var transfer_quantity: SpinBox
var transfer_button: Button
var logistics_info: RichTextLabel
var warehouse_target: Button
var warehouse_target_product: OptionButton
var warehouse_target_quantity: SpinBox
var staff_info: RichTextLabel
var staff_role: OptionButton
var hire_staff: Button
var dismiss_staff: Button

var header_title: Label
var header_meta: Label
var header_status: Label
var overview_page: VBoxContainer
var operations_page: VBoxContainer
var sourcing_page: VBoxContainer
var logistics_page: VBoxContainer
var legacy_content: VBoxContainer
var production_sections: Array[Control] = []
var retail_sections: Array[Control] = []
var production_metrics: Dictionary = {}
var production_operation_metrics: Dictionary = {}
var retail_metrics: Dictionary = {}
var retail_line_metrics: Dictionary = {}
var production_line_section: Control
var production_line_body: VBoxContainer
var retail_line_section: Control
var price_section: Control
var stock_section: Control
var quality_section: Control
var recipe_section: Control
var product_lines_section: Control
var product_lines_body: VBoxContainer
var change_production: Button
var production_current: Label
var production_note: Label
var price_heading: Label
var recipe_rows: VBoxContainer
var assortment_summary: Label
var selected_lines: Dictionary = {}
var sourcing_selections: Dictionary = {}
var transfer_product_selections: Dictionary = {}
var transfer_destination_selections: Dictionary = {}
var replenishment_selections: Dictionary = {}

var sourcing_policy: Label
var sourcing_policy_note: Label
var offer_rows: VBoxContainer
var recent_sourcing: Label
var shipment_summary: Dictionary = {}
var active_shipment_rows: VBoxContainer
var recent_delivery_rows: VBoxContainer
var transfer_quote: Dictionary = {}
var warehouse_sections: Array[Control] = []
var warehouse_metrics: Dictionary = {}
var warehouse_inventory_rows: VBoxContainer
var replenishment_rows: VBoxContainer
var replenishment_current: Label
var replenishment_section: Control
var sourcing_rows_key: String = ""
var logistics_rows_key: String = ""
var warehouse_rows_key: String = ""
var replenishment_rows_key: String = ""

var research_overview_sections: Array[Control] = []
var research_overview_metrics: Dictionary = {}
var research_project_metrics: Dictionary = {}
var research_detail_metrics: Dictionary = {}
var research_overview_project_section: Control
var research_overview_empty: Label
var research_page_sections: Array[Control] = []
var research_status: Label
var research_prerequisites: VBoxContainer
var research_progress: ProgressBar
var research_progress_text: Label
var research_attention: Label
var research_stop_note: Label
var research_selections: Dictionary = {}

var headquarters_overview_sections: Array[Control] = []
var headquarters_finance_metrics: Dictionary = {}
var headquarters_staff_metrics: Dictionary = {}
var headquarters_effect_metrics: Dictionary = {}
var headquarters_overview_note: Label
var staffing_sections: Array[Control] = []
var staffing_metrics: Dictionary = {}
var staffing_status: Label
var staffing_roles: VBoxContainer
var staffing_role_metrics: Dictionary = {}
var staffing_note: Label
var demolition_note: Label

func _ready() -> void:
	custom_minimum_size.x = 410
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(column)
	_build_header(column)
	tabs = TabContainer.new()
	tabs.custom_minimum_size.x = 400
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	overview_page = VBoxContainer.new()
	overview_page.name = "Overview"
	tabs.add_child(overview_page)
	operations_page = VBoxContainer.new()
	operations_page.name = "Operations"
	tabs.add_child(operations_page)
	sourcing_page = VBoxContainer.new()
	sourcing_page.name = "Sourcing"
	tabs.add_child(sourcing_page)
	logistics_page = VBoxContainer.new()
	logistics_page.name = "Logistics"
	tabs.add_child(logistics_page)
	_build_overview()
	_build_operations()
	_build_sourcing()
	_build_logistics()

func _build_header(parent: VBoxContainer) -> void:
	var body: VBoxContainer = _section(parent, "FACILITY")
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(identity)
	header_title = Label.new()
	header_title.theme_type_variation = "TitleLabel"
	header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(header_title)
	header_meta = Label.new()
	header_meta.theme_type_variation = "MetaLabel"
	header_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(header_meta)
	header_status = Label.new()
	header_status.theme_type_variation = "PositiveLabel"
	header_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(header_status)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	operating = _button(actions, "Suspend", func() -> void:
		var f: SimFacility = session.sim.facility(selected_id)
		command_requested.emit({"type": "set_operating", "facility": selected_id, "operating": not f.operating}))
	operating.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demolish = _button(actions, "Demolish…", func() -> void: demolition_requested.emit())
	demolish.theme_type_variation = "DestructiveButton"
	demolish.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_overview() -> void:
	production_sections.append(_metric_section(overview_page, "CURRENT PRODUCT", ["product_name", "product_state"], ["Product", "Availability"], production_metrics))
	production_sections.append(_metric_section(overview_page, "TODAY", ["produced_today", "capacity"], ["Units produced", "Daily capacity"], production_metrics))
	production_sections.append(_metric_section(overview_page, "INVENTORY", ["finished_units", "finished_value", "physical_quality", "incoming"], ["Finished units", "Book value", "Physical quality", "Incoming units"], production_metrics))
	production_sections.append(_metric_section(overview_page, "COST / OPERATIONS", ["overhead", "conversion"], ["Daily overhead", "Conversion cost"], production_metrics))
	production_sections.append(_metric_section(overview_page, "CAPABILITY", ["process_quality", "effective_quality", "quality_level", "efficiency_level"], ["Process quality", "Effective process quality", "Product-quality R&D", "Process-efficiency R&D"], production_metrics))
	production_sections.append(_metric_section(overview_page, "RECENT ACTIVITY", ["recent_production", "recent_sales"], ["Production · 7 days", "Sales · 7 days"], production_metrics))
	retail_sections.append(_metric_section(overview_page, "STORE", ["store_type", "assortment"], ["Store type", "Assortment"], retail_metrics))
	retail_sections.append(_metric_section(overview_page, "TODAY", ["sold_today", "checkout"], ["Consumer units sold", "Checkout capacity"], retail_metrics))
	retail_sections.append(_metric_section(overview_page, "RECENT", ["recent_sales"], ["Sales · 7 days"], retail_metrics))
	retail_sections.append(_metric_section(overview_page, "INVENTORY SUMMARY", ["on_hand", "incoming", "book_value"], ["On hand", "Incoming", "Book value"], retail_metrics))
	retail_sections.append(_metric_section(overview_page, "OPERATING COST", ["overhead"], ["Daily overhead"], retail_metrics))
	warehouse_sections.append(_metric_section(overview_page, "STORAGE", ["used", "capacity", "incoming", "free"], ["Used units", "Physical capacity", "Incoming reserved", "Free after reservations"], warehouse_metrics))
	warehouse_sections.append(_metric_section(overview_page, "INVENTORY", ["units", "value", "products"], ["On-hand units", "Book value", "Stocked products"], warehouse_metrics))
	warehouse_sections.append(_metric_section(overview_page, "OPERATIONS", ["state", "overhead"], ["Facility state", "Daily overhead"], warehouse_metrics))
	warehouse_sections.append(_metric_section(overview_page, "ACTIVITY", ["incoming_shipments", "outgoing_shipments", "recent"], ["Incoming shipments", "Outgoing shipments", "Recent deliveries"], warehouse_metrics))
	var inventory_body := _section(overview_page, "STORED PRODUCTS")
	warehouse_sections.append(inventory_body.get_parent())
	warehouse_inventory_rows = VBoxContainer.new()
	inventory_body.add_child(warehouse_inventory_rows)
	research_overview_sections.append(_metric_section(overview_page, "FACILITY", ["state", "overhead"], ["Operating state", "Daily overhead"], research_overview_metrics))
	research_overview_sections.append(_metric_section(overview_page, "RESEARCH CAPACITY", ["rate", "bonus"], ["Research rate", "R&D manager bonus"], research_overview_metrics))
	research_overview_project_section = _metric_section(overview_page, "CURRENT PROJECT", ["name", "kind", "status", "progress", "remaining", "expense"], ["Project", "Type", "Status", "Progress", "Funded days remaining", "Project expense"], research_project_metrics)
	research_overview_sections.append(research_overview_project_section)
	research_overview_empty = _note(research_overview_project_section.get_child(0) as VBoxContainer, "No active research project")
	research_overview_sections.append(_metric_section(overview_page, "COMPANY KNOWLEDGE", ["known"], ["Technologies known"], research_overview_metrics))
	headquarters_overview_sections.append(_metric_section(overview_page, "FACILITY FINANCES", ["overhead", "asset_cost", "depreciation", "book_value"], ["Daily overhead", "Construction / fixed asset", "Accumulated depreciation", "Net book value"], headquarters_finance_metrics))
	headquarters_overview_sections.append(_metric_section(overview_page, "STAFFING SUMMARY", ["staff", "payroll", "status"], ["Total staff", "Configured payroll", "Management effects"], headquarters_staff_metrics))
	headquarters_overview_sections.append(_metric_section(overview_page, "MANAGEMENT EFFECTS", ["operations", "marketing", "research", "finance"], ["Operations", "Marketing", "R&D", "Finance"], headquarters_effect_metrics))
	headquarters_overview_note = _note(headquarters_overview_sections.back().get_child(0) as VBoxContainer, "Configured effects apply company-wide only while management effects are ACTIVE.")
	demolition_note = _note(overview_page, "Dismiss all staff before demolition.")
	legacy_content = VBoxContainer.new()
	overview_page.add_child(legacy_content)
	info = RichTextLabel.new()
	info.custom_minimum_size = Vector2(390, 190)
	legacy_content.add_child(info)
	staff_info = RichTextLabel.new()
	staff_info.bbcode_enabled = true
	staff_info.custom_minimum_size = Vector2(390, 340)
	legacy_content.add_child(staff_info)
	staff_role = OptionButton.new()
	legacy_content.add_child(staff_role)
	staff_role.item_selected.connect(func(_index: int) -> void: refresh())
	var staff_row := HBoxContainer.new()
	legacy_content.add_child(staff_row)
	hire_staff = _button(staff_row, "Hire 1", func() -> void:
		if staff_role.selected >= 0: command_requested.emit({"type": "hire_staff", "facility": selected_id, "role": str(staff_role.get_item_metadata(staff_role.selected)), "quantity": 1}))
	dismiss_staff = _button(staff_row, "Dismiss 1", func() -> void:
		if staff_role.selected >= 0: command_requested.emit({"type": "dismiss_staff", "facility": selected_id, "role": str(staff_role.get_item_metadata(staff_role.selected)), "quantity": 1}))
	dismiss_staff.theme_type_variation = "DestructiveButton"
	research_choices = OptionButton.new()
	legacy_content.add_child(research_choices)
	research_choices.item_selected.connect(func(_index: int) -> void:
		if not selected_id.is_empty() and research_choices.selected >= 0:
			var selected: Variant = research_choices.get_item_metadata(research_choices.selected)
			if selected is Dictionary and not (selected as Dictionary).is_empty(): research_selections[selected_id] = (selected as Dictionary).duplicate(true)
		refresh())
	research_info = RichTextLabel.new()
	research_info.custom_minimum_size = Vector2(390, 225)
	legacy_content.add_child(research_info)
	assign_research = _button(legacy_content, "Assign / resume research", func() -> void:
		if research_choices.selected >= 0:
			var project: Dictionary = research_choices.get_item_metadata(research_choices.selected)
			if not project.is_empty(): command_requested.emit({"type": "assign_research", "facility": selected_id, "project": project}))
	stop_research = _button(legacy_content, "Stop research (retain progress)", func() -> void: command_requested.emit({"type": "stop_research", "facility": selected_id}))
	info.visible = false
	staff_info.custom_minimum_size = Vector2.ZERO
	research_info.custom_minimum_size = Vector2.ZERO

func _build_operations() -> void:
	_build_research_page()
	_build_staffing_page()
	production_line_body = _section(operations_page, "PRODUCTION LINE")
	production_line_section = production_line_body.get_parent()
	production_current = Label.new()
	production_current.theme_type_variation = "ValueLabel"
	production_line_body.add_child(production_current)
	choices = OptionButton.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	production_line_body.add_child(choices)
	change_production = _button(production_line_body, "Change production", func() -> void:
		if choices.selected >= 0: command_requested.emit({"type": "set_production", "facility": selected_id, "product": str(choices.get_item_metadata(choices.selected))}))
	change_production.name = "ChangeProduction"
	production_note = _note(production_line_body, "Change production — existing inventory is retained")

	var retail_body := _section(operations_page, "SELECTED PRODUCT LINE")
	retail_line_section = retail_body.get_parent()
	line = OptionButton.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retail_body.add_child(line)
	line.item_selected.connect(func(_index: int) -> void:
		if line.selected >= 0:
			selected_lines[selected_id] = _selected_line_id()
			price.value = session.sim.facility(selected_id).line_price(_selected_line_id()) / 100.0
		refresh())
	var line_grid := GridContainer.new()
	line_grid.columns = 2
	retail_body.add_child(line_grid)
	for item: Array in [["product", "Product"], ["current_price", "Selling price"], ["stock", "Stock"], ["incoming", "Incoming"], ["quality", "Physical quality"], ["supplier", "Supplier policy"], ["recent", "Units sold · 7 days"], ["unit_cost", "Unit cost"], ["margin", "Lifetime gross margin"]]:
		_metric_row(line_grid, str(item[1]), str(item[0]), retail_line_metrics)
	line_info = Label.new()
	line_info.visible = false
	retail_body.add_child(line_info)

	var price_body := _section(operations_page, "WHOLESALE PRICE")
	price_section = price_body.get_parent()
	price_heading = _note(price_body, "Facility sale price")
	var price_row := HBoxContainer.new()
	price_body.add_child(price_row)
	price = SpinBox.new()
	price.min_value = 0.01
	price.max_value = 1000000
	price.step = 0.01
	price.prefix = "$"
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(price)
	apply_price = _button(price_row, "Queue price", func() -> void: command_requested.emit({"type": "set_price", "facility": selected_id, "product": _selected_line_id() if line.selected >= 0 and session.sim._behavior(session.sim.facility(selected_id)) == "retail" else session.sim.facility(selected_id).product_id, "price": int(round(price.value * 100.0))}))

	var stock_body := _section(operations_page, "STOCK TARGET")
	stock_section = stock_body.get_parent()
	var stock_row := HBoxContainer.new()
	stock_body.add_child(stock_row)
	stock = SpinBox.new()
	stock.min_value = 1
	stock.max_value = 7
	stock.suffix = " days"
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_row.add_child(stock)
	apply_stock = _button(stock_row, "Queue target", func() -> void: command_requested.emit({"type": "set_stock_days", "facility": selected_id, "days": int(stock.value)}))

	quality_section = _metric_section(operations_page, "QUALITY / EFFICIENCY", ["process_quality", "quality_level", "effective_quality", "efficiency_level", "effective_cost"], ["Process quality", "Product-quality R&D", "Effective process quality", "Process-efficiency R&D", "Effective conversion cost"], production_operation_metrics)
	var recipe_body := _section(operations_page, "RECIPE")
	recipe_section = recipe_body.get_parent()
	_note(recipe_body, "Inputs per unit")
	recipe_rows = VBoxContainer.new()
	recipe_body.add_child(recipe_rows)

	product_lines_body = _section(operations_page, "PRODUCT LINES")
	product_lines_section = product_lines_body.get_parent()
	assortment_summary = Label.new()
	assortment_summary.theme_type_variation = "ValueLabel"
	product_lines_body.add_child(assortment_summary)
	configure = _button(product_lines_body, "Add product line", func() -> void:
		if choices.selected >= 0:
			var behavior: String = session.sim._behavior(session.sim.facility(selected_id))
			command_requested.emit({"type": "add_line" if behavior == "retail" else "set_production", "facility": selected_id, "product": str(choices.get_item_metadata(choices.selected))}))
	remove_line = _button(product_lines_body, "Remove selected line", func() -> void:
		if line.selected >= 0: command_requested.emit({"type": "remove_line", "facility": selected_id, "product": _selected_line_id()}))
	remove_line.theme_type_variation = "DestructiveButton"
	_note(product_lines_body, "Removing a line retains its existing stock.")

	var replenishment_body := _section(operations_page, "REPLENISHMENT TARGET")
	replenishment_section = replenishment_body.get_parent()
	warehouse_target_product = OptionButton.new()
	warehouse_target_product.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replenishment_body.add_child(warehouse_target_product)
	warehouse_target_product.item_selected.connect(func(_index: int) -> void:
		if warehouse_target_product.selected >= 0:
			replenishment_selections[selected_id] = str(warehouse_target_product.get_item_metadata(warehouse_target_product.selected))
			_load_replenishment_value(session.sim.facility(selected_id))
			_refresh_replenishment(session.sim.facility(selected_id), session.sim.facility(selected_id).company_id == session.active_company))
	replenishment_current = _note(replenishment_body, "Current target: Off")
	_note(replenishment_body, "New target quantity")
	var target_row := HBoxContainer.new()
	replenishment_body.add_child(target_row)
	warehouse_target_quantity = SpinBox.new()
	warehouse_target_quantity.min_value = 0
	warehouse_target_quantity.max_value = 100000
	warehouse_target_quantity.step = 1
	warehouse_target_quantity.suffix = " units"
	warehouse_target_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_child(warehouse_target_quantity)
	warehouse_target = _button(target_row, "Set target", func() -> void:
		if warehouse_target_product.selected >= 0:
			command_requested.emit({"type": "set_warehouse_target", "facility": selected_id, "product": str(warehouse_target_product.get_item_metadata(warehouse_target_product.selected)), "quantity": int(warehouse_target_quantity.value)}))
	_note(replenishment_body, "Set 0 units to turn replenishment off.")
	var summary_body := _section(operations_page, "CURRENT TARGETS")
	replenishment_rows = VBoxContainer.new()
	summary_body.add_child(replenishment_rows)

func _build_research_page() -> void:
	var selection_body := _section(operations_page, "PROJECT TYPE / PROJECT")
	research_page_sections.append(selection_body.get_parent())
	if research_choices.get_parent() != selection_body: research_choices.reparent(selection_body)
	research_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_section: Control = _metric_section(operations_page, "SELECTED PROJECT", ["name", "kind", "public_year", "knowledge", "levels", "status"], ["Project", "Type", "Public year", "Company knowledge", "Levels", "Status"], research_detail_metrics)
	research_page_sections.append(detail_section)
	research_status = _note(detail_section.get_child(0) as VBoxContainer, "")
	var prerequisites_body := _section(operations_page, "PREREQUISITES")
	research_page_sections.append(prerequisites_body.get_parent())
	research_prerequisites = VBoxContainer.new()
	prerequisites_body.add_child(research_prerequisites)
	var progress_body := _section(operations_page, "PROGRESS")
	research_page_sections.append(progress_body.get_parent())
	research_progress = ProgressBar.new()
	research_progress.show_percentage = false
	research_progress.custom_minimum_size.y = 14
	progress_body.add_child(research_progress)
	research_progress_text = _note(progress_body, "")
	var cost_section: Control = _metric_section(operations_page, "COST / RATE", ["project_cost", "overhead", "rate", "remaining"], ["Project expense", "Facility overhead", "Research rate", "Funded days remaining"], research_detail_metrics)
	research_page_sections.append(cost_section)
	var assignment_section: Control = _metric_section(operations_page, "ASSIGNMENT", ["facility"], ["Assigned facility"], research_detail_metrics)
	research_page_sections.append(assignment_section)
	research_attention = _note(assignment_section.get_child(0) as VBoxContainer, "")
	var actions_body := _section(operations_page, "ACTIONS")
	research_page_sections.append(actions_body.get_parent())
	if assign_research.get_parent() != actions_body: assign_research.reparent(actions_body)
	if stop_research.get_parent() != actions_body: stop_research.reparent(actions_body)
	research_stop_note = _note(actions_body, "Progress is retained; prior spending is not refunded.")

func _build_staffing_page() -> void:
	staffing_sections.append(_metric_section(operations_page, "STAFF CAPACITY / PAYROLL", ["capacity", "payroll"], ["Staff capacity", "Configured payroll"], staffing_metrics))
	var status_body := _section(operations_page, "STATUS")
	staffing_sections.append(status_body.get_parent())
	staffing_status = Label.new()
	staffing_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_body.add_child(staffing_status)
	_note(status_body, "Payroll is paid in full or skipped if cash is insufficient.")
	var roles_body := _section(operations_page, "ROLES")
	staffing_sections.append(roles_body.get_parent())
	staffing_roles = VBoxContainer.new()
	roles_body.add_child(staffing_roles)
	var selected_body := _section(operations_page, "SELECTED ROLE")
	staffing_sections.append(selected_body.get_parent())
	if staff_role.get_parent() != selected_body: staff_role.reparent(selected_body)
	var role_grid := GridContainer.new()
	role_grid.columns = 2
	selected_body.add_child(role_grid)
	for item: Array in [["count", "Employed"], ["salary", "Salary / employee"], ["effect", "Effect / employee"], ["configured", "Configured effect"], ["cap", "Cap"]]:
		_metric_row(role_grid, str(item[1]), str(item[0]), staffing_role_metrics)
	var action_row := HBoxContainer.new()
	selected_body.add_child(action_row)
	if hire_staff.get_parent() != action_row: hire_staff.reparent(action_row)
	if dismiss_staff.get_parent() != action_row: dismiss_staff.reparent(action_row)
	hire_staff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismiss_staff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staffing_note = _note(selected_body, "")

func _build_sourcing() -> void:
	var body := _section(sourcing_page, "SOURCING PRODUCT / INPUT")
	product = OptionButton.new()
	product.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(product)
	product.item_selected.connect(func(_index: int) -> void:
		if product.selected >= 0:
			sourcing_selections[selected_id] = str(product.get_item_metadata(product.selected))
		_populate_suppliers()
		_refresh_sourcing(session.sim.facility(selected_id), session.sim.facility(selected_id).company_id == session.active_company))
	var policy_body := _section(sourcing_page, "CURRENT POLICY")
	sourcing_policy = Label.new()
	sourcing_policy.theme_type_variation = "ValueLabel"
	policy_body.add_child(sourcing_policy)
	sourcing_policy_note = _note(policy_body, "")
	var selection_body := _section(sourcing_page, "SUPPLIER SELECTION")
	suppliers = OptionButton.new()
	suppliers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_body.add_child(suppliers)
	apply_supplier = _button(selection_body, "Queue supplier", func() -> void:
		if product.selected >= 0 and suppliers.selected >= 0:
			command_requested.emit({"type": "set_supplier", "facility": selected_id, "product": str(product.get_item_metadata(product.selected)), "supplier": str(suppliers.get_item_metadata(suppliers.selected))}))
	var offers_body := _section(sourcing_page, "AVAILABLE OFFERS")
	offer_rows = VBoxContainer.new()
	offers_body.add_child(offer_rows)
	var recent_body := _section(sourcing_page, "RECENT SOURCING")
	recent_sourcing = Label.new()
	recent_sourcing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recent_body.add_child(recent_sourcing)
	sourcing_info = RichTextLabel.new()
	sourcing_info.visible = false
	recent_body.add_child(sourcing_info)

func _build_logistics() -> void:
	_metric_section(logistics_page, "SHIPMENT SUMMARY", ["incoming_units", "incoming_count", "outgoing_count"], ["Incoming units", "Active incoming", "Active outgoing"], shipment_summary)
	var shipments_body := _section(logistics_page, "ACTIVE SHIPMENTS")
	active_shipment_rows = VBoxContainer.new()
	shipments_body.add_child(active_shipment_rows)
	var body := _section(logistics_page, "MANUAL TRANSFER")
	logistics_info = RichTextLabel.new()
	logistics_info.visible = false
	body.add_child(logistics_info)
	_note(body, "Product")
	transfer_product = OptionButton.new()
	transfer_product.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(transfer_product)
	transfer_product.item_selected.connect(func(_index: int) -> void:
		if transfer_product.selected >= 0: transfer_product_selections[selected_id] = str(transfer_product.get_item_metadata(transfer_product.selected))
		_refresh_transfer_quote())
	_note(body, "Destination")
	transfer_destination = OptionButton.new()
	transfer_destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(transfer_destination)
	transfer_destination.item_selected.connect(func(_index: int) -> void:
		if transfer_destination.selected >= 0: transfer_destination_selections[selected_id] = str(transfer_destination.get_item_metadata(transfer_destination.selected))
		_refresh_transfer_quote())
	_note(body, "Quantity")
	var transfer_row := HBoxContainer.new()
	body.add_child(transfer_row)
	transfer_quantity = SpinBox.new()
	transfer_quantity.min_value = 1
	transfer_quantity.max_value = 100000
	transfer_quantity.step = 1
	transfer_quantity.value = 10
	transfer_quantity.suffix = " units"
	transfer_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer_row.add_child(transfer_quantity)
	transfer_quantity.value_changed.connect(func(_value: float) -> void: _refresh_transfer_quote())
	transfer_button = _button(transfer_row, "Send transfer", func() -> void:
		if transfer_destination.selected >= 0 and transfer_product.selected >= 0:
			command_requested.emit({"type": "transfer", "facility": selected_id, "product": str(transfer_product.get_item_metadata(transfer_product.selected)), "destination": str(transfer_destination.get_item_metadata(transfer_destination.selected)), "quantity": int(transfer_quantity.value)}))
	var quote_body := _section(logistics_page, "TRANSFER QUOTE")
	var quote_grid := GridContainer.new()
	quote_grid.columns = 2
	quote_body.add_child(quote_grid)
	for item: Array in [["distance", "Distance"], ["delivery", "Delivery"], ["freight", "Freight"]]: _metric_row(quote_grid, str(item[1]), str(item[0]), transfer_quote)
	var delivered_body := _section(logistics_page, "RECENT DELIVERIES")
	recent_delivery_rows = VBoxContainer.new()
	delivered_body.add_child(recent_delivery_rows)

func _section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ManagementSection"
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var heading := Label.new()
	heading.text = title
	heading.theme_type_variation = "SectionLabel"
	body.add_child(heading)
	return body

func _metric_section(parent: VBoxContainer, title: String, keys: Array, labels: Array, target: Dictionary) -> Control:
	var body := _section(parent, title)
	var grid := GridContainer.new()
	grid.columns = 2
	body.add_child(grid)
	for index: int in range(keys.size()): _metric_row(grid, str(labels[index]), str(keys[index]), target)
	return body.get_parent()

func _metric_row(grid: GridContainer, label_text: String, key: String, target: Dictionary) -> void:
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = "MetaLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.custom_minimum_size.x = 155
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)
	target[key] = value

func _note(parent: VBoxContainer, text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = "MetaLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func bind(game_session: GameSession, id: String) -> void:
	session = game_session
	selected_id = id
	sourcing_rows_key = ""
	logistics_rows_key = ""
	warehouse_rows_key = ""
	replenishment_rows_key = ""
	var f: SimFacility = session.sim.facility(id)
	layout_key = _layout_key(f)
	_populate_staff(f)
	_populate_research(f)
	choices.clear()
	line.clear()
	for product_id: String in session.sim.catalog.facility_types[f.type_id].products:
		if session.sim.can_configure(f.company_id, f.type_id, product_id):
			choices.add_item(product_id)
			choices.set_item_metadata(choices.item_count - 1, product_id)
			if product_id == f.product_id: choices.select(choices.item_count - 1)
	var preferred_line: String = str(selected_lines.get(id, f.product_id))
	for product_id: String in f.line_ids():
		line.add_item(product_id)
		line.set_item_metadata(line.item_count - 1, product_id)
		if product_id == preferred_line: line.select(line.item_count - 1)
	if line.selected < 0 and line.item_count > 0: line.select(0)
	price.value = f.line_price(_selected_line_id()) / 100.0 if session.sim._behavior(f) == "retail" and line.selected >= 0 else f.price / 100.0
	stock.value = f.stock_days
	_populate_transfer_controls(f)
	_populate_sourcing_products(f)
	_populate_suppliers()
	_populate_replenishment_products(f)
	_load_replenishment_value(f)
	tabs.current_tab = 0
	refresh()

func _populate_staff(f: SimFacility) -> void:
	var selected_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
	staff_role.clear()
	for role_id: String in _staff_role_order():
		if not session.sim.catalog.staff_roles.has(role_id): continue
		staff_role.add_item(str(session.sim.catalog.staff_roles[role_id].name))
		staff_role.set_item_metadata(staff_role.item_count - 1, role_id)
		if role_id == selected_role: staff_role.select(staff_role.item_count - 1)

func _populate_research(f: SimFacility) -> void:
	var selected_project: Dictionary = research_selections.get(f.id, {}) as Dictionary
	if selected_project.is_empty() and research_choices.selected >= 0 and research_choices.get_item_metadata(research_choices.selected) is Dictionary:
		selected_project = research_choices.get_item_metadata(research_choices.selected)
	research_choices.clear()
	for group: Array in [["TECHNOLOGY PROJECTS", "technology"], ["PRODUCT QUALITY PROJECTS", "product_quality"], ["PROCESS EFFICIENCY PROJECTS", "process_efficiency"]]:
		research_choices.add_item(str(group[0]))
		research_choices.set_item_disabled(research_choices.item_count - 1, true)
		research_choices.set_item_metadata(research_choices.item_count - 1, {})
		if group[1] == "technology":
			var tech_ids: Array = session.sim.catalog.technologies.keys()
			tech_ids.sort()
			for technology: String in tech_ids: _add_project("Technology — " + _display_id(technology), session.sim.technology_project(technology), selected_project)
		else:
			var product_ids: Array = session.sim.catalog.products.keys()
			product_ids.sort()
			for product_id: String in product_ids:
				if not session.sim.catalog.manufacturable_product(product_id): continue
				var project: Dictionary = session.sim.product_quality_project(f.company_id, product_id) if group[1] == "product_quality" else session.sim.process_efficiency_project(f.company_id, product_id)
				_add_project(("Product quality — " if group[1] == "product_quality" else "Process efficiency — ") + _product_name(product_id), project, selected_project)
	if research_choices.selected < 0 or (research_choices.get_item_metadata(research_choices.selected) as Dictionary).is_empty():
		if research_choices.item_count > 1: research_choices.select(1)
	if research_choices.selected >= 0:
		research_selections[f.id] = (research_choices.get_item_metadata(research_choices.selected) as Dictionary).duplicate(true)

func _add_project(label_text: String, project: Dictionary, selected_project: Dictionary) -> void:
	research_choices.add_item(label_text)
	research_choices.set_item_metadata(research_choices.item_count - 1, project)
	if session.sim.project_equal(project, selected_project): research_choices.select(research_choices.item_count - 1)

func _populate_transfer_controls(f: SimFacility) -> void:
	var selected_product: String = str(transfer_product_selections.get(f.id, ""))
	transfer_product.clear()
	var ids: Array = session.sim.catalog.products.keys()
	ids.sort()
	for product_id: String in ids:
		if session.sim.product_public(product_id):
			transfer_product.add_item(_product_name(product_id))
			transfer_product.set_item_metadata(transfer_product.item_count - 1, product_id)
			if product_id == selected_product: transfer_product.select(transfer_product.item_count - 1)
	if transfer_product.selected < 0 and transfer_product.item_count > 0: transfer_product.select(0)
	var selected_destination: String = str(transfer_destination_selections.get(f.id, ""))
	transfer_destination.clear()
	for other: SimFacility in session.sim.facilities:
		if other.company_id == f.company_id and other != f and not session.sim.catalog.productless_behavior(session.sim._behavior(other)):
			transfer_destination.add_item("%s • %s" % [session.sim.catalog.facility_types[other.type_id].name, other.id])
			transfer_destination.set_item_metadata(transfer_destination.item_count - 1, other.id)
			if other.id == selected_destination: transfer_destination.select(transfer_destination.item_count - 1)
	if transfer_destination.selected < 0 and transfer_destination.item_count > 0: transfer_destination.select(0)

func _populate_sourcing_products(f: SimFacility) -> void:
	var selected_product: String = str(sourcing_selections.get(f.id, ""))
	product.clear()
	var behavior: String = session.sim._behavior(f)
	if behavior == "retail":
		for product_id: String in f.line_ids(): _add_product_option(product, product_id, selected_product)
	elif behavior == "production":
		var input_ids: Array = session.sim.catalog.products.get(f.product_id, {}).get("inputs", {}).keys()
		input_ids.sort()
		for input: String in input_ids: _add_product_option(product, input, selected_product)
	else:
		var ids: Array = session.sim.catalog.products.keys()
		ids.sort()
		for product_id: String in ids: _add_product_option(product, product_id, selected_product)
	if product.selected < 0 and product.item_count > 0: product.select(0)

func _add_product_option(option: OptionButton, product_id: String, selected_product: String = "") -> void:
	option.add_item(_product_name(product_id))
	option.set_item_metadata(option.item_count - 1, product_id)
	if product_id == selected_product: option.select(option.item_count - 1)

func _populate_replenishment_products(f: SimFacility) -> void:
	var selected_product: String = str(replenishment_selections.get(f.id, ""))
	warehouse_target_product.clear()
	if session.sim._behavior(f) != "storage": return
	var relevant: Dictionary = {}
	for product_id: String in f.replenishment_targets: relevant[product_id] = true
	for product_id: String in f.inventory.quantities: relevant[product_id] = true
	for product_id: String in session.sim.catalog.products:
		if session.sim.product_public(product_id): relevant[product_id] = true
	var ids: Array = relevant.keys()
	ids.sort()
	for product_id: String in ids: _add_product_option(warehouse_target_product, product_id, selected_product)
	if warehouse_target_product.selected < 0 and warehouse_target_product.item_count > 0: warehouse_target_product.select(0)

func _load_replenishment_value(f: SimFacility) -> void:
	if warehouse_target_product.selected < 0: return
	var product_id: String = str(warehouse_target_product.get_item_metadata(warehouse_target_product.selected))
	warehouse_target_quantity.value = int(f.replenishment_targets.get(product_id, 0))

func _populate_suppliers() -> void:
	suppliers.clear()
	suppliers.add_item("Automatic")
	suppliers.set_item_metadata(0, "")
	if product.selected < 0 or session == null: return
	var product_id: String = str(product.get_item_metadata(product.selected))
	var f: SimFacility = session.sim.facility(selected_id)
	for offer: Dictionary in session.sim.supplier_offers(selected_id, product_id):
		if not bool(offer.eligible): continue
		suppliers.add_item(_facility_label(str(offer.id)))
		suppliers.set_item_metadata(suppliers.item_count - 1, str(offer.id))
		if str(f.suppliers.get(product_id, "")) == str(offer.id): suppliers.select(suppliers.item_count - 1)

func refresh() -> void:
	if session == null or selected_id.is_empty(): return
	var f: SimFacility = session.sim.facility(selected_id)
	if f == null: return
	if layout_key != _layout_key(f):
		if session.sim._behavior(f) == "research" and research_choices.selected >= 0:
			var selected_project: Variant = research_choices.get_item_metadata(research_choices.selected)
			if selected_project is Dictionary and not (selected_project as Dictionary).is_empty(): research_selections[f.id] = (selected_project as Dictionary).duplicate(true)
		bind(session, selected_id)
		return
	var owner: SimCompany = session.sim.companies[f.company_id]
	var definition: Dictionary = session.sim.catalog.facility_types[f.type_id]
	var behavior: String = session.sim._behavior(f)
	var own: bool = f.company_id == session.active_company
	_refresh_header(f, owner, definition, own)
	_configure_tabs(behavior)
	for section: Control in production_sections: section.visible = behavior == "production"
	for section: Control in retail_sections: section.visible = behavior == "retail"
	for section: Control in warehouse_sections: section.visible = behavior == "storage"
	for section: Control in research_overview_sections: section.visible = behavior == "research"
	for section: Control in headquarters_overview_sections: section.visible = behavior == "headquarters"
	for section: Control in research_page_sections: section.visible = behavior == "research"
	for section: Control in staffing_sections: section.visible = behavior == "headquarters"
	demolition_note.visible = behavior == "headquarters" and session.sim.total_staff(owner.id) > 0
	legacy_content.visible = false
	research_choices.visible = behavior == "research"
	assign_research.visible = behavior == "research"
	stop_research.visible = behavior == "research"
	staff_role.visible = behavior == "headquarters"
	hire_staff.visible = behavior == "headquarters"
	dismiss_staff.visible = behavior == "headquarters"
	production_line_section.visible = behavior == "production"
	retail_line_section.visible = behavior == "retail"
	replenishment_section.visible = behavior == "storage"
	replenishment_rows.get_parent().get_parent().visible = behavior == "storage"
	quality_section.visible = behavior == "production"
	recipe_section.visible = behavior == "production"
	product_lines_section.visible = behavior == "retail"
	if behavior == "production":
		if choices.get_parent() != production_line_body: choices.reparent(production_line_body)
		production_line_body.move_child(choices, 2)
	elif behavior == "retail":
		if choices.get_parent() != product_lines_body: choices.reparent(product_lines_body)
		product_lines_body.move_child(choices, 2)
	configure.visible = behavior == "retail"
	change_production.visible = behavior == "production"
	line.visible = behavior == "retail"
	line_info.visible = false
	price_section.visible = behavior in ["production", "retail"]
	stock_section.visible = behavior in ["production", "retail"]
	price.get_parent().visible = behavior in ["production", "retail"]
	stock.get_parent().visible = behavior in ["production", "retail"]
	if behavior == "production": _refresh_production(f, owner, definition)
	elif behavior == "retail": _refresh_retail(f, definition)
	elif behavior == "storage":
		_refresh_warehouse(f, definition)
		_refresh_replenishment(f, own)
	elif behavior == "research":
		_refresh_research_overview(f, owner, definition)
		_refresh_research(f, own)
	elif behavior == "headquarters":
		_refresh_headquarters_overview(f, owner, definition)
		_refresh_staff(f, owner, own)
	else: _refresh_legacy(f, owner, definition, behavior, own)
	_refresh_sourcing(f, own)
	_refresh_logistics(f, own, behavior)

func _refresh_header(f: SimFacility, owner: SimCompany, definition: Dictionary, own: bool) -> void:
	header_title.text = str(definition.name)
	header_meta.text = "%s • %s" % [owner.display_name, f.id]
	header_status.text = "OPERATING" if f.operating else "SUSPENDED"
	header_status.theme_type_variation = "PositiveLabel" if f.operating else "WarningLabel"
	operating.text = "Suspend" if f.operating else "Resume"
	operating.disabled = not own
	demolish.disabled = not own or (session.sim._behavior(f) == "headquarters" and session.sim.total_staff(owner.id) > 0)

func _configure_tabs(behavior: String) -> void:
	for index: int in range(4): tabs.set_tab_hidden(index, false)
	tabs.set_tab_title(0, "Overview")
	tabs.set_tab_title(1, "Operations")
	if behavior in ["research", "headquarters"]:
		tabs.set_tab_title(1, "Research" if behavior == "research" else "Staffing")
		for index: int in [2, 3]: tabs.set_tab_hidden(index, true)
	elif behavior == "storage":
		tabs.set_tab_title(0, "Overview")
		tabs.set_tab_title(1, "Replenishment")

func _refresh_production(f: SimFacility, owner: SimCompany, facility_definition: Dictionary) -> void:
	var definition: Dictionary = session.sim.catalog.products[f.product_id]
	var capacity: int = session.sim.effective_capacity(f)
	var overhead: int = session.sim.effective_overhead(f)
	var quality_level: int = owner.product_quality_level(f.product_id)
	var efficiency_level: int = owner.process_efficiency_level(f.product_id)
	var effective_quality: int = clampi(f.quality + session.sim.catalog.quality_bonus(quality_level), 1, 100)
	var effective_cost: int = session.sim.effective_conversion_cost(owner.id, f.product_id)
	_set_metric(production_metrics, "product_name", str(definition.name))
	_set_metric(production_metrics, "product_state", _availability(f, f.product_id))
	_set_metric(production_metrics, "produced_today", "%d units" % f.produced_today)
	_set_metric(production_metrics, "capacity", _base_effective_int(f.capacity, capacity, " units/day"))
	_set_metric(production_metrics, "finished_units", str(f.inventory.quantity(f.product_id)))
	_set_metric(production_metrics, "finished_value", CompanyReports.money(f.inventory.value(f.product_id)))
	_set_metric(production_metrics, "physical_quality", f.inventory.quality_text(f.product_id))
	_set_metric(production_metrics, "incoming", str(session.sim.logistics.incoming(f.id, f.product_id)))
	_set_metric(production_metrics, "overhead", _base_effective_money(int(facility_definition.overhead), overhead) + "/day")
	_set_metric(production_metrics, "conversion", _base_effective_money(int(definition.conversion_cost), effective_cost) + "/unit")
	_set_metric(production_metrics, "process_quality", str(f.quality))
	_set_metric(production_metrics, "effective_quality", str(effective_quality))
	_set_metric(production_metrics, "quality_level", "Level %d / %d" % [quality_level, session.sim.catalog.quality_max_level()])
	_set_metric(production_metrics, "efficiency_level", "Level %d / %d" % [efficiency_level, session.sim.catalog.efficiency_max_level()])
	_set_metric(production_operation_metrics, "process_quality", str(f.quality))
	_set_metric(production_operation_metrics, "effective_quality", str(effective_quality))
	_set_metric(production_operation_metrics, "quality_level", "Level %d / %d" % [quality_level, session.sim.catalog.quality_max_level()])
	_set_metric(production_operation_metrics, "efficiency_level", "Level %d / %d" % [efficiency_level, session.sim.catalog.efficiency_max_level()])
	_set_metric(production_operation_metrics, "effective_cost", CompanyReports.money(effective_cost) + "/unit")
	var recent_produced: int = 0
	var recent_sold: int = 0
	for record: Dictionary in f.recent_sales:
		recent_produced += int(record.get("produced", 0))
		recent_sold += int(record.get("units", 0))
	_set_metric(production_metrics, "recent_production", "%d units" % recent_produced)
	_set_metric(production_metrics, "recent_sales", "%d units" % recent_sold)
	production_current.text = str(definition.name)
	price_heading.text = "Wholesale sale price"
	price.value = f.price / 100.0
	stock.value = f.stock_days
	apply_price.disabled = f.company_id != session.active_company
	apply_stock.disabled = f.company_id != session.active_company
	_refresh_recipe(definition.get("inputs", {}))
	info.text = "%s\n%s\n%s" % [str(definition.name), _availability(f, f.product_id).to_upper(), "Operating" if f.operating else "Suspended"]

func _refresh_retail(f: SimFacility, facility_definition: Dictionary) -> void:
	var capacity: int = session.sim.effective_capacity(f)
	var overhead: int = session.sim.effective_overhead(f)
	var total_units: int = 0
	var total_value: int = 0
	for product_id: String in f.inventory.quantities:
		total_units += f.inventory.quantity(product_id)
		total_value += f.inventory.value(product_id)
	var weekly: int = 0
	for record: Dictionary in f.recent_sales: weekly += int(record.get("units", 0))
	_set_metric(retail_metrics, "store_type", str(facility_definition.name))
	_set_metric(retail_metrics, "assortment", "%d / %d lines" % [f.assortment.size(), int(facility_definition.get("slots", 1))])
	_set_metric(retail_metrics, "sold_today", "%d units" % f.sold_today)
	_set_metric(retail_metrics, "checkout", _base_effective_int(f.capacity, capacity, " units/day"))
	_set_metric(retail_metrics, "recent_sales", "%d units" % weekly)
	_set_metric(retail_metrics, "on_hand", "%d units" % total_units)
	_set_metric(retail_metrics, "incoming", "%d units" % session.sim.logistics.incoming(f.id))
	_set_metric(retail_metrics, "book_value", CompanyReports.money(total_value))
	_set_metric(retail_metrics, "overhead", _base_effective_money(int(facility_definition.overhead), overhead) + "/day")
	assortment_summary.text = "Lines %d / %d" % [f.assortment.size(), int(facility_definition.get("slots", 1))]
	price_heading.text = "Retail selling price"
	configure.disabled = f.company_id != session.active_company or choices.item_count == 0 or f.assortment.size() >= int(facility_definition.get("slots", 1))
	remove_line.disabled = f.company_id != session.active_company or f.assortment.size() <= 1
	_refresh_retail_line(f)
	stock.value = f.stock_days
	info.text = "%s\nLines %d / %d\n%s" % [facility_definition.name, f.assortment.size(), int(facility_definition.get("slots", 1)), "Operating" if f.operating else "Suspended"]

func _refresh_retail_line(f: SimFacility) -> void:
	if line.selected < 0: return
	var selected: String = _selected_line_id()
	var sales: Dictionary = f.line_sales.get(selected, {})
	var recent: int = 0
	for record: Dictionary in f.product_history: recent += int(record.products.get(selected, {}).get("units", 0))
	var quantity: int = f.inventory.quantity(selected)
	var unit_cost: int = f.inventory.value(selected) / maxi(1, quantity)
	var cost_label: String = "Unit book cost"
	if quantity == 0:
		unit_cost = int(sales.get("cogs", 0)) / maxi(1, int(sales.get("units", 0)))
		cost_label = "Avg. sold cost"
	_set_metric(retail_line_metrics, "product", _product_name(selected))
	_set_metric(retail_line_metrics, "current_price", CompanyReports.money(f.line_price(selected)))
	_set_metric(retail_line_metrics, "stock", "%d units" % quantity)
	_set_metric(retail_line_metrics, "incoming", "%d units" % session.sim.logistics.incoming(f.id, selected))
	_set_metric(retail_line_metrics, "quality", f.inventory.quality_text(selected))
	var policy: String = str(f.suppliers.get(selected, ""))
	_set_metric(retail_line_metrics, "supplier", "Automatic" if policy.is_empty() else policy)
	_set_metric(retail_line_metrics, "recent", "%d units" % recent)
	_set_metric(retail_line_metrics, "unit_cost", "%s · %s" % [cost_label, CompanyReports.money(unit_cost)])
	_set_metric(retail_line_metrics, "margin", CompanyReports.money(int(sales.get("revenue", 0)) - int(sales.get("cogs", 0))))
	line_info.text = "Lines %d / %d • %s" % [f.assortment.size(), int(session.sim.catalog.facility_types[f.type_id].get("slots", 1)), selected]
	price.value = f.line_price(selected) / 100.0
	apply_price.disabled = f.company_id != session.active_company
	apply_stock.disabled = f.company_id != session.active_company

func _refresh_recipe(inputs: Dictionary) -> void:
	for child: Node in recipe_rows.get_children(): child.queue_free()
	var input_ids: Array = inputs.keys()
	input_ids.sort()
	if input_ids.is_empty():
		_note(recipe_rows, "No material inputs")
		return
	for input: String in input_ids:
		var row := HBoxContainer.new()
		recipe_rows.add_child(row)
		var label := Label.new()
		label.text = _product_name(input)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var quantity := Label.new()
		quantity.text = str(inputs[input])
		quantity.theme_type_variation = "ValueLabel"
		row.add_child(quantity)

func _refresh_legacy(f: SimFacility, owner: SimCompany, definition: Dictionary, behavior: String, own: bool) -> void:
	info.text = "%s / %s\n%s | %s\nStorage: %d / %d units | free %d after reservations\nReplenishment targets: %s" % [f.id, owner.display_name, definition.name, "Operating" if f.operating else "Suspended", session.sim.logistics.used(f), f.capacity, session.sim.logistics.free_capacity(session.sim, f), str(f.replenishment_targets)]

func _refresh_research_overview(f: SimFacility, owner: SimCompany, definition: Dictionary) -> void:
	var sim: Economy = session.sim
	var base_rate: int = int(definition.research_rate)
	var effective_rate: int = sim.effective_research_rate(f)
	var bonus: int = _configured_effect(owner.id, "research_manager")
	_set_metric(research_overview_metrics, "state", "Operating" if f.operating else "Suspended")
	_set_metric(research_overview_metrics, "overhead", _base_effective_money(int(definition.overhead), sim.effective_overhead(f)) + "/day")
	_set_metric(research_overview_metrics, "rate", _base_effective_int(base_rate, effective_rate, " points/day"))
	_set_metric(research_overview_metrics, "bonus", "+%d%% configured" % bonus)
	_set_metric(research_overview_metrics, "known", "%d / %d" % [owner.known_technologies.size(), sim.catalog.technologies.size()])
	var has_project: bool = not f.research_project.is_empty()
	research_overview_empty.visible = not has_project
	var grid: GridContainer = research_overview_project_section.get_child(0).get_child(1) as GridContainer
	grid.visible = has_project
	if not has_project: return
	var project: Dictionary = f.research_project
	var progress: int = sim.project_progress(owner, project)
	var work: int = sim.project_work(project)
	var status: String = _research_state(f, owner, project, f.id)
	_set_metric(research_project_metrics, "name", _project_display_name(project))
	_set_metric(research_project_metrics, "kind", _project_kind_name(project))
	_set_metric(research_project_metrics, "status", status)
	_set_metric(research_project_metrics, "progress", "%d / %d points · %.1f%%" % [progress, work, _percent(progress, work)])
	_set_metric(research_project_metrics, "remaining", "%d days" % _funded_days(progress, work, effective_rate))
	_set_metric(research_project_metrics, "expense", CompanyReports.money(sim.project_cost(project)) + "/day")

func _refresh_headquarters_overview(f: SimFacility, owner: SimCompany, definition: Dictionary) -> void:
	var sim: Economy = session.sim
	_set_metric(headquarters_finance_metrics, "overhead", _base_effective_money(int(definition.overhead), sim.effective_overhead(f)) + "/day")
	_set_metric(headquarters_finance_metrics, "asset_cost", CompanyReports.money(f.asset_cost))
	_set_metric(headquarters_finance_metrics, "depreciation", CompanyReports.money(f.accumulated_depreciation))
	_set_metric(headquarters_finance_metrics, "book_value", CompanyReports.money(f.asset_cost - f.accumulated_depreciation))
	_set_metric(headquarters_staff_metrics, "staff", "%d / %d employed" % [sim.total_staff(owner.id), sim.staff_capacity(owner.id)])
	_set_metric(headquarters_staff_metrics, "payroll", CompanyReports.money(sim.daily_payroll(owner.id)) + "/day")
	_set_metric(headquarters_staff_metrics, "status", _staff_effect_state(f, owner))
	_set_metric(headquarters_effect_metrics, "operations", "+%d%% production / retail capacity" % _configured_effect(owner.id, "operations_manager"))
	_set_metric(headquarters_effect_metrics, "marketing", "+%d%% advertising progress" % _configured_effect(owner.id, "marketing_manager"))
	_set_metric(headquarters_effect_metrics, "research", "+%d%% research rate" % _configured_effect(owner.id, "research_manager"))
	_set_metric(headquarters_effect_metrics, "finance", "−%d%% facility overhead" % _configured_effect(owner.id, "finance_manager"))

func _refresh_staff(f: SimFacility, owner: SimCompany, own: bool) -> void:
	var sim: Economy = session.sim
	staff_info.text = ""
	_set_metric(staffing_metrics, "capacity", "%d / %d employed" % [sim.total_staff(owner.id), sim.staff_capacity(owner.id)])
	_set_metric(staffing_metrics, "payroll", CompanyReports.money(sim.daily_payroll(owner.id)) + "/day")
	staffing_status.text = "Management effects: " + _staff_effect_state(f, owner)
	staffing_status.theme_type_variation = "PositiveLabel" if sim.staff_effects_active(owner.id) else "WarningLabel"
	_clear_rows(staffing_roles)
	for role_id: String in _staff_role_order():
		if not sim.catalog.staff_roles.has(role_id): continue
		var role: Dictionary = sim.catalog.staff_roles[role_id]
		var sign: String = _effect_sign(role)
		var configured: int = _configured_effect(owner.id, role_id)
		_add_compact_row(staffing_roles, str(role.name), "%d employed · %s/day each" % [sim.staff_count(owner.id, role_id), CompanyReports.money(int(role.daily_salary))], "%s%d%% %s each · Current %s%d%% · Cap %s%d%%" % [sign, int(role.effect_per_staff), _effect_description(role), sign, configured, sign, int(role.effect_cap_percent)])
	var selected_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
	if not selected_role.is_empty():
		var selected: Dictionary = sim.catalog.staff_roles[selected_role]
		var sign: String = _effect_sign(selected)
		_set_metric(staffing_role_metrics, "count", str(sim.staff_count(owner.id, selected_role)))
		_set_metric(staffing_role_metrics, "salary", CompanyReports.money(int(selected.daily_salary)) + "/day")
		_set_metric(staffing_role_metrics, "effect", "%s%d%% %s" % [sign, int(selected.effect_per_staff), _effect_description(selected)])
		_set_metric(staffing_role_metrics, "configured", "%s%d%%" % [sign, _configured_effect(owner.id, selected_role)])
		_set_metric(staffing_role_metrics, "cap", "%s%d%%" % [sign, int(selected.effect_cap_percent)])
	staff_role.disabled = not own
	hire_staff.disabled = not own or not f.operating or sim.total_staff(owner.id) >= sim.staff_capacity(owner.id)
	dismiss_staff.disabled = not own or selected_role.is_empty() or sim.staff_count(owner.id, selected_role) <= 0
	staffing_note.text = "HQ suspended: hiring unavailable; dismissal remains available. Payroll remains due, management effects are inactive, building overhead is paused, and depreciation continues." if not f.operating else ""
	staffing_note.visible = not f.operating

func _refresh_sourcing(f: SimFacility, own: bool) -> void:
	var has_product: bool = product.selected >= 0
	product.disabled = not has_product
	suppliers.disabled = not own or not has_product
	apply_supplier.disabled = not own or not has_product or suppliers.selected < 0
	if not has_product:
		sourcing_policy.text = "No sourcing products"
		sourcing_policy_note.text = "This facility has no applicable sourcing policy."
		recent_sourcing.text = "No purchases today"
		if sourcing_rows_key != selected_id + ":empty":
			sourcing_rows_key = selected_id + ":empty"
			_clear_rows(offer_rows)
			_add_empty_row(offer_rows, "No eligible supplier offers.")
		return
	var product_id: String = str(product.get_item_metadata(product.selected))
	var policy: String = str(f.suppliers.get(product_id, ""))
	sourcing_policy.text = "Automatic" if policy.is_empty() else "Manual — %s" % policy
	sourcing_policy_note.text = "Ranks eligible offers using the existing landed-cost / quality / lead-time score." if policy.is_empty() else "Applies to %s." % _product_name(product_id)
	var offers: Array[Dictionary] = session.sim.supplier_offers(selected_id, product_id)
	var recent: Array = f.last_sources.get(product_id, [])
	var rows_key: String = selected_id + product_id + str(offers) + str(recent)
	if rows_key != sourcing_rows_key:
		sourcing_rows_key = rows_key
		_clear_rows(offer_rows)
		if offers.is_empty():
			_add_empty_row(offer_rows, "No eligible supplier offers.")
		else:
			for index: int in range(offers.size()): _add_offer_row(offer_rows, offers[index], index)
	if recent.is_empty():
		recent_sourcing.text = "No purchases today"
	else:
		var purchases: PackedStringArray = []
		for source: Dictionary in recent:
			purchases.append("Bought %d units • %s\n%s/unit • Q%d" % [int(source.units), _facility_label(str(source.supplier)), CompanyReports.money(int(source.price)), int(source.quality)])
		recent_sourcing.text = "\n".join(purchases)
	sourcing_info.text = sourcing_policy.text

func _refresh_logistics(f: SimFacility, own: bool, behavior: String) -> void:
	transfer_product.disabled = not own
	transfer_destination.disabled = not own
	transfer_quantity.editable = own
	transfer_button.disabled = not own or transfer_destination.item_count == 0 or transfer_product.item_count == 0
	var incoming_count: int = 0
	var outgoing_count: int = 0
	var active_records: Array[Dictionary] = []
	var delivered_records: Array[Dictionary] = []
	for shipment: Dictionary in session.sim.logistics.shipments:
		if shipment.source != f.id and shipment.destination != f.id: continue
		if shipment.status == "in_transit":
			active_records.append(shipment)
			if shipment.destination == f.id: incoming_count += 1
			else: outgoing_count += 1
		else:
			delivered_records.append(shipment)
	_set_metric(shipment_summary, "incoming_units", "%d units" % session.sim.logistics.incoming(f.id))
	_set_metric(shipment_summary, "incoming_count", str(incoming_count))
	_set_metric(shipment_summary, "outgoing_count", str(outgoing_count))
	var rows_key: String = selected_id + str(active_records) + str(delivered_records) + str(session.sim.clock.tick)
	if rows_key != logistics_rows_key:
		logistics_rows_key = rows_key
		_clear_rows(active_shipment_rows)
		_clear_rows(recent_delivery_rows)
		for shipment: Dictionary in active_records: _add_shipment_row(active_shipment_rows, shipment, f.id)
		for shipment: Dictionary in delivered_records: _add_shipment_row(recent_delivery_rows, shipment, f.id)
		if active_records.is_empty(): _add_empty_row(active_shipment_rows, "No active shipments.")
		if delivered_records.is_empty(): _add_empty_row(recent_delivery_rows, "No recent deliveries.")
	_refresh_transfer_quote()
	logistics_info.text = "%d active shipments" % active_records.size()

func _refresh_warehouse(f: SimFacility, definition: Dictionary) -> void:
	var used: int = session.sim.logistics.used(f)
	var incoming: int = session.sim.logistics.incoming(f.id)
	var stocked: int = 0
	var incoming_shipments: int = 0
	var outgoing_shipments: int = 0
	var recent: int = 0
	for product_id: String in f.inventory.quantities:
		if f.inventory.quantity(product_id) > 0: stocked += 1
	for shipment: Dictionary in session.sim.logistics.shipments:
		if shipment.status == "in_transit" and shipment.destination == f.id: incoming_shipments += 1
		if shipment.status == "in_transit" and shipment.source == f.id: outgoing_shipments += 1
		if shipment.status == "delivered" and (shipment.source == f.id or shipment.destination == f.id): recent += 1
	_set_metric(warehouse_metrics, "used", "%d units" % used)
	_set_metric(warehouse_metrics, "capacity", "%d units" % f.capacity)
	_set_metric(warehouse_metrics, "incoming", "%d units" % incoming)
	_set_metric(warehouse_metrics, "free", "%d units" % session.sim.logistics.free_capacity(session.sim, f))
	_set_metric(warehouse_metrics, "units", "%d units" % used)
	_set_metric(warehouse_metrics, "value", CompanyReports.money(f.inventory.total_value()))
	_set_metric(warehouse_metrics, "products", str(stocked))
	_set_metric(warehouse_metrics, "state", "Operating" if f.operating else "Suspended")
	_set_metric(warehouse_metrics, "overhead", _base_effective_money(int(definition.overhead), session.sim.effective_overhead(f)) + "/day")
	_set_metric(warehouse_metrics, "incoming_shipments", str(incoming_shipments))
	_set_metric(warehouse_metrics, "outgoing_shipments", str(outgoing_shipments))
	_set_metric(warehouse_metrics, "recent", "%d delivered" % recent)
	var ids: Array = f.inventory.quantities.keys()
	ids.sort()
	var rows_key: String = selected_id + str(f.inventory.snapshot()) + str(incoming)
	if rows_key != warehouse_rows_key:
		warehouse_rows_key = rows_key
		_clear_rows(warehouse_inventory_rows)
		for product_id: String in ids:
			var units: int = f.inventory.quantity(product_id)
			if units <= 0: continue
			_add_compact_row(warehouse_inventory_rows, _product_name(product_id), "%d units • %s • %s" % [units, CompanyReports.money(f.inventory.value(product_id)), f.inventory.quality_text(product_id)], "Incoming %d units" % session.sim.logistics.incoming(f.id, product_id))
		if stocked == 0: _add_empty_row(warehouse_inventory_rows, "Warehouse is empty.")

func _refresh_replenishment(f: SimFacility, own: bool) -> void:
	warehouse_target_product.disabled = not own
	warehouse_target_quantity.editable = own
	warehouse_target.disabled = not own or warehouse_target_product.selected < 0
	warehouse_target_quantity.max_value = f.capacity
	if warehouse_target_product.selected >= 0:
		var product_id: String = str(warehouse_target_product.get_item_metadata(warehouse_target_product.selected))
		var current: int = int(f.replenishment_targets.get(product_id, 0))
		replenishment_current.text = "Current target: %s" % ("Off" if current == 0 else "%d units" % current)
	else:
		replenishment_current.text = "Current target: Off"
	var ids: Array = f.replenishment_targets.keys()
	ids.sort()
	var rows_key: String = selected_id + str(f.replenishment_targets)
	if rows_key != replenishment_rows_key:
		replenishment_rows_key = rows_key
		_clear_rows(replenishment_rows)
		for product_id: String in ids:
			var target: int = int(f.replenishment_targets[product_id])
			_add_compact_row(replenishment_rows, _product_name(product_id), "Off" if target == 0 else "%d units" % target)
		if ids.is_empty(): _add_empty_row(replenishment_rows, "No replenishment targets configured.")

func _refresh_transfer_quote() -> void:
	if session == null or selected_id.is_empty() or transfer_destination == null or transfer_destination.selected < 0:
		_set_metric(transfer_quote, "distance", "—")
		_set_metric(transfer_quote, "delivery", "—")
		_set_metric(transfer_quote, "freight", "—")
		return
	var destination: String = str(transfer_destination.get_item_metadata(transfer_destination.selected))
	var quote: Dictionary = session.sim.logistics.quote(session.sim, selected_id, destination, int(transfer_quantity.value))
	_set_metric(transfer_quote, "distance", "%d cells" % int(quote.distance))
	_set_metric(transfer_quote, "delivery", "%d day%s" % [int(quote.lead_days), "" if int(quote.lead_days) == 1 else "s"])
	_set_metric(transfer_quote, "freight", CompanyReports.money(int(quote.freight)))

func _add_offer_row(parent: VBoxContainer, offer: Dictionary, index: int) -> void:
	var status: String = "AVAILABLE" if bool(offer.eligible) else "UNAVAILABLE"
	var rank: String = " • Automatic rank #1" if index == 0 and bool(offer.eligible) else ""
	var row: Control = _add_compact_row(parent, "%s%s" % [_facility_label(str(offer.id)), rank], "%s • %s/unit • Q%d • %d in stock" % [status, CompanyReports.money(int(offer.price)), int(offer.quality), int(offer.stock)], "Delivery %dd • Landed %s/unit • Score %.2f\n%d cells • Freight %s for %d" % [int(offer.lead_days), CompanyReports.money(int(offer.landed)), float(offer.score), int(offer.distance), CompanyReports.money(int(offer.freight)), int(offer.quote_quantity)])
	row.set_meta("offer", offer.duplicate(true))
	if not bool(offer.eligible):
		for child: Node in row.get_children():
			if child is Label: (child as Label).theme_type_variation = "WarningLabel"

func _add_shipment_row(parent: VBoxContainer, shipment: Dictionary, facility_id: String) -> void:
	var incoming: bool = str(shipment.destination) == facility_id
	var counterpart: String = str(shipment.source) if incoming else str(shipment.destination)
	var active: bool = str(shipment.status) == "in_transit"
	var eta: int = maxi(0, int(shipment.arrival) - session.sim.clock.tick)
	var status: String = "IN TRANSIT" if active else "DELIVERED"
	var detail: String = "%s • ETA %d day%s • %d cells • Freight %s" % [_facility_label(counterpart), eta, "" if eta == 1 else "s", int(shipment.distance), CompanyReports.money(int(shipment.transport_cost))]
	var row: Control = _add_compact_row(parent, "#%d • %s • %s" % [int(shipment.id), "IN" if incoming else "OUT", _product_name(str(shipment.product))], "%d units • %s" % [int(shipment.quantity), status], detail)
	row.set_meta("shipment", shipment.duplicate(true))

func _add_compact_row(parent: VBoxContainer, title: String, detail: String, secondary: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ManagementSection"
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var title_label := Label.new()
	title_label.text = title
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.theme_type_variation = "MetaLabel"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail_label)
	if not secondary.is_empty():
		var secondary_label := Label.new()
		secondary_label.text = secondary
		secondary_label.theme_type_variation = "MetaLabel"
		secondary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(secondary_label)
	return panel

func _add_empty_row(parent: VBoxContainer, message: String) -> void:
	var label := _note(parent, message)
	label.name = "EmptyState"

func _clear_rows(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _facility_label(facility_id: String) -> String:
	var facility: SimFacility = session.sim.facility(facility_id)
	if facility == null: return facility_id
	return "%s • %s" % [session.sim.catalog.facility_types[facility.type_id].name, facility.id]

func _availability(f: SimFacility, product_id: String) -> String:
	if session.sim.can_configure(f.company_id, f.type_id, product_id): return "Available"
	return "Research required" if session.sim.product_public(product_id) else "Era locked"

func _base_effective_int(base: int, effective: int, suffix: String = "") -> String:
	return "%d%s" % [base, suffix] if base == effective else "%d base · %d effective%s" % [base, effective, suffix]

func _base_effective_money(base: int, effective: int) -> String:
	return CompanyReports.money(base) if base == effective else "%s base · %s effective" % [CompanyReports.money(base), CompanyReports.money(effective)]

func _set_metric(target: Dictionary, key: String, value: String) -> void:
	(target[key] as Label).text = value

func _product_name(product_id: String) -> String:
	return str(session.sim.catalog.products.get(product_id, {"name": product_id.replace("_", " ")}).name)

func _selected_line_id() -> String:
	return str(line.get_item_metadata(line.selected)) if line.selected >= 0 else ""

func _layout_key(f: SimFacility) -> String:
	var owner: SimCompany = session.sim.companies[f.company_id]
	return str(f.line_ids()) + f.product_id + str(session.sim.clock.year) + str(owner.known_technologies) + str(owner.product_quality_levels) + str(owner.product_quality_progress) + str(owner.process_efficiency_levels) + str(owner.process_efficiency_progress) + str(owner.staff_counts) + str(session.sim.unlocked_technologies)

func _refresh_research(f: SimFacility, own: bool) -> void:
	if research_choices.selected < 0: return
	var project: Dictionary = research_choices.get_item_metadata(research_choices.selected)
	if project.is_empty(): return
	var sim: Economy = session.sim
	var owner: SimCompany = sim.companies[f.company_id]
	var work: int = sim.project_work(project)
	var progress: int = sim.project_progress(owner, project)
	if project.get("kind") == "technology" and owner.knows(str(project.get("technology", ""))): progress = work
	var error: String = sim.research_project_error(owner.id, project, f.id)
	var assigned: String = _assigned_research_facility(owner.id, project)
	var status: String = _research_state(f, owner, project, assigned)
	var effective_rate: int = sim.effective_research_rate(f)
	_set_metric(research_detail_metrics, "name", _project_display_name(project))
	_set_metric(research_detail_metrics, "kind", _project_kind_name(project))
	_set_metric(research_detail_metrics, "status", status)
	_set_metric(research_detail_metrics, "public_year", "—")
	_set_metric(research_detail_metrics, "knowledge", "—")
	_set_metric(research_detail_metrics, "levels", "—")
	_set_metric(research_detail_metrics, "project_cost", CompanyReports.money(sim.project_cost(project)) + "/day")
	_set_metric(research_detail_metrics, "overhead", _base_effective_money(int(sim.catalog.facility_types[f.type_id].overhead), sim.effective_overhead(f)) + "/day")
	_set_metric(research_detail_metrics, "rate", _base_effective_int(int(sim.catalog.facility_types[f.type_id].research_rate), effective_rate, " points/day"))
	_set_metric(research_detail_metrics, "remaining", "%d days" % _funded_days(progress, work, effective_rate))
	_set_metric(research_detail_metrics, "facility", "None" if assigned.is_empty() else _facility_label(assigned))
	research_progress.max_value = maxi(1, work)
	research_progress.value = clampi(progress, 0, work)
	research_progress_text.text = "%d / %d points · %.1f%%" % [progress, work, _percent(progress, work)]
	_clear_rows(research_prerequisites)
	research_status.text = ""
	if project.kind == "technology":
		var technology: String = str(project.technology)
		var definition: Dictionary = sim.catalog.technologies[technology]
		if owner.knows(technology):
			status = "Known"
			progress = work
		_set_metric(research_detail_metrics, "status", status)
		_set_metric(research_detail_metrics, "public_year", str(int(definition.year)))
		_set_metric(research_detail_metrics, "knowledge", "Known" if owner.knows(technology) else "Unknown")
		research_status.text = "Public via Debug override." if technology in sim.unlocked_technologies else ""
		if definition.prerequisites.is_empty():
			_add_empty_row(research_prerequisites, "No prerequisites")
		else:
			for prerequisite: String in definition.prerequisites:
				_add_compact_row(research_prerequisites, _display_id(prerequisite), "KNOWN" if owner.knows(prerequisite) else "UNKNOWN")
	elif project.kind == "product_quality":
		var product_id: String = str(project.product)
		var current: int = owner.product_quality_level(product_id)
		_set_metric(research_detail_metrics, "levels", "%d current · %d target · %d maximum" % [current, int(project.target_level), sim.catalog.quality_max_level()])
		_add_empty_row(research_prerequisites, "Manufacturing knowledge — " + ("KNOWN" if owner.knows(str(sim.catalog.products[product_id].technology)) else "UNKNOWN"))
		research_status.text = "Each completed level improves process quality for newly manufactured goods."
	else:
		var product_id: String = str(project.product)
		var current: int = owner.process_efficiency_level(product_id)
		var reduction: int = sim.catalog.conversion_cost_reduction(int(project.target_level))
		_set_metric(research_detail_metrics, "levels", "%d current · %d target · %d maximum" % [current, int(project.target_level), sim.catalog.efficiency_max_level()])
		_add_compact_row(research_prerequisites, "Target conversion-cost reduction", "%d%%" % reduction)
		_add_compact_row(research_prerequisites, "Conversion cost", "%s base · %s target" % [CompanyReports.money(int(sim.catalog.products[product_id].conversion_cost)), CompanyReports.money(sim.conversion_cost_at_level(product_id, int(project.target_level)))])
		research_status.text = "Applies to conversion cost of newly produced goods."
	var assigned_here: bool = assigned == f.id
	research_attention.text = "ATTENTION — " + status if assigned_here and status in ["Suspended", "Insufficient operating funds"] else ""
	research_attention.visible = not research_attention.text.is_empty()
	assign_research.text = "Resume project" if progress > 0 else "Assign project"
	assign_research.disabled = not own or not error.is_empty() or (not f.research_project.is_empty() and sim.project_equal(f.research_project, project))
	stop_research.disabled = not own or f.research_project.is_empty()
	# Compatibility readback for focused pre-B3 smoke tests; primary presentation is structured above.
	research_info.text = "%s\n%s\nProgress %.1f%%\nAssigned facility: %s" % [_project_display_name(project), status, _percent(progress, work), "None" if assigned.is_empty() else assigned]

func _assigned_research_facility(company_id: String, project: Dictionary) -> String:
	for other: SimFacility in session.sim.facilities:
		if other.company_id == company_id and not other.research_project.is_empty() and session.sim.project_equal(other.research_project, project): return other.id
	return ""

func _research_state(f: SimFacility, owner: SimCompany, project: Dictionary, assigned: String = "") -> String:
	var sim: Economy = session.sim
	var facility_id: String = assigned if not assigned.is_empty() else _assigned_research_facility(owner.id, project)
	if facility_id == f.id:
		if not f.operating: return "Suspended"
		if not f.active or owner.cash < sim.project_cost(project): return "Insufficient operating funds"
		return "Assigned"
	var error: String = sim.research_project_error(owner.id, project, f.id)
	if error.is_empty(): return "Researchable"
	if error == "Already known.": return "Known"
	if error.begins_with("Requires knowledge:"): return "Prerequisite missing — " + _display_id(error.trim_prefix("Requires knowledge:" ).strip_edges())
	if error.begins_with("Assigned to "): return "Assigned — " + error.trim_prefix("Assigned to ")
	if error.begins_with("Maximum ") or error.begins_with("Target must be "): return "Maximum level / invalid next level"
	return error.trim_suffix(".")

func _project_display_name(project: Dictionary) -> String:
	if project.get("kind") == "technology": return _display_id(str(project.get("technology", "")))
	return _product_name(str(project.get("product", "")))

func _project_kind_name(project: Dictionary) -> String:
	return {"technology": "Technology", "product_quality": "Product quality", "process_efficiency": "Process efficiency"}.get(str(project.get("kind", "")), "Unknown")

func _display_id(value: String) -> String:
	return value.replace("_", " ").capitalize()

func _percent(progress: int, work: int) -> float:
	return 0.0 if work <= 0 else clampf(progress * 100.0 / work, 0.0, 100.0)

func _funded_days(progress: int, work: int, rate: int) -> int:
	if rate <= 0: return 0
	return maxi(0, ceili(float(maxi(0, work - progress)) / rate))

func _staff_effect_state(f: SimFacility, owner: SimCompany) -> String:
	if session.sim.staff_effects_active(owner.id): return "ACTIVE"
	if not f.operating: return "INACTIVE — headquarters suspended"
	if session.sim.total_staff(owner.id) == 0: return "INACTIVE — no staff"
	return "INACTIVE — payroll not funded"

func _configured_effect(company_id: String, role_id: String) -> int:
	var role: Dictionary = session.sim.catalog.staff_roles.get(role_id, {})
	if role.is_empty(): return 0
	return mini(session.sim.staff_count(company_id, role_id) * int(role.effect_per_staff), int(role.effect_cap_percent))

func _effect_sign(role: Dictionary) -> String:
	return "−" if role.effect == "facility_overhead_reduction_percent" else "+"

func _effect_description(role: Dictionary) -> String:
	return {"operations_capacity_percent": "production / retail capacity", "advertising_progress_percent": "advertising progress", "research_rate_percent": "research rate", "facility_overhead_reduction_percent": "facility overhead"}.get(str(role.effect), str(role.effect))

func _staff_role_order() -> Array[String]:
	return ["operations_manager", "marketing_manager", "research_manager", "finance_manager"]
