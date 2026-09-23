extends Control

const Session = preload("res://src/session/game_session.gd")
const City = preload("res://src/ui/city_view.gd")
const Inspector = preload("res://src/ui/facility_panel.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")
const Browser = preload("res://src/ui/save_browser.gd")
const Store = preload("res://src/session/save_store.gd")

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
var managed_company_selector: OptionButton
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
var app_menu: AcceptDialog
var save_browser: SaveBrowser
var overwrite_confirmation: ConfirmationDialog
var load_confirmation: ConfirmationDialog
var new_session_confirmation: ConfirmationDialog
var application_pause: bool = false
var pending_slot: int = 0
var pending_era: int = 0
var pending_difficulty: String = "standard"
var current_difficulty: Label
var new_sandbox_difficulty: OptionButton
var difficulty_description: Label
var status_override: String = ""
var status_kind: String = "normal"
var build_category: Label
var build_action: Button
var build_cancel: Button

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
	minimap.tooltip_text = "Click the minimap to move the city camera."
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
	managed_company_selector = OptionButton.new()
	managed_company_selector.name = "ManagedCompanySelector"
	managed_company_selector.tooltip_text = "Select a company controlled by your corporate group."
	identity.add_child(managed_company_selector)
	managed_company_selector.item_selected.connect(func(index: int) -> void:
		if session.select_company(str(managed_company_selector.get_item_metadata(index))):
			city.cancel_placement()
			if construction != null and construction.visible and build_choices.selected >= 0: _choose_build()
			refresh())
	for item: Array in [["Company", _show_company, "Open company reports and management."], ["Build", _show_construction, "Open construction and choose a facility."]]:
		var navigation: Button = _button(row, str(item[0]), item[1])
		navigation.theme_type_variation = "NavigationButton"
		navigation.tooltip_text = str(item[2])
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var menu_button: Button = _button(row, "Menu", _show_menu)
	menu_button.name = "MenuButton"
	menu_button.tooltip_text = "Pause simulation advancement and open Save, Load or Settings."

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
	facility_list.tooltip_text = "Select and focus a facility in the city."
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
			if application_pause: return
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
		_update_placement_feedback(reason))
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
		if facility_list != null and facility_list.item_count > 0: facility_list.select(0)
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
	var days: int = 0 if application_pause else session.time.advance(delta, session.sim)
	refresh_elapsed += delta
	if days > 0 or refresh_elapsed >= 0.25:
		refresh_elapsed = 0.0
		refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_handle_escape()
		get_viewport().set_input_as_handled()
		refresh()
		return
	if world_input_blocked() or application_pause: return
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
	session._refresh_active_company()
	if city.buildings.keys() != session.sim.city.plots.keys():
		city.sync(session.sim.snapshot())
		_refresh_facility_list()
		select_facility(selected_id)
	_refresh_managed_companies()
	var owner: SimCompany = session.sim.companies[session.active_company]
	company_name_label.text = owner.display_name
	date_label.text = session.sim.clock.date_string()
	sim_state_label.text = ("MENU • " if application_pause else "") + ("PAUSED" if session.time.speed == 0 else ("MAX" if session.time.speed == 16 else "%d×" % session.time.speed))
	cash_value.text = CompanyReports.money(owner.cash)
	var ttm_profit: int = owner.ttm_profit(session.sim.clock)
	profit_value.text = CompanyReports.money(ttm_profit)
	profit_value.theme_type_variation = "PositiveLabel" if ttm_profit > 0 else ("NegativeLabel" if ttm_profit < 0 else "MetricValue")
	profit_chart.update_history(owner.monthly_history)
	for speed: int in speed_buttons:
		speed_buttons[speed].button_pressed = session.time.speed == speed
	inspector.refresh()
	var message: String = status_override if not status_override.is_empty() else session.message
	status.text = "%s | Pending commands: %d" % [message, session.sim.pending_commands.size()]
	status.theme_type_variation = "NegativeLabel" if status_kind == "error" else ("PositiveLabel" if status_kind == "success" else "StatusLabel")
	if not city.build_type.is_empty():
		city.update_preview(city.preview_cell.x, city.preview_cell.y)
		status.text = "Construction: " + build_reason.text + " | Pending commands: %d" % session.sim.pending_commands.size()
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

