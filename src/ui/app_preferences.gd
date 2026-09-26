class_name AppPreferences
extends RefCounted

var master_volume: float = 0.7
var ui_volume: float = 0.6
var mute: bool = false
var ui_scale: int = 100
var high_contrast: bool = false
var tooltips: bool = true
const FIELDS: Array[String] = ["master_volume", "ui_volume", "mute", "ui_scale", "high_contrast", "tooltips"]

func save_to(path: String = "user://settings.cfg") -> Error:
	var config: ConfigFile = ConfigFile.new()
	for field: String in FIELDS: config.set_value("presentation", field, get(field))
	return config.save(path)

func load_from(path: String = "user://settings.cfg") -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK: return
	for field: String in FIELDS:
		var value: Variant = config.get_value("presentation", field, get(field))
		if typeof(value) != typeof(get(field)): continue
		if field in ["master_volume", "ui_volume"] and (not is_finite(value) or value < 0.0 or value > 1.0): continue
		if field == "ui_scale" and value not in [100, 110, 125]: continue
		set(field, value)
