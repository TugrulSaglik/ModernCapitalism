class_name FacilityPanel
extends PanelContainer

signal command_requested(command: Dictionary)
signal demolition_requested
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

func _ready() -> void:
	custom_minimum_size.x = 410
	var scroll: ScrollContainer = ScrollContainer.new()
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var tabs: TabContainer = TabContainer.new()
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
	choices = OptionButton.new()
	operations.add_child(choices)
	configure = _button(operations, "Add product line / set production", func() -> void:
		if choices.selected >= 0:
			var f: SimFacility = session.sim.facility(selected_id)
			command_requested.emit({"type": "add_line" if session.sim._behavior(f) == "retail" else "set_production", "facility": selected_id, "product": choices.get_item_text(choices.selected)}))
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
	layout_key = str(f.line_ids()) + f.product_id
	choices.clear()
	line.clear()
	for id_value: String in session.sim.catalog.facility_types[f.type_id].products:
		if session.sim.available(id_value):
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
		if session.sim.available(id_value): transfer_product.add_item(id_value)
	transfer_destination.clear()
	for other: SimFacility in session.sim.facilities:
		if other.company_id == f.company_id and other != f:
			transfer_destination.add_item("To: " + other.id + " / " + other.type_id)
			transfer_destination.set_item_metadata(transfer_destination.item_count - 1, other.id)
	product.clear()
	var inputs: Dictionary = session.sim.catalog.products[f.product_id].inputs
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
	if layout_key != str(f.line_ids()) + f.product_id:
		bind(session, selected_id)
		return
	var owner: SimCompany = session.sim.companies[f.company_id]
	var definition: Dictionary = session.sim.catalog.products[f.product_id]
	var lines: PackedStringArray = [f.id + " / " + owner.display_name,
		str(definition.name) + " | " + f.type_id,
		("Available" if session.sim.available(f.product_id) else "ERA LOCKED") + " | " + ("Operating" if f.operating else "Suspended"),
		"Price $%.2f | Quality %d | Capacity %d/day" % [f.price / 100.0, f.quality, f.capacity],
		"Today: made %d | consumer sales %d" % [f.produced_today, f.sold_today], "Inventory (units / book value):"]
	for id: String in f.inventory.quantities:
		lines.append("  %s: %d / $%.2f" % [id, f.inventory.quantity(id), f.inventory.value(id) / 100.0])
	if session.sim.catalog.facility_types[f.type_id].behavior == "production":
		lines.append("Recipe inputs: " + str(definition.inputs))
	elif session.sim.catalog.facility_types[f.type_id].behavior == "storage":
		lines[3] = "Storage: %d / %d units | free %d (after reservations)" % [session.sim.logistics.used(f), f.capacity, session.sim.logistics.free_capacity(session.sim, f)]
		lines.append("Replenishment targets: " + str(f.replenishment_targets))
	var weekly: int = 0
	if session.sim._behavior(f) == "retail":
		lines[1] = str(session.sim.catalog.facility_types[f.type_id].name) + " • %d product lines" % f.assortment.size()
		lines[3] = "Quality %d • Shared checkout capacity %d/day" % [f.quality, f.capacity]
	for sale: Dictionary in f.recent_sales: weekly += int(sale.units)
	lines.append("Recent 7 days: %d consumer units" % weekly)
	lines.append("Owner daily revenue $%.2f / costs $%.2f / profit $%.2f" % [owner.daily_revenue / 100.0, (owner.daily_cogs + owner.daily_expenses) / 100.0, (owner.daily_revenue - owner.daily_cogs - owner.daily_expenses) / 100.0])
	info.text = "\n".join(lines)
	var own: bool = f.company_id == session.player_company
	configure.disabled = not own
	configure.text = "Add product line" if session.sim._behavior(f) == "retail" else "Change production (keep stock)"
	info.custom_minimum_size.y = 310 if session.sim._behavior(f) == "production" else 190
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
		line_info.text = "Lines %d / %d • %s\nStock %d • Incoming %d • Supplier %s\n7 days: %d sold • %s %s\nLifetime gross margin %s" % [f.assortment.size(), session.sim.catalog.facility_types[f.type_id].get("slots", 1), selected, f.inventory.quantity(selected), session.sim.logistics.incoming(f.id, selected), str(f.suppliers.get(selected, "Automatic")), recent, cost_label, CompanyReports.money(unit_cost), CompanyReports.money(int(sales.get("revenue", 0)) - int(sales.get("cogs", 0)))]
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
