extends Control

const Session = preload("res://src/session/game_session.gd")
const City = preload("res://src/ui/city_view.gd")
const Inspector = preload("res://src/ui/facility_panel.gd")
var session: GameSession = Session.new()
var city: CityView
var inspector: FacilityPanel
var city_viewport: SubViewport
var date_label: Label
var finance_label: Label
var status: Label
var facility_list: OptionButton
var settings: AcceptDialog
var overview: AcceptDialog
var overview_text: RichTextLabel
var debug_entry: LineEdit
var debug_panel: VBoxContainer
var debug_amount: SpinBox
var debug_days: SpinBox
var slot: SpinBox
var save_directory: String = "user://saves"
var speed_buttons: Dictionary = {}
var selected_id: String = "20_player"
var refresh_elapsed: float = 0.0
var construction: VBoxContainer
var build_choices: OptionButton
var build_products: OptionButton
var build_details: Label
var build_reason: Label
var demolition: ConfirmationDialog
var profit_chart: ProfitChart

func _ready() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("182833")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_directory = argument.trim_prefix("--save-dir=")
	session.start()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	var toolbar: HBoxContainer = HBoxContainer.new()
	column.add_child(toolbar)
	date_label = Label.new()
	date_label.custom_minimum_size.x = 235
	toolbar.add_child(date_label)
	for speed: int in GameTime.SPEEDS:
		var text_value: String = "Pause" if speed == 0 else ("Max" if speed == 16 else str(speed) + "x")
		var button: Button = _button(toolbar, text_value, func() -> void:
			session.time.set_speed(speed)
			refresh())
		speed_buttons[speed] = button
	_button(toolbar, "Company", _show_company)
	_button(toolbar, "Build", _show_construction)
	slot = SpinBox.new()
	slot.min_value = 1
	slot.max_value = 3
	slot.prefix = "Slot"
	toolbar.add_child(slot)
	_button(toolbar, "Save", _save)
	_button(toolbar, "Load", _load)
	_button(toolbar, "Settings", _show_settings)
	finance_label = Label.new()
	finance_label.tooltip_text = "Trailing 12 calendar months, updated daily. Uses available history before 12 months."
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	facility_list = OptionButton.new()
	left.add_child(facility_list)
	for f: SimFacility in session.sim.facilities:
		facility_list.add_item(f.id + " / " + str(session.sim.companies[f.company_id].display_name))
		facility_list.set_item_metadata(facility_list.item_count - 1, f.id)
	facility_list.item_selected.connect(func(index: int) -> void: select_facility(str(facility_list.get_item_metadata(index))))
	var container: SubViewportContainer = SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(container)
	city_viewport = SubViewport.new()
	city_viewport.size = Vector2i(800, 650)
	city_viewport.msaa_3d = Viewport.MSAA_4X
	city_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(city_viewport)
	_build_city()
	var legend: Label = Label.new()
	legend.text = "Middle drag: pan | Wheel: zoom | Click: inspect | Esc: cancel / close\nTeal: player • Blue: components • Tan: Orion • Purple: Nova • Coral: rival"
	legend.add_theme_font_size_override("font_size", 13)
	left.add_child(legend)
	inspector = Inspector.new()
	body.add_child(inspector)
	inspector.command_requested.connect(func(command: Dictionary) -> void:
		session.submit(command)
		refresh())
	_build_construction(body)
	var financial_bar: HBoxContainer = HBoxContainer.new()
	column.add_child(financial_bar)
	financial_bar.add_child(finance_label)
	finance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profit_chart = ProfitChart.new()
	financial_bar.add_child(profit_chart)
	toolbar.remove_child(date_label)
	financial_bar.add_child(date_label)
	for speed: int in speed_buttons:
		var button: Button = speed_buttons[speed]
		toolbar.remove_child(button)
		financial_bar.add_child(button)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.clip_text = true
	column.add_child(status)
	_build_dialogs()
	select_facility(selected_id)
	inspector.hide()
	refresh()

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _build_city() -> void:
	if city != null:
		city_viewport.remove_child(city)
		city.queue_free()
	city = City.new()
	city_viewport.add_child(city)
	city.session = session
	city.input_blocked = world_input_blocked
	city.build(session.sim.snapshot())
	city.facility_selected.connect(select_facility)
	city.placement_requested.connect(_place)
	city.placement_changed.connect(func(reason: String) -> void:
		if build_reason != null: build_reason.text = reason
		if status != null: status.text = "Construction: " + reason)
	city.placement_cancelled.connect(func() -> void:
		if construction != null:
			construction.hide()
			inspector.visible = session.sim.facility(selected_id) != null)
	_refresh_facility_list()

