extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func session(era: int = 2022, seed: int = 42) -> GameSession:
	var result: GameSession = GameSession.new()
	check(result.start(era, seed), "Start %d session" % era)
	return result

func build_lab(s: GameSession) -> SimFacility:
	var definition: Dictionary = s.sim.catalog.facility_types.research_center
	var sites: Array[Vector2i] = s.sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "R&D construction site")
	if sites.is_empty(): return null
	var id: String = "built_%06d" % s.sim.city.next_facility
	check(s.submit({"type": "build_facility", "archetype": "research_center", "product": "", "x": sites[0].x, "y": sites[0].y}), "Build R&D center")
	return s.sim.facility(id)

func submit_project(s: GameSession, lab: SimFacility, project: Dictionary) -> bool:
	var accepted: bool = s.submit({"type": "assign_research", "facility": lab.id, "project": project})
	if accepted: s.sim.process_commands()
	return accepted

func isolate(s: GameSession) -> void:
	for f: SimFacility in s.sim.facilities: f.operating = false
	for owner: SimCompany in s.sim.companies.values(): owner.ai = false

func _initialize() -> void:
	_catalog_and_eligibility()
	_projects_progress_and_accounting()
	_quality_formula_and_provenance()
	_ai_selection()
	_persistence()
	print("M7B3A TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog_and_eligibility() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for corruption: String in ["max", "work", "cost", "bonus", "fraction"]:
		var data: Dictionary = raw.duplicate(true)
		match corruption:
			"max": data.product_quality_research.max_level = 0
			"work": data.product_quality_research.base_work = -1
			"cost": data.product_quality_research.base_daily_cost = 0
			"bonus": data.product_quality_research.quality_bonus_per_level = 26
			"fraction": data.product_quality_research.base_work = 1.5
		var path: String = "res://.godot/7b3a-invalid-%s.json" % corruption
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data(path), "Reject invalid quality research " + corruption)
	var s: GameSession = session(2022)
	var owner: SimCompany = s.sim.companies.player
	check(s.sim.catalog.quality_max_level() == 5 and s.sim.catalog.quality_bonus(1) == 5, "Small explicit quality level model")
	check(owner.product_quality_levels.size() > 0 and owner.product_quality_level("smartphone") == 0, "Company-product levels start at zero")
	var project: Dictionary = s.sim.product_quality_project(owner.id, "smartphone")
	check(project == {"kind": "product_quality", "product": "smartphone", "target_level": 1}, "Structured next-level project")
	check(s.sim.research_project_error(owner.id, project).is_empty(), "Public known manufacturable product eligible")
	owner.known_technologies.erase(str(s.sim.catalog.products.smartphone.technology))
	check(not s.sim.research_project_error(owner.id, project).is_empty(), "Retail access without manufacturing knowledge is ineligible")
	owner.known_technologies.mobile_computing = -1
	check(not s.sim.research_project_error(owner.id, {"kind": "product_quality", "product": "missing", "target_level": 1}).is_empty(), "Unknown product rejected")
	check(not s.sim.research_project_error(owner.id, {"kind": "product_quality", "product": "smartphone", "target_level": 2}).is_empty(), "Skipping a level rejected")
	owner.product_quality_levels.smartphone = 5
	check(not s.sim.research_project_error(owner.id, s.sim.product_quality_project(owner.id, "smartphone")).is_empty(), "Maximum level rejected")
	var early: GameSession = session(2012)
	check(early.sim.research_project_error("player", early.sim.product_quality_project("player", "smartphone")).is_empty(), "2012 known product can improve immediately")
	check(not early.sim.research_project_error("player", early.sim.product_quality_project("player", "advanced_phone")).is_empty(), "2012 locked/unknown product cannot improve")

func _projects_progress_and_accounting() -> void:
	var s: GameSession = session()
	var lab: SimFacility = build_lab(s)
	var second: SimFacility = build_lab(s)
	isolate(s)
	lab.operating = true
	second.operating = true
	var owner: SimCompany = s.sim.companies.player
	var project: Dictionary = s.sim.product_quality_project(owner.id, "smartphone")
	check(submit_project(s, lab, project), "Assign product-quality project")
	check(not submit_project(s, second, project), "Reject duplicate exact project")
	second.operating = false
	var cash: int = owner.cash
	s.sim.step()
	check(owner.product_quality_progress.smartphone == {"target_level": 1, "progress": 10}, "Funded daily progress uses shared scheduler")
	check(cash - owner.cash == 3000 and owner.research_expense == 2500, "Quality research cost and overhead expensed")
	check(owner.monthly_history.back().research_expense == 2500 and s.sim.invariant_errors().is_empty(), "Statements and balance reconcile")
	check(s.submit({"type": "stop_research", "facility": lab.id}), "Queue quality project stop")
	s.sim.process_commands()
	check(lab.research_project.is_empty() and owner.product_quality_progress.smartphone.progress == 10, "Stop retains product-quality progress")
	check(submit_project(s, lab, project), "Resume retained project")
	owner.cash = 2499
	s.sim.step()
	check(owner.product_quality_progress.smartphone.progress == 10 and owner.cash == 1999, "Insufficient project cash stalls after funded overhead")
	owner.cash = 1000000
	owner.product_quality_progress.smartphone.progress = 290
	var brand: int = owner.brand("smartphone")
	s.sim.step()
	check(owner.product_quality_level("smartphone") == 1 and not owner.product_quality_progress.has("smartphone") and lab.research_project.is_empty(), "Completion increments exactly one level")
	check(owner.brand("smartphone") == brand, "Quality research does not change corporate brand")
	var next: Dictionary = s.sim.product_quality_project(owner.id, "smartphone")
	check(next.target_level == 2 and s.sim.project_work(next) == 600 and s.sim.project_cost(next) == 5000, "Repeatable level scaling is deterministic")

