extends Node

signal preferences_changed
var preferences: AppPreferences = AppPreferences.new()
var player: AudioStreamPlayer
var sounds: Dictionary = {}
var known_tooltips: Dictionary = {}
var tooltip_elapsed: float = 0.0

func _ready() -> void:
	preferences.load_from()
	player = AudioStreamPlayer.new()
	add_child(player)
	for id: String in ["click", "success", "error", "construction", "research", "tutorial"]:
		sounds[id] = load("res://assets/audio/" + id + ".wav")
	get_tree().node_added.connect(func(node: Node) -> void: _attach.call_deferred(node))
	apply()

func play(id: String) -> void:
	if preferences.mute or not sounds.has(id): return
	player.volume_db = linear_to_db(maxf(0.0001, preferences.master_volume * preferences.ui_volume))
	player.stream = sounds[id]
	player.play()

func _attach(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is Control: node.add_to_group("presentation_controls")
	if node is Button:
		node.pressed.connect(func() -> void: play("click"))
	if node is Control and not node.tooltip_text.is_empty():
		known_tooltips[node.get_instance_id()] = node.tooltip_text
		if not preferences.tooltips: node.tooltip_text = ""

func _process(delta: float) -> void:
	if preferences.tooltips: return
	tooltip_elapsed += delta
	if tooltip_elapsed < 0.25: return
	tooltip_elapsed = 0.0
	_suppress_tooltips()

func _suppress_tooltips() -> void:
	for node: Node in get_tree().get_nodes_in_group("presentation_controls"):
		if not node.tooltip_text.is_empty():
			known_tooltips[node.get_instance_id()] = node.tooltip_text
			node.tooltip_text = ""

func apply() -> void:
	if not preferences.tooltips: _suppress_tooltips()
	get_tree().root.content_scale_factor = preferences.ui_scale / 100.0
	var minimum: Vector2i = Vector2i(Vector2(1024, 640) * get_tree().root.content_scale_factor)
	get_tree().root.min_size = minimum
	for id: int in known_tooltips.keys():
		var node: Object = instance_from_id(id)
		if not is_instance_valid(node): known_tooltips.erase(id)
		else: node.tooltip_text = known_tooltips[id] if preferences.tooltips else ""
	preferences_changed.emit()

func persist() -> void:
	if preferences.save_to() != OK: push_warning("Could not save application preferences.")
	apply()
