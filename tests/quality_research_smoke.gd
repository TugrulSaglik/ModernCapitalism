extends SceneTree

var screen: Control
var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func capture(name_value: String) -> void:
	screen.refresh()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/7b3a-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Capture " + name_value)

func build(kind: String, product: String = "") -> SimFacility:
	var sim: Economy = screen.session.sim
	var definition: Dictionary = sim.catalog.facility_types[kind]
	var sites: Array[Vector2i] = sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "Visual construction site")
	var id: String = "built_%06d" % sim.city.next_facility
	check(screen.session.submit({"type": "build_facility", "archetype": kind, "product": product, "x": sites[0].x, "y": sites[0].y}), "Visual construction " + kind)
	screen._build_city()
	return sim.facility(id)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	var lab: SimFacility = build("research_center")
	screen.select_facility(lab.id)
	var panel: FacilityPanel = screen.inspector
	for index: int in range(panel.research_choices.item_count):
		var project: Variant = panel.research_choices.get_item_metadata(index)
		if project is Dictionary and project.get("kind") == "product_quality" and project.get("product") == "smartphone":
			panel.research_choices.select(index)
			break
	panel.refresh()
	check(panel.research_info.text.contains("PRODUCT QUALITY PROJECT") and panel.research_info.text.contains("Maximum: 5"), "Quality project is distinct and bounded")
	panel.assign_research.pressed.emit()
	for day: int in range(12): screen.session.sim.step()
	panel.refresh()
	check(panel.research_info.text.contains("120 / 300") and panel.research_info.text.contains("$25.00/day"), "Quality project progress and cost readable")
	await capture("01-quality-project")
	for day: int in range(18): screen.session.sim.step()
	check(screen.session.sim.companies.player.product_quality_level("smartphone") == 1, "Visual workflow completes quality level")
	var factory: SimFacility = build("assembly_plant", "smartphone")
	var owner: SimCompany = screen.session.sim.companies.player
	for product: String in screen.session.sim.catalog.products.smartphone.inputs:
		var units: int = int(screen.session.sim.catalog.products.smartphone.inputs[product])
		check(factory.inventory.add(product, units, units * 100, 50), "Seed visual component " + product)
		owner.spend(units * 100)
		owner.purchases += units * 100
	check(screen.session.sim.produce(factory) == 1 and factory.inventory.quality("smartphone") == 52, "Improved factory produces quality-bearing output")
	screen.select_facility(factory.id)
	panel = screen.inspector
	check(panel.info.text.contains("Product quality R&D L1/5") and panel.info.text.contains("Q52"), "Factory read model exposes level and output quality")
	await capture("02-factory-quality")
	check(screen.session.sim.invariant_errors().is_empty(), "Rendered quality R&D economy reconciles")
	print("M7B3A VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
