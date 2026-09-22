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
	research_choices.item_selected.connect(func(_index: int) -> void: refresh())
	research_info = RichTextLabel.new()
	research_info.custom_minimum_size = Vector2(390, 225)
	legacy_content.add_child(research_info)
	assign_research = _button(legacy_content, "Assign / resume research", func() -> void:
		if research_choices.selected >= 0:
			var project: Dictionary = research_choices.get_item_metadata(research_choices.selected)
			if not project.is_empty(): command_requested.emit({"type": "assign_research", "facility": selected_id, "project": project}))
	stop_research = _button(legacy_content, "Stop research (retain progress)", func() -> void: command_requested.emit({"type": "stop_research", "facility": selected_id}))

func _build_operations() -> void:
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

func _build_sourcing() -> void:
	var body := _section(sourcing_page, "SOURCING / WHOLESALE OFFERS")
	product = OptionButton.new()
	body.add_child(product)
	product.item_selected.connect(func(_index: int) -> void: _populate_suppliers())
	suppliers = OptionButton.new()
	body.add_child(suppliers)
	apply_supplier = _button(body, "Queue supplier selection", func() -> void:
		if product.selected >= 0 and suppliers.selected >= 0:
			command_requested.emit({"type": "set_supplier", "facility": selected_id, "product": product.get_item_text(product.selected), "supplier": str(suppliers.get_item_metadata(suppliers.selected))}))
	sourcing_info = RichTextLabel.new()
	sourcing_info.custom_minimum_size = Vector2(390, 220)
	body.add_child(sourcing_info)

func _build_logistics() -> void:
	var body := _section(logistics_page, "SHIPMENTS / TRANSFERS")
	logistics_info = RichTextLabel.new()
	logistics_info.custom_minimum_size = Vector2(390, 170)
	body.add_child(logistics_info)
	transfer_product = OptionButton.new()
	body.add_child(transfer_product)
	transfer_destination = OptionButton.new()
	body.add_child(transfer_destination)
	var transfer_row := HBoxContainer.new()
	body.add_child(transfer_row)
	transfer_quantity = SpinBox.new()
	transfer_quantity.min_value = 0
	transfer_quantity.max_value = 100000
	transfer_quantity.value = 10
	transfer_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer_row.add_child(transfer_quantity)
	transfer_button = _button(transfer_row, "Send transfer", func() -> void:
		if transfer_destination.selected >= 0 and transfer_product.selected >= 0:
			command_requested.emit({"type": "transfer", "facility": selected_id, "product": transfer_product.get_item_text(transfer_product.selected), "destination": str(transfer_destination.get_item_metadata(transfer_destination.selected)), "quantity": int(transfer_quantity.value)}))
	warehouse_target = _button(body, "Set warehouse replenishment target (0 = off)", func() -> void:
		if transfer_product.selected >= 0: command_requested.emit({"type": "set_warehouse_target", "facility": selected_id, "product": transfer_product.get_item_text(transfer_product.selected), "quantity": int(transfer_quantity.value)}))

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
	tabs.current_tab = 0
	refresh()

func _populate_staff(f: SimFacility) -> void:
	var selected_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
	staff_role.clear()
	var role_ids: Array = session.sim.catalog.staff_roles.keys()
	role_ids.sort()
	for role_id: String in role_ids:
		staff_role.add_item(str(session.sim.catalog.staff_roles[role_id].name))
		staff_role.set_item_metadata(staff_role.item_count - 1, role_id)
		if role_id == selected_role: staff_role.select(staff_role.item_count - 1)

func _populate_research(f: SimFacility) -> void:
	var selected_project: Dictionary = research_choices.get_item_metadata(research_choices.selected) if research_choices.selected >= 0 and research_choices.get_item_metadata(research_choices.selected) is Dictionary else {}
	research_choices.clear()
	for group: Array in [["TECHNOLOGY PROJECTS", "technology"], ["PRODUCT QUALITY PROJECTS", "product_quality"], ["PROCESS EFFICIENCY PROJECTS", "process_efficiency"]]:
		research_choices.add_item(str(group[0]))
		research_choices.set_item_disabled(research_choices.item_count - 1, true)
		research_choices.set_item_metadata(research_choices.item_count - 1, {})
		if group[1] == "technology":
			var tech_ids: Array = session.sim.catalog.technologies.keys()
			tech_ids.sort()
			for technology: String in tech_ids: _add_project("Technology — " + technology.replace("_", " "), session.sim.technology_project(technology), selected_project)
		else:
			var product_ids: Array = session.sim.catalog.products.keys()
			product_ids.sort()
			for product_id: String in product_ids:
				if not session.sim.catalog.manufacturable_product(product_id): continue
				var project: Dictionary = session.sim.product_quality_project(f.company_id, product_id) if group[1] == "product_quality" else session.sim.process_efficiency_project(f.company_id, product_id)
				_add_project(("Product quality — " if group[1] == "product_quality" else "Process efficiency — ") + _product_name(product_id), project, selected_project)
	if research_choices.selected <= 0 and research_choices.item_count > 1: research_choices.select(1)

