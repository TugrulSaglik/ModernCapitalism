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

func fresh() -> GameSession:
	var s: GameSession = GameSession.new()
	check(s.start(2012), "2012 generated start")
	return s

func build(s: GameSession, kind: String = "research_center", product: String = "") -> SimFacility:
	var d: Dictionary = s.sim.catalog.facility_types[kind]
	var sites: Array[Vector2i] = s.sim.city.valid_sites(d.width, d.depth)
	check(not sites.is_empty(), "Construction site for " + kind)
	if sites.is_empty(): return null
	var id: String = "built_%06d" % s.sim.city.next_facility
	check(s.submit({"type": "build_facility", "archetype": kind, "product": product, "x": sites[0].x, "y": sites[0].y}), "Construct " + kind)
	return s.sim.facility(id)

func command(s: GameSession, f: SimFacility, kind: String, technology: String = "") -> bool:
	var accepted: bool = s.submit({"type": kind, "facility": f.id, "technology": technology})
	if accepted: s.sim.process_commands()
	return accepted

func isolate(s: GameSession) -> void:
	for f: SimFacility in s.sim.facilities: f.operating = false
	for owner: SimCompany in s.sim.companies.values(): owner.ai = false

func _initialize() -> void:
	if "--long-only" not in OS.get_cmdline_user_args():
		_catalog()
		_core()
		_persistence()
	if "--long" in OS.get_cmdline_user_args() or "--long-only" in OS.get_cmdline_user_args(): _long_run()
	print("M7A TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for corruption: String in ["work", "cost", "fraction", "missing", "duplicate", "cycle", "rate", "product", "prerequisite_type"]:
		var data: Dictionary = raw.duplicate(true)
		match corruption:
			"work": data.technologies[0].research_work = 0
			"cost": data.technologies[0].research_cost = -1
			"fraction": data.technologies[0].research_work = 1.5
			"missing": data.technologies[0].prerequisites = ["absent"]
			"duplicate": data.technologies[1].prerequisites = ["electronics", "electronics"]
			"cycle": data.technologies[0].prerequisites = ["mobile_computing"]
			"prerequisite_type": data.technologies[1].prerequisites = 3
			"rate": data.facility_types.back().research_rate = 0
			"product": data.facility_types.back().products = ["smartphone"]
		var path: String = "res://.godot/m7a-invalid.json"
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data(path), "Reject invalid research catalog " + corruption)

