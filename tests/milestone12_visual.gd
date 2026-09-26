extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,800):
		printerr("Unexpected capture size: ", image.get_size())
		failures += 1
	if image.save_png("res://docs/images/"+filename+".png") != OK: failures += 1
	print("Capture: docs/images/",filename,".png")

func neighborhood(screen: Control) -> void:
	var map: CityMap = screen.session.sim.city
	var best: Vector2 = Vector2.ZERO
	var best_score: float = -1.0
	for b: Dictionary in map.ambient.values():
		var point: Vector2 = Vector2(b.x,b.y)
		var kinds: Dictionary = {}
		var score: float = 0.0
		for other: Dictionary in map.ambient.values():
			if point.distance_to(Vector2(other.x,other.y)) < 13:
				kinds[other.kind] = true
				score += 1
		for plot: Dictionary in map.plots.values():
			if point.distance_to(Vector2(plot.x,plot.y)) < 15: score += 45
		score += kinds.size()*25
		if kinds.has("house"): score += 50
		if score > best_score:
			best_score = score
			best = point
	screen.city.focus_cell(best.x,best.y)
	screen.city.camera.size = 40
	screen.city._update_camera()

func run() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_factor = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/images"))
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	title.show_setup()
	title.city_mode.select(1)
	title.city_box.show()
	title.random_cities.hide()
	await capture("sandbox-setup")
	title.queue_free()
	await process_frame
	var session: GameSession = GameSession.new()
	if not session.start(2022,42,"sandbox",{"profiles":["jakarta","sydney","vancouver"],"width":384,"depth":288}):
		printerr("Large city failed")
		quit(1)
		return
	session.time.set_speed(0)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	screen.session = session
	root.add_child(screen)
	screen.set_process(false)
	screen.select_facility("")
	screen.refresh()
	neighborhood(screen)
	await capture("city-gameplay")
	print("Large city ",session.sim.city.width,"x",session.sim.city.depth," properties ",session.sim.city.ambient.size()," city scene nodes ",screen.city.find_children("*","",true,false).size()," detail batches ",screen.city.property_structures.get_child_count())
	screen.queue_free()
	await process_frame
	var tutorial: GameSession = GameSession.new()
	if not tutorial.start_setup(SessionSetup.tutorial(),"tutorial"):
		quit(1)
		return
	screen = load("res://scenes/game.tscn").instantiate()
	screen.session = tutorial
	root.add_child(screen)
	screen.set_process(false)
	screen.select_facility("")
	screen.refresh()
	neighborhood(screen)
	await capture("tutorial")
	print("M12 rendered smoke: ",failures," failures")
	quit(0 if failures == 0 else 1)
