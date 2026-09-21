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

func _ready() -> void:
	custom_minimum_size.x = 410
	var scroll: ScrollContainer = ScrollContainer.new()
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(400, 620)
	column.add_child(tabs)
	var operations: VBoxContainer = VBoxContainer.new()
	operations.name = "Products"
	tabs.add_child(operations)
	var sourcing: VBoxContainer = VBoxContainer.new()
	sourcing.name = "Sourcing"
	tabs.add_child(sourcing)
	var transport: VBoxContainer = VBoxContainer.new()
	transport.name = "Logistics"
	tabs.add_child(transport)
	info = RichTextLabel.new()
	info.custom_minimum_size = Vector2(390, 255)
	operations.add_child(info)
	info.custom_minimum_size.y = 190
	staff_info = RichTextLabel.new()
	staff_info.custom_minimum_size = Vector2(390, 340)
	operations.add_child(staff_info)
	staff_role = OptionButton.new()
	operations.add_child(staff_role)
	staff_role.item_selected.connect(func(_index: int) -> void: refresh())
	var staff_row: HBoxContainer = HBoxContainer.new()
	operations.add_child(staff_row)
	hire_staff = _button(staff_row, "Hire 1", func() -> void:
		if staff_role.selected >= 0: command_requested.emit({"type": "hire_staff", "facility": selected_id, "role": str(staff_role.get_item_metadata(staff_role.selected)), "quantity": 1}))
	dismiss_staff = _button(staff_row, "Dismiss 1", func() -> void:
		if staff_role.selected >= 0: command_requested.emit({"type": "dismiss_staff", "facility": selected_id, "role": str(staff_role.get_item_metadata(staff_role.selected)), "quantity": 1}))
	choices = OptionButton.new()
	operations.add_child(choices)
	configure = _button(operations, "Add product line / set production", func() -> void:
		if choices.selected >= 0:
			var f: SimFacility = session.sim.facility(selected_id)
			command_requested.emit({"type": "add_line" if session.sim._behavior(f) == "retail" else "set_production", "facility": selected_id, "product": choices.get_item_text(choices.selected)}))
	research_choices = OptionButton.new()
	operations.add_child(research_choices)
	research_choices.item_selected.connect(func(_index: int) -> void: refresh())
	research_info = RichTextLabel.new()
	research_info.custom_minimum_size = Vector2(390, 225)
	operations.add_child(research_info)
	assign_research = _button(operations, "Assign / resume research", func() -> void:
		if research_choices.selected >= 0:
			var project: Dictionary = research_choices.get_item_metadata(research_choices.selected)
			if not project.is_empty(): command_requested.emit({"type": "assign_research", "facility": selected_id, "project": project}))
	stop_research = _button(operations, "Stop research (retain progress)", func() -> void: command_requested.emit({"type": "stop_research", "facility": selected_id}))
	line = OptionButton.new()
	operations.add_child(line)
	line.item_selected.connect(func(_index: int) -> void:
		price.value = session.sim.facility(selected_id).line_price(line.get_item_text(line.selected)) / 100.0
		refresh())
	line_info = Label.new()
	line_info.add_theme_font_size_override("font_size", 14)
	operations.add_child(line_info)
	remove_line = _button(operations, "Remove selected line (stock retained)", func() -> void:
		if line.selected >= 0: command_requested.emit({"type": "remove_line", "facility": selected_id, "product": line.get_item_text(line.selected)}))
	logistics_info = RichTextLabel.new()
	logistics_info.custom_minimum_size = Vector2(390, 170)
	logistics_info.add_theme_font_size_override("normal_font_size", 14)
	transport.add_child(logistics_info)
	transfer_product = OptionButton.new()
	transport.add_child(transfer_product)
	transfer_destination = OptionButton.new()
	transport.add_child(transfer_destination)
	var transfer_row: HBoxContainer = HBoxContainer.new()
	transport.add_child(transfer_row)
	transfer_quantity = SpinBox.new()
	transfer_quantity.min_value = 0
	transfer_quantity.max_value = 100000
	transfer_quantity.value = 10
	transfer_row.add_child(transfer_quantity)
	transfer_button = _button(transfer_row, "Send transfer", func() -> void:
		if transfer_destination.selected >= 0 and transfer_product.selected >= 0:
			command_requested.emit({"type": "transfer", "facility": selected_id, "product": transfer_product.get_item_text(transfer_product.selected), "destination": str(transfer_destination.get_item_metadata(transfer_destination.selected)), "quantity": int(transfer_quantity.value)}))
	warehouse_target = _button(transport, "Set warehouse replenishment target (0 = off)", func() -> void:
		if transfer_product.selected >= 0: command_requested.emit({"type": "set_warehouse_target", "facility": selected_id, "product": transfer_product.get_item_text(transfer_product.selected), "quantity": int(transfer_quantity.value)}))
	var price_row: HBoxContainer = HBoxContainer.new()
	operations.add_child(price_row)
	price = SpinBox.new()
	price.min_value = 0.01
	price.max_value = 1000000
	price.step = 0.01
	price.prefix = "$"
	price.custom_minimum_size.x = 170
	price_row.add_child(price)
	apply_price = _button(price_row, "Queue price", func() -> void: command_requested.emit({"type": "set_price", "facility": selected_id, "product": line.get_item_text(line.selected) if line.selected >= 0 else session.sim.facility(selected_id).product_id, "price": int(round(price.value * 100.0))}))
	operating = _button(operations, "Suspend operation", func() -> void:
		var f: SimFacility = session.sim.facility(selected_id)
		command_requested.emit({"type": "set_operating", "facility": selected_id, "operating": not f.operating}))
	demolish = _button(operations, "Demolish facility…", func() -> void: demolition_requested.emit())
	var stock_row: HBoxContainer = HBoxContainer.new()
	operations.add_child(stock_row)
	stock = SpinBox.new()
	stock.min_value = 1
	stock.max_value = 7
	stock.suffix = "days"
	stock_row.add_child(stock)
	apply_stock = _button(stock_row, "Queue stock target", func() -> void: command_requested.emit({"type": "set_stock_days", "facility": selected_id, "days": int(stock.value)}))
	var label: Label = Label.new()
	label.text = "SOURCING / WHOLESALE OFFERS"
	sourcing.add_child(label)
	product = OptionButton.new()
	sourcing.add_child(product)
	product.item_selected.connect(func(_index: int) -> void: _populate_suppliers())
	suppliers = OptionButton.new()
	sourcing.add_child(suppliers)
	apply_supplier = _button(sourcing, "Queue supplier selection", func() -> void:
		if product.selected >= 0 and suppliers.selected >= 0:
			command_requested.emit({"type": "set_supplier", "facility": selected_id, "product": product.get_item_text(product.selected), "supplier": str(suppliers.get_item_metadata(suppliers.selected))}))
	sourcing_info = RichTextLabel.new()
	sourcing_info.custom_minimum_size = Vector2(390, 220)
	sourcing.add_child(sourcing_info)

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func bind(game_session: GameSession, id: String) -> void:
	session = game_session
	selected_id = id
	var f: SimFacility = session.sim.facility(id)
	layout_key = _layout_key(f)
	var selected_staff_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
	staff_role.clear()
	var role_ids: Array = session.sim.catalog.staff_roles.keys()
	role_ids.sort()
	for role_id: String in role_ids:
		staff_role.add_item(str(session.sim.catalog.staff_roles[role_id].name))
		staff_role.set_item_metadata(staff_role.item_count - 1, role_id)
		if role_id == selected_staff_role: staff_role.select(staff_role.item_count - 1)
	var selected_project: Dictionary = research_choices.get_item_metadata(research_choices.selected) if research_choices.selected >= 0 and research_choices.get_item_metadata(research_choices.selected) is Dictionary else {}
	research_choices.clear()
	research_choices.add_item("TECHNOLOGY PROJECTS")
	research_choices.set_item_disabled(0, true)
	research_choices.set_item_metadata(0, {})
	var tech_ids: Array = session.sim.catalog.technologies.keys()
	tech_ids.sort()
	for technology: String in tech_ids:
		var project: Dictionary = session.sim.technology_project(technology)
		research_choices.add_item("Technology — " + technology.replace("_", " "))
		research_choices.set_item_metadata(research_choices.item_count - 1, project)
		if session.sim.project_equal(project, selected_project): research_choices.select(research_choices.item_count - 1)
	research_choices.add_item("PRODUCT QUALITY PROJECTS")
	research_choices.set_item_disabled(research_choices.item_count - 1, true)
	research_choices.set_item_metadata(research_choices.item_count - 1, {})
	var product_ids: Array = session.sim.catalog.products.keys()
	product_ids.sort()
	for product_id: String in product_ids:
		if not session.sim.catalog.manufacturable_product(product_id): continue
		var project: Dictionary = session.sim.product_quality_project(f.company_id, product_id)
		research_choices.add_item("Product quality — " + product_id.replace("_", " "))
		research_choices.set_item_metadata(research_choices.item_count - 1, project)
		if session.sim.project_equal(project, selected_project): research_choices.select(research_choices.item_count - 1)
	research_choices.add_item("PROCESS EFFICIENCY PROJECTS")
	research_choices.set_item_disabled(research_choices.item_count - 1, true)
	research_choices.set_item_metadata(research_choices.item_count - 1, {})
	for product_id: String in product_ids:
		if not session.sim.catalog.manufacturable_product(product_id): continue
		var project: Dictionary = session.sim.process_efficiency_project(f.company_id, product_id)
		research_choices.add_item("Process efficiency — " + product_id.replace("_", " "))
		research_choices.set_item_metadata(research_choices.item_count - 1, project)
		if session.sim.project_equal(project, selected_project): research_choices.select(research_choices.item_count - 1)
	if research_choices.selected <= 0 and research_choices.item_count > 1: research_choices.select(1)
	choices.clear()
	line.clear()
	for id_value: String in session.sim.catalog.facility_types[f.type_id].products:
		if session.sim.can_configure(f.company_id, f.type_id, id_value):
			choices.add_item(id_value)
			if id_value == f.product_id: choices.select(choices.item_count - 1)
	for id_value: String in f.line_ids():
		line.add_item(id_value)
		if id_value == f.product_id: line.select(line.item_count - 1)
	price.value = f.price / 100.0
	stock.value = f.stock_days
	transfer_product.clear()
	var ids: Array = session.sim.catalog.products.keys()
	ids.sort()
	for id_value: String in ids:
		if session.sim.product_public(id_value): transfer_product.add_item(id_value)
	transfer_destination.clear()
	for other: SimFacility in session.sim.facilities:
		if other.company_id == f.company_id and other != f and not session.sim.catalog.productless_behavior(session.sim._behavior(other)):
			transfer_destination.add_item("To: " + other.id + " / " + other.type_id)
			transfer_destination.set_item_metadata(transfer_destination.item_count - 1, other.id)
	product.clear()
	var inputs: Dictionary = session.sim.catalog.products.get(f.product_id, {}).get("inputs", {})
	if str(session.sim.catalog.facility_types[f.type_id].behavior) == "retail":
		for id_value: String in f.line_ids(): product.add_item(id_value)
	elif str(session.sim.catalog.facility_types[f.type_id].behavior) == "production":
		var input_ids: Array = inputs.keys()
		input_ids.sort()
		for input: String in input_ids:
			product.add_item(input)
	else:
		for id_value: String in ids: product.add_item(id_value)
	_populate_suppliers()
	refresh()

