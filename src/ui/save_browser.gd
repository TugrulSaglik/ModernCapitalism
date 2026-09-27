class_name SaveBrowser
extends AcceptDialog

signal game_loaded

var browser_mode: String = "save"
var directory: String = "user://saves"
var session: GameSession
var store: SaveStore = SaveStore.new()
var summaries: Array[Dictionary] = []
var rows: VBoxContainer
var heading: Label
var feedback: Label
var create_button: Button
var scroller: ScrollContainer
var name_prompt: ConfirmationDialog
var name_input: LineEdit
var confirmation: ConfirmationDialog
var pending_action: String = ""
var pending_filename: String = ""
var pending_label: String = ""

func _ready() -> void:
	title = "Save Game"
	get_ok_button().text = "Back"
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 420)
	add_child(column)
	heading = Label.new()
	heading.theme_type_variation = "TitleLabel"
	column.add_child(heading)
	create_button = Button.new()
	create_button.text = "Create New Save"
	create_button.pressed.connect(func() -> void: _request_name("create", {}))
	column.add_child(create_button)
	scroller = ScrollContainer.new()
	scroller.custom_minimum_size.y = 320
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroller)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(rows)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	name_prompt = ConfirmationDialog.new()
	name_prompt.title = "Save name"
	add_child(name_prompt)
	name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(420, 40)
	name_input.max_length = 100
	name_input.placeholder_text = "Save name"
	name_prompt.add_child(name_input)
	name_input.text_changed.connect(func(value: String) -> void: name_prompt.get_ok_button().disabled = value.strip_edges().is_empty())
	name_prompt.confirmed.connect(_commit_name)
	name_input.text_submitted.connect(func(_value: String) -> void:
		if not name_input.text.strip_edges().is_empty():
			name_prompt.hide()
			_commit_name())
	confirmation = ConfirmationDialog.new()
	confirmation.dialog_autowrap = true
	add_child(confirmation)
	confirmation.confirmed.connect(_commit_action)

func configure(mode: String, save_directory: String, game_session: GameSession = null) -> void:
	browser_mode = mode
	directory = save_directory
	session = game_session
	title = "Save Game" if mode == "save" else "Load Game"
	heading.text = title.to_upper()
	create_button.visible = mode == "save"
	feedback.text = ""
	refresh_files()

func refresh_files() -> void:
	summaries = store.discover(directory)
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if summaries.is_empty():
		var empty: Label = Label.new()
		empty.text = "No saved games yet."
		rows.add_child(empty)
	for summary: Dictionary in summaries:
		var panel: PanelContainer = PanelContainer.new()
		rows.add_child(panel)
		var column: VBoxContainer = VBoxContainer.new()
		panel.add_child(column)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = str(summary.label) + "\n"
		if summary.state == "valid":
			label.text += "%s • %s\n%s • %s • %s\n" % [summary.company, summary.date, str(summary.mode).capitalize(), summary.difficulty_name, summary.city]
		else: label.text += str(summary.get("reason", "Unavailable save")) + "\n"
		label.text += "Modified: " + str(summary.modified) + " UTC"
		column.add_child(label)
		var actions: HBoxContainer = HBoxContainer.new()
		column.add_child(actions)
		var action: Button = _button(actions, "Overwrite" if browser_mode == "save" else "Load", func() -> void: _request_action("overwrite" if browser_mode == "save" else "load", summary))
		action.disabled = browser_mode == "load" and summary.state != "valid"
		if browser_mode == "save" and summary.state == "valid": _button(actions, "Rename", func() -> void: _request_name("rename", summary))
		_button(actions, "Delete", func() -> void: _request_action("delete", summary))

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _request_name(action: String, summary: Dictionary) -> void:
	pending_action = action
	pending_filename = str(summary.get("filename", ""))
	name_input.text = str(summary.get("label", "%s — %s" % [session.sim.companies[session.player_company].display_name, session.sim.clock.date_string()]))
	name_prompt.get_ok_button().disabled = false
	name_prompt.popup_centered(Vector2i(460, 120))
	name_input.grab_focus()
	name_input.select_all()

func _commit_name() -> void:
	var label: String = name_input.text.strip_edges()
	if label.is_empty(): return
	var ok: bool = false
	if pending_action == "create":
		pending_filename = store.unique_filename(directory)
		ok = store.save_named(directory, pending_filename, session.snapshot(), label)
	elif pending_action == "rename": ok = store.rename_save(directory, pending_filename, label)
	_finish(ok, "Saved “%s”." % label if pending_action == "create" else "Renamed to “%s”." % label)

func _request_action(action: String, summary: Dictionary) -> void:
	pending_action = action
	pending_filename = str(summary.filename)
	pending_label = str(summary.label)
	confirmation.title = {"overwrite": "Overwrite save", "load": "Load saved game", "delete": "Delete save"}[action]
	confirmation.dialog_text = "%s?\n\n%s\n%s • %s\n\n%s" % [confirmation.title, pending_label, summary.get("company", "Unavailable company"), summary.get("date", "Unknown date"), "Only this save file will be deleted. This cannot be undone." if action == "delete" else "This replaces the selected save file." if action == "overwrite" else "Current unsaved progress will be replaced."]
	confirmation.popup_centered(Vector2i(480, 240))

func _commit_action() -> void:
	var ok: bool = false
	match pending_action:
		"overwrite": ok = store.save_named(directory, pending_filename, session.snapshot(), pending_label)
		"delete": ok = store.delete_save(directory, pending_filename)
		"load":
			if session == null: session = GameSession.new()
			ok = session.load_game(directory.path_join(pending_filename))
			if not ok: store.error = session.message
			else:
				hide()
				game_loaded.emit()
				return
	_finish(ok, ("Deleted “%s”." if pending_action == "delete" else "Saved “%s”.") % pending_label)

func _finish(ok: bool, message: String) -> void:
	var error: String = store.error
	if ok: refresh_files()
	feedback.text = message if ok else error
	feedback.theme_type_variation = "PositiveLabel" if ok else "NegativeLabel"
	get_node("/root/UIService").play("success" if ok else "error")

func close_child() -> bool:
	for dialog: Window in [name_prompt, confirmation]:
		if dialog.visible:
			dialog.hide()
			return true
	return false
