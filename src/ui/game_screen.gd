extends Control

const Session = preload("res://src/session/game_session.gd")
const City = preload("res://src/ui/city_view.gd")
const Inspector = preload("res://src/ui/facility_panel.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

class WorkspaceScroll:
	extends ScrollContainer
	func _get_minimum_size() -> Vector2:
		return Vector2(410, 0)

var session: GameSession = Session.new()
var city: CityView
var inspector: FacilityPanel
var city_viewport: SubViewport
var date_label: Label
var finance_label: Label
var cash_value: Label
var profit_value: Label
var sim_state_label: Label
var company_name_label: Label
var status: Label
var facility_list: OptionButton
var settings: AcceptDialog
var overview: AcceptDialog
var reports: CompanyReports
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
var city_settings: Dictionary = {}
var city_seed: SpinBox
var city_summary: Label
var city_diagnostics: Label
var minimap: CityMinimap

func _ready() -> void:
	theme = UITheme.build()
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = UITheme.BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_directory = argument.trim_prefix("--save-dir=")
	session.start(2022, 42, "sandbox", city_settings)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "ShellMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UITheme.SPACE_2)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "ShellColumn"
	margin.add_child(column)
	_build_top_shell(column)
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "MainWorkspace"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_build_context_bar(left)
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
	legend.text = "CONTROLS  Middle drag: pan  •  Wheel: zoom  •  Click: inspect  •  Esc: cancel / close\nOWNERSHIP  Teal: player  •  Blue: components  •  Tan: Orion  •  Purple: Nova  •  Coral: rival"
	legend.theme_type_variation = "MetaLabel"
	left.add_child(legend)
	inspector = Inspector.new()
	var inspector_scroll: ScrollContainer = WorkspaceScroll.new()
	inspector_scroll.name = "WorkspaceInspectorScroll"
	inspector_scroll.custom_minimum_size.x = 410
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(inspector_scroll)
	var management_host: VBoxContainer = VBoxContainer.new()
	management_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(management_host)
	management_host.add_child(inspector)
	# FacilityPanel owns its internal management scroll; give it the content height
	# while this shell-level scroll constrains the panel to the workspace viewport.
	inspector.custom_minimum_size.y = inspector.tabs.get_combined_minimum_size().y + UITheme.SPACE_3 * 2
	inspector.command_requested.connect(func(command: Dictionary) -> void:
		session.submit(command)
		refresh())
	_build_construction(management_host)
	_build_bottom_hud(column)
	minimap = CityMinimap.new()
	minimap.position = Vector2(22, 145)
	add_child(minimap)
	minimap.city = city
	minimap.map = session.sim.city
	_build_dialogs()
	select_facility(selected_id)
	inspector.hide()
	refresh()

func _build_top_shell(parent: VBoxContainer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TopApplicationBar"
	panel.theme_type_variation = "AppBarPanel"
	parent.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.custom_minimum_size.x = 190
	row.add_child(identity)
	var game_name: Label = Label.new()
	game_name.text = "ModernCapitalism"
	game_name.theme_type_variation = "MetaLabel"
	identity.add_child(game_name)
	company_name_label = Label.new()
	company_name_label.theme_type_variation = "SectionLabel"
	identity.add_child(company_name_label)
	for item: Array in [["Company", _show_company], ["Build", _show_construction]]:
		var navigation: Button = _button(row, str(item[0]), item[1])
		navigation.theme_type_variation = "NavigationButton"
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	slot = SpinBox.new()
	slot.min_value = 1
	slot.max_value = 3
	slot.prefix = "Slot "
	slot.custom_minimum_size.x = 88
	row.add_child(slot)
	_button(row, "Save", _save)
	_button(row, "Load", _load)
	_button(row, "Settings", _show_settings)

func _build_context_bar(parent: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "FacilityContextBar"
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = "FACILITY"
	label.theme_type_variation = "MetricLabel"
	label.custom_minimum_size.x = 70
	row.add_child(label)
	facility_list = OptionButton.new()
	facility_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(facility_list)
	facility_list.item_selected.connect(func(index: int) -> void: select_facility(str(facility_list.get_item_metadata(index))))
	_refresh_facility_list()

func _metric(parent: HBoxContainer, label_text: String) -> Label:
	var block: VBoxContainer = VBoxContainer.new()
	block.custom_minimum_size.x = 155
	parent.add_child(block)
	var label: Label = Label.new()
	label.text = label_text
	label.theme_type_variation = "MetricLabel"
	block.add_child(label)
	var value: Label = Label.new()
	value.theme_type_variation = "MetricValue"
	block.add_child(value)
	return value

func _build_bottom_hud(parent: VBoxContainer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BottomHudBar"
	panel.theme_type_variation = "HudPanel"
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	cash_value = _metric(row, "CASH")
	profit_value = _metric(row, "TTM PROFIT")
	profit_value.tooltip_text = "Trailing 12 calendar months, updated daily. Uses available history before 12 months."
	finance_label = profit_value
	profit_chart = ProfitChart.new()
	profit_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(profit_chart)
	var time_block: VBoxContainer = VBoxContainer.new()
	time_block.custom_minimum_size.x = 355
	row.add_child(time_block)
	var date_row: HBoxContainer = HBoxContainer.new()
	time_block.add_child(date_row)
	date_label = Label.new()
	date_label.theme_type_variation = "ValueLabel"
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_row.add_child(date_label)
	sim_state_label = Label.new()
	sim_state_label.theme_type_variation = "MetricLabel"
	date_row.add_child(sim_state_label)
	var controls: HBoxContainer = HBoxContainer.new()
	time_block.add_child(controls)
	for speed: int in GameTime.SPEEDS:
		var text_value: String = "Pause" if speed == 0 else ("Max" if speed == 16 else str(speed) + "x")
		var button: Button = _button(controls, text_value, func() -> void:
			session.time.set_speed(speed)
			refresh())
		button.toggle_mode = true
		button.tooltip_text = "Space" if speed == 0 else "Shortcut %d" % ([1, 2, 4, 16].find(speed) + 1)
		speed_buttons[speed] = button
	status = Label.new()
	status.theme_type_variation = "StatusLabel"
	status.clip_text = true
	column.add_child(status)

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
	if minimap != null:
		minimap.city = city
		minimap.map = session.sim.city
		minimap.queue_redraw()
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
	company_name_label.text = owner.display_name
	date_label.text = session.sim.clock.date_string()
	sim_state_label.text = "PAUSED" if session.time.speed == 0 else ("MAX" if session.time.speed == 16 else "%d×" % session.time.speed)
	cash_value.text = CompanyReports.money(owner.cash)
	var ttm_profit: int = owner.ttm_profit(session.sim.clock)
	profit_value.text = CompanyReports.money(ttm_profit)
	profit_value.theme_type_variation = "PositiveLabel" if ttm_profit > 0 else ("NegativeLabel" if ttm_profit < 0 else "MetricValue")
	profit_chart.update_history(owner.monthly_history)
	for speed: int in speed_buttons:
		speed_buttons[speed].button_pressed = session.time.speed == speed
	inspector.refresh()
	status.text = "%s | Pending commands: %d" % [session.message, session.sim.pending_commands.size()]
	if not city.build_type.is_empty():
		city.update_preview(city.preview_cell.x, city.preview_cell.y)
		status.text = "Construction: " + build_reason.text
	if overview.visible:
		_update_company()
	if minimap != null: minimap.queue_redraw()
	if city_summary != null:
		var p: Dictionary = session.sim.city.population
		city_summary.text = "City seed %s • Residents %d / %d • Purchasing power %d%%" % [session.sim.city.generation.seed, p.total, p.capacity, p.purchasing_power]
	if city_diagnostics != null and session.debug_unlocked:
		var plot: Dictionary = session.sim.city.plots.get(selected_id, {})
		var point: Vector2i = city.preview_cell if not city.build_type.is_empty() else Vector2i(int(plot.get("x", 0)), int(plot.get("y", 0)))
		var p: Dictionary = session.sim.city.parcel_info(point.x, point.y)
		city_diagnostics.text = "Cell %s • %s\nLand $%.0f/cell • Waterfront %s • Port eligible %s\nAmbient properties %d • Roads %d" % [point, p.get("district", "fixture"), p.get("land_value", 0) / 100.0, p.get("waterfront", false), p.get("port_eligible", false), session.sim.city.ambient.size(), session.sim.city.roads.size()]
		city_diagnostics.text += "\nSegments: " + str(ConsumerMarket.populations(session.sim)) + "\nAccounting difference: " + str(int(FinancialReports.balance(session.sim, session.player_company).assets) - int(FinancialReports.balance(session.sim, session.player_company).equity))

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
	reports = CompanyReports.new()
	overview.add_child(reports)
	reports.session = session
	reports.command_requested.connect(func(command: Dictionary) -> void:
		session.submit(command)
		refresh())
	settings = AcceptDialog.new()
	settings.title = "Session settings"
	add_child(settings)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 250)
	settings.add_child(column)
	var help: Label = Label.new()
	help.text = "1 second/day at 1x; Max = 16x. Space pauses.\nNew sessions discard unsaved progress. Save using the HUD."
	column.add_child(help)
	city_summary = Label.new()
	column.add_child(city_summary)
	var seed_row: HBoxContainer = HBoxContainer.new()
	column.add_child(seed_row)
	city_seed = SpinBox.new()
	city_seed.min_value = 0
	city_seed.max_value = 2147483647
	city_seed.value = 42
	city_seed.prefix = "City seed"
	city_seed.custom_minimum_size.x = 260
	seed_row.add_child(city_seed)
	_button(seed_row, "Random seed", func() -> void:
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.randomize()
		city_seed.value = random.randi_range(0, 2147483647))
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
	_button(debug_panel, "Make all technologies public (no knowledge grant)", func() -> void: _debug("unlock"))
	city_diagnostics = Label.new()
	debug_panel.add_child(city_diagnostics)
	_button(debug_panel, "Toggle vacant frontage overlay", func() -> void: city.parcel_overlay.visible = not city.parcel_overlay.visible)
	debug_panel.hide()

func _new_session(era: int) -> void:
	city_seed.apply()
	if not session.start(era, int(city_seed.value), "sandbox", city_settings): return
	_build_city()
	city.cancel_placement()
	select_facility("20_player")
	debug_entry.clear()
	debug_panel.hide()
	settings.hide()
	refresh()

func _show_settings() -> void:
	session.time.set_speed(0)
	city_seed.value = int(session.sim.city.generation.seed)
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
	overview.popup_centered(Vector2i(800, 650))

func _update_company() -> void:
	reports.refresh()

func world_input_blocked() -> bool:
	return GameInputPolicy.blocked(get_viewport(), [settings, overview, demolition])

func _refresh_facility_list() -> void:
	facility_list.clear()
	for f: SimFacility in session.sim.facilities:
		var definition: Dictionary = session.sim.catalog.facility_types.get(f.type_id, {})
		var type_name: String = str(definition.get("name", f.type_id))
		facility_list.add_item("%s • %s • %s" % [f.id, type_name, session.sim.companies[f.company_id].display_name])
		facility_list.set_item_metadata(facility_list.item_count - 1, f.id)

func _build_construction(parent: Node) -> void:
	construction = VBoxContainer.new()
	construction.custom_minimum_size.x = 410
	parent.add_child(construction)
	var title: Label = Label.new()
	title.text = "CONSTRUCTION / METRO CITY"
	title.theme_type_variation = "TitleLabel"
	construction.add_child(title)
	build_choices = OptionButton.new()
	construction.add_child(build_choices)
	for category: String in ["Retail", "Industrial", "Corporate"]:
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
	var cancel: Button = _button(construction, "Cancel construction", func() -> void: city.cancel_placement())
	cancel.theme_type_variation = "DestructiveButton"
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
		if session.sim.can_configure(session.player_company, id, product):
			build_products.add_item(str(session.sim.catalog.products[product].name))
			build_products.set_item_metadata(build_products.item_count - 1, product)
	var productless: bool = session.sim.catalog.productless_behavior(str(definition.behavior))
	build_products.visible = not productless
	build_details.text = "$%.2f • %d × %d cells\nCapacity: %d/day • Overhead: $%.2f/day\n\n%s" % [definition.cost / 100.0, definition.width, definition.depth, definition.capacity, definition.overhead / 100.0, definition.description]
	if definition.behavior == "storage" or productless:
		build_details.text = "$%.2f • %d × %d cells\nOverhead: $%.2f/day\n\n%s" % [definition.cost / 100.0, definition.width, definition.depth, definition.overhead / 100.0, definition.description]
	_begin_preview()

func _begin_preview() -> void:
	var type_id: String = str(build_choices.get_item_metadata(build_choices.selected))
	if session.sim.catalog.productless_behavior(str(session.sim.catalog.facility_types[type_id].behavior)):
		city.begin_placement(type_id, "")
	elif build_products.selected >= 0:
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
