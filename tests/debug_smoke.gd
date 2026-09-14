extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/debug.tscn")
	var screen: Control = scene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.call("_advance", 30)
	await process_frame
	var sim: Economy = screen.get("sim")
	if sim.clock.tick != 30 or not sim.invariant_errors().is_empty():
		printerr("FAIL: Debug screen advance")
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/debug-smoke.png")
	print("DEBUG SMOKE: scene loaded and advanced 30 days successfully")
	quit(0)