func _output_quality(level: int, component_quality: int = 50) -> int:
	var s: GameSession = session()
	var sim: Economy = s.sim
	var factory: SimFacility = sim.facility("10_orion")
	var owner: SimCompany = sim.companies[factory.company_id]
	owner.product_quality_levels.smartphone = level
	factory.stock_days = 7
	for product: String in sim.catalog.products.smartphone.inputs:
		var units: int = int(sim.catalog.products.smartphone.inputs[product])
		factory.inventory.add(product, units, units * 100, component_quality)
		owner.spend(units * 100)
	check(sim.produce(factory) == 1, "Produce quality fixture level %d" % level)
	return factory.inventory.quality("smartphone")

func _quality_formula_and_provenance() -> void:
	var qualities: Array[int] = []
	for level: int in range(6): qualities.append(_output_quality(level))
	for level: int in range(1, qualities.size()): check(qualities[level] > qualities[level - 1], "Quality rises monotonically at level %d" % level)
	check(qualities[0] == 52 and qualities[1] == 55, "Exact component formula includes +5 effective process bonus")
	check(qualities.back() <= 100 and _output_quality(5, 100) <= 100, "Finished quality remains bounded")
	check(_output_quality(2, 80) > _output_quality(2, 20), "Component quality still affects improved output")
	var raw: GameSession = session()
	var processor: SimFacility = raw.sim.facility("01_processors")
	raw.sim.companies[processor.company_id].product_quality_levels.processor = 0
	check(raw.sim.produce(processor) > 0, "Produce zero-input baseline")
	var base: int = processor.inventory.quality("processor")
	processor.inventory = SimInventory.new()
	processor.produced_today = 0
	raw.sim.companies[processor.company_id].product_quality_levels.processor = 2
	check(raw.sim.produce(processor) > 0 and processor.inventory.quality("processor") == base + 10, "Zero-input product uses improved effective process")

	var s: GameSession = session()
	var sim: Economy = s.sim
	var factory: SimFacility = sim.facility("10_orion")
	var warehouse: SimFacility = sim.facility("30_warehouse")
	var owner: SimCompany = sim.companies[factory.company_id]
	factory.stock_days = 7
	for product: String in sim.catalog.products.smartphone.inputs:
		factory.inventory.add(product, 4, 400, 50)
		owner.spend(400)
	check(sim.produce(factory) == 4, "Produce pre-improvement goods")
	var old_quality: int = factory.inventory.quality("smartphone")
	check(sim.trade(factory, warehouse, "smartphone", 1) == 1, "Dispatch pre-improvement goods")
	var transit_points: int = sim.logistics.shipments.back().quality_points
	warehouse.inventory.add("smartphone", 2, 200, old_quality)
	var warehouse_points: int = warehouse.inventory.points("smartphone")
	var remaining_points: int = factory.inventory.points("smartphone")
	owner.product_quality_levels.smartphone = 1
	check(factory.inventory.points("smartphone") == remaining_points and sim.logistics.shipments.back().quality_points == transit_points and warehouse.inventory.points("smartphone") == warehouse_points, "Completion never rewrites existing factory/transit/warehouse goods")
	factory.produced_today = 0
	for product: String in sim.catalog.products.smartphone.inputs:
		factory.inventory.add(product, 1, 100, 50)
		owner.spend(100)
	check(sim.produce(factory) == 1 and factory.inventory.points("smartphone") > remaining_points + old_quality, "Only newly produced goods receive improved capability")
	while sim.clock.tick < int(sim.logistics.shipments.back().arrival): sim.clock.advance()
	sim.logistics.deliver(sim)
	check(warehouse.inventory.points("smartphone") == warehouse_points + transit_points, "Shipment preserves pre-improvement physical quality")
	var improved: GameSession = session()
	var improved_factory: SimFacility = improved.sim.facility("10_orion")
	var retailer: SimFacility = improved.sim.facility("20_player")
	var improved_owner: SimCompany = improved.sim.companies[improved_factory.company_id]
	improved_owner.product_quality_levels.smartphone = 1
	improved_factory.stock_days = 7
	for product: String in improved.sim.catalog.products.smartphone.inputs:
		improved_factory.inventory.add(product, 2, 200, 50)
		improved_owner.spend(200)
	check(improved.sim.produce(improved_factory) == 2, "Produce improved downstream batch")
	var improved_quality: int = improved_factory.inventory.quality("smartphone")
	check(improved.sim.trade(improved_factory, retailer, "smartphone", 2) == 2 and improved.sim.logistics.shipments.back().quality_points == improved_quality * 2, "Improved shipment retains quality")
	while improved.sim.clock.tick < int(improved.sim.logistics.shipments.back().arrival): improved.sim.clock.advance()
	improved.sim.logistics.deliver(improved.sim)
	check(retailer.inventory.quality("smartphone") == improved_quality, "Retailer displays delivered improved quality")
	var local_before: Dictionary = sim.catalog.local_values("smartphone")
	check(same(local_before, sim.catalog.local_values("smartphone")), "Local behavior is unchanged")
	var low: Array[int] = ConsumerDemand.allocate(100, [
		{"price": 30000, "reference_price": 30000, "quality": old_quality, "brand": 20, "stock": 1000, "price_sensitivity": 0.7, "quality_sensitivity": 2.0},
		{"price": 30000, "reference_price": 30000, "quality": old_quality + 5, "brand": 20, "stock": 1000, "price_sensitivity": 0.7, "quality_sensitivity": 2.0}])
	check(low[1] > low[0], "Improved goods compete through normal consumer quality preference")

