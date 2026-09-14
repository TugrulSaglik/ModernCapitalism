class_name SimClock
extends RefCounted

var year: int
var month: int = 1
var day: int = 1
var tick: int = 0

func _init(start_year: int) -> void:
	year = start_year

func advance() -> void:
	tick += 1
	day += 1
	var lengths: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		lengths[1] = 29
	if day > lengths[month - 1]:
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1

func date_string() -> String:
	return "%04d-%02d-%02d" % [year, month, day]

func snapshot() -> Dictionary:
	return {"year": year, "month": month, "day": day, "tick": tick}