func select_facility(id: String) -> void:
	if session.sim.facility(id) == null:
		selected_id = ""
		inspector.selected_id = ""
		inspector.hide()
		city.select("")
		return
	selected_id = id
	city.select(id)
	inspector.bind(session, id)
	inspector.visible = construction == null or not construction.visible
	for index: int in range(facility_list.item_count):
		if facility_list.get_item_metadata(index) == id:
			facility_list.select(index)

func _process(delta: float) -> void:
	if session.sim == null:
		return
	var days: int = session.time.advance(delta, session.sim)
	refresh_elapsed += delta
	if days > 0 or refresh_elapsed >= 0.25:
		refresh_elapsed = 0.0
		refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if world_input_blocked():
		return
	match event.keycode:
		KEY_ESCAPE:
			if not city.build_type.is_empty(): city.cancel_placement()
			else: inspector.hide()
		KEY_SPACE: session.time.toggle_pause()
		KEY_1: session.time.set_speed(1)
		KEY_2: session.time.set_speed(2)
		KEY_3: session.time.set_speed(4)
		KEY_4: session.time.set_speed(16)
		_: return
	get_viewport().set_input_as_handled()
	refresh()

func refresh() -> void:
	if city.buildings.keys() != session.sim.city.plots.keys():
		city.sync(session.sim.snapshot())
		_refresh_facility_list()
		select_facility(selected_id)
	var owner: SimCompany = session.sim.companies[session.player_company]
	date_label.text = "%s | %s" % [session.sim.clock.date_string(), "PAUSED" if session.time.speed == 0 else "%dx" % session.time.speed]
	finance_label.text = "Cash  $%.2f\nTTM Profit  $%.2f" % [owner.cash / 100.0, owner.ttm_profit(session.sim.clock) / 100.0]
	profit_chart.update_history(owner.monthly_history)
	for speed: int in speed_buttons:
		speed_buttons[speed].modulate = Color("ffe190") if session.time.speed == speed else Color.WHITE
	inspector.refresh()
	status.text = "%s | Pending commands: %d" % [session.message, session.sim.pending_commands.size()]
	if not city.build_type.is_empty():
		city.update_preview(city.preview_cell.x, city.preview_cell.y)
		status.text = "Construction: " + build_reason.text
	if overview.visible:
		_update_company()

func slot_path() -> String:
	return save_directory.path_join("slot_%d.json" % int(slot.value))

func _save() -> void:
	session.save_game(slot_path())
	refresh()

func _load() -> void:
	if session.load_game(slot_path()):
		_build_city()
		city.cancel_placement()
		select_facility(selected_id)
		debug_panel.hide()
		debug_entry.clear()
	refresh()

