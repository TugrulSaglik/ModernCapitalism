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

var tutorial_panel: VBoxContainer
var tutorial_text: Label
var tutorial_ack: Button
var tutorial_last_step: int = -1
var research_signature: String = ""
var return_confirmation: ConfirmationDialog

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
var city_selector: OptionButton
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
var city_summary: Label
var city_diagnostics: Label
var minimap: CityMinimap
var app_menu: AcceptDialog
var save_browser: SaveBrowser
var application_pause: bool = false
var current_difficulty: Label
var status_override: String = ""
var status_kind: String = "normal"
var build_category: Label
var build_action: Button
var build_cancel: Button
var property_panel: VBoxContainer
var property_details: Label
var property_type_choice: OptionButton
var property_type_label: Label
var property_action: Button
var property_acquire: Button
var property_demolish: Button
var property_buy_land: Button
var property_confirm: ConfirmationDialog
var selected_property: String = ""
var selected_port: bool = false
var selected_parcel: Vector2i = Vector2i(-1, -1)
var property_pending: Dictionary = {}

func _ready() -> void:
	_apply_preferences()
	get_node("/root/UIService").preferences_changed.connect(_apply_preferences)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = UITheme.BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_directory = argument.trim_prefix("--save-dir=")
	if session.sim == null: session.start(2022, 42, "sandbox", city_settings)
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
	var workspace: Control = Control.new()
	workspace.name = "CityWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.clip_contents = true
	left.add_child(workspace)
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(container)
	city_viewport = SubViewport.new()
	city_viewport.size = Vector2i(800, 650)
	city_viewport.msaa_3d = Viewport.MSAA_4X
	city_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(city_viewport)
	_build_city()
	var legend: Label = Label.new()
	legend.text = "CONTROLS  Middle drag: pan  •  Wheel: zoom  •  Click: inspect  •  Right click: clear/cancel  •  Esc: menu\nOWNERSHIP  Teal: player  •  Blue: components  •  Tan: Orion  •  Purple: Nova  •  Coral: rival"
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
	_build_tutorial_panel(management_host)
	management_host.add_child(inspector)
	_build_property_panel(management_host)
	# FacilityPanel owns its internal management scroll; give it the content height
	# while this shell-level scroll constrains the panel to the workspace viewport.
	inspector.custom_minimum_size.y = inspector.tabs.get_combined_minimum_size().y + UITheme.SPACE_3 * 2
	inspector.command_requested.connect(func(command: Dictionary) -> void:
		_submit_with_audio(command)
		refresh())
	_build_construction(management_host)
	_build_bottom_hud(column)
	minimap = CityMinimap.new()
	workspace.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 12
	minimap.offset_right = 180
	minimap.offset_top = -138
	minimap.offset_bottom = -12
	minimap.city = city
	minimap.map = session.sim.cities[session.active_city]
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
	company_name_label.clip_text = true
	company_name_label.custom_minimum_size.x = 180
	identity.add_child(company_name_label)
	managed_company_selector = OptionButton.new()
	managed_company_selector.name = "ManagedCompanySelector"
	managed_company_selector.tooltip_text = "Select a company controlled by your corporate group."
	managed_company_selector.fit_to_longest_item = false
	managed_company_selector.custom_minimum_size.x = 190
	managed_company_selector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(managed_company_selector)
	managed_company_selector.item_selected.connect(func(index: int) -> void:
		if session.select_company(str(managed_company_selector.get_item_metadata(index))):
			city.cancel_placement()
			if construction != null and construction.visible and build_choices.selected >= 0: _choose_build()
			refresh())
	city_selector = OptionButton.new()
	city_selector.name = "ActiveCitySelector"
	city_selector.tooltip_text = "Choose the city to view and build in."
	city_selector.fit_to_longest_item = false
	city_selector.custom_minimum_size.x = 145
	city_selector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(city_selector)
	city_selector.item_selected.connect(func(index: int) -> void:
		if session.select_city(str(city_selector.get_item_metadata(index))):
			selected_id = ""
			selected_property = ""
			selected_parcel = Vector2i(-1, -1)
			_build_city()
			select_facility("")
			refresh())
	for item: Array in [["Company", _show_company, "Open company reports and management."], ["Build", _show_construction, "Open construction and choose a facility."]]:
		var navigation: Button = _button(row, str(item[0]), item[1])
		navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		navigation.theme_type_variation = "NavigationButton"
		navigation.tooltip_text = str(item[2])
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var menu_button: Button = _button(row, "Menu", _show_menu)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_button.name = "MenuButton"
	menu_button.tooltip_text = "Pause simulation advancement and open Save, Load or Settings."