func _add_project(label_text: String, project: Dictionary, selected_project: Dictionary) -> void:
	research_choices.add_item(label_text)
	research_choices.set_item_metadata(research_choices.item_count - 1, project)
	if session.sim.project_equal(project, selected_project): research_choices.select(research_choices.item_count - 1)

func _populate_transfer_controls(f: SimFacility) -> void:
	transfer_product.clear()
	var ids: Array = session.sim.catalog.products.keys()
	ids.sort()
	for product_id: String in ids:
		if session.sim.product_public(product_id): transfer_product.add_item(product_id)
	transfer_destination.clear()
	for other: SimFacility in session.sim.facilities:
		if other.company_id == f.company_id and other != f and not session.sim.catalog.productless_behavior(session.sim._behavior(other)):
			transfer_destination.add_item("To: " + other.id + " / " + other.type_id)
			transfer_destination.set_item_metadata(transfer_destination.item_count - 1, other.id)

func _populate_sourcing_products(f: SimFacility) -> void:
	product.clear()
	var behavior: String = session.sim._behavior(f)
	if behavior == "retail":
		for product_id: String in f.line_ids(): product.add_item(product_id)
	elif behavior == "production":
		var input_ids: Array = session.sim.catalog.products.get(f.product_id, {}).get("inputs", {}).keys()
		input_ids.sort()
		for input: String in input_ids: product.add_item(input)
	else:
		var ids: Array = session.sim.catalog.products.keys()
		ids.sort()
		for product_id: String in ids: product.add_item(product_id)

func _populate_suppliers() -> void:
	suppliers.clear()
	suppliers.add_item("Automatic: landed cost / quality + lead time")
	suppliers.set_item_metadata(0, "")
	if product.selected < 0 or session == null: return
	var product_id: String = product.get_item_text(product.selected)
	var f: SimFacility = session.sim.facility(selected_id)
	for offer: Dictionary in session.sim.supplier_offers(selected_id, product_id):
		suppliers.add_item(str(offer.id))
		suppliers.set_item_metadata(suppliers.item_count - 1, str(offer.id))
		if str(f.suppliers.get(product_id, "")) == str(offer.id): suppliers.select(suppliers.item_count - 1)

func refresh() -> void:
	if session == null or selected_id.is_empty(): return
	var f: SimFacility = session.sim.facility(selected_id)
	if f == null: return
	if layout_key != _layout_key(f):
		bind(session, selected_id)
		return
	var owner: SimCompany = session.sim.companies[f.company_id]
	var definition: Dictionary = session.sim.catalog.facility_types[f.type_id]
	var behavior: String = session.sim._behavior(f)
	var own: bool = f.company_id == session.player_company
	_refresh_header(f, owner, definition, own)
	_configure_tabs(behavior)
	for section: Control in production_sections: section.visible = behavior == "production"
	for section: Control in retail_sections: section.visible = behavior == "retail"
	legacy_content.visible = behavior not in ["production", "retail"]
	production_line_section.visible = behavior == "production"
	retail_line_section.visible = behavior == "retail"
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
		tabs.set_tab_title(0, "R&D" if behavior == "research" else "Headquarters")
		for index: int in [1, 2, 3]: tabs.set_tab_hidden(index, true)
		tabs.current_tab = 0
	elif behavior == "storage":
		tabs.set_tab_title(0, "Warehouse")
		tabs.set_tab_hidden(1, true)
		if tabs.current_tab == 1: tabs.current_tab = 0

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
	apply_price.disabled = f.company_id != session.player_company
	apply_stock.disabled = f.company_id != session.player_company
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
	configure.disabled = f.company_id != session.player_company or choices.item_count == 0 or f.assortment.size() >= int(facility_definition.get("slots", 1))
	remove_line.disabled = f.company_id != session.player_company or f.assortment.size() <= 1
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
	apply_price.disabled = f.company_id != session.player_company
	apply_stock.disabled = f.company_id != session.player_company

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
	for control: Control in [research_choices, research_info, assign_research, stop_research]: control.visible = behavior == "research"
	for control: Control in [staff_info, staff_role, hire_staff, dismiss_staff]: control.visible = behavior == "headquarters"
	if behavior == "research":
		var base_rate: int = int(definition.research_rate)
		var effective_rate: int = session.sim.effective_research_rate(f)
		var rate_text: String = "%d points/day" % base_rate if base_rate == effective_rate else "%d base / %d effective points/day" % [base_rate, effective_rate]
		info.text = "%s / %s\nR&D center | %s\nRate %s | Overhead %s/day\nAssigned: %s\nCompany knowledge: %d / %d technologies" % [f.id, owner.display_name, "Operating" if f.operating else "Suspended", rate_text, _base_effective_money(int(definition.overhead), session.sim.effective_overhead(f)), session.sim.project_name(f.research_project) if not f.research_project.is_empty() else "None", owner.known_technologies.size(), session.sim.catalog.technologies.size()]
		_refresh_research(f, own)
	elif behavior == "headquarters":
		var book_value: int = f.asset_cost - f.accumulated_depreciation
		info.text = "Corporate headquarters\n%s\n%s\nDaily overhead: %s\nConstruction / fixed-asset cost: %s\nAccumulated depreciation: %s\nNet book value: %s" % [owner.display_name, "Operating" if f.operating else "Suspended", _base_effective_money(int(definition.overhead), session.sim.effective_overhead(f)), CompanyReports.money(f.asset_cost), CompanyReports.money(f.accumulated_depreciation), CompanyReports.money(book_value)]
		_refresh_staff(f, owner, own)
	else:
		info.text = "%s / %s\n%s | %s\nStorage: %d / %d units | free %d after reservations\nReplenishment targets: %s" % [f.id, owner.display_name, definition.name, "Operating" if f.operating else "Suspended", session.sim.logistics.used(f), f.capacity, session.sim.logistics.free_capacity(session.sim, f), str(f.replenishment_targets)]

