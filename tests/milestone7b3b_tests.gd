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

func isolate(s: GameSession) -> void:
	for f: SimFacility in s.sim.facilities: f.operating = false
	for owner: SimCompany in s.sim.companies.values(): owner.ai = false

func build_lab(s: GameSession) -> SimFacility:
	var definition: Dictionary = s.sim.catalog.facility_types.research_center
	var sites: Array[Vector2i] = s.sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "R&D construction site")
	var id: String = "built_%06d" % s.sim.city.next_facility
	check(s.submit({"type": "build_facility", "archetype": "research_center", "product": "", "x": sites[0].x, "y": sites[0].y}), "Build R&D center")
	return s.sim.facility(id)

func submit_project(s: GameSession, lab: SimFacility, project: Dictionary) -> bool:
	var accepted: bool = s.submit({"type": "assign_research", "facility": lab.id, "project": project})
	if accepted: s.sim.process_commands()
	return accepted

func seed_inputs(sim: Economy, factory: SimFacility, units: int, quality: int = 50) -> void:
	var owner: SimCompany = sim.companies[factory.company_id]
	for product: String in sim.catalog.products[factory.product_id].inputs:
		var amount: int = units * int(sim.catalog.products[factory.product_id].inputs[product])
		factory.inventory.add(product, amount, amount * 100, quality)
		owner.spend(amount * 100)

func _initialize() -> void:
	_catalog_and_projects()
	_scheduler()
	_cost_and_accounting()
	_nonretroactive_and_separation()
	_ai_selection()
	_persistence()
	print("M7B3B TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog_and_projects() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for corruption: String in ["max", "work", "cost", "reduction", "fraction"]:
		var data: Dictionary = raw.duplicate(true)
		match corruption:
			"max": data.process_efficiency_research.max_level = 0
			"work": data.process_efficiency_research.base_work = -1
			"cost": data.process_efficiency_research.base_daily_cost = 0
			"reduction": data.process_efficiency_research.conversion_cost_reduction_per_level = 20
			"fraction": data.process_efficiency_research.base_work = 1.5
		var path: String = "res://.godot/7b3b-invalid-%s.json" % corruption
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data(path), "Reject invalid process research " + corruption)
	var s: GameSession = session()
	var owner: SimCompany = s.sim.companies.player
	check(s.sim.catalog.efficiency_max_level() == 5 and s.sim.catalog.conversion_cost_reduction(5) == 25, "Bounded data-driven efficiency levels")
	check(owner.process_efficiency_levels.size() > 0 and owner.process_efficiency_level("smartphone") == 0, "Company-product efficiency starts at zero")
	var project: Dictionary = s.sim.process_efficiency_project(owner.id, "smartphone")
	check(project == {"kind": "process_efficiency", "product": "smartphone", "target_level": 1}, "Structured process project")
	check(s.sim.research_project_error(owner.id, project).is_empty(), "Known public manufacturable product eligible")
	owner.known_technologies.erase(str(s.sim.catalog.products.smartphone.technology))
	check(not s.sim.research_project_error(owner.id, project).is_empty(), "Retail-only access rejected")
	owner.known_technologies.mobile_computing = -1
	check(not s.sim.research_project_error(owner.id, {"kind": "process_efficiency", "product": "smartphone", "target_level": 2}).is_empty(), "Skipped target rejected")
	check(not s.sim.research_project_error(owner.id, {"kind": "process_efficiency", "product": "missing", "target_level": 1}).is_empty(), "Unknown product rejected")
	owner.process_efficiency_levels.smartphone = 5
	check(not s.sim.research_project_error(owner.id, s.sim.process_efficiency_project(owner.id, "smartphone")).is_empty(), "Maximum level rejected")
	var early: GameSession = session(2012)
	check(early.sim.research_project_error("player", early.sim.process_efficiency_project("player", "smartphone")).is_empty(), "2012 known product immediately eligible")
	check(not early.sim.research_project_error("player", early.sim.process_efficiency_project("player", "advanced_phone")).is_empty(), "2012 future product remains ineligible")