func _refresh_managed_companies() -> void:
	var ids: Array[String] = session.controlled_companies()
	if managed_company_selector.item_count == ids.size():
		var same: bool = true
		for index: int in range(ids.size()):
			if str(managed_company_selector.get_item_metadata(index)) != ids[index]: same = false
		if same:
			for index: int in range(ids.size()):
				if ids[index] == session.active_company: managed_company_selector.select(index)
			return
	managed_company_selector.clear()
	for id: String in ids:
		managed_company_selector.add_item(session.sim.companies[id].display_name)
		managed_company_selector.set_item_metadata(managed_company_selector.item_count - 1, id)
		if id == session.active_company: managed_company_selector.select(managed_company_selector.item_count - 1)

func slot_path(slot_number: int = 1) -> String:
	return save_directory.path_join("slot_%d.json" % slot_number)

func _save(slot_number: int = 1) -> void:
	var success: bool = session.save_game(slot_path(slot_number))
	_set_status(("Saved Slot %d." if success else "Save failed: %s") % ([slot_number] if success else [session.message]), "success" if success else "error")
	if save_browser != null and save_browser.visible: _refresh_save_browser("save")
	refresh()

func _load(slot_number: int = 1) -> void:
	if session.load_game(slot_path(slot_number)):
		_build_city()
		if not city.build_type.is_empty(): city.cancel_placement()
		_refresh_facility_list()
		var preferred: String = selected_id if session.sim.facility(selected_id) != null else "20_player"
		select_facility(preferred if session.sim.facility(preferred) != null else "")
		debug_panel.hide()
		debug_entry.clear()
		_set_status("Loaded Slot %d. Resume when ready." % slot_number, "success")
	else:
		_set_status("Load failed: " + session.message, "error")
	refresh()

