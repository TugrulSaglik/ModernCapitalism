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

func _ready() -> void:
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
	slot = SpinBox.new()
	slot.min_value = 1
	slot.max_value = 3
	slot.prefix = "Slot"
	toolbar.add_child(slot)
	_button(toolbar, "Save", _save)
	_button(toolbar, "Load", _load)
	_button(toolbar, "Settings", _show_settings)
	finance_label = Label.new()
	column.add_child(finance_label)
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
	city_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(city_viewport)
	_build_city()
	var legend: Label = Label.new()
	legend.text = "WASD/arrows: pan | Wheel: zoom | Click: inspect\nTeal: player • Blue: components • Tan: Orion • Purple: Nova • Coral: rival"
	legend.add_theme_font_size_override("font_size", 13)
	left.add_child(legend)
	inspector = Inspector.new()
	body.add_child(inspector)
	inspector.command_requested.connect(func(command: Dictionary) -> void:
		session.submit(command)
		refresh())
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.clip_text = true
	column.add_child(status)
	_build_dialogs()
	select_facility(selected_id)
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
	city.build(session.sim.snapshot())
	city.facility_selected.connect(select_facility)

func select_facility(id: String) -> void:
	selected_id = id
	city.select(id)
	inspector.bind(session, id)
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
	if settings.visible or overview.visible or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match event.keycode:
		KEY_SPACE: session.time.toggle_pause()
		KEY_1: session.time.set_speed(1)
		KEY_2: session.time.set_speed(2)
		KEY_3: session.time.set_speed(4)
		KEY_4: session.time.set_speed(16)
		_: return
	get_viewport().set_input_as_handled()
	refresh()

func refresh() -> void:
	var owner: SimCompany = session.sim.companies[session.player_company]
	date_label.text = "%s | %s" % [session.sim.clock.date_string(), "PAUSED" if session.time.speed == 0 else "%dx" % session.time.speed]
	finance_label.text = "%s | Cash $%.2f | Today's profit $%.2f | Total profit $%.2f" % [owner.display_name, owner.cash / 100.0, (owner.daily_revenue - owner.daily_cogs - owner.daily_expenses) / 100.0, owner.profit() / 100.0]
	for speed: int in speed_buttons:
		speed_buttons[speed].modulate = Color("ffe190") if session.time.speed == speed else Color.WHITE
	inspector.refresh()
	status.text = "%s | Pending commands: %d" % [session.message, session.sim.pending_commands.size()]
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