func _scheduler() -> void:
	var s: GameSession = session()
	var lab: SimFacility = build_lab(s)
	var second: SimFacility = build_lab(s)
	isolate(s)
	lab.operating = true
	second.operating = true
	var owner: SimCompany = s.sim.companies.player
	var project: Dictionary = s.sim.process_efficiency_project(owner.id, "smartphone")
	check(submit_project(s, lab, project), "Assign process project")
	check(not submit_project(s, second, project), "Reject duplicate process assignment")
	second.operating = false
	var cash: int = owner.cash
	s.sim.step()
	check(owner.process_efficiency_progress.smartphone == {"target_level": 1, "progress": 10}, "Shared scheduler funded progress")
	check(cash - owner.cash == 3000 and owner.research_expense == 2500, "Research and overhead accounting")
	check(s.submit({"type": "stop_research", "facility": lab.id}), "Queue process stop")
	s.sim.process_commands()
	check(lab.research_project.is_empty() and owner.process_efficiency_progress.smartphone.progress == 10, "Stop retains process progress")
	check(submit_project(s, lab, project), "Resume process project")
	owner.cash = 2499
	s.sim.step()
	check(owner.process_efficiency_progress.smartphone.progress == 10 and owner.cash == 1999, "Insufficient cash stalls shared scheduler")
	owner.cash = 1000000
	owner.process_efficiency_progress.smartphone.progress = 290
	s.sim.step()
	check(owner.process_efficiency_level("smartphone") == 1 and not owner.process_efficiency_progress.has("smartphone") and lab.research_project.is_empty(), "Exact deterministic completion raises one level")
	var next: Dictionary = s.sim.process_efficiency_project(owner.id, "smartphone")
	check(next.target_level == 2 and s.sim.project_work(next) == 600 and s.sim.project_cost(next) == 5000, "Repeatable work and cost scale by target")

func _production_result(level: int) -> Dictionary:
	var s: GameSession = session()
	var factory: SimFacility = s.sim.facility("10_orion")
	var owner: SimCompany = s.sim.companies[factory.company_id]
	owner.process_efficiency_levels.smartphone = level
	factory.stock_days = 7
	seed_inputs(s.sim, factory, 1, 50)
	var cash: int = owner.cash
	check(s.sim.produce(factory) == 1, "Produce efficiency fixture L%d" % level)
	return {"cash": cash - owner.cash, "production_cash": owner.production_cash, "value": factory.inventory.value("smartphone"), "quality": factory.inventory.quality("smartphone"), "inputs": factory.inventory.quantity("processor") + factory.inventory.quantity("display") + factory.inventory.quantity("battery")}

func _cost_and_accounting() -> void:
	var s: GameSession = session()
	var costs: Array[int] = []
	for level: int in range(6): costs.append(s.sim.conversion_cost_at_level("smartphone", level))
	check(costs[0] == 3000, "Level zero uses base conversion cost")
	for level: int in range(1, costs.size()): check(costs[level] < costs[level - 1], "Conversion cost falls at level %d" % level)
	check(costs[5] == 2250, "Level five applies configured 25 percent reduction")
	var original: int = s.sim.catalog.products.smartphone.conversion_cost
	s.sim.catalog.products.smartphone.conversion_cost = 101
	check(s.sim.conversion_cost_at_level("smartphone", 1) == 95, "Integer conversion rounding floors deterministically")
	s.sim.catalog.products.smartphone.conversion_cost = 0
	check(s.sim.conversion_cost_at_level("smartphone", 5) == 0, "Zero conversion cost remains zero")
	s.sim.catalog.products.smartphone.conversion_cost = original
	var base: Dictionary = _production_result(0)
	var efficient: Dictionary = _production_result(5)
	check(base.cash == 3000 and efficient.cash == 2250, "Reduced cost lowers actual cash outflow")
	check(base.production_cash == 3000 and efficient.production_cash == 2250, "Production cash records actual reduced amount")
	check(base.value == 3300 and efficient.value == 2550, "Finished inventory capitalizes actual inputs plus conversion")
	var boundary: GameSession = session()
	var component_factory: SimFacility = boundary.sim.facility("01_processors")
	var component_owner: SimCompany = boundary.sim.companies[component_factory.company_id]
	component_owner.process_efficiency_levels.processor = 5
	var boundary_units: int = boundary.sim.produce(component_factory)
	check(boundary_units == 55 and component_owner.production_cash == boundary_units * boundary.sim.conversion_cost_at_level("processor", 5), "Zero-input production uses reduced resource cash normally")
	var sale: GameSession = session()
	var factory: SimFacility = sale.sim.facility("10_orion")
	var retailer: SimFacility = sale.sim.facility("20_player")
	var maker: SimCompany = sale.sim.companies[factory.company_id]
	maker.process_efficiency_levels.smartphone = 5
	factory.stock_days = 7
	seed_inputs(sale.sim, factory, 1)
	check(sale.sim.produce(factory) == 1, "Produce lower-cost sale fixture")
	var before_cogs: int = maker.cogs
	check(sale.sim.trade(factory, retailer, "smartphone", 1) == 1 and maker.cogs - before_cogs == 2550, "Sale recognizes correspondingly lower COGS")
	check(sale.sim.invariant_errors().is_empty(), "Reduced-cost production and sale preserve accounting identities")