func _build_dialogs() -> void:
	overview = AcceptDialog.new()
	overview.title = "Company overview"
	overview.max_size = Vector2i(800, 650)
	add_child(overview)
	reports = CompanyReports.new()
	overview.add_child(reports)
	reports.session = session
	reports.command_requested.connect(func(command: Dictionary) -> void:
		session.submit(command)
		refresh())
	_build_application_menu()
	save_browser = Browser.new()
	add_child(save_browser)
	save_browser.slot_requested.connect(_on_browser_slot_requested)
	save_browser.canceled.connect(_return_to_menu)
	save_browser.close_requested.connect(_return_to_menu)
	settings = AcceptDialog.new()
	settings.title = "Session settings"
	add_child(settings)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 250)
	settings.add_child(column)
	var help: Label = Label.new()
	help.text = "1 second/day at 1x; Max = 16x. Space pauses during gameplay.\nSave and Load are available from the Game Menu."
	column.add_child(help)
	city_summary = Label.new()
	column.add_child(city_summary)
	var current_heading: Label = Label.new()
	current_heading.text = "CURRENT DIFFICULTY"
	current_heading.theme_type_variation = "MetaLabel"
	column.add_child(current_heading)
	current_difficulty = Label.new()
	current_difficulty.name = "CurrentDifficulty"
	current_difficulty.theme_type_variation = "SectionTitleLabel"
	column.add_child(current_difficulty)
	var difficulty_heading: Label = Label.new()
	difficulty_heading.text = "NEW SANDBOX DIFFICULTY"
	difficulty_heading.theme_type_variation = "MetaLabel"
	column.add_child(difficulty_heading)
	new_sandbox_difficulty = OptionButton.new()
	new_sandbox_difficulty.name = "NewSandboxDifficulty"
	for difficulty_id: String in StrategicAI.DIFFICULTY_IDS:
		new_sandbox_difficulty.add_item(session.sim.strategic_ai.difficulty_display_name(difficulty_id))
		new_sandbox_difficulty.set_item_metadata(new_sandbox_difficulty.item_count - 1, difficulty_id)
	column.add_child(new_sandbox_difficulty)
	difficulty_description = Label.new()
	difficulty_description.name = "DifficultyDescription"
	difficulty_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(difficulty_description)
	var difficulty_note: Label = Label.new()
	difficulty_note.name = "DifficultyRulesNote"
	difficulty_note.text = "Difficulty changes AI strategy, not economic rules or hidden bonuses."
	difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_note.theme_type_variation = "MetaLabel"
	column.add_child(difficulty_note)
	new_sandbox_difficulty.item_selected.connect(func(_index: int) -> void: _update_difficulty_description())
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
	_button(row, "New sandbox 2012", func() -> void: _confirm_new_session(2012))
	_button(row, "New sandbox 2022", func() -> void: _confirm_new_session(2022))
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
	settings.canceled.connect(_return_to_menu)
	settings.close_requested.connect(_return_to_menu)
	settings.confirmed.connect(_return_to_menu)
	overwrite_confirmation = ConfirmationDialog.new()
	overwrite_confirmation.title = "Overwrite save"
	save_browser.add_child(overwrite_confirmation)
	overwrite_confirmation.confirmed.connect(func() -> void:
		overwrite_confirmation.hide()
		_save(pending_slot)
		_refresh_save_browser("save"))
	load_confirmation = ConfirmationDialog.new()
	load_confirmation.title = "Load saved game"
	save_browser.add_child(load_confirmation)
	load_confirmation.confirmed.connect(func() -> void:
		load_confirmation.hide()
		_load(pending_slot)
		if save_browser.visible: save_browser.hide()
		_show_menu(false))
	new_session_confirmation = ConfirmationDialog.new()
	new_session_confirmation.title = "Start new sandbox"
	settings.add_child(new_session_confirmation)
	new_session_confirmation.confirmed.connect(func() -> void:
		new_session_confirmation.hide()
		_new_session(pending_era, pending_difficulty))

func _build_application_menu() -> void:
	app_menu = AcceptDialog.new()
	app_menu.title = "Game Menu"
	app_menu.get_ok_button().hide()
	add_child(app_menu)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 310)
	app_menu.add_child(column)
	var title_label: Label = Label.new()
	title_label.text = "GAME MENU"
	title_label.theme_type_variation = "TitleLabel"
	column.add_child(title_label)
	var subtitle: Label = Label.new()
	subtitle.text = "Simulation advancement is paused while this menu is open."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.theme_type_variation = "MetaLabel"
	column.add_child(subtitle)
	_button(column, "Resume", _resume_game)
	_button(column, "Save Game", func() -> void: _show_save_browser("save"))
	_button(column, "Load Game", func() -> void: _show_save_browser("load"))
	_button(column, "Settings", _show_settings)
	app_menu.canceled.connect(_resume_game)
	app_menu.close_requested.connect(_resume_game)

func _show_menu(begin_pause: bool = true) -> void:
	if begin_pause: application_pause = true
	if save_browser != null: save_browser.hide()
	if settings != null: settings.hide()
	app_menu.popup_centered(Vector2i(420, 390))
	refresh()

func _resume_game() -> void:
	for dialog: Window in [app_menu, save_browser, settings, overwrite_confirmation, load_confirmation, new_session_confirmation]:
		if dialog != null: dialog.hide()
	application_pause = false
	refresh()

func _return_to_menu() -> void:
	if not application_pause: return
	if save_browser != null: save_browser.hide()
	if settings != null: settings.hide()
	_show_menu(false)

func _show_save_browser(browser_mode: String) -> void:
	application_pause = true
	app_menu.hide()
	_refresh_save_browser(browser_mode)
	save_browser.popup_centered(Vector2i(700, 520))
	refresh()

