extends Control

var content: VBoxContainer
var company: LineEdit
var era: OptionButton
var difficulty: OptionButton
var capital: OptionButton
var seed_input: SpinBox
var city_mode: OptionButton
var city_choices: Array[OptionButton] = []
var city_box: VBoxContainer
var random_cities: Label
var error_label: Label
var catalog: SimCatalog = SimCatalog.new()
var browser: SaveBrowser
var scroller: ScrollContainer

func _ready() -> void:
	catalog.load_data()
	_apply_theme()
	get_node("/root/UIService").preferences_changed.connect(_apply_theme)
	var background: ColorRect = ColorRect.new()
	background.color = ModernUITheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size.x = 700
	center.add_child(scroller)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 680
	scroller.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	content.minimum_size_changed.connect(func() -> void: _fit_content.call_deferred())
	get_viewport().size_changed.connect(_fit_content)
	show_title()
	_fit_content.call_deferred()

func _fit_content() -> void:
	if scroller == null or content == null: return
	scroller.custom_minimum_size.y = minf(content.get_combined_minimum_size().y + 28, get_viewport_rect().size.y - 36)

func _apply_theme() -> void:
	theme = ModernUITheme.build(get_node("/root/UIService").preferences.high_contrast)

func _clear() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	city_choices.clear()

func _label(text_value: String, style: String = "") -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.theme_type_variation = style
	content.add_child(label)
	return label

func _button(text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	content.add_child(button)
	button.pressed.connect(action)
	return button

func show_title() -> void:
	_clear()
	_label("ModernCapitalism", "TitleLabel")
	_label("Build a business. Connect a region. Shape a city.", "SectionLabel")
	_label("68 products • 36 metropolitan profiles • One connected economy", "MetaLabel")
	_button("New Sandbox", show_setup).theme_type_variation = "PrimaryButton"
	_button("Tutorial", show_tutorial)
	_button("Load Game", show_load)
	_button("Settings", show_settings)
	_button("Quit", func() -> void: get_tree().quit())

func _choice(label_text: String, labels: Array) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	content.add_child(row)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var choice: OptionButton = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text_value: String in labels: choice.add_item(text_value)
	row.add_child(choice)
	return choice

func show_setup() -> void:
	_clear()
	_label("New Sandbox", "TitleLabel")
	_label("Your company, your starting point", "MetaLabel")
	company = LineEdit.new()
	company.text = "Player Electronics"
	company.max_length = 48
	company.placeholder_text = "Company name"
	_label("Company name", "SectionLabel")
	content.add_child(company)
	era = _choice("Starting era", ["2012", "2022"])
	era.select(1)
	difficulty = _choice("Difficulty", ["Relaxed", "Standard", "Competitive"])
	difficulty.select(1)
	capital = _choice("Starting capital", ["$100,000", "$200,000", "$500,000", "$1,000,000"])
	capital.select(1)
	var row: HBoxContainer = HBoxContainer.new()
	content.add_child(row)
	var label: Label = Label.new()
	label.text = "Seed"
	label.custom_minimum_size.x = 180
	row.add_child(label)
	seed_input = SpinBox.new()
	seed_input.max_value = 2147483647
	seed_input.value = 42
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seed_input)
	var randomize_button: Button = Button.new()
	randomize_button.text = "Randomize"
	row.add_child(randomize_button)
	randomize_button.pressed.connect(func() -> void: seed_input.value = randi_range(0, 2147483647))
	city_mode = _choice("Cities", ["Random cities", "Choose cities manually"])
	city_box = VBoxContainer.new()
	content.add_child(city_box)
	var ids: Array = catalog.city_profiles.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return catalog.city_profiles[a].display_name < catalog.city_profiles[b].display_name)
	for i: int in range(3):
		var choice: OptionButton = OptionButton.new()
		for id: String in ids:
			var p: Dictionary = catalog.city_profiles[id]
			choice.add_item("%s — %s • %.1fM residents" % [p.display_name, p.country, int(p.reference_population_2025) / 1000000.0])
			choice.set_item_metadata(choice.item_count - 1, id)
		choice.select(i)
		city_box.add_child(choice)
		city_choices.append(choice)
	city_box.hide()
	random_cities = _label("", "MetaLabel")
	_update_random_cities()
	seed_input.value_changed.connect(func(_value: float) -> void: _update_random_cities())
	city_mode.item_selected.connect(func(index: int) -> void:
		city_box.visible = index == 1
		random_cities.visible = index == 0)
	_label("Manual cities must be unique. The first is your starting city.\nDifficulty changes competitor strategy; capital changes only your company.", "MetaLabel")
	error_label = _label("", "NegativeLabel")
	_button("Start Sandbox", _start_sandbox).theme_type_variation = "PrimaryButton"
	_button("Back", show_title)

func _update_random_cities() -> void:
	var lines: PackedStringArray = []
	for p: Dictionary in CityProfiles.select(catalog.city_profiles,int(seed_input.value)):
		lines.append("%s — %s • %.1fM residents" % [p.display_name,p.country,int(p.reference_population_2025)/1000000.0])
	random_cities.text = "\n".join(lines)

func setup_values() -> Dictionary:
	seed_input.apply()
	var values: Dictionary = SessionSetup.defaults()
	values.company_name = company.text
	values.era = [2012, 2022][era.selected]
	values.difficulty = StrategicAI.DIFFICULTY_IDS[difficulty.selected]
	values.starting_capital = SessionSetup.CAPITAL[capital.selected]
	values.seed = int(seed_input.value)
	if city_mode.selected == 1:
		for choice: OptionButton in city_choices: values.city_profiles.append(str(choice.get_item_metadata(choice.selected)))
	return values

func _start_sandbox() -> void:
	var session: GameSession = GameSession.new()
	if session.start_setup(setup_values()): enter_game(session)
	else:
		error_label.text = session.message
		get_node("/root/UIService").play("error")

func show_tutorial() -> void:
	_clear()
	_label("Learn by running a real company", "TitleLabel")
	_label("Twelve short objectives guide you from your first sale to regional trade.\nYou will use the full economy, with $1,000,000 to explore.\n\n2022 • Standard • Istanbul, Sydney and Vancouver\nStart paused. Save whenever you like; progress resumes exactly.")
	_button("Begin Tutorial", func() -> void:
		var session: GameSession = GameSession.new()
		if session.start_setup(SessionSetup.tutorial(), "tutorial"): enter_game(session))
	_button("Back", show_title)

func show_settings() -> void:
	_clear()
	_label("Application Settings", "TitleLabel")
	content.add_child(PreferencesPanel.new())
	_button("Back", show_title)

func show_load() -> void:
	if browser != null: browser.queue_free()
	browser = SaveBrowser.new()
	add_child(browser)
	var summaries: Dictionary = {}
	for slot: int in range(1, 4): summaries[slot] = SaveStore.new().inspect_file("user://saves/slot_%d.json" % slot)
	browser.configure("load", summaries)
	browser.slot_requested.connect(func(_mode: String, slot: int, _summary: Dictionary) -> void:
		var session: GameSession = GameSession.new()
		if session.load_game("user://saves/slot_%d.json" % slot): enter_game(session)
		else:
			browser.title = session.message
			get_node("/root/UIService").play("error"))
	browser.popup_centered()

func enter_game(session: GameSession) -> void:
	var game: Control = load("res://scenes/game.tscn").instantiate()
	game.session = session
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()