func _populate_suppliers() -> void:
	suppliers.clear()
	suppliers.add_item("Automatic: landed cost / quality + lead time")
	suppliers.set_item_metadata(0, "")
	if product.selected < 0:
		return
	var id: String = product.get_item_text(product.selected)
	var f: SimFacility = session.sim.facility(selected_id)
	for offer: Dictionary in session.sim.supplier_offers(selected_id, id):
		suppliers.add_item(str(offer.id))
		suppliers.set_item_metadata(suppliers.item_count - 1, str(offer.id))
		if str(f.suppliers.get(id, "")) == str(offer.id):
			suppliers.select(suppliers.item_count - 1)

func refresh() -> void:
	if session == null or selected_id.is_empty():
		return
	var f: SimFacility = session.sim.facility(selected_id)
	if f == null:
		return
	if layout_key != _layout_key(f):
		bind(session, selected_id)
		return
	var owner: SimCompany = session.sim.companies[f.company_id]
	var definition: Dictionary = session.sim.catalog.products.get(f.product_id, {"name": "Research", "inputs": {}})
	var lines: PackedStringArray = [f.id + " / " + owner.display_name,
		str(definition.name) + " | " + f.type_id,
		("Available" if session.sim.can_configure(f.company_id, f.type_id, f.product_id) else ("RESEARCH REQUIRED" if session.sim.product_public(f.product_id) else "ERA LOCKED")) + " | " + ("Operating" if f.operating else "Suspended"),
		"Price $%.2f | Process Q%d | Capacity %d/day" % [f.price / 100.0, f.quality, f.capacity],
		"Today: made %d | consumer sales %d" % [f.produced_today, f.sold_today], "Inventory (units / book value):"]
	for id: String in f.inventory.quantities:
		lines.append("  %s: %d / $%.2f / %s" % [id, f.inventory.quantity(id), f.inventory.value(id) / 100.0, f.inventory.quality_text(id)])
	if session.sim.catalog.facility_types[f.type_id].behavior == "production":
		var production_capacity: int = session.sim.effective_capacity(f)
		if production_capacity != f.capacity: lines[3] = "Price $%.2f | Process Q%d | Capacity %d base / %d effective per day" % [f.price / 100.0, f.quality, f.capacity, production_capacity]
		var quality_level: int = owner.product_quality_level(f.product_id)
		lines.insert(4, "Product quality R&D L%d/%d | Effective process Q%d" % [quality_level, session.sim.catalog.quality_max_level(), clampi(f.quality + session.sim.catalog.quality_bonus(quality_level), 1, 100)])
		var efficiency_level: int = owner.process_efficiency_level(f.product_id)
		lines.insert(5, "Process efficiency R&D: L%d/%d" % [efficiency_level, session.sim.catalog.efficiency_max_level()])
		lines.insert(6, "Base conversion cost: %s | Effective: %s" % [CompanyReports.money(int(definition.conversion_cost)), CompanyReports.money(session.sim.effective_conversion_cost(owner.id, f.product_id))])
		lines.append("Recipe inputs: " + str(definition.inputs))
	elif session.sim.catalog.facility_types[f.type_id].behavior == "storage":
		lines[3] = "Storage: %d / %d units | free %d (after reservations)" % [session.sim.logistics.used(f), f.capacity, session.sim.logistics.free_capacity(session.sim, f)]
		lines.append("Replenishment targets: " + str(f.replenishment_targets))
	var weekly: int = 0
	if session.sim._behavior(f) == "retail":
		lines[1] = str(session.sim.catalog.facility_types[f.type_id].name) + " • %d product lines" % f.assortment.size()
		var retail_capacity: int = session.sim.effective_capacity(f)
		lines[3] = "Goods quality per product | Checkout %d/day" % f.capacity if retail_capacity == f.capacity else "Goods quality per product | Checkout %d base / %d effective per day" % [f.capacity, retail_capacity]
	var displayed_base_overhead: int = int(session.sim.catalog.facility_types[f.type_id].overhead)
	var displayed_effective_overhead: int = session.sim.effective_overhead(f)
	if displayed_base_overhead != displayed_effective_overhead: lines.append("Daily overhead: %s base | %s effective" % [CompanyReports.money(displayed_base_overhead), CompanyReports.money(displayed_effective_overhead)])
	for sale: Dictionary in f.recent_sales: weekly += int(sale.units)
	lines.append("Recent 7 days: %d consumer units" % weekly)
	lines.append("Owner daily revenue $%.2f / costs $%.2f / profit $%.2f" % [owner.daily_revenue / 100.0, (owner.daily_cogs + owner.daily_expenses) / 100.0, (owner.daily_revenue - owner.daily_cogs - owner.daily_expenses) / 100.0])
	info.text = "\n".join(lines)
	var own: bool = f.company_id == session.player_company
	configure.disabled = not own
	configure.text = "Add product line" if session.sim._behavior(f) == "retail" else "Change production (keep stock)"
	info.custom_minimum_size.y = 310 if session.sim._behavior(f) == "production" else (250 if session.sim._behavior(f) == "retail" else 190)
	remove_line.disabled = not own or f.assortment.size() <= 1
	configure.visible = session.sim._behavior(f) != "storage"
	choices.visible = configure.visible
	remove_line.visible = session.sim._behavior(f) == "retail"
	line.visible = remove_line.visible
	line_info.visible = remove_line.visible
	if line.selected >= 0:
		var selected: String = line.get_item_text(line.selected)
		var sales: Dictionary = f.line_sales.get(selected, {})
		var recent: int = 0
		for record: Dictionary in f.product_history: recent += int(record.products.get(selected, {}).get("units", 0))
		var unit_cost: int = f.inventory.value(selected) / maxi(1, f.inventory.quantity(selected))
		var cost_label: String = "Unit book cost"
		if f.inventory.quantity(selected) == 0:
			unit_cost = int(sales.get("cogs", 0)) / maxi(1, int(sales.get("units", 0)))
			cost_label = "Avg. sold cost"
		line_info.text = f.inventory.quality_text(selected) + " | Lines %d / %d • %s\nStock %d • Incoming %d • Supplier %s\n7 days: %d sold • %s %s\nLifetime gross margin %s" % [f.assortment.size(), session.sim.catalog.facility_types[f.type_id].get("slots", 1), selected, f.inventory.quantity(selected), session.sim.logistics.incoming(f.id, selected), str(f.suppliers.get(selected, "Automatic")), recent, cost_label, CompanyReports.money(unit_cost), CompanyReports.money(int(sales.get("revenue", 0)) - int(sales.get("cogs", 0)))]
	transfer_button.disabled = not own or transfer_destination.item_count == 0
	warehouse_target.visible = session.sim._behavior(f) == "storage"
	warehouse_target.disabled = not own
	var shipment_lines: PackedStringArray = ["LOGISTICS • incoming %d units" % session.sim.logistics.incoming(f.id)]
	var records: Array[Dictionary] = session.sim.logistics.shipments.duplicate()
	records.reverse()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.status == "in_transit" and b.status != "in_transit")
	for shipment: Dictionary in records:
		if shipment.source == f.id or shipment.destination == f.id:
			shipment_lines.append("#%d %s %d %s • %s\n%s | ETA %dd | freight $%.2f" % [shipment.id, "IN" if shipment.destination == f.id else "OUT", shipment.quantity, shipment.product, shipment.status, shipment.source if shipment.destination == f.id else shipment.destination, maxi(0, int(shipment.arrival) - session.sim.clock.tick), shipment.transport_cost / 100.0])
	if transfer_destination.selected >= 0:
		var quote: Dictionary = session.sim.logistics.quote(session.sim, f.id, str(transfer_destination.get_item_metadata(transfer_destination.selected)), int(transfer_quantity.value))
		shipment_lines.insert(1, "Transfer quote: %d cells / %dd / $%.2f" % [quote.distance, quote.lead_days, quote.freight / 100.0])
	logistics_info.text = "\n".join(shipment_lines)
	demolish.disabled = not own
	var storage: bool = session.sim.catalog.facility_types[f.type_id].behavior == "storage"
	price.get_parent().visible = not storage
	stock.get_parent().visible = not storage
	apply_price.disabled = not own or storage
	apply_supplier.disabled = not own or product.item_count == 0
	apply_stock.disabled = not own or storage
	operating.disabled = not own
	operating.text = "Suspend operation" if f.operating else "Resume operation"
	var details: PackedStringArray = []
	if product.selected >= 0:
		var id: String = product.get_item_text(product.selected)
		var policy: String = str(f.suppliers.get(id, ""))
		details.append("Policy: " + ("Automatic" if policy.is_empty() else policy))
		for offer: Dictionary in session.sim.supplier_offers(selected_id, id):
			details.append("%s: $%.2f | Q%d | stock %d\n%d cells / %dd | freight $%.2f for %d\nLanded $%.2f/unit | score %.2f%s" % [offer.id, offer.price / 100.0, offer.quality, offer.stock, offer.distance, offer.lead_days, offer.freight / 100.0, offer.quote_quantity, offer.landed / 100.0, offer.score, "" if offer.eligible else " (unavailable)"])
		for source: Dictionary in f.last_sources.get(id, []):
			details.append("Bought %d from %s today" % [source.units, source.supplier])
	var market: Dictionary = session.sim.market.get(f.product_id, {})
	if not market.is_empty():
		details.append("Market: %d sold / %d potential\nAverage price $%.2f | owner share %.1f%%" % [market.units, market.potential, market.average_price / 100.0, float(market.market_share.get(f.company_id, 0.0)) * 100.0])
	sourcing_info.text = "\n".join(details)
	var research: bool = session.sim._behavior(f) == "research"
	var headquarters: bool = session.sim._behavior(f) == "headquarters"
	for control: Control in [research_choices, research_info, assign_research, stop_research]: control.visible = research
	for control: Control in [staff_info, staff_role, hire_staff, dismiss_staff]: control.visible = headquarters
	tabs.set_tab_title(0, "R&D" if research else ("Headquarters" if headquarters else "Products"))
	tabs.set_tab_hidden(1, research or headquarters)
	tabs.set_tab_hidden(2, research or headquarters)
	if research:
		tabs.current_tab = 0
		for control: Control in [choices, configure, line, line_info, remove_line, price.get_parent(), stock.get_parent()]: control.hide()
		info.custom_minimum_size.y = 155
		var base_rate: int = int(session.sim.catalog.facility_types[f.type_id].research_rate)
		var effective_rate: int = session.sim.effective_research_rate(f)
		var rate_text: String = "%d points/day" % base_rate if base_rate == effective_rate else "%d base / %d effective points/day" % [base_rate, effective_rate]
		var research_base_overhead: int = int(session.sim.catalog.facility_types[f.type_id].overhead)
		var research_effective_overhead: int = session.sim.effective_overhead(f)
		var research_overhead_text: String = CompanyReports.money(research_base_overhead) if research_base_overhead == research_effective_overhead else "%s base / %s effective" % [CompanyReports.money(research_base_overhead), CompanyReports.money(research_effective_overhead)]
		info.text = "%s / %s\nR&D center | %s\nRate %s | Overhead %s/day\nAssigned: %s\nCompany knowledge: %d / %d technologies" % [f.id, owner.display_name, "Operating" if f.operating else "Suspended", rate_text, research_overhead_text, session.sim.project_name(f.research_project) if not f.research_project.is_empty() else "None", owner.known_technologies.size(), session.sim.catalog.technologies.size()]
		_refresh_research(f, own)
	elif headquarters:
		tabs.current_tab = 0
		for control: Control in [choices, configure, line, line_info, remove_line, price.get_parent(), stock.get_parent()]: control.hide()
		info.custom_minimum_size.y = 175
		var facility_definition: Dictionary = session.sim.catalog.facility_types[f.type_id]
		var book_value: int = f.asset_cost - f.accumulated_depreciation
		var hq_base_overhead: int = int(facility_definition.overhead)
		var hq_effective_overhead: int = session.sim.effective_overhead(f)
		var hq_overhead_text: String = CompanyReports.money(hq_base_overhead) if hq_base_overhead == hq_effective_overhead else "%s base / %s effective" % [CompanyReports.money(hq_base_overhead), CompanyReports.money(hq_effective_overhead)]
		info.text = "Corporate headquarters\n%s\n%s\nDaily overhead: %s\nConstruction / fixed-asset cost: %s\nAccumulated depreciation: %s\nNet book value: %s" % [owner.display_name, "Operating" if f.operating else "Suspended", hq_overhead_text, CompanyReports.money(f.asset_cost), CompanyReports.money(f.accumulated_depreciation), CompanyReports.money(book_value)]
		var active: bool = session.sim.staff_effects_active(owner.id)
		var effect_state: String = "ACTIVE" if active else "INACTIVE"
		if not active:
			if not f.operating: effect_state += " — headquarters suspended"
			elif session.sim.total_staff(owner.id) == 0: effect_state += " — no staff"
			else: effect_state += " — payroll not funded"
		var staff_lines: PackedStringArray = ["STAFFING", "Total staff: %d / %d" % [session.sim.total_staff(owner.id), session.sim.staff_capacity(owner.id)], "Configured daily payroll: %s/day" % CompanyReports.money(session.sim.daily_payroll(owner.id)), "Management effects: " + effect_state, ""]
		var role_ids: Array = session.sim.catalog.staff_roles.keys()
		role_ids.sort()
		for role_id: String in role_ids:
			var role: Dictionary = session.sim.catalog.staff_roles[role_id]
			var configured: int = mini(session.sim.staff_count(owner.id, role_id) * int(role.effect_per_staff), int(role.effect_cap_percent))
			var description: String = {
				"operations_capacity_percent": "production/retail capacity",
				"advertising_progress_percent": "advertising progress",
				"research_rate_percent": "research rate",
				"facility_overhead_reduction_percent": "facility overhead",
			}.get(str(role.effect), str(role.effect))
			var sign: String = "-" if role.effect == "facility_overhead_reduction_percent" else "+"
			staff_lines.append("%s: %d | %s%d%% each | %s%d%% %s | %s/day" % [role.name, session.sim.staff_count(owner.id, role_id), sign, int(role.effect_per_staff), sign, configured, description, CompanyReports.money(int(role.daily_salary))])
		staff_info.text = "\n".join(staff_lines)
		var selected_role: String = str(staff_role.get_item_metadata(staff_role.selected)) if staff_role.selected >= 0 else ""
		staff_role.disabled = not own
		hire_staff.disabled = not own or not f.operating or session.sim.total_staff(owner.id) >= session.sim.staff_capacity(owner.id)
		dismiss_staff.disabled = not own or selected_role.is_empty() or session.sim.staff_count(owner.id, selected_role) <= 0
		demolish.disabled = not own or session.sim.total_staff(owner.id) > 0

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
		var known: bool = owner.knows(technology)
		if known:
			status = "Known"
			progress = work
		if technology in sim.unlocked_technologies: status += " (Debug public override)"
		var prerequisites: PackedStringArray = []
		for prerequisite: String in definition.prerequisites:
			prerequisites.append(prerequisite.replace("_", " ") + (" (known)" if owner.knows(prerequisite) else " (unknown)"))
		research_info.text = "TECHNOLOGY PROJECT\n%s | Public year %d\n%s\nPrerequisites: %s\nProgress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead)\nRemaining: %d funded operating days\nAssigned facility: %s" % [technology.replace("_", " "), definition.year, status, ", ".join(prerequisites) if not prerequisites.is_empty() else "None", progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), assigned]
	elif project.kind == "product_quality":
		var product: String = str(project.product)
		var current: int = owner.product_quality_level(product)
		research_info.text = "PRODUCT QUALITY PROJECT\nProduct: %s\nCurrent level: %d | Target level: %d | Maximum: %d\n%s\nRetained progress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead)\nRemaining: %d funded operating days\nAssigned facility: %s" % [product.replace("_", " "), current, int(project.target_level), sim.catalog.quality_max_level(), status, progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), assigned]
	else:
		var product: String = str(project.product)
		var current: int = owner.process_efficiency_level(product)
		var base_cost: int = int(sim.catalog.products[product].conversion_cost)
		var reduction: int = sim.catalog.conversion_cost_reduction(int(project.target_level))
		research_info.text = "PROCESS EFFICIENCY PROJECT\nProduct: %s\nCurrent level: %d | Target level: %d | Maximum: %d\n%s\nRetained progress: %d / %d points (%.1f%%)\nProject expense: %s/day (+ overhead) | Remaining: %d funded days\nTarget reduction: %d%%\nBase conversion cost: %s | Target effective cost: %s\nAssigned facility: %s" % [product.replace("_", " "), current, int(project.target_level), sim.catalog.efficiency_max_level(), status, progress, work, progress * 100.0 / work, CompanyReports.money(sim.project_cost(project)), maxi(0, eta), reduction, CompanyReports.money(base_cost), CompanyReports.money(sim.conversion_cost_at_level(product, int(project.target_level))), assigned]
	research_info.text += "\nStopping retains progress; spending is not refunded."
	if not f.research_project.is_empty() and sim.project_equal(f.research_project, project) and (not f.operating or not f.active or owner.cash < sim.project_cost(project) + int(sim.catalog.facility_types[f.type_id].overhead)):
		research_info.text += "\nStalled: suspended or insufficient operating funds."
	assign_research.disabled = not own or not error.is_empty() or (not f.research_project.is_empty() and sim.project_equal(f.research_project, project))
	stop_research.disabled = not own or f.research_project.is_empty()