func _refresh_staff(f: SimFacility, owner: SimCompany, own: bool) -> void:
	var active: bool = session.sim.staff_effects_active(owner.id)
	var effect_state: String = "ACTIVE" if active else "INACTIVE"
	if not active:
		if not f.operating: effect_state += " — headquarters suspended"
		elif session.sim.total_staff(owner.id) == 0: effect_state += " — no staff"
		else: effect_state += " — payroll not funded"
	var lines: PackedStringArray = ["[font_size=16][color=#AAB8C1]STAFFING[/color][/font_size]", "Total staff: %d / %d" % [session.sim.total_staff(owner.id), session.sim.staff_capacity(owner.id)], "Configured daily payroll: %s/day" % CompanyReports.money(session.sim.daily_payroll(owner.id)), "Management effects: " + effect_state, ""]
	var role_ids: Array = session.sim.catalog.staff_roles.keys()
	role_ids.sort()
	for role_id: String in role_ids:
		var role: Dictionary = session.sim.catalog.staff_roles[role_id]
		var configured: int = mini(session.sim.staff_count(owner.id, role_id) * int(role.effect_per_staff), int(role.effect_cap_percent))
		var description: String = {"operations_capacity_percent": "production/retail capacity", "advertising_progress_percent": "advertising progress", "research_rate_percent": "research rate", "facility_overhead_reduction_percent": "facility overhead"}.get(str(role.effect), str(role.effect))
		var sign: String = "-" if role.effect == "facility_overhead_reduction_percent" else "+"
		lines.append("%s: %d | %s%d%% each | %s%d%% %s | %s/day" % [role.name, session.sim.staff_count(owner.id, role_id), sign, int(role.effect_per_staff), sign, configured, description, CompanyReports.money(int(role.daily_salary))])
	staff_info.text = "\n".join(lines)
	var selected_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
	staff_role.disabled = not own
	hire_staff.disabled = not own or not f.operating or session.sim.total_staff(owner.id) >= session.sim.staff_capacity(owner.id)
	dismiss_staff.disabled = not own or selected_role.is_empty() or session.sim.staff_count(owner.id, selected_role) <= 0

func _refresh_sourcing(f: SimFacility, own: bool) -> void:
	apply_supplier.disabled = not own or product.item_count == 0
	var details: PackedStringArray = []
	if product.selected >= 0:
		var product_id: String = product.get_item_text(product.selected)
		var policy: String = str(f.suppliers.get(product_id, ""))
		details.append("Policy: " + ("Automatic" if policy.is_empty() else policy))
		for offer: Dictionary in session.sim.supplier_offers(selected_id, product_id): details.append("%s: $%.2f | Q%d | stock %d\n%d cells / %dd | freight $%.2f for %d\nLanded $%.2f/unit | score %.2f%s" % [offer.id, offer.price / 100.0, offer.quality, offer.stock, offer.distance, offer.lead_days, offer.freight / 100.0, offer.quote_quantity, offer.landed / 100.0, offer.score, "" if offer.eligible else " (unavailable)"])
		for source: Dictionary in f.last_sources.get(product_id, []): details.append("Bought %d from %s today" % [source.units, source.supplier])
	var market: Dictionary = session.sim.market.get(f.product_id, {})
	if not market.is_empty(): details.append("Market: %d sold / %d potential\nAverage price $%.2f | owner share %.1f%%" % [market.units, market.potential, market.average_price / 100.0, float(market.market_share.get(f.company_id, 0.0)) * 100.0])
	sourcing_info.text = "\n".join(details)