func _core() -> void:
	var s: GameSession = fresh()
	var sim: Economy = s.sim
	var owner: SimCompany = sim.companies.player
	for company: SimCompany in sim.companies.values():
		check(company.knows("electronics") and company.knows("mobile_computing") and company.known_technologies.size() == 2, "2012 baseline only " + company.id)
	var modern: GameSession = GameSession.new()
	check(modern.start(2022), "2022 start")
	for company: SimCompany in modern.sim.companies.values(): check(company.known_technologies.size() == sim.catalog.technologies.size(), "2022 baseline " + company.id)
	isolate(s)
	var lab: SimFacility = build(s)
	var other: SimFacility = build(s)
	check(lab.product_id.is_empty() and lab.assortment.is_empty() and lab.inventory.quantities.is_empty() and lab.price == 0, "R&D has no fake product or stock")
	check(not command(s, lab, "assign_research", "modern_wearables"), "Unavailable research rejected")
	check(s.unlock_debug(DebugConfig.PASSWORD) and s.debug_action("unlock"), "Public Debug unlock retained")
	check(sim.technology_public("modern_wearables") and not owner.knows("modern_wearables"), "Public override does not grant company knowledge")
	check(not sim.can_manufacture(owner.id, "earbuds"), "Public goods cannot be manufactured without knowledge")
	var factory: SimFacility = build(s, "assembly_plant", "smartphone")
	check(not s.submit({"type": "set_production", "facility": factory.id, "product": "earbuds"}), "Unknown production switch rejected")
	var site: Vector2i = sim.city.valid_sites(4, 3)[0]
	check(not s.submit({"type": "build_facility", "archetype": "assembly_plant", "product": "earbuds", "x": site.x, "y": site.y}), "Unknown manufacturing construction rejected")
	check(s.submit({"type": "add_line", "facility": "20_player", "product": "earbuds"}), "Public finished-good retail line permitted")
	sim.process_commands()
	owner.known_technologies.erase("electronics")
	check(not sim.research_error(owner.id, "modern_wearables").is_empty(), "Unknown prerequisite blocks assignment")
	owner.known_technologies.electronics = -1
	check(command(s, lab, "assign_research", "modern_wearables"), "Assign project")
	check(not command(s, other, "assign_research", "modern_wearables"), "Duplicate project blocked")
	check(command(s, other, "assign_research", "smart_home"), "Different parallel project allowed")
	check(command(s, other, "stop_research"), "Stop second project")
	other.operating = false
	factory.operating = false
	var cash: int = owner.cash
	var expense: int = owner.expenses
	sim.step()
	check(owner.research_progress.modern_wearables == 10, "Daily facility rate")
	check(cash - owner.cash == 3000 and owner.research_expense == 2500, "Project expense plus overhead charged once")
	check(owner.expenses - expense == 3000 + lab.accumulated_depreciation + other.accumulated_depreciation + factory.accumulated_depreciation, "R&D and depreciation are operating expenses")
	var p: Dictionary = FinancialReports.period(owner, sim.clock)
	check(p.research_expense == 2500 and p.profit == owner.profit(), "Income Statement and monthly research")
	check(p.operating_cash == -3000 and p.opening_cash + p.net_cash == p.closing_cash, "Cash Flow operating and total reconciliation")
	var b: Dictionary = FinancialReports.balance(sim, owner.id)
	check(b.retained_earnings == owner.profit() and b.assets == b.equity and owner.ttm_profit(sim.clock) == owner.profit(), "Retained earnings, TTM and balance identity")
	check(command(s, lab, "stop_research"), "Stop retains work")
	sim.step()
	check(owner.research_progress.modern_wearables == 10, "Stopped progress retained")
	check(command(s, other, "assign_research", "modern_wearables"), "Resume at another facility")
	sim.step()
	check(owner.research_progress.modern_wearables == 10, "Suspended facility does not progress")
	lab.operating = false
	other.operating = true
	var saved_cash: int = owner.cash
	owner.capital -= saved_cash - 2999
	owner.cash = 2999
	sim.step()
	check(owner.cash == 2499 and owner.research_progress.modern_wearables == 10, "Insufficient research funds stalls without negative cash")
	owner.capital += saved_cash - owner.cash
	owner.cash = saved_cash
	sim.step()
	check(owner.research_progress.modern_wearables == 20, "Funded project resumes")
	for day: int in range(58): sim.step()
	check(owner.knows("modern_wearables") and not owner.research_progress.has("modern_wearables") and other.research_project.is_empty(), "Completion permanent, no duplicate derived progress")
	check(sim.can_manufacture(owner.id, "earbuds") and not sim.can_manufacture("maker_a", "earbuds"), "Company-specific capability")
	check(s.submit({"type": "set_production", "facility": factory.id, "product": "earbuds"}), "Known production switch accepted")
	sim.process_commands()
	factory.active = true
	factory.inventory.add("electronics", 10, 0)
	factory.inventory.add("battery", 10, 0)
	check(sim.produce(factory) > 0, "Known recipe produces")
	var buyer: SimFacility = sim.facility("21_rival")
	check(sim.trade(factory, buyer, "earbuds", 1) == 1 and not sim.companies[buyer.company_id].knows("modern_wearables"), "Purchase finished goods does not grant knowledge")
	check(sim.trade(factory, other, "earbuds", 1) == 0, "R&D rejects inventory delivery")
	for day: int in range(4): sim.step()
	buyer.assortment.earbuds = 12600
	buyer.active = true
	check(sim.consumer_sale(buyer, 1, "earbuds") == 1, "Unknown company may resell finished good")
	# Test generic dependency eligibility using existing graph, without adding catalog content.
	owner.known_technologies.erase("mobile_computing")
	check(not sim.research_error(owner.id, "advanced_mobile").is_empty(), "Dependent blocked before prerequisite known")
	check(command(s, other, "assign_research", "mobile_computing"), "Prerequisite project starts")
	for day: int in range(30): sim.step()
	check(sim.research_error(owner.id, "advanced_mobile").is_empty(), "Completion enables dependent project")
	check(sim.invariant_errors().is_empty(), "Research accounting/logistics invariants")

