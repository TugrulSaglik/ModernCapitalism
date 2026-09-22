class_name SaveBrowser
extends AcceptDialog

signal slot_requested(mode: String, slot_number: int, summary: Dictionary)

var browser_mode: String = "save"
var slot_buttons: Dictionary = {}
var slot_labels: Dictionary = {}
var summaries: Dictionary = {}

func _ready() -> void:
	title = "Save Game"
	max_size = Vector2i(720, 560)
	get_ok_button().hide()
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(640, 390)
	add_child(column)
	var heading: Label = Label.new()
	heading.name = "Heading"
	heading.text = "SAVE GAME"
	heading.theme_type_variation = "TitleLabel"
	column.add_child(heading)
	var help: Label = Label.new()
	help.name = "Help"
	help.text = "Choose one of the three fixed save slots."
	help.theme_type_variation = "MetaLabel"
	column.add_child(help)
	for slot_number: int in range(1, 4):
		var panel: PanelContainer = PanelContainer.new()
		panel.theme_type_variation = "SectionPanel"
		column.add_child(panel)
		var row: HBoxContainer = HBoxContainer.new()
		panel.add_child(row)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(470, 82)
		row.add_child(label)
		var action: Button = Button.new()
		action.custom_minimum_size.x = 110
		action.focus_mode = Control.FOCUS_NONE
		row.add_child(action)
		action.pressed.connect(func() -> void:
			slot_requested.emit(browser_mode, slot_number, summaries.get(slot_number, {})))
		slot_labels[slot_number] = label
		slot_buttons[slot_number] = action

func configure(browser_mode: String, values: Dictionary) -> void:
	self.browser_mode = browser_mode
	summaries = values.duplicate(true)
	title = "Save Game" if self.browser_mode == "save" else "Load Game"
	var heading: Label = get_node_or_null("VBoxContainer/Heading")
	if heading == null:
		# The generated VBoxContainer is unnamed until it enters the scene tree.
		heading = find_child("Heading", true, false)
	if heading != null: heading.text = title.to_upper()
	var help: Label = find_child("Help", true, false)
	if help != null:
		help.text = "Choose a slot to save the current session." if self.browser_mode == "save" else "Choose a compatible save to replace the current session."
	for slot_number: int in range(1, 4):
		var summary: Dictionary = summaries.get(slot_number, {"state": "empty", "reason": "Empty"})
		var state: String = str(summary.get("state", "unreadable"))
		var lines: PackedStringArray = ["SLOT %d" % slot_number]
		if state == "valid":
			lines.append("%s" % summary.get("company", "Player company"))
			lines.append("%s  •  %s  •  %s start" % [summary.get("date", "Unknown date"), str(summary.get("mode", "sandbox")).capitalize(), summary.get("starting_year", "?")])
			if not str(summary.get("modified", "")).is_empty(): lines.append("Saved: " + str(summary.modified))
		elif state == "empty":
			lines.append("Empty")
		else:
			lines.append("Unavailable")
			lines.append(str(summary.get("reason", "Unreadable save")))
		slot_labels[slot_number].text = "\n".join(lines)
		slot_labels[slot_number].theme_type_variation = "NegativeLabel" if state in ["unreadable", "incompatible"] else "BodyLabel"
		var action: Button = slot_buttons[slot_number]
		action.text = "Save here" if self.browser_mode == "save" else "Load"
		action.disabled = self.browser_mode == "load" and state != "valid"
		action.tooltip_text = ("Overwrite this occupied slot." if state != "empty" else "Save to this empty slot.") if self.browser_mode == "save" else ("Load this saved session." if state == "valid" else str(summary.get("reason", "This slot is empty.")))
