extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control = load("res://scenes/game.tscn").instantiate()
	game.city_settings = {"preset": "legacy"}
	game.save_directory = "res://.godot/release-polish-followup-saves"
	root.add_child(game)
	game.session.time.set_speed(0)
	await process_frame
	await process_frame
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.factor = 3.0
	game.city.camera.size = 20.0
	game.city._unhandled_input(wheel)
	check(is_equal_approx(game.city.camera.size, 26.0), "wheel gesture factor")
	wheel.factor = 1000.0
	game.city._unhandled_input(wheel)
	check(is_equal_approx(game.city.camera.size, game.city.max_zoom), "wheel maximum clamp")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	game.city._unhandled_input(wheel)
	check(is_equal_approx(game.city.camera.size, 18.0), "wheel minimum clamp")
	game._show_menu()
	await process_frame
	await process_frame
	check(game.app_menu.size.y <= 410, "first menu opening fits contents")
	var theme: Theme = ModernUITheme.build()
	check(theme.get_stylebox("scroll", "VScrollBar").get_minimum_size().x >= 12, "vertical scroll track is visible")
	check(theme.get_stylebox("grabber", "VScrollBar").get_minimum_size().x >= 12, "vertical scroll thumb is usable")
	check(theme.get_stylebox("scroll", "HScrollBar").get_minimum_size().y >= 12, "horizontal scroll track is visible")
	print("RELEASE POLISH FOLLOWUP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