func _build_dialogs() -> void:
	overview = AcceptDialog.new()
	overview.title = "Company overview"
	add_child(overview)
	overview_text = RichTextLabel.new()
	overview_text.custom_minimum_size = Vector2(680, 330)
	overview.add_child(overview_text)
	settings = AcceptDialog.new()
	settings.title = "Session settings"
	add_child(settings)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 250)
	settings.add_child(column)
	var help: Label = Label.new()
	help.text = "Sandbox session • seed 42\n1 second/day at 1x; Max = 16x. Space pauses.\nNew sessions discard unsaved progress. Save using the HUD."
	column.add_child(help)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	_button(row, "New sandbox 2012", func() -> void: _new_session(2012))
	_button(row, "New sandbox 2022", func() -> void: _new_session(2022))
	var debug_row: HBoxContainer = HBoxContainer.new()
	debug_row.name = "DebugRow"
	column.add_child(debug_row)
	var label: Label = Label.new()
	label.text = "Debug"
	debug_row.add_child(label)
	debug_entry = LineEdit.new()
	debug_entry.secret = true
	debug_entry.custom_minimum_size.x = 250
	debug_row.add_child(debug_entry)
	_button(debug_row, "Unlock", _unlock_debug)
	debug_panel = VBoxContainer.new()
	column.add_child(debug_panel)
	var cash_row: HBoxContainer = HBoxContainer.new()
	debug_panel.add_child(cash_row)
	debug_amount = SpinBox.new()
	debug_amount.min_value = 1
	debug_amount.max_value = 10000000
	debug_amount.value = 10000
	debug_amount.prefix = "$"
	cash_row.add_child(debug_amount)
	_button(cash_row, "Add cash", func() -> void: _debug("cash", int(debug_amount.value * 100)))
	_button(cash_row, "Subtract cash", func() -> void: _debug("cash", -int(debug_amount.value * 100)))
	var days_row: HBoxContainer = HBoxContainer.new()
	debug_panel.add_child(days_row)
	debug_days = SpinBox.new()
	debug_days.min_value = 1
	debug_days.max_value = 3650
	debug_days.value = 30
	days_row.add_child(debug_days)
	_button(days_row, "Advance days", func() -> void: _debug("advance", int(debug_days.value)))
	_button(debug_panel, "Unlock example technologies", func() -> void: _debug("unlock"))
	debug_panel.hide()

func _new_session(era: int) -> void:
	session.start(era)
	_build_city()
	city.cancel_placement()
	select_facility("20_player")
	debug_entry.clear()
	debug_panel.hide()
	settings.hide()
	refresh()

func _show_settings() -> void:
	session.time.set_speed(0)
	debug_entry.get_parent().visible = session.mode == "sandbox"
	debug_panel.visible = session.mode == "sandbox" and session.debug_unlocked
	settings.popup_centered()
	refresh()

func _unlock_debug() -> void:
	debug_panel.visible = session.unlock_debug(debug_entry.text)
	debug_entry.clear()
	refresh()

func _debug(action: String, amount: int = 0) -> void:
	session.debug_action(action, amount)
	refresh()

func _show_company() -> void:
	_update_company()
	overview.popup_centered()

func _update_company() -> void:
	var lines: PackedStringArray = []
	for owner: SimCompany in session.sim.companies.values():
		lines.append("%s\nCash $%.2f | Inventory assets $%.2f\nRevenue $%.2f | COGS $%.2f | Overhead $%.2f | Profit $%.2f\n" % [owner.display_name, owner.cash / 100.0, session.sim.inventory_assets(owner.id) / 100.0, owner.revenue / 100.0, owner.cogs / 100.0, owner.expenses / 100.0, owner.profit() / 100.0])
	overview_text.text = "\n".join(lines)
	var owner: SimCompany = session.sim.companies[session.player_company]
	overview_text.text += "\nPlayer freight $%.2f | In transit $%.2f | Fixed assets $%.2f | Depreciation $%.2f\nTTM profit $%.2f\nMonthly history: %s" % [owner.freight / 100.0, session.sim.logistics.assets(owner.id) / 100.0, session.sim.fixed_assets(owner.id) / 100.0, owner.depreciation / 100.0, owner.ttm_profit(session.sim.clock) / 100.0, str(owner.monthly_history)]

func world_input_blocked() -> bool:
	return GameInputPolicy.blocked(get_viewport(), [settings, overview, demolition])

