extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func command(session: GameSession, request: Dictionary) -> bool:
	var accepted: bool = session.submit(request)
	check(accepted, "command %s: %s" % [request.type, session.message])
	session.sim.process_commands()
	return accepted

func build(session: GameSession, type_id: String, product: String) -> String:
	var d: Dictionary = session.sim.catalog.facility_types[type_id]
	var sites: Array = session.sim.city.valid_sites(int(d.width), int(d.depth))
	for site: Vector2i in sites:
		var request: Dictionary = {"type":"build_facility","company":"player","city":"metro","archetype":type_id,"product":product,"x":int(site.x),"y":int(site.y)}
		if not session.sim.command_error(request).is_empty(): continue
		var id: String = "built_%06d" % session.sim.next_facility_id
		if command(session, request): return id
	check(false, "No affordable site: " + type_id)
	return ""

func run() -> void:
	var catalog: SimCatalog = SimCatalog.new()
	check(catalog.load_data(), "catalog " + str(catalog.errors))
	check(catalog.version == 13 and catalog.products.size() == 68, "catalog totals")
	for product: String in catalog.products:
		check(catalog.manufacturable_product(product), "manufacturable " + product)
		var p: Dictionary = catalog.products[product]
		var recipe_cost: int = int(p.conversion_cost)
		for input: String in p.inputs: recipe_cost += int(p.inputs[input]) * int(catalog.products[input].reference_price)
		check(recipe_cost < int(p.reference_price), "positive conversion/wholesale margin " + product)
		if catalog.consumer_product(product): check(not catalog.local_values(product).is_empty(), "Local " + product)
	check(not catalog.product_public("electric_vehicle", 2012) and catalog.product_public("electric_vehicle", 2022), "EV era gate")
	check(catalog.product_public("compact_car", 2012), "conventional automotive 2012")
	for year: int in [2012, 2022]:
		for difficulty: String in StrategicAI.DIFFICULTY_IDS:
			for cash: int in SessionSetup.CAPITAL:
				var config: Dictionary = SessionSetup.defaults()
				config.era = year
				config.difficulty = difficulty
				config.starting_capital = cash
				check(SessionSetup.error(config, catalog.city_profiles).is_empty(), "setup valid combination")
	var invalid: Dictionary = SessionSetup.defaults()
	invalid.city_profiles = ["istanbul", "istanbul", "sydney"]
	check(not SessionSetup.error(invalid, catalog.city_profiles).is_empty(), "duplicate profiles rejected")
	invalid.city_profiles = ["istanbul"]
	check(not SessionSetup.error(invalid, catalog.city_profiles).is_empty(), "three cities required")
	invalid = SessionSetup.defaults()
	invalid.company_name = "\n"
	check(not SessionSetup.error(invalid, catalog.city_profiles).is_empty(), "blank company rejected")
	var prefs: AppPreferences = AppPreferences.new()
	prefs.mute = true
	prefs.ui_scale = 125
	prefs.high_contrast = true
	prefs.tooltips = false
	prefs.master_volume = 0.25
	check(prefs.save_to("res://.godot/m12-settings.cfg") == OK, "settings write")
	var restored_prefs: AppPreferences = AppPreferences.new()
	restored_prefs.load_from("res://.godot/m12-settings.cfg")
	for field: String in AppPreferences.FIELDS: check(restored_prefs.get(field) == prefs.get(field), "settings " + field)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "title startup")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	check(title.content.get_child_count() == 8, "title five actions")
	title.show_setup()
	check(title.setup_values() == SessionSetup.defaults(), "setup UI defaults")
	title.city_mode.select(1)
	check(title.setup_values().city_profiles.size() == 3, "manual UI three profiles")
	title.show_tutorial()
	check(title.content.get_child_count() == 4, "tutorial introduction")
	title.show_settings()
	check(title.content.get_child(1) is PreferencesPanel, "global settings from title")
	title.show_load()
	check(title.browser.slot_buttons.size() == 3, "shared load browser")
	title.queue_free()
	await process_frame
	var small: GameSession = GameSession.new()
	var setup: Dictionary = SessionSetup.defaults()
	setup.company_name = "Atlas & Sons"
	setup.starting_capital = 10000000
	setup.difficulty = "relaxed"
	setup.city_profiles = ["vancouver","sydney","barcelona"]
	check(small.start_setup(setup), "custom setup")
	check(small.sim.companies.player.display_name == "Atlas & Sons" and small.sim.companies.player.cash == 10000000, "custom name/capital")
	check(small.sim.city.profile.id == "vancouver" and small.sim.companies.rival.cash == 20000000, "primary profile and AI cash unchanged")
	check(small.save_game("res://.godot/m12-setup.json"), "custom save")
	var restored: GameSession = GameSession.new()
	check(restored.load_game("res://.godot/m12-setup.json"), "custom restore " + restored.message)
	if restored.sim != null: check(restored.snapshot() == small.snapshot(), "custom exact restore")
	for b: Dictionary in small.sim.city.ambient.values():
		check(b.has("roof") and b.has("orientation") and b.has("tone"), "ambient metadata")
	var ambient_parent: Node3D = Node3D.new()
	root.add_child(ambient_parent)
	AmbientDetails.build(ambient_parent, small.sim.city.ambient, func(x: float, y: float) -> Vector3: return Vector3(x,0,y), func(color: Color) -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		return material)
	check(ambient_parent.get_child_count() < 600 and ambient_parent.get_child_count() > 50, "bounded detailed ambient groups")
	for child: Node in ambient_parent.get_children(): check(child is MultiMeshInstance3D, "batched component")
	ambient_parent.queue_free()
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	screen.session = small
	root.size = Vector2i(1280,800)
	root.add_child(screen)
	screen.set_process(false)
	check(screen.session == small, "prepared session is not restarted by game screen")
	screen._show_settings()
	check(screen.current_difficulty.text.contains("Relaxed") and screen.current_difficulty.text.contains("Vancouver"), "immutable session summary")
	check(screen.find_child("NewSandboxDifficulty",true,false) == null, "in-game setup removed")
	screen.settings.hide()
	screen.return_confirmation.popup_centered()
	check(screen.world_input_blocked(), "return-to-title confirmation blocks world input")
	screen.return_confirmation.hide()
	var service: Node = root.get_node("UIService")
	for scale_value: int in [100,110,125]:
		service.preferences.ui_scale = scale_value
		service.preferences.high_contrast = true
		service.apply()
		await process_frame
		check(is_equal_approx(root.content_scale_factor, scale_value / 100.0), "UI scale applies")
		check(screen.theme.get_color("font_color","Label") == Color.WHITE, "high contrast applies")
	service.preferences.ui_scale = 100
	service.preferences.high_contrast = false
	service.apply()
	screen.queue_free()
	await process_frame
	_tutorial()
	_ai_breadth()
	var preset: ConfigFile = ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "export preset parse")
	print("M12 focused: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _tutorial() -> void:
	var s: GameSession = GameSession.new()
	check(s.start_setup(SessionSetup.tutorial(), "tutorial"), "tutorial fixed setup")
	var guide: TutorialController = s.tutorial
	check(not guide.evaluate(s.sim), "controls require acknowledgement")
	guide.observe("controls")
	check(guide.evaluate(s.sim) and guide.step == 1, "controls complete")
	guide.observe("overview")
	check(guide.evaluate(s.sim), "overview complete")
	guide.observe("retail")
	check(guide.evaluate(s.sim), "existing retailer complete")
	check(not guide.evaluate(s.sim), "sourcing cannot complete on failed action")
	check(not s.submit({"type":"set_supplier","facility":"20_player","product":"missing"}), "rejected source")
	command(s,{"type":"set_supplier","facility":"20_player","product":"smartphone","supplier":""})
	check(guide.evaluate(s.sim), "configured source complete")
	for day: int in range(25):
		if guide.satisfied("sale",s.sim): break
		s.sim.step()
	check(guide.evaluate(s.sim), "real sale complete")
	var plant: String = build(s,"materials_plant","flour")
	for day: int in range(25):
		if guide.satisfied("production",s.sim): break
		s.sim.step()
	check(not plant.is_empty() and guide.evaluate(s.sim), "real production complete")
	var warehouse: String = build(s,"warehouse","flour")
	command(s,{"type":"set_warehouse_target","facility":warehouse,"product":"flour","quantity":10})
	check(guide.evaluate(s.sim), "warehouse complete")
	check(s.save_game("res://.godot/m12-tutorial.json"), "tutorial save")
	var loaded: GameSession = GameSession.new()
	check(loaded.load_game("res://.godot/m12-tutorial.json"), "tutorial load " + loaded.message)
	if loaded.sim != null: check(loaded.snapshot() == s.snapshot(), "exact tutorial step and state")
	var lab: String = build(s,"research_center","")
	command(s,{"type":"assign_research","facility":lab,"project":s.sim.product_quality_project("player","flour")})
	check(guide.evaluate(s.sim), "research complete")
	command(s,{"type":"set_advertising_budget","product":"smartphone","budget":100})
	s.sim.step()
	check(guide.evaluate(s.sim), "funded advertising complete")
	var hq: String = build(s,"corporate_headquarters","")
	command(s,{"type":"hire_staff","facility":hq,"role":"operations_manager","quantity":1})
	check(guide.evaluate(s.sim), "HQ staffing complete")
	for site: Vector2i in s.sim.city.valid_sites(1,1):
		var request: Dictionary = {"type":"develop_property","company":"player","city":"metro","property_type":"house","x":int(site.x),"y":int(site.y)}
		if s.sim.command_error(request).is_empty():
			command(s,request)
			break
	check(guide.evaluate(s.sim), "property complete")
	command(s,{"type":"import_goods","facility":warehouse,"product":"milk","quantity":1})
	check(guide.evaluate(s.sim) and guide.complete() and guide.step == 12, "trade and course complete")
	check(s.sim.invariant_errors().is_empty(), "tutorial accounting invariants " + str(s.sim.invariant_errors()))
	var skipped: TutorialController = TutorialController.new()
	skipped.skipped = true
	var copy: TutorialController = TutorialController.new()
	check(copy.restore(skipped.snapshot()) and copy.complete(), "skip persists")
	check(not copy.restore({"step":13,"skipped":false,"observations":{}}), "invalid step rejected")
	print("Tutorial finished at day ", s.sim.clock.tick, "; cash ", s.sim.companies.player.cash)

func _ai_breadth() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42,2022,SaveStore.DATA_PATH,{"preset":"legacy"}), "AI fixture")
	for product: String in ["bread","shirt","chair","compact_car"]:
		check(product in sim.strategic_ai.eligible_consumer_products(sim), "AI eligible " + product)
		var factory: String = sim.strategic_ai._production_archetype(sim,product)
		var store: String = sim.strategic_ai._retail_archetype(sim,product)
		check(not factory.is_empty() and not store.is_empty(), "AI compatible archetypes " + product)
		# A focused ordinary AI policy fixture: clear competitors' existing facilities,
		# restrict opportunity to this category and ask the real capital planner.
		for p: String in sim.catalog.products:
			if sim.catalog.consumer_product(p): sim.catalog.products[p].daily_demand = 1 if p != product else 10000
		var candidate: Dictionary = sim.strategic_ai._capital_command(sim,"rival",false,{},sim.strategic_ai.difficulty_profile("standard"),"metro")
		check(not candidate.is_empty(), "AI capital action " + product)
		check(sim.can_configure("rival",factory,product) and sim.can_configure("rival",store,product), "AI knowledge " + product)