func _ai_selection() -> void:
	var s: GameSession = session(2022)
	var lab: SimFacility = s.sim.facility("30_research")
	check(lab.research_project.is_empty(), "2022 AI center begins idle")
	s.sim.step()
	check(lab.research_project.get("kind") == "product_quality", "AI falls back to quality when all technology is known")
	check(lab.research_project.get("product") == "smartphone" and lab.research_project.get("target_level") == 1, "AI quality selection favors the highest-opportunity manufactured product")

func _persistence() -> void:
	var s: GameSession = session(2022, 73)
	var lab: SimFacility = build_lab(s)
	build_lab(s)
	var project: Dictionary = s.sim.product_quality_project("player", "smartphone")
	check(submit_project(s, lab, project), "Assign project for persistence")
	for day: int in range(7): s.sim.step()
	var path: String = "res://.godot/7b3a-save.json"
	check(s.save_game(path), "Save partial quality project")
	var restored: GameSession = GameSession.new()
	check(restored.load_game(path), "Restore partial quality project")
	if restored.sim == null: return
	check(same(s.sim.snapshot(), restored.sim.snapshot()), "Partial project exact restore")
	var completion_a: int = -1
	var completion_b: int = -1
	for day: int in range(40):
		s.sim.step()
		restored.sim.step()
		check(same(s.sim.snapshot(), restored.sim.snapshot()), "Exact quality replay day %d" % day)
		if completion_a < 0 and s.sim.companies.player.product_quality_level("smartphone") == 1: completion_a = s.sim.clock.tick - 1
		if completion_b < 0 and restored.sim.companies.player.product_quality_level("smartphone") == 1: completion_b = restored.sim.clock.tick - 1
	check(completion_a == completion_b and completion_a >= 0, "Completion tick matches after replay")
	check(restored.sim.companies.player.product_quality_level("smartphone") == 1, "Completed level exact restore/continuation")

	var base: Dictionary = restored.sim.snapshot()
	var player_index: int = -1
	for index: int in range(base.companies.size()):
		if base.companies[index].id == "player": player_index = index
	for corruption: String in ["unknown", "negative", "above", "target", "knowledge", "duplicate", "schema"]:
		var bad: Dictionary = base.duplicate(true)
		var company: Dictionary = bad.companies[player_index]
		match corruption:
			"unknown": company.product_quality_levels.missing = 0
			"negative": company.product_quality_levels.smartphone = -1
			"above": company.product_quality_levels.smartphone = 6
			"target": company.product_quality_progress.smartphone = {"target_level": 4, "progress": 1}
			"knowledge":
				company.product_quality_progress.smartphone = {"target_level": 2, "progress": 1}
				company.known_technologies.erase("mobile_computing")
			"duplicate":
				var active: Dictionary = {"kind": "product_quality", "product": "smartphone", "target_level": 2}
				company.product_quality_progress.smartphone = {"target_level": 2, "progress": 1}
				var assigned: int = 0
				for facility: Dictionary in bad.facilities:
					if facility.company == "player" and facility.type == "research_center" and assigned < 2:
						facility.research_project = active.duplicate(true)
						assigned += 1
			"schema": bad.schema_version = 9
		check(SaveStore.new().restore(bad) == null, "Reject invalid quality state " + corruption)