func _refresh_save_browser(browser_mode: String) -> void:
	var values: Dictionary = {}
	for slot_number: int in range(1, 4): values[slot_number] = Store.new().inspect_file(slot_path(slot_number))
	save_browser.configure(browser_mode, values)

func _on_browser_slot_requested(browser_mode: String, slot_number: int, summary: Dictionary) -> void:
	pending_slot = slot_number
	if browser_mode == "save":
		if str(summary.get("state", "empty")) == "empty":
			_save(slot_number)
			return
		overwrite_confirmation.dialog_text = "Overwrite Slot %d?\n\nExisting save: %s\n\nThis cannot be undone." % [slot_number, _summary_line(summary)]
		overwrite_confirmation.popup_centered()
		return
	if str(summary.get("state", "empty")) != "valid":
		_set_status("Load unavailable: " + str(summary.get("reason", "Empty slot.")), "error")
		refresh()
		return
	load_confirmation.dialog_text = "Load Slot %d?\n\n%s\n\nCurrent unsaved progress will be replaced." % [slot_number, _summary_line(summary)]
	load_confirmation.popup_centered()

func _summary_line(summary: Dictionary) -> String:
	if str(summary.get("state", "")) != "valid": return str(summary.get("reason", "Existing data"))
	return "%s • %s" % [summary.get("company", "Player company"), summary.get("date", "Unknown date")]

func _new_session(era: int, difficulty: String = "standard") -> void:
	city_seed.apply()
	if not session.start(era, int(city_seed.value), "sandbox", city_settings, difficulty): return
	_build_city()
	city.cancel_placement()
	select_facility("20_player")
	debug_entry.clear()
	debug_panel.hide()
	settings.hide()
	_set_status("Started a new %d %s sandbox." % [era, session.sim.strategic_ai.difficulty_display_name(difficulty)], "success")
	_show_menu(false)
	refresh()

func _confirm_new_session(era: int) -> void:
	pending_era = era
	pending_difficulty = _selected_difficulty()
	new_session_confirmation.dialog_text = "Start a new %d %s sandbox?\n\nUnsaved progress in the current session will be lost." % [era, session.sim.strategic_ai.difficulty_display_name(pending_difficulty)]
	new_session_confirmation.popup_centered()

func _show_settings() -> void:
	application_pause = true
	if app_menu != null: app_menu.hide()
	city_seed.value = int(session.sim.city.generation.seed)
	current_difficulty.text = session.sim.strategic_ai.difficulty_display_name(session.sim.difficulty)
	_select_difficulty(session.sim.difficulty)
	_update_difficulty_description()
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
	reports.size = Vector2(760, 510)
	overview.size = Vector2i(800, 650)
	overview.popup_centered(Vector2i(800, 650))

func _update_company() -> void:
	reports.refresh()

func world_input_blocked() -> bool:
	return GameInputPolicy.blocked(get_viewport(), [settings, overview, demolition, app_menu, save_browser, overwrite_confirmation, load_confirmation, new_session_confirmation])

func _refresh_facility_list() -> void:
	facility_list.clear()
	facility_list.add_item("No facility selected")
	facility_list.set_item_metadata(0, "")
	for f: SimFacility in session.sim.facilities:
		var definition: Dictionary = session.sim.catalog.facility_types.get(f.type_id, {})
		var type_name: String = str(definition.get("name", f.type_id))
		facility_list.add_item("%s • %s • %s" % [f.id, type_name, session.sim.companies[f.company_id].display_name])
		facility_list.set_item_metadata(facility_list.item_count - 1, f.id)
	if selected_id.is_empty(): facility_list.select(0)

