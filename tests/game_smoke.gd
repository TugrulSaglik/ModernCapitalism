extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn")
	var screen: Control = packed.instantiate()
	root.add_child(screen)
	await process_frame
	var session: GameSession = screen.get("session")
	var city: CityView = screen.get("city")
	screen.set("save_directory", "res://.godot/game-smoke-saves")
	check(session.mode == "sandbox" and session.sim.starting_year == 2022, "Graphical sandbox defaults")
	var camera_size: float = city.camera.size
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	city.call("_unhandled_input", wheel)
	check(city.camera.size < camera_size, "City camera zoom responds to wheel input")
	var focus_before: Vector3 = city.focus
	city.pan(Vector3(-1, 0, -1), 0.5)
	check(city.focus != focus_before, "City camera pan updates its focus")
	# Drive the same game host callback that receives frame deltas.
	screen.set_process(false)
	screen.call("_process", 3.0)
	check(session.sim.clock.tick >= 3, "Game host advances continuously")
	session.time.set_speed(0)
	var tick: int = session.sim.clock.tick
	screen.call("_process", 3.0)
	check(session.sim.clock.tick == tick, "HUD pause stops economic time")
	var panel: FacilityPanel = screen.get("inspector")
	panel.price.value = 400.0
	panel.apply_price.pressed.emit()
	check(session.sim.pending_commands.size() == 1, "Inspector submits a queued command")
	session.time.set_speed(1)
	screen.call("_process", 1.0)
	session.time.set_speed(0)
	check(session.sim.facility("20_player").price == 40000, "Inspector price applies on tick")
	await physics_frame
	var rival: StaticBody3D = city.buildings["11_nova"].body
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = city.camera.unproject_position(rival.global_position)
	city.call("_unhandled_input", click)
	check(panel.selected_id == "11_nova" and panel.apply_price.disabled, "City click selects rival and controls become read-only")
	screen.call("_save")
	var expected: Dictionary = session.snapshot()
	session.time.set_speed(16)
	screen.call("_process", 2.0)
	screen.call("_load")
	check(JSON.stringify(SaveStore.encode(expected), "", true, true) == JSON.stringify(SaveStore.encode(session.snapshot()), "", true, true), "HUD load restores complete state")
	screen.call("_show_settings")
	var entry: LineEdit = screen.get("debug_entry")
	entry.text = DebugConfig.PASSWORD
	screen.call("_unlock_debug")
	check(session.debug_unlocked and screen.get("debug_panel").visible and entry.text.is_empty(), "Settings unlock and clear password")
	var cash: int = session.sim.companies.player.cash
	screen.call("_debug", "cash", 1000000)
	check(session.sim.companies.player.cash == cash + 1000000, "Graphical debug cash API")
	screen.call("_new_session", 2012)
	session.time.set_speed(0)
	screen.call("select_facility", "12_advanced")
	check(not session.sim.product_public("advanced_phone") and panel.info.text.contains("ERA LOCKED"), "2012 facility inspector shows lock")
	check(not session.debug_unlocked, "New graphical session locks cheats")
	session.start(2012, 42, "tutorial")
	screen.call("_show_settings")
	check(not entry.get_parent().visible, "Tutorial Settings hides Debug entry")
	screen.get("settings").hide()
	screen.call("_new_session", 2022)
	session.time.set_speed(0)
	screen.call("refresh")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/game-smoke.png")
	check(session.sim.invariant_errors().is_empty(), "Graphical session preserves invariants")
	print("GAME SMOKE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
