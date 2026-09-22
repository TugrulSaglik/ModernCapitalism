extends SceneTree

const Planner = preload("res://src/sim/strategic_ai.gd")

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func fresh(difficulty: String = "standard", era: int = 2022) -> Economy:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, era, SaveStore.DATA_PATH, {"preset": "legacy"}, difficulty), "Economy starts at " + difficulty)
	return sim

func add_build(sim: Economy, company: String, archetype: String, product: String = "") -> SimFacility:
	var definition: Dictionary = sim.catalog.facility_types[archetype]
	for site: Vector2i in sim.city.valid_sites(int(definition.width), int(definition.depth)):
		var id: String = "built_%06d" % sim.city.next_facility
		var command: Dictionary = {"type": "build_facility", "company": company, "city": sim.city.id, "archetype": archetype, "product": product, "x": site.x, "y": site.y}
		if sim.command_error(command).is_empty():
			sim.queue_command(command)
			sim.process_commands()
			return sim.facility(id)
	return null

func _initialize() -> void:
	_definitions_and_session()
	_policy_differentiation()
	_no_cheats()
	_persistence()
	print("M8D TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _definitions_and_session() -> void:
	var planner: StrategicAI = Planner.new()
	check(Planner.DIFFICULTY_IDS == ["relaxed", "standard", "competitive"] and Planner.DIFFICULTY_PROFILES.size() == 3, "Exactly three stable difficulty IDs")
	var expected: Dictionary = {
		"relaxed": ["Relaxed", 7500000, 3, 70, 2, 4, 90],
		"standard": ["Standard", 5000000, 4, 40, 3, 3, 60],
		"competitive": ["Competitive", 3500000, 5, 25, 4, 2, 45],
	}
	for id: String in Planner.DIFFICULTY_IDS:
		var p: Dictionary = planner.difficulty_profile(id)
		var e: Array = expected[id]
		check([p.display_name, p.minimum_cash_reserve, p.reserve_divisor, p.opportunity_threshold, p.maximum_retailers, p.warehouse_commercial_threshold, p.staff_payroll_runway_days] == e, id + " profile exact")
		check(planner.valid_difficulty(id) and planner.difficulty_display_name(id) == e[0] and not str(p.description).is_empty(), id + " helpers and description")
	check(not planner.valid_difficulty(12) and not planner.valid_difficulty("hard") and planner.difficulty_profile("hard").is_empty(), "Unknown and non-string difficulties rejected")
	var r: Dictionary = planner.difficulty_profile("relaxed")
	var s: Dictionary = planner.difficulty_profile("standard")
	var c: Dictionary = planner.difficulty_profile("competitive")
	check(r.minimum_cash_reserve > s.minimum_cash_reserve and s.minimum_cash_reserve > c.minimum_cash_reserve, "Minimum reserves monotonic")
	check(r.reserve_divisor < s.reserve_divisor and s.reserve_divisor < c.reserve_divisor, "Reserve fractions monotonic")
	check(r.opportunity_threshold > s.opportunity_threshold and s.opportunity_threshold > c.opportunity_threshold, "Opportunity thresholds monotonic")
	check(r.maximum_retailers < s.maximum_retailers and s.maximum_retailers < c.maximum_retailers, "Retail caps monotonic")
	check(r.warehouse_commercial_threshold > s.warehouse_commercial_threshold and s.warehouse_commercial_threshold > c.warehouse_commercial_threshold, "Warehouse thresholds monotonic")
	check(r.staff_payroll_runway_days > s.staff_payroll_runway_days and s.staff_payroll_runway_days > c.staff_payroll_runway_days, "Payroll runway monotonic")
	var session: GameSession = GameSession.new()
	check(session.start() and session.sim.difficulty == "standard", "Session defaults to Standard")
	check(session.start(2022, 42, "sandbox", {"preset": "legacy"}, "relaxed") and session.sim.difficulty == "relaxed", "Explicit Relaxed session")
	check(session.start(2022, 42, "sandbox", {"preset": "legacy"}, "competitive") and session.sim.difficulty == "competitive", "Explicit Competitive session")
	var previous: Economy = session.sim
	check(not session.start(2022, 42, "sandbox", {"preset": "legacy"}, "hard") and session.sim == previous, "Invalid difficulty does not replace current session")

func _policy_differentiation() -> void:
	var sim: Economy = fresh()
	var planner: StrategicAI = sim.strategic_ai
	var r: Dictionary = planner.difficulty_profile("relaxed")
	var s: Dictionary = planner.difficulty_profile("standard")
	var c: Dictionary = planner.difficulty_profile("competitive")
	check(planner.cash_reserve(10000000, s) == 5000000 and planner.cash_reserve(40000000, s) == 10000000, "Standard reserve reproduces 8C")
	check(planner.cash_reserve(30000000, r) == 10000000 and planner.cash_reserve(30000000, s) == 7500000 and planner.cash_reserve(30000000, c) == 6000000, "Reserve differs monotonically at equal cash")
	for product: String in planner.eligible_consumer_products(sim):
		var category: String = str(sim.catalog.products[product].category)
		sim.category_market[category] = {"potential": 100, "units": 100}
		sim.market[product] = {"units": 100, "local_units": 0, "company_units": {"rival": 1000}}
	sim.market.laptop = {"units": 100, "local_units": 0, "company_units": {"rival": 30}}
	check(planner.market_opportunity(sim, "rival", "laptop") == 50, "Opportunity formula remains exact")
	check(planner._assortment_commands(sim, "rival", r).is_empty(), "Score 50 rejected on Relaxed")
	check(not planner._assortment_commands(sim, "rival", s).is_empty() and not planner._assortment_commands(sim, "rival", c).is_empty(), "Score 50 accepted on Standard and Competitive")
	sim.market.laptop.company_units.rival = 50
	check(planner.market_opportunity(sim, "rival", "laptop") == 30, "Controlled score 30 fixture")
	check(planner._assortment_commands(sim, "rival", s).is_empty() and not planner._assortment_commands(sim, "rival", c).is_empty(), "Score 30 accepted only on Competitive")

	var staffing: Economy = fresh()
	check(add_build(staffing, "rival", "corporate_headquarters") != null, "Staffing HQ fixture")
	var resulting_payroll: int = 2 * int(staffing.catalog.staff_roles.operations_manager.daily_salary) + 2 * int(staffing.catalog.staff_roles.marketing_manager.daily_salary) + int(staffing.catalog.staff_roles.finance_manager.daily_salary)
	var available_cash: int = staffing.strategic_ai.cash_reserve(staffing.companies.rival.cash, c) + resulting_payroll * int(c.staff_payroll_runway_days)
	var competitive_commands: Array = staffing.strategic_ai._staffing_commands(staffing, "rival", available_cash, c)
	var standard_commands: Array = staffing.strategic_ai._staffing_commands(staffing, "rival", available_cash, s)
	check(not competitive_commands.is_empty() and standard_commands.is_empty(), "Competitive may hire while Standard retains longer runway")
	for command: Dictionary in competitive_commands:
		check(command.type == "hire_staff" and staffing.command_error(command).is_empty(), "Hiring still uses ordinary valid commands")

	var warehouse_standard: Economy = fresh("standard")
	var warehouse_competitive: Economy = fresh("competitive")
	for candidate: Economy in [warehouse_standard, warehouse_competitive]:
		check(add_build(candidate, "rival", "corporate_headquarters") != null, "Warehouse HQ fixture")
		check(add_build(candidate, "rival", "research_center") != null, "Warehouse lab fixture")
		candidate.companies.rival.known_technologies.clear()
	var standard_capital: Dictionary = warehouse_standard.strategic_ai._capital_command(warehouse_standard, "rival", true, {}, s)
	var competitive_capital: Dictionary = warehouse_competitive.strategic_ai._capital_command(warehouse_competitive, "rival", true, {}, c)
	check(standard_capital.get("archetype", "") != "warehouse" and competitive_capital.get("archetype", "") == "warehouse", "Warehouse eligible at two commercial facilities only on Competitive")
	check(warehouse_competitive.command_error(competitive_capital).is_empty(), "Competitive warehouse is an ordinary valid build")

func _no_cheats() -> void:
	var relaxed: Economy = fresh("relaxed")
	var competitive: Economy = fresh("competitive")
	check(relaxed.catalog.version == 9 and competitive.catalog.version == 9, "Catalog remains version 9")
	check(same(relaxed.catalog.facility_types, competitive.catalog.facility_types), "Construction, capacity, overhead, and research facility rules identical")
	check(same(relaxed.catalog.products, competitive.catalog.products), "Demand, recipes, conversion costs, and product rules identical")
	check(same(relaxed.catalog.staff_roles, competitive.catalog.staff_roles), "Wages and staff effects identical")
	check(relaxed.companies.player.cash == competitive.companies.player.cash and relaxed.companies.rival.cash == competitive.companies.rival.cash, "Player and AI starting cash identical")
	var policy_keys: Array = relaxed.strategic_ai.difficulty_profile("relaxed").keys()
	policy_keys.sort()
	check(policy_keys == ["description", "display_name", "maximum_retailers", "minimum_cash_reserve", "opportunity_threshold", "reserve_divisor", "staff_payroll_runway_days", "warehouse_commercial_threshold"], "Profiles contain strategic policy only")

func _persistence() -> void:
	var sim: Economy = fresh("competitive")
	for day: int in range(40): sim.step()
	var state: Dictionary = sim.snapshot()
	check(state.schema_version == 16 and state.difficulty == "competitive" and state.catalog_version == 9 and SaveStore.FORMAT_VERSION == 2, "Schema 16 contains exact difficulty; catalog 9 / format 2")
	var restored: Economy = SaveStore.new().restore(state)
	check(restored != null and restored.difficulty == "competitive" and same(state, restored.snapshot()), "Exact schema-16 restore")
	if restored != null:
		for day: int in range(35):
			sim.step()
			restored.step()
		check(same(sim.snapshot(), restored.snapshot()), "Deterministic continuation preserves strategic timing and choices")
	var invalid: Dictionary = state.duplicate(true)
	invalid.difficulty = "hard"
	check(SaveStore.new().restore(invalid) == null, "Unknown saved difficulty rejected")
	invalid = state.duplicate(true)
	invalid.difficulty = 1
	check(SaveStore.new().restore(invalid) == null, "Non-string saved difficulty rejected")
	invalid = state.duplicate(true)
	invalid.erase("difficulty")
	check(SaveStore.new().restore(invalid) == null, "Missing saved difficulty rejected")
	invalid = state.duplicate(true)
	invalid.schema_version = 15
	check(SaveStore.new().restore(invalid) == null, "Schema 15 rejected without migration")