func _persistence() -> void:
	var s: GameSession = fresh()
	var lab: SimFacility = build(s)
	var spare: SimFacility = build(s)
	spare.operating = false
	s.unlock_debug(DebugConfig.PASSWORD)
	s.debug_action("unlock")
	check(command(s, lab, "assign_research", "modern_wearables"), "Persistence project assigned")
	for day: int in range(17): s.sim.step()
	var path: String = "res://.godot/m7a-partial.json"
	check(s.save_game(path), "Save partial research")
	var saved: Dictionary = s.sim.snapshot()
	var copy: GameSession = fresh()
	check(copy.load_game(path) and same(copy.sim.snapshot(), saved), "Exact partial save restore")
	var completion: int = -1
	for day: int in range(50):
		s.sim.step()
		copy.sim.step()
		check(same(s.sim.snapshot(), copy.sim.snapshot()), "Exact continuation day " + str(day))
		if completion < 0 and s.sim.companies.player.knows("modern_wearables"): completion = s.sim.clock.tick - 1
	check(completion == 59 and copy.sim.companies.player.known_technologies.modern_wearables == completion, "Completion at identical expected tick")
	check(not copy.debug_unlocked, "Debug re-locks on load")
	for corruption: String in ["unknown", "progress", "known_progress", "prerequisite", "assignment", "duplicate", "product", "inventory", "expense"]:
		var bad: Dictionary = saved.duplicate(true)
		var owner: Dictionary
		for company: Dictionary in bad.companies:
			if company.id == "player": owner = company
		match corruption:
			"unknown": owner.known_technologies.missing = 0
			"progress": owner.research_progress.modern_wearables = 600
			"known_progress": owner.research_progress.electronics = 1
			"prerequisite": owner.known_technologies.erase("electronics")
			"expense": owner.research_expense = owner.expenses + 1
			_:
				for f: Dictionary in bad.facilities:
					if f.id == lab.id:
						if corruption == "assignment": f.research_project = s.sim.technology_project("electronics")
						if corruption == "product": f.product = "smartphone"
						if corruption == "inventory": f.inventory.quantities.smartphone = 1; f.inventory.costs.smartphone = 0
					if f.id == spare.id and corruption == "duplicate": f.research_project = s.sim.technology_project("modern_wearables")
		check(SaveStore.new().restore(bad) == null, "Reject corrupted research " + corruption)
	var before: Dictionary = copy.snapshot()
	var invalid: Dictionary = copy.snapshot()
	invalid.economy.companies[0].known_technologies.missing = 0
	SaveStore.new().write_file("res://.godot/m7a-bad.json", invalid)
	check(not copy.load_game("res://.godot/m7a-bad.json") and same(before, copy.snapshot()), "Transactional session rejection")

func _long_run() -> void:
	var s: GameSession = fresh()
	check(not s.sim.technology_public("modern_wearables"), "Long run later gate initially closed")
	while s.sim.clock.year < 2015:
		s.sim.step()
		check(s.sim.invariant_errors().is_empty(), "Long daily invariants")
	check(s.sim.technology_public("modern_wearables") and not s.sim.companies.maker_b.knows("modern_wearables"), "2015 public but not automatically known")
	check(s.sim.research_error("maker_b", "modern_wearables").is_empty(), "Later gate now researchable")
	var started: int = s.sim.clock.tick
	for day: int in range(60):
		s.sim.step()
		check(s.sim.invariant_errors().is_empty(), "Long research daily invariants")
		if day == 0: check(s.sim.facility("30_research").research_project == s.sim.technology_project("modern_wearables"), "AI deterministic earliest public project")
	check(s.sim.companies.maker_b.knows("modern_wearables") and s.sim.companies.maker_b.known_technologies.modern_wearables == started + 59, "AI completes on expected tick")
	check(s.sim.can_manufacture("maker_b", "earbuds") and not s.sim.can_manufacture("maker_a", "earbuds"), "Research company capability stays specific")
	for day: int in range(7): s.sim.step()
	check(s.sim.facility("16_earbuds").inventory.quantity("earbuds") > 0, "Research unlock produces dependent product")
	check(s.sim.invariant_errors().is_empty() and s.sim.cumulative_consumer_units > 0, "Long economy/accounting/logistics healthy")
	print("M7A LONG: date=%s completed_tick=%d research_expense=%d consumer_units=%d" % [s.sim.clock.date_string(), started + 59, s.sim.companies.maker_b.research_expense, s.sim.cumulative_consumer_units])