func _build_construction(parent: Node) -> void:
	construction = VBoxContainer.new()
	construction.custom_minimum_size.x = 410
	parent.add_child(construction)
	var title: Label = Label.new()
	title.text = "CONSTRUCTION"
	title.theme_type_variation = "TitleLabel"
	construction.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Choose a facility, review its operating profile, then place it on a road-accessible site."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.theme_type_variation = "MetaLabel"
	construction.add_child(subtitle)
	var facility_heading: Label = Label.new()
	facility_heading.text = "FACILITY TYPE"
	facility_heading.theme_type_variation = "SectionLabel"
	construction.add_child(facility_heading)
	build_category = Label.new()
	build_category.theme_type_variation = "MetricLabel"
	construction.add_child(build_category)
	build_choices = OptionButton.new()
	build_choices.tooltip_text = "Choose a catalog-defined facility type."
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
	build_products.tooltip_text = "Choose the initial product or warehouse line."
	construction.add_child(build_products)
	build_products.item_selected.connect(func(_index: int) -> void: _begin_preview())
	build_details = Label.new()
	build_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_details.custom_minimum_size = Vector2(400, 98)
	construction.add_child(build_details)
	var placement_heading: Label = Label.new()
	placement_heading.text = "PLACEMENT"
	placement_heading.theme_type_variation = "SectionLabel"
	construction.add_child(placement_heading)
	build_reason = Label.new()
	build_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_reason.custom_minimum_size = Vector2(400, 54)
	construction.add_child(build_reason)
	var hint: Label = Label.new()
	hint.text = "Green: valid • Red: invalid\nLMB: build • RMB / Esc: cancel • Costs apply immediately"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	construction.add_child(hint)
	var actions: HBoxContainer = HBoxContainer.new()
	construction.add_child(actions)
	build_action = _button(actions, "Begin placement", _begin_preview)
	build_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_action.tooltip_text = "Show the green/red footprint preview in the city."
	build_cancel = _button(actions, "Cancel construction", func() -> void: city.cancel_placement())
	build_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_cancel.theme_type_variation = "DestructiveButton"
	build_cancel.tooltip_text = "Leave construction and return to facility management."
	construction.hide()
	demolition = ConfirmationDialog.new()
	demolition.title = "Demolish owned facility"
	add_child(demolition)
	demolition.confirmed.connect(func() -> void:
		session.submit({"type": "demolish_facility", "facility": selected_id})
		refresh())
	inspector.demolition_requested.connect(func() -> void:
		var facility: SimFacility = session.sim.facility(selected_id)
		var name_value: String = selected_id
		if facility != null: name_value = str(session.sim.catalog.facility_types[facility.type_id].name) + " (" + facility.id + ")"
		demolition.dialog_text = "Demolish %s permanently?\n\nRemaining inventory will be written off. No refund is paid." % name_value
		demolition.popup_centered())

func _show_construction() -> void:
	construction.show()
	inspector.hide()
	if build_choices.selected < 0 or build_choices.is_item_separator(build_choices.selected):
		build_choices.select(1)
	_choose_build()

func _choose_build() -> void:
	var id: String = str(build_choices.get_item_metadata(build_choices.selected))
	var definition: Dictionary = session.sim.catalog.facility_types[id]
	build_category.text = str(definition.category).to_upper() + " FACILITY"
	build_products.clear()
	for product: String in definition.products:
		if session.sim.can_configure(session.active_company, id, product):
			build_products.add_item(str(session.sim.catalog.products[product].name))
			build_products.set_item_metadata(build_products.item_count - 1, product)
	var productless: bool = session.sim.catalog.productless_behavior(str(definition.behavior))
	build_products.visible = not productless
	var capacity_label: String = "Base daily capacity"
	if definition.behavior == "storage": capacity_label = "Storage capacity"
	elif definition.behavior == "research": capacity_label = "Base research rate"
	elif definition.behavior == "headquarters": capacity_label = "Staff capacity"
	var capacity_value: int = int(definition.get("capacity", 0))
	if definition.behavior == "research": capacity_value = int(definition.get("research_rate", capacity_value))
	elif definition.behavior == "headquarters": capacity_value = int(definition.get("staff_capacity", capacity_value))
	var suffix: String = "/day" if definition.behavior in ["production", "retail", "research"] else (" units" if definition.behavior == "storage" else " staff")
	build_details.text = "FACILITY DETAILS\nCost  $%.2f  •  Footprint  %d × %d cells\n%s  %d%s  •  Daily overhead  $%.2f\n%s" % [definition.cost / 100.0, definition.width, definition.depth, capacity_label, capacity_value, suffix, definition.overhead / 100.0, definition.description]
	_begin_preview()