func _nonretroactive_and_separation() -> void:
	var s: GameSession = session()
	isolate(s)
	var factory: SimFacility = s.sim.facility("11_nova")
	var lab: SimFacility = s.sim.facility("30_research")
	var owner: SimCompany = s.sim.companies[factory.company_id]
	lab.operating = true
	factory.stock_days = 7
	seed_inputs(s.sim, factory, 4)
	check(s.sim.produce(factory) == 4, "Produce pre-research inventory")
	var factory_value: int = factory.inventory.value("smartphone")
	var store: SimFacility = s.sim.facility("20_player")
	check(s.sim.trade(factory, store, "smartphone", 1) == 1, "Dispatch pre-research shipment")
	var shipment_value: int = int(s.sim.logistics.shipments.back().value)
	var factory_after_dispatch: int = factory.inventory.value("smartphone")
	var warehouse: SimFacility = s.sim.facility("30_warehouse")
	warehouse.inventory.add("smartphone", 1, 7777, 50)
	store.inventory.add("smartphone", 1, 8888, 50)
	var warehouse_value: int = warehouse.inventory.value("smartphone")
	var retail_value: int = store.inventory.value("smartphone")
	var prior_production_cash: int = owner.production_cash
	var project: Dictionary = s.sim.process_efficiency_project(owner.id, "smartphone")
	check(s.sim.research_project_error(owner.id, project).is_empty(), "Completion fixture is eligible")
	lab.research_project = project
	owner.process_efficiency_progress.smartphone = {"target_level": 1, "progress": 290}
	s.sim.step()
	check(owner.process_efficiency_level("smartphone") == 1, "Complete process research with existing goods")
	check(factory_after_dispatch < factory_value and factory.inventory.value("smartphone") == factory_after_dispatch, "Existing factory inventory carrying value unchanged by completion")
	check(int(s.sim.logistics.shipments.back().value) == shipment_value, "Shipment carrying value unchanged by completion")
	check(warehouse.inventory.value("smartphone") == warehouse_value and store.inventory.value("smartphone") == retail_value, "Warehouse and retail carrying values unchanged")
	check(owner.production_cash == prior_production_cash, "Research completion never rewrites prior production cash")
	factory.produced_today = 0
	factory.active = true
	seed_inputs(s.sim, factory, 1)
	var old_value: int = factory.inventory.value("smartphone")
	var newly_produced: int = s.sim.produce(factory)
	var added_value: int = factory.inventory.value("smartphone") - old_value
	check(newly_produced == 1 and added_value == 3150, "Only new output uses reduced conversion cost (%d units / %d cents)" % [newly_produced, added_value])
	var zero: Dictionary = _production_result(0)
	var maxed: Dictionary = _production_result(5)
	check(zero.quality == maxed.quality, "Process efficiency never changes physical quality")
	check(zero.inputs == 0 and maxed.inputs == 0, "Recipe input quantities remain exact at all levels")
	var quality_level: int = owner.product_quality_level("smartphone")
	var brand: int = owner.brand("smartphone")
	var local: Dictionary = s.sim.catalog.local_values("smartphone")
	owner.process_efficiency_levels.smartphone = 5
	check(owner.product_quality_level("smartphone") == quality_level and owner.brand("smartphone") == brand and same(local, s.sim.catalog.local_values("smartphone")), "Quality level, corporate brand and Local remain separate")
	check(factory.capacity == 18, "Efficiency does not change facility capacity")

