extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	var only_istanbul: bool = "--only=istanbul" in OS.get_cmdline_user_args()
	if only_istanbul: screen.city_settings = {"preset": "legacy"}
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	var directory: String = "res://.godot/m11r2-screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	# Default seed 42 provides Tokyo; seed 108 provides Istanbul and Sydney.
	for profile_id: String in ["tokyo", "istanbul", "sydney"]:
		if only_istanbul and profile_id != "istanbul": continue
		if profile_id == "istanbul":
			if not screen.session.start(2022, 108, "sandbox", {"archetype": "estuary"}):
				quit(1)
				return
			screen.session.time.set_speed(0)
		var city_id: String = "highland" if profile_id == "sydney" else "metro"
		screen.session.select_city(city_id)
		screen._build_city()
		var map: CityMap = screen.session.sim.cities[city_id]
		if map.profile.id != profile_id:
			printerr("Unexpected screenshot profile")
			quit(1)
			return
		var center: Dictionary = map.generation.centers[0]
		screen.city.focus_cell(int(center.x), int(center.y))
		if profile_id == "istanbul":
			# Choose the bridge with the most surrounding development, not a full-map fit.
			var best: Vector2i = Vector2i(-1, -1)
			var best_score: int = -1
			for key: String in map.bridges:
				var parts: PackedStringArray = key.split(",")
				var p: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
				var score: int = 0
				for b: Dictionary in map.ambient.values():
					if Vector2(p).distance_to(Vector2(b.x, b.y)) < 22: score += 1
				if score > best_score:
					best = p
					best_score = score
			if best.x < 0:
				printerr("Missing bridge screenshot")
				quit(1)
				return
			var neighborhood: Vector2 = Vector2.ZERO
			var nearby: int = 0
			for b: Dictionary in map.ambient.values():
				if Vector2(best).distance_to(Vector2(b.x, b.y)) < 22:
					neighborhood += Vector2(b.x, b.y)
					nearby += 1
			var focus: Vector2 = Vector2(best).lerp(neighborhood / maxi(1, nearby), 0.6)
			screen.city.focus_cell(focus.x, focus.y)
		screen.status_override = "%s, %s • Population %s • %d × %d cells • Neighborhood view" % [map.display_name, map.profile.country, map.population_text(), map.width, map.depth]
		screen.refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = directory.path_join(profile_id + ".png")
		var result: Error = root.get_texture().get_image().save_png(path)
		print("11R2 screenshot ", profile_id, " terrain=", map.generation.archetype, " size=", map.width, "x", map.depth, " camera=", screen.city.camera.size, " path=", ProjectSettings.globalize_path(path), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if result != OK:
			quit(1)
			return
	quit(0)