func _build_context_bar(parent: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "FacilityContextBar"
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = "CONTEXT"
	label.theme_type_variation = "MetricLabel"
	label.custom_minimum_size.x = 70
	row.add_child(label)
	facility_list = OptionButton.new()
	facility_list.fit_to_longest_item = false
	facility_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facility_list.tooltip_text = "Select and focus a facility in the city."
	row.add_child(facility_list)
	facility_list.item_selected.connect(func(index: int) -> void: select_facility(str(facility_list.get_item_metadata(index))))
	_refresh_facility_list()

func _active_snapshot() -> Dictionary:
	var company_data: Array[Dictionary] = []
	var company_ids: Array = session.sim.companies.keys()
	company_ids.sort()
	for id: String in company_ids: company_data.append({"id": id})
	var local_facilities: Array[Dictionary] = []
	for f: SimFacility in session.sim.facilities:
		if f.city_id == session.active_city: local_facilities.append(f.snapshot())
	var map: CityMap = session.sim.cities[session.active_city]
	# Rendering needs no copy of the potentially 100,000 authoritative parcels.
	var view: Dictionary = {"width": map.width, "depth": map.depth, "generation": map.generation, "port": map.port, "plots": map.plots.duplicate(true), "ambient": map.ambient.duplicate(true)}
	return {"city": view, "companies": company_data, "facilities": local_facilities}

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
	city.build(_active_snapshot())
	if minimap != null:
		minimap.city = city
		minimap.map = session.sim.cities[session.active_city]
		minimap.queue_redraw()
	city.facility_selected.connect(select_facility)
	city.property_selected.connect(select_property)
	city.parcel_selected.connect(select_parcel)
	city.port_selected.connect(_select_port)
	city.context_cleared.connect(func() -> void:
		select_facility("")
		refresh())
	city.placement_requested.connect(_place)
	city.placement_changed.connect(func(reason: String) -> void:
		_update_placement_feedback(reason))
	city.placement_cancelled.connect(func() -> void:
		if construction != null:
			construction.hide()
			inspector.visible = session.sim.facility(selected_id) != null)
	_refresh_facility_list()

func select_facility(id: String) -> void:
	selected_port = false
	if session.sim.facility(id) != null and session.sim.facility(id).city_id != session.active_city: id = ""
	selected_property = ""
	selected_parcel = Vector2i(-1, -1)
	if facility_list != null and facility_list.item_count > 0: facility_list.set_item_text(0, "Select a facility, property or parcel")
	if property_panel != null: property_panel.hide()
	city.select_property("")
	if session.sim.facility(id) == null:
		selected_id = ""
		inspector.selected_id = ""
		inspector.hide()
		city.select("")
		if facility_list != null and facility_list.item_count > 0: facility_list.select(0)
		return
	selected_id = id
	if session.mode == "tutorial" and session.sim._behavior(session.sim.facility(id)) == "retail" and session.sim.facility(id).company_id == "player": session.tutorial.observe("retail")
	city.select(id)
	inspector.bind(session, id)
	inspector.visible = construction == null or not construction.visible
	for index: int in range(facility_list.item_count):
		if facility_list.get_item_metadata(index) == id:
			facility_list.select(index)

func _build_property_panel(parent: Node) -> void:
	property_panel = VBoxContainer.new()
	property_panel.name = "PropertyInspector"
	property_panel.custom_minimum_size.x = 410
	parent.add_child(property_panel)
	var title: Label = Label.new()
	title.text = "PROPERTY & LAND"
	title.theme_type_variation = "TitleLabel"
	property_panel.add_child(title)
	property_details = Label.new()
	property_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_details.custom_minimum_size = Vector2(400, 250)
	property_panel.add_child(property_details)
	property_type_label = Label.new()
	property_type_label.text = "DEVELOPMENT TYPE"
	property_type_label.theme_type_variation = "SectionLabel"
	property_panel.add_child(property_type_label)
	property_type_choice = OptionButton.new()
	for id: String in session.sim.catalog.property_types:
		property_type_choice.add_item(str(session.sim.catalog.property_types[id].name))
		property_type_choice.set_item_metadata(property_type_choice.item_count - 1, id)
	property_panel.add_child(property_type_choice)
	property_type_choice.item_selected.connect(func(_index: int) -> void: _refresh_property_panel())
	property_action = _button(property_panel, "Develop property", _property_develop)
	property_buy_land = _button(property_panel, "Buy this land cell", func() -> void:
		var accepted: bool = _submit_with_audio({"type": "buy_land", "x": selected_parcel.x, "y": selected_parcel.y, "width": 1, "depth": 1})
		_set_status(session.message, "success" if accepted else "error")
		_refresh_property_panel())
	property_acquire = _button(property_panel, "Acquire existing property", _property_acquire)
	property_demolish = _button(property_panel, "Demolish property", _property_demolish)
	property_demolish.theme_type_variation = "DestructiveButton"
	property_confirm = ConfirmationDialog.new()
	property_confirm.title = "Confirm property action"
	add_child(property_confirm)
	property_confirm.confirmed.connect(func() -> void: _apply_property_command(property_pending))
	property_panel.hide()

func select_property(id: String) -> void:
	if not session.sim.real_estates[session.active_city].properties.has(id): return
	selected_port = false
	select_facility("")
	construction.hide()
	city.cancel_placement()
	selected_property = id
	var b: Dictionary = session.sim.real_estates[session.active_city].properties[id]
	selected_parcel = Vector2i(int(b.x), int(b.y))
	city.select_property(id)
	property_panel.show()
	facility_list.set_item_text(0, DisplayLabels.property_label(session.sim, session.active_city, b))
	_refresh_property_panel()

func select_parcel(x: int, y: int) -> void:
	selected_port = false
	if not session.sim.cities[session.active_city].parcels.has(CityMap.key(x, y)):
		select_facility("")
		return
	var info: Dictionary = session.sim.cities[session.active_city].parcel_info(x, y)
	if not str(info.occupant).is_empty():
		if session.sim.real_estates[session.active_city].properties.has(str(info.occupant)): select_property(str(info.occupant))
		else: select_facility(str(info.occupant))
		return
	select_facility("")
	construction.hide()
	selected_parcel = Vector2i(x, y)
	property_panel.show()
	facility_list.set_item_text(0, DisplayLabels.parcel_label(session.sim.cities[session.active_city], x, y))
	_refresh_property_panel()

func _select_port() -> void:
	select_facility("")
	construction.hide()
	selected_port = true
	property_panel.show()
	facility_list.set_item_text(0, "Regional Port • " + session.sim.cities[session.active_city].display_name)
	_refresh_property_panel()

func _refresh_property_panel() -> void:
	if property_panel == null or not property_panel.visible: return
	if selected_port:
		var map: CityMap = session.sim.cities[session.active_city]
		var imports: int = 0
		var exports: int = 0
		for entry: Dictionary in session.sim.regional_trade.history:
			for row: Dictionary in entry.cities.get(session.active_city, {}).values():
				imports += int(row.import_units)
				exports += int(row.export_units)
		property_details.text = "REGIONAL PORT\n%s  •  Public infrastructure\nRoad connected: Yes\nRegional trade enabled: Yes\nRecent imports: %d units  •  Exports: %d units\nPosition: %d, %d" % [map.display_name, imports, exports, int(map.port.x), int(map.port.y)]
		for button: Button in [property_action, property_buy_land, property_acquire, property_demolish]: button.hide()
		property_type_label.hide()
		property_type_choice.hide()
		return
	property_type_label.show()
	property_type_choice.show()
	var sim: Economy = session.sim
	var estate: RealEstate = sim.real_estates[session.active_city]
	var city_info: Dictionary = sim.cities[session.active_city].population
	var city_line: String = "%s  •  Population %s / Housing %s  •  Workforce %s\nJobs %s  •  Employed %s  •  Unemployed %s  •  Purchasing power %d%%" % [sim.cities[session.active_city].display_name, sim.cities[session.active_city].population_text(int(city_info.total)), sim.cities[session.active_city].population_text(int(city_info.get("housing_capacity", city_info.capacity))), sim.cities[session.active_city].population_text(int(city_info.get("workforce", 0))), sim.cities[session.active_city].population_text(int(city_info.get("jobs", 0))), sim.cities[session.active_city].population_text(int(city_info.get("employed", 0))), sim.cities[session.active_city].population_text(int(city_info.get("unemployed", 0))), city_info.purchasing_power]
	var type_id: String = str(property_type_choice.get_item_metadata(property_type_choice.selected)) if property_type_choice.selected >= 0 else "apartments"
	var definition: Dictionary = sim.catalog.property_types[type_id]
	var b: Dictionary = estate.properties.get(selected_property, {})
	var x: int = selected_parcel.x
	var y: int = selected_parcel.y
	if not b.is_empty():
		x = int(b.x)
		y = int(b.y)
	var parcel: Dictionary = sim.cities[session.active_city].parcel_info(x, y)
	var land_owner: String = str(estate.land.get(CityMap.key(x, y), {}).get("owner", ""))
	var owner_name: String = "Unowned" if b.is_empty() or str(b.owner).is_empty() else str(sim.companies[str(b.owner)].display_name)
	var road_access: bool = bool(parcel.get("road_access", false))
	if not b.is_empty():
		for cell: String in b.land_cells:
			var parts: PackedStringArray = cell.split(",")
			road_access = road_access or sim.cities[session.active_city].touches_road(int(parts[0]), int(parts[1]))
	var detail: String = "LOCATION  %d, %d  •  %s\nSelected cell land value: $%.2f  •  Road access %s  •  Waterfront %s\nLand owner  %s\n" % [x, y, DisplayLabels.district(sim.cities[session.active_city], str(parcel.get("district", ""))), int(parcel.get("land_value", 0)) / 100.0, "Yes" if road_access else "No", "Yes" if parcel.get("waterfront", false) else "No", "Unowned" if land_owner.is_empty() else str(sim.companies[land_owner].display_name)]
	if not b.is_empty():
		var current: Dictionary = sim.catalog.property_types[str(b.type)]
		var capacity: int = int(current.residential_capacity) if int(current.residential_capacity) > 0 else int(current.job_capacity)
		var occupied: int = int(b.population) if int(current.residential_capacity) > 0 else int(b.occupied_jobs)
		var gross: int = estate.gross_rent(sim, b)
		detail += "\n%s  •  %s\nOwner  %s\nBuilding basis $%.2f  •  Book value $%.2f\n%s  %s / %s (%d%%)\nMonthly rent $%.2f  •  Maintenance $%.2f\nNet rent $%.2f  •  Accumulated depreciation $%.2f\n" % [str(current.name), str(current.use), owner_name, int(b.building_cost) / 100.0, (int(b.building_cost) - int(b.depreciation)) / 100.0, "Residents" if current.use == "residential" else "Jobs", sim.cities[session.active_city].population_text(occupied), sim.cities[session.active_city].population_text(capacity), occupied * 100 / maxi(1, capacity), gross / 100.0, (gross * 25 / 100) / 100.0, (gross - gross * 25 / 100) / 100.0, int(b.depreciation) / 100.0]
	var map: CityMap = sim.cities[session.active_city]
	var project_cells: Array[String] = estate.cells(x, y, int(definition.width), int(definition.depth))
	var land_cost: int = estate.land_cost(sim, session.active_company, x, y, int(definition.width), int(definition.depth))
	var additional_cells: int = 0
	var prices: Dictionary = {}
	var full_value: int = int(definition.cost)
	for cell: String in project_cells:
		var value: int = int(map.parcels.get(cell, {}).get("land_value", 0))
		full_value += value
		if not estate.land.has(cell):
			additional_cells += 1
			prices[value] = true
	var project_error: String = estate.land_error(sim, session.active_company, x, y, int(definition.width), int(definition.depth), true, selected_property)
	if map.is_road(x, y) or map.is_water(x, y):
		detail = "LOCATION  %d, %d • %s\nPublic %s • Land cannot be purchased.\n" % [x, y, DisplayLabels.district(map, str(parcel.get("district", ""))), "road" if map.is_road(x, y) else "water"]
	detail += "\nPROJECT  %s • %d × %d cells\n" % [definition.name, definition.width, definition.depth]
	if project_error.is_empty() and land_cost >= 0:
		detail += "Building %s\nAdditional land required: %d cells • %s\n%s\nTotal %s\n" % [CompanyReports.money(int(definition.cost)), additional_cells, CompanyReports.money(land_cost), "Cell prices vary across this footprint; total sums each unowned cell." if prices.size() > 1 else "Land already owned by your company is excluded.", CompanyReports.money(int(definition.cost) + land_cost)]
	else:
		detail += "Development unavailable: %s\n" % project_error
	detail += "Capacity %s %s • Full occupancy gross rent %s / month\n\n%s" % [map.population_text(int(definition.residential_capacity) if definition.use == "residential" else int(definition.job_capacity)), "residents" if definition.use == "residential" else "jobs", CompanyReports.money(full_value * 12 / 1200), city_line]
	property_details.text = detail
	var owned: bool = not b.is_empty() and str(b.owner) == session.active_company
	var unowned_property: bool = not b.is_empty() and str(b.owner).is_empty()
	property_action.text = "Redevelop property" if owned else "Develop property"
	property_action.visible = owned or b.is_empty()
	property_buy_land.visible = b.is_empty() and land_owner.is_empty()
	property_buy_land.disabled = not _property_error({"type": "buy_land", "company": session.active_company, "x": x, "y": y, "width": 1, "depth": 1}).is_empty()
	property_action.disabled = not _property_error({"type": "redevelop_property", "company": session.active_company, "property": selected_property, "property_type": type_id} if owned else {"type": "develop_property", "company": session.active_company, "property_type": type_id, "x": x, "y": y}).is_empty()
	property_acquire.visible = unowned_property
	property_acquire.disabled = not unowned_property or not _property_error({"type": "acquire_property", "company": session.active_company, "property": selected_property}).is_empty()
	property_demolish.visible = owned
	property_action.tooltip_text = _property_error({"type": "redevelop_property", "company": session.active_company, "property": selected_property, "property_type": type_id} if owned else {"type": "develop_property", "company": session.active_company, "property_type": type_id, "x": x, "y": y})

func _property_error(command: Dictionary) -> String:
	var request: Dictionary = command.duplicate(true)
	request["city"] = session.active_city
	return session.sim.property_command_error(request)

func _property_develop() -> void:
	var type_id: String = str(property_type_choice.get_item_metadata(property_type_choice.selected))
	if selected_property.is_empty():
		_apply_property_command({"type": "develop_property", "property_type": type_id, "x": selected_parcel.x, "y": selected_parcel.y})
	else:
		_confirm_property({"type": "redevelop_property", "property": selected_property, "property_type": type_id}, "Write off this building and redevelop the site?")

func _property_acquire() -> void:
	_confirm_property({"type": "acquire_property", "property": selected_property}, "Acquire this property at land value plus replacement cost?")

func _property_demolish() -> void:
	_confirm_property({"type": "demolish_property", "property": selected_property}, "Demolish this building? Its remaining book value will be expensed; land stays owned.")

func _confirm_property(command: Dictionary, question: String) -> void:
	property_pending = command
	property_confirm.dialog_text = question
	property_confirm.popup_centered()

func _apply_property_command(command: Dictionary) -> void:
	var id: String = selected_property
	var accepted: bool = _submit_with_audio(command)
	if accepted:
		city.sync(_active_snapshot())
		if command.type == "develop_property" or command.type == "redevelop_property":
			select_property("property_%06d" % (session.sim.real_estates[session.active_city].next_property - 1))
		elif command.type == "demolish_property": select_parcel(selected_parcel.x, selected_parcel.y)
		else: select_property(id)
		_set_status(session.message, "success")
	else: _set_status(session.message, "error")
	refresh()

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
	_refresh_tutorial()
	var signature: String = str(session.sim.companies.player.product_quality_levels) + str(session.sim.companies.player.process_efficiency_levels) + str(session.sim.companies.player.known_technologies)
	if not research_signature.is_empty() and signature != research_signature: get_node("/root/UIService").play("research")
	research_signature = signature
	var workspace: Control = find_child("WorkspaceInspectorScroll", true, false)
	if workspace != null: workspace.visible = inspector.visible or construction.visible or property_panel.visible or tutorial_panel.visible
	session._refresh_active_company()
	_refresh_city_selector()
	if city.buildings.keys() != session.sim.cities[session.active_city].plots.keys() or city.property_buildings.keys() != session.sim.cities[session.active_city].ambient.keys():
		var restore_property: String = selected_property
		var restore_parcel: Vector2i = selected_parcel
		get_node("/root/UIService").play("construction")
		city.sync(_active_snapshot())
		_refresh_facility_list()
		if not restore_property.is_empty() and session.sim.real_estates[session.active_city].properties.has(restore_property): select_property(restore_property)
		elif restore_parcel.x >= 0: select_parcel(restore_parcel.x, restore_parcel.y)
		else: select_facility(selected_id)
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
	if property_panel != null and property_panel.visible: _refresh_property_panel()
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
		var p: Dictionary = session.sim.cities[session.active_city].population
		var active_map: CityMap = session.sim.cities[session.active_city]
		var port_text: String = "none" if active_map.port.is_empty() else "%d,%d" % [int(active_map.port.x), int(active_map.port.y)]
		var regional_shipments: int = 0
		for shipment: Dictionary in session.sim.logistics.shipments:
			if shipment.mode == "regional": regional_shipments += 1
		city_summary.text = "%s  •  Seed %s  •  Population %s / %s  •  Power %d%%\nCities: %s  •  Port %s  •  Regional shipments %d" % [active_map.display_name, active_map.generation.seed, active_map.population_text(), active_map.population_text(int(p.capacity)), p.purchasing_power, ", ".join(PackedStringArray(session.sim.cities.values().map(func(map: CityMap) -> String: return map.display_name))), port_text, regional_shipments]
	if city_diagnostics != null and session.debug_unlocked:
		var plot: Dictionary = session.sim.cities[session.active_city].plots.get(selected_id, {})
		var point: Vector2i = city.preview_cell if not city.build_type.is_empty() else Vector2i(int(plot.get("x", 0)), int(plot.get("y", 0)))
		var p: Dictionary = session.sim.cities[session.active_city].parcel_info(point.x, point.y)
		city_diagnostics.text = "Cell %s • %s\nLand $%.0f/cell • Waterfront %s • Port eligible %s\nAmbient properties %d • Roads %d" % [point, p.get("district", "fixture"), p.get("land_value", 0) / 100.0, p.get("waterfront", false), p.get("port_eligible", false), session.sim.cities[session.active_city].ambient.size(), session.sim.cities[session.active_city].roads.size()]
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

func _on_game_loaded() -> void:
	_build_city()
	_refresh_facility_list()
	select_facility("")
	debug_panel.hide()
	debug_entry.clear()
	_set_status("Saved game loaded. Resume when ready.", "success")
	_show_menu(false)

func _build_dialogs() -> void:
	overview = AcceptDialog.new()
	overview.title = "Company overview"
	overview.max_size = Vector2i(800, 650)
	add_child(overview)
	reports = CompanyReports.new()
	overview.add_child(reports)
	reports.session = session
	reports.command_requested.connect(func(command: Dictionary) -> void:
		_submit_with_audio(command)
		refresh())
	_build_application_menu()
	save_browser = Browser.new()
	add_child(save_browser)
	save_browser.game_loaded.connect(_on_game_loaded)
	save_browser.confirmed.connect(_return_to_menu)
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
	current_heading.text = "CURRENT SESSION (fixed at start)"
	current_heading.theme_type_variation = "MetaLabel"
	column.add_child(current_heading)
	current_difficulty = Label.new()
	current_difficulty.name = "CurrentDifficulty"
	current_difficulty.theme_type_variation = "SectionTitleLabel"
	column.add_child(current_difficulty)
	column.add_child(PreferencesPanel.new())
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
	subtitle.text = "Simulation is paused while this menu is open."
	subtitle.theme_type_variation = "MetaLabel"
	column.add_child(subtitle)
	_button(column, "Resume", _resume_game)
	_button(column, "Save Game", func() -> void: _show_save_browser("save"))
	_button(column, "Load Game", func() -> void: _show_save_browser("load"))
	_button(column, "Settings", _show_settings)
	return_confirmation = ConfirmationDialog.new()
	return_confirmation.title = "Return to Title"
	return_confirmation.dialog_text = "Return to Title? Unsaved progress will be lost."
	add_child(return_confirmation)
	return_confirmation.confirmed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	_button(column, "Return to Title", func() -> void: return_confirmation.popup_centered())
	app_menu.canceled.connect(_resume_game)
	app_menu.close_requested.connect(_resume_game)

func _show_menu(begin_pause: bool = true) -> void:
	if begin_pause: application_pause = true
	if save_browser != null: save_browser.hide()
	if settings != null: settings.hide()
	app_menu.popup_centered(Vector2i(420, 390))
	refresh()

func _resume_game() -> void:
	for dialog: Window in [app_menu, save_browser, settings, return_confirmation]:
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
	save_browser.configure(browser_mode, save_directory, session)

func _show_settings() -> void:
	application_pause = true
	if app_menu != null: app_menu.hide()
	current_difficulty.text = session.sim.strategic_ai.difficulty_display_name(session.sim.difficulty)
	current_difficulty.text = session.setup_summary()
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
	if session.mode == "tutorial": session.tutorial.observe("overview")
	_update_company()
	reports.size = Vector2(760, 510)
	overview.size = Vector2i(800, 650)
	overview.popup_centered(Vector2i(800, 650))

func _update_company() -> void:
	reports.refresh()

func world_input_blocked() -> bool:
	return GameInputPolicy.blocked(get_viewport(), [settings, overview, demolition, property_confirm, app_menu, save_browser, return_confirmation])

func _refresh_facility_list() -> void:
	facility_list.clear()
	facility_list.add_item("Select a facility, property or parcel")
	facility_list.set_item_metadata(0, "")
	for f: SimFacility in session.sim.facilities:
		if f.city_id != session.active_city: continue
		var definition: Dictionary = session.sim.catalog.facility_types.get(f.type_id, {})
		var type_name: String = str(definition.get("name", f.type_id))
		facility_list.add_item(DisplayLabels.facility(session.sim, f))
		facility_list.set_item_metadata(facility_list.item_count - 1, f.id)
	if selected_id.is_empty(): facility_list.select(0)

func _refresh_city_selector() -> void:
	if city_selector == null: return
	var city_ids: Array = session.sim.cities.keys()
	city_ids.sort()
	if city_selector.item_count != city_ids.size():
		city_selector.clear()
		for city_id: String in city_ids:
			city_selector.add_item(session.sim.cities[city_id].display_name)
			city_selector.set_item_metadata(city_selector.item_count - 1, city_id)
	for index: int in range(city_selector.item_count):
		var map: CityMap = session.sim.cities[str(city_selector.get_item_metadata(index))]
		city_selector.set_item_text(index, map.display_name)
		city_selector.set_item_tooltip(index, "%s, %s • Population %s • %d × %d cells" % [map.display_name, map.profile.get("country", ""), map.population_text(), map.width, map.depth])
		if city_selector.get_item_metadata(index) == session.active_city: city_selector.select(index)

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
	build_choices.tooltip_text = "Choose a facility type."
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
	hint.text = "Green: valid • Red: invalid\nClick: build • Right click: cancel • Esc: menu\nCosts apply immediately"
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
		_submit_with_audio({"type": "demolish_facility", "facility": selected_id})
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
	var land_cost: int = 0
	if city.preview_cell.x >= 0 and session.sim.cities[session.active_city].generation.preset != "legacy": land_cost = maxi(0, session.sim.real_estates[session.active_city].land_cost(session.sim, session.active_company, city.preview_cell.x, city.preview_cell.y, int(definition.width), int(definition.depth)))
	build_details.text = "FACILITY DETAILS  •  %s\nBuilding  $%.2f  •  Land acquisition  $%.2f  •  Total  $%.2f\nFootprint  %d × %d cells  •  %s  %d%s\nDaily overhead  $%.2f\n%s" % [session.sim.cities[session.active_city].display_name, definition.cost / 100.0, land_cost / 100.0, (int(definition.cost) + land_cost) / 100.0, definition.width, definition.depth, capacity_label, capacity_value, suffix, definition.overhead / 100.0, definition.description]
	_begin_preview()

func _begin_preview() -> void:
	var type_id: String = str(build_choices.get_item_metadata(build_choices.selected))
	if session.sim.catalog.productless_behavior(str(session.sim.catalog.facility_types[type_id].behavior)):
		city.begin_placement(type_id, "")
	elif build_products.selected >= 0:
		city.begin_placement(str(build_choices.get_item_metadata(build_choices.selected)), str(build_products.get_item_metadata(build_products.selected)))
	if build_action != null: build_action.text = "Continue placement"

func _place(x: int, y: int) -> void:
	var next_id: String = "built_%06d" % session.sim.next_facility_id
	var accepted: bool = _submit_with_audio({"type": "build_facility", "archetype": city.build_type, "product": city.build_product, "x": x, "y": y})
	if accepted:
		get_node("/root/UIService").play("construction")
		city.sync(_active_snapshot())
		_refresh_facility_list()
		city.cancel_placement()
		select_facility(next_id)
		_set_status("Built " + DisplayLabels.facility(session.sim, session.sim.facility(next_id)) + ".", "success")
	else:
		build_reason.text = session.message
		_set_status(session.message, "error")
	refresh()

func _update_placement_feedback(reason: String) -> void:
	if build_reason == null: return
	if construction != null and construction.visible and build_choices != null and build_choices.selected >= 0 and not build_choices.is_item_separator(build_choices.selected):
		var definition: Dictionary = session.sim.catalog.facility_types[str(build_choices.get_item_metadata(build_choices.selected))]
		var land_cost: int = 0
		if session.sim.cities[session.active_city].generation.preset != "legacy" and city.preview_cell.x >= 0:
			land_cost = maxi(0, session.sim.real_estates[session.active_city].land_cost(session.sim, session.active_company, city.preview_cell.x, city.preview_cell.y, int(definition.width), int(definition.depth)))
		var detail_lines: PackedStringArray = build_details.text.split("\n")
		if detail_lines.size() > 1:
			detail_lines[1] = "Building  $%.2f  •  Land acquisition  $%.2f  •  Total  $%.2f" % [int(definition.cost) / 100.0, land_cost / 100.0, (int(definition.cost) + land_cost) / 100.0]
			build_details.text = "\n".join(detail_lines)
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
	if property_confirm != null and property_confirm.visible:
		property_confirm.hide()
		return
	if return_confirmation != null and return_confirmation.visible:
		return_confirmation.hide()
		return
	if save_browser != null and save_browser.visible:
		if save_browser.close_child(): return
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

func _apply_preferences() -> void:
	theme = UITheme.build(get_node("/root/UIService").preferences.high_contrast)

func _submit_with_audio(command: Dictionary) -> bool:
	var ok: bool = session.submit(command)
	get_node("/root/UIService").play("success" if ok else "error")
	return ok

func _build_tutorial_panel(parent: Node) -> void:
	tutorial_panel = VBoxContainer.new()
	parent.add_child(tutorial_panel)
	tutorial_text = Label.new()
	tutorial_text.custom_minimum_size.x = 380
	tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_panel.add_child(tutorial_text)
	tutorial_ack = _button(tutorial_panel, "Understood", func() -> void:
		session.tutorial.observe("controls")
		refresh())
	_button(tutorial_panel, "Previous explanation", func() -> void:
		var previous: Dictionary = TutorialController.STEPS[maxi(0, session.tutorial.step - 1)]
		var help: AcceptDialog = AcceptDialog.new()
		help.title = str(previous.title)
		help.dialog_text = str(previous.instruction) + "\n\n" + str(previous.hint)
		add_child(help)
		help.confirmed.connect(help.queue_free)
		help.close_requested.connect(help.queue_free)
		help.popup_centered(Vector2i(560, 220)))
	_button(tutorial_panel, "Skip Tutorial", func() -> void:
		session.tutorial.skipped = true
		refresh())

func _refresh_tutorial() -> void:
	if tutorial_panel == null: return
	tutorial_panel.visible = session.mode == "tutorial" and not session.tutorial.complete()
	if not tutorial_panel.visible: return
	if session.tutorial.evaluate(session.sim):
		get_node("/root/UIService").play("tutorial")
		if session.tutorial.complete():
			tutorial_panel.hide()
			var done: AcceptDialog = AcceptDialog.new()
			done.title = "Tutorial complete"
			done.dialog_text = "Your company is ready. Continue playing freely, or return to Title for a new Sandbox."
			add_child(done)
			done.confirmed.connect(done.queue_free)
			done.popup_centered()
			return
	var step: Dictionary = session.tutorial.current()
	tutorial_text.text = "TUTORIAL • Step %d / %d\n\n%s\n\n%s\n\nHint: %s" % [session.tutorial.step + 1, TutorialController.STEPS.size(), step.title, step.instruction, step.hint]
	tutorial_ack.visible = session.tutorial.step == 0