func _begin_preview() -> void:
	var type_id: String = str(build_choices.get_item_metadata(build_choices.selected))
	if session.sim.catalog.productless_behavior(str(session.sim.catalog.facility_types[type_id].behavior)):
		city.begin_placement(type_id, "")
	elif build_products.selected >= 0:
		city.begin_placement(str(build_choices.get_item_metadata(build_choices.selected)), str(build_products.get_item_metadata(build_products.selected)))
	if build_action != null: build_action.text = "Continue placement"

func _place(x: int, y: int) -> void:
	var next_id: String = "built_%06d" % session.sim.city.next_facility
	var accepted: bool = session.submit({"type": "build_facility", "archetype": city.build_type, "product": city.build_product, "x": x, "y": y})
	if accepted:
		city.sync(session.sim.snapshot())
		_refresh_facility_list()
		city.cancel_placement()
		select_facility(next_id)
		_set_status("Built %s and selected %s." % [session.sim.catalog.facility_types[session.sim.facility(next_id).type_id].name, next_id], "success")
	else:
		build_reason.text = session.message
		_set_status(session.message, "error")
	refresh()

func _selected_difficulty() -> String:
	if new_sandbox_difficulty == null or new_sandbox_difficulty.selected < 0: return "standard"
	return str(new_sandbox_difficulty.get_item_metadata(new_sandbox_difficulty.selected))

func _select_difficulty(difficulty: String) -> void:
	for index: int in range(new_sandbox_difficulty.item_count):
		if str(new_sandbox_difficulty.get_item_metadata(index)) == difficulty:
			new_sandbox_difficulty.select(index)
			return

func _update_difficulty_description() -> void:
	if difficulty_description == null: return
	var profile: Dictionary = session.sim.strategic_ai.difficulty_profile(_selected_difficulty())
	difficulty_description.text = str(profile.get("description", ""))

func _update_placement_feedback(reason: String) -> void:
	if build_reason == null: return
	var lines: PackedStringArray = reason.split("\n")
	var detail: String = "\n".join(lines.slice(1))
	if city.preview_error.is_empty():
		build_reason.text = "VALID SITE\n" + (detail if not detail.is_empty() else "Click to build here.")
		build_reason.theme_type_variation = "PositiveLabel"
		status_kind = "success"
	else:
		build_reason.text = "CANNOT BUILD HERE\n" + city.preview_error + ("\n" + detail if not detail.is_empty() else "")
		build_reason.theme_type_variation = "NegativeLabel"
		status_kind = "error"

func _set_status(message: String, kind: String = "normal") -> void:
	status_override = message
	status_kind = kind

func _handle_escape() -> void:
	if city != null and not city.build_type.is_empty():
		city.cancel_placement()
		return
	if overwrite_confirmation != null and overwrite_confirmation.visible:
		overwrite_confirmation.hide()
		return
	if load_confirmation != null and load_confirmation.visible:
		load_confirmation.hide()
		return
	if new_session_confirmation != null and new_session_confirmation.visible:
		new_session_confirmation.hide()
		return
	if save_browser != null and save_browser.visible:
		_return_to_menu()
		return
	if settings != null and settings.visible:
		_return_to_menu()
		return
	if demolition != null and demolition.visible:
		demolition.hide()
		return
	if overview != null and overview.visible:
		overview.hide()
		return
	if app_menu != null and app_menu.visible:
		_resume_game()
		return
	_show_menu()