func _refresh_logistics(f: SimFacility, own: bool, behavior: String) -> void:
	transfer_button.disabled = not own or transfer_destination.item_count == 0
	warehouse_target.visible = behavior == "storage"
	warehouse_target.disabled = not own
	var lines: PackedStringArray = ["LOGISTICS • incoming %d units" % session.sim.logistics.incoming(f.id)]
	var records: Array[Dictionary] = session.sim.logistics.shipments.duplicate()
	records.reverse()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.status == "in_transit" and b.status != "in_transit")
	for shipment: Dictionary in records:
		if shipment.source == f.id or shipment.destination == f.id: lines.append("#%d %s %d %s • %s\n%s | ETA %dd | freight $%.2f" % [shipment.id, "IN" if shipment.destination == f.id else "OUT", shipment.quantity, shipment.product, shipment.status, shipment.source if shipment.destination == f.id else shipment.destination, maxi(0, int(shipment.arrival) - session.sim.clock.tick), shipment.transport_cost / 100.0])
	if transfer_destination.selected >= 0:
		var quote: Dictionary = session.sim.logistics.quote(session.sim, f.id, str(transfer_destination.get_item_metadata(transfer_destination.selected)), int(transfer_quantity.value))
		lines.insert(1, "Transfer quote: %d cells / %dd / $%.2f" % [quote.distance, quote.lead_days, quote.freight / 100.0])
	logistics_info.text = "\n".join(lines)

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
	var error: String = sim.research_project_error(owner.id, project, f.id)
	var status: String = "Researchable" if error.is_empty() else error
	var assigned: String = "None"
	for other: SimFacility in sim.facilities:
		if other.company_id == owner.id and not other.research_project.is_empty() and sim.project_equal(other.research_project, project): assigned = other.id
	var eta: int = ceili(float(work - progress) / sim.effective_research_rate(f))
	if project.kind == "technology":
		var technology: String = str(project.technology)
		var definition: Dictionary = sim.catalog.technologies[technology]
		if owner.knows(technology):
			status = "Known"
			progress = work
		if technology in sim.unlocked_technologies: status += " (Debug public override)"
		var prerequisites: PackedStringArray = []
		for prerequisite: String in definition.prerequisites: prerequisites.append(prerequisite.replace("_", " ") + (" (known)" if owner.knows(prerequisite) else " (unknown)"))
		research_info.text = "TECHNOLOGY PROJECT\n%s | Public year %d\n%s\nPrerequisites: %s\nProgress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead)\nRemaining: %d funded operating days\nAssigned facility: %s" % [technology.replace("_", " "), definition.year, status, ", ".join(prerequisites) if not prerequisites.is_empty() else "None", progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), assigned]
	elif project.kind == "product_quality":
		var product_id: String = str(project.product)
		var current: int = owner.product_quality_level(product_id)
		research_info.text = "PRODUCT QUALITY PROJECT\nProduct: %s\nCurrent level: %d | Target level: %d | Maximum: %d\n%s\nRetained progress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead)\nRemaining: %d funded operating days\nAssigned facility: %s" % [_product_name(product_id), current, int(project.target_level), sim.catalog.quality_max_level(), status, progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), assigned]
	else:
		var product_id: String = str(project.product)
		var current: int = owner.process_efficiency_level(product_id)
		var reduction: int = sim.catalog.conversion_cost_reduction(int(project.target_level))
		research_info.text = "PROCESS EFFICIENCY PROJECT\nProduct: %s\nCurrent level: %d | Target level: %d | Maximum: %d\n%s\nRetained progress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead) | Remaining: %d funded days\nTarget reduction: %d%%\nBase conversion cost: %s | Target effective cost: %s\nAssigned facility: %s" % [_product_name(product_id), current, int(project.target_level), sim.catalog.efficiency_max_level(), status, progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), reduction, CompanyReports.money(int(sim.catalog.products[product_id].conversion_cost)), CompanyReports.money(sim.conversion_cost_at_level(product_id, int(project.target_level))), assigned]
	research_info.text += "\nStopping retains progress; spending is not refunded."
	if not f.research_project.is_empty() and sim.project_equal(f.research_project, project) and (not f.operating or not f.active or owner.cash < sim.project_cost(project) + int(sim.catalog.facility_types[f.type_id].overhead)): research_info.text += "\nStalled: suspended or insufficient operating funds."
	assign_research.disabled = not own or not error.is_empty() or (not f.research_project.is_empty() and sim.project_equal(f.research_project, project))
	stop_research.disabled = not own or f.research_project.is_empty()