func _refresh_facility_list() -> void:
	facility_list.clear()
	for f: SimFacility in session.sim.facilities:
		facility_list.add_item(f.id + " / " + str(session.sim.companies[f.company_id].display_name))
		facility_list.set_item_metadata(facility_list.item_count - 1, f.id)

func _build_construction(parent: Node) -> void:
	construction = VBoxContainer.new()
	construction.custom_minimum_size.x = 410
	parent.add_child(construction)
	var title: Label = Label.new()
	title.text = "CONSTRUCTION / METRO CITY"
	title.add_theme_font_size_override("font_size", 22)
	construction.add_child(title)
	build_choices = OptionButton.new()
	construction.add_child(build_choices)
	for category: String in ["Retail", "Industrial"]:
		build_choices.add_separator(category)
		for id: String in session.sim.catalog.facility_types:
			var definition: Dictionary = session.sim.catalog.facility_types[id]
			if definition.category == category:
				build_choices.add_item(str(definition.name))
				build_choices.set_item_metadata(build_choices.item_count - 1, id)
	build_choices.item_selected.connect(func(_index: int) -> void: _choose_build())
	build_products = OptionButton.new()
	construction.add_child(build_products)
	build_products.item_selected.connect(func(_index: int) -> void: _begin_preview())
	build_details = Label.new()
	build_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_details.custom_minimum_size = Vector2(400, 160)
	construction.add_child(build_details)
	build_reason = Label.new()
	build_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_reason.custom_minimum_size = Vector2(400, 100)
	construction.add_child(build_reason)
	var hint: Label = Label.new()
	hint.text = "Green: valid • Red: invalid\nClick land to build; right-click / Esc to cancel.\nCosts apply immediately, including while paused.\nEarlier queued management commands apply first."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	construction.add_child(hint)
	_button(construction, "Cancel construction", func() -> void: city.cancel_placement())
	construction.hide()
	demolition = ConfirmationDialog.new()
	demolition.title = "Demolish owned facility"
	demolition.dialog_text = "Remove the selected facility permanently?\nRemaining inventory is written off. No refund."
	add_child(demolition)
	demolition.confirmed.connect(func() -> void:
		session.submit({"type": "demolish_facility", "facility": selected_id})
		refresh())
	inspector.demolition_requested.connect(func() -> void: demolition.popup_centered())

func _show_construction() -> void:
	construction.show()
	inspector.hide()
	if build_choices.selected < 0 or build_choices.is_item_separator(build_choices.selected):
		build_choices.select(1)
	_choose_build()

func _choose_build() -> void:
	var id: String = str(build_choices.get_item_metadata(build_choices.selected))
	var definition: Dictionary = session.sim.catalog.facility_types[id]
	build_products.clear()
	for product: String in definition.products:
		if session.sim.available(product):
			build_products.add_item(str(session.sim.catalog.products[product].name))
			build_products.set_item_metadata(build_products.item_count - 1, product)
	build_details.text = "$%.2f • %d × %d cells\nCapacity: %d/day • Overhead: $%.2f/day\n\n%s" % [definition.cost / 100.0, definition.width, definition.depth, definition.capacity, definition.overhead / 100.0, definition.description]
	if definition.behavior == "storage":
		build_details.text = "$%.2f • %d × %d cells\nOverhead: $%.2f/day\n\n%s" % [definition.cost / 100.0, definition.width, definition.depth, definition.overhead / 100.0, definition.description]
	_begin_preview()

func _begin_preview() -> void:
	if build_products.selected >= 0:
		city.begin_placement(str(build_choices.get_item_metadata(build_choices.selected)), str(build_products.get_item_metadata(build_products.selected)))

func _place(x: int, y: int) -> void:
	var next_id: String = "built_%06d" % session.sim.city.next_facility
	var accepted: bool = session.submit({"type": "build_facility", "archetype": city.build_type, "product": city.build_product, "x": x, "y": y})
	if accepted:
		city.sync(session.sim.snapshot())
		_refresh_facility_list()
		city.cancel_placement()
		select_facility(next_id)
	else:
		build_reason.text = session.message
	refresh()
