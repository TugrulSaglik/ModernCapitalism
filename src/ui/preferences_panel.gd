class_name PreferencesPanel
extends VBoxContainer

func _ready() -> void:
	var service: Node = get_node("/root/UIService")
	var prefs: AppPreferences = service.preferences
	var heading: Label = Label.new()
	heading.text = "PRESENTATION & AUDIO"
	heading.theme_type_variation = "SectionLabel"
	add_child(heading)
	for field: String in ["master_volume", "ui_volume"]:
		var row: HBoxContainer = HBoxContainer.new()
		add_child(row)
		var label: Label = Label.new()
		label.text = field.replace("_", " ").capitalize()
		label.custom_minimum_size.x = 180
		row.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = prefs.get(field)
		slider.custom_minimum_size.x = 220
		row.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void:
			prefs.set(field, value)
			service.persist())
	var scale_choice: OptionButton = OptionButton.new()
	for value: int in [100, 110, 125]: scale_choice.add_item("UI scale: %d%%" % value)
	scale_choice.select([100, 110, 125].find(prefs.ui_scale))
	add_child(scale_choice)
	scale_choice.item_selected.connect(func(index: int) -> void:
		prefs.ui_scale = [100, 110, 125][index]
		service.persist())
	for field: String in ["high_contrast", "tooltips", "mute"]:
		var button: CheckBox = CheckBox.new()
		button.text = field.replace("_", " ").capitalize()
		button.button_pressed = prefs.get(field)
		add_child(button)
		button.toggled.connect(func(value: bool) -> void:
			prefs.set(field, value)
			service.persist())
