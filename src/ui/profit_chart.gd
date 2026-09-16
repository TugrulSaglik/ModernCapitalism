class_name ProfitChart
extends Control

var history: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(250, 70)
	mouse_filter = Control.MOUSE_FILTER_STOP

func update_history(records: Array[Dictionary]) -> void:
	history = records.slice(maxi(0, records.size() - 12))
	var lines: PackedStringArray = ["Monthly profit • newest at right • outlined bar is current month"]
	for entry: Dictionary in history: lines.append("%s: $%.2f" % [entry.month, entry.profit / 100.0])
	tooltip_text = "\n".join(lines)
	queue_redraw()

func _draw() -> void:
	var peak: int = 1
	for entry: Dictionary in history: peak = maxi(peak, absi(entry.profit))
	var baseline: float = size.y * 0.5
	draw_string(ThemeDB.fallback_font, Vector2(0, 12), "MONTHLY PROFIT  − / +", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b9cbd6"))
	draw_line(Vector2(0, baseline), Vector2(size.x, baseline), Color("8b9faa"))
	var width: float = size.x / 12.0
	for index: int in range(history.size()):
		var profit: int = history[index].profit
		var height: float = maxf(1.0, float(absi(profit)) / peak * (baseline - 17))
		var rect: Rect2 = Rect2((index + 12 - history.size()) * width + 2, baseline - height if profit >= 0 else baseline, width - 4, height)
		draw_rect(rect, Color("59d7a6") if profit >= 0 else Color("f28389"))
		if index == history.size() - 1: draw_rect(rect.grow(1), Color("ffe190"), false)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, size.y - 2), str(history[index].month).substr(5, 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b9cbd6"))
