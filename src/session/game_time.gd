class_name GameTime
extends RefCounted

const SPEEDS: Array[int] = [0, 1, 2, 4, 16]
var speed: int = 1
var last_speed: int = 1
var seconds_per_day: float = 1.0
var accumulator: float = 0.0
const MAX_TICKS_PER_FRAME: int = 64

func set_speed(value: int) -> bool:
	if value not in SPEEDS:
		return false
	speed = value
	if value > 0:
		last_speed = value
	return true

func toggle_pause() -> void:
	set_speed(last_speed if speed == 0 else 0)

func advance(elapsed: float, sim: Economy) -> int:
	if speed == 0 or elapsed < 0.0 or not is_finite(elapsed):
		return 0
	accumulator += elapsed * speed
	var days: int = 0
	while accumulator + 0.000000001 >= seconds_per_day and days < MAX_TICKS_PER_FRAME:
		accumulator = maxf(0.0, accumulator - seconds_per_day)
		sim.step()
		days += 1
	return days

func snapshot() -> Dictionary:
	return {"speed": speed, "last_speed": last_speed, "seconds_per_day": seconds_per_day, "accumulator": accumulator}