func _ai_selection() -> void:
	var technology: GameSession = session()
	var tech_owner: SimCompany = technology.sim.companies.maker_b
	tech_owner.known_technologies.erase("advanced_mobile")
	technology.sim.step()
	check(technology.sim.facility("30_research").research_project == technology.sim.technology_project("advanced_mobile"), "AI still prioritizes eligible technology")
	var continuous: GameSession = session()
	continuous.sim.step()
	var lab: SimFacility = continuous.sim.facility("30_research")
	check(lab.research_project.kind == "product_quality" and lab.research_project.product == "smartphone", "Strategic continuous research starts with highest-opportunity manufactured product and quality tie-break")
	lab.research_project = {}
	continuous.sim.companies.maker_b.product_quality_levels.smartphone = 1
	continuous.sim.step()
	check(lab.research_project.kind == "process_efficiency" and lab.research_project.product == "smartphone", "Lower attained process level wins within the highest-opportunity manufactured product")

func _persistence() -> void:
	var s: GameSession = session(2022, 73)
	var lab: SimFacility = build_lab(s)
	build_lab(s)
	var project: Dictionary = s.sim.process_efficiency_project("player", "smartphone")
	check(submit_project(s, lab, project), "Assign process project for persistence")
	for day: int in range(7): s.sim.step()
	var path: String = "res://.godot/7b3b-save.json"
	check(s.save_game(path), "Save partial process project")
	var restored: GameSession = GameSession.new()
	check(restored.load_game(path), "Restore partial process project")
	if restored.sim == null: return
	check(same(s.sim.snapshot(), restored.sim.snapshot()), "Partial process state restores exactly")
	var completion_a: int = -1
	var completion_b: int = -1
	for day: int in range(40):
		s.sim.step()
		restored.sim.step()
		check(same(s.sim.snapshot(), restored.sim.snapshot()), "Exact process replay day %d" % day)
		if completion_a < 0 and s.sim.companies.player.process_efficiency_level("smartphone") == 1: completion_a = s.sim.clock.tick - 1
		if completion_b < 0 and restored.sim.companies.player.process_efficiency_level("smartphone") == 1: completion_b = restored.sim.clock.tick - 1
	check(completion_a == completion_b and completion_a >= 0, "Process completion tick matches deterministic continuation")
	check(restored.sim.companies.player.process_efficiency_level("smartphone") == 1, "Attained process level restores exactly")
	var base: Dictionary = restored.sim.snapshot()
	var player_index: int = -1
	for index: int in range(base.companies.size()):
		if base.companies[index].id == "player": player_index = index
	for corruption: String in ["unknown", "negative", "above", "target", "knowledge", "attained_knowledge", "duplicate", "schema"]:
		var bad: Dictionary = base.duplicate(true)
		var company: Dictionary = bad.companies[player_index]
		match corruption:
			"unknown": company.process_efficiency_levels.missing = 0
			"negative": company.process_efficiency_levels.smartphone = -1
			"above": company.process_efficiency_levels.smartphone = 6
			"target": company.process_efficiency_progress.smartphone = {"target_level": 4, "progress": 1}
			"knowledge":
				company.process_efficiency_progress.smartphone = {"target_level": 2, "progress": 1}
				company.known_technologies.erase("mobile_computing")
			"attained_knowledge":
				company.known_technologies.erase("mobile_computing")
			"duplicate":
				var active: Dictionary = {"kind": "process_efficiency", "product": "smartphone", "target_level": 2}
				company.process_efficiency_progress.smartphone = {"target_level": 2, "progress": 1}
				var assigned: int = 0
				for facility: Dictionary in bad.facilities:
					if facility.company == "player" and facility.type == "research_center" and assigned < 2:
						facility.research_project = active.duplicate(true)
						assigned += 1
			"schema": bad.schema_version = 10
		check(SaveStore.new().restore(bad) == null, "Reject invalid process state " + corruption)
