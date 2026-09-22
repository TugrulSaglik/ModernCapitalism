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

func fresh(era: int = 2022) -> Economy:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, era, SaveStore.DATA_PATH, {"preset": "legacy"}), "Economy starts")
	return sim

func commands_of(plan: Dictionary, type: String, company: String = "") -> Array:
	return plan.commands.filter(func(command: Dictionary) -> bool: return command.type == type and (company.is_empty() or command.company == company))

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
	_cadence_determinism_and_cash()
	_market_and_assortment()
	_capital_and_placement()
	_staff_research_warehouse_sourcing()
	_compatibility_and_separation()
	print("M8C TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _cadence_determinism_and_cash() -> void:
	var a: Economy = fresh()
	var b: Economy = fresh()
	var pa: Dictionary = a.strategic_ai.evaluate_month(a)
	var pb: Dictionary = b.strategic_ai.evaluate_month(b)
	check(same(pa, pb), "Same state produces identical strategic commands and trace")
	var company_order: Array = []
	for command: Dictionary in pa.commands:
		if command.company not in company_order: company_order.append(command.company)
	var sorted_order: Array = company_order.duplicate()
	sorted_order.sort()
	check(company_order == sorted_order, "AI companies processed in stable company order")
	for company: String in ["maker_b", "rival"]:
		check(commands_of(pa, "build_facility", company).size() <= 1, "At most one capital build for " + company)
	var builds: Array = commands_of(pa, "build_facility")
	for build: Dictionary in builds:
		check(a.command_error(build).is_empty(), "Construction candidate uses ordinary valid command")
		var cost: int = int(a.catalog.facility_types[build.archetype].cost)
		check(a.companies[build.company].cash - cost >= a.strategic_ai.cash_reserve(a.companies[build.company].cash), "Capital preserves exact reserve")
	check(a.strategic_ai.cash_reserve(10000000) == 5000000 and a.strategic_ai.cash_reserve(40000000) == 10000000, "Reserve is max $50,000 or one quarter cash")
	var poor: Economy = fresh()
	poor.companies.rival.cash = 5000000
	check(commands_of(poor.strategic_ai.evaluate_month(poor), "build_facility", "rival").is_empty(), "Unaffordable investment skipped")
	var non_month: Economy = fresh()
	non_month.clock.day = 2
	non_month.clock.tick = 1
	non_month._ai_decisions()
	check(commands_of({"commands": non_month.pending_commands}, "build_facility").is_empty(), "Strategy does not run off monthly cadence")
	var continuous: Economy = fresh()
	continuous.step()
	var restored: Economy = SaveStore.new().restore(continuous.snapshot())
	check(restored != null, "Strategic state restores without schema change")
	if restored != null:
		while continuous.clock.day != 1:
			continuous.step()
			restored.step()
		check(same(continuous.snapshot(), restored.snapshot()), "Save/load continuation reaches same next monthly state")
		continuous.step()
		restored.step()
		check(same(continuous.snapshot(), restored.snapshot()), "Save/load chooses same strategic actions")
	check(continuous.snapshot().schema_version == 15 and continuous.catalog.version == 9 and SaveStore.FORMAT_VERSION == 2, "Schema 15 / catalog 9 / save format 2 unchanged")

func _market_and_assortment() -> void:
	var sim: Economy = fresh()
	sim.category_market.smartphones = {"potential": 100, "units": 50}
	sim.market.smartphone = {"units": 50, "local_units": 30, "company_units": {"rival": 5}}
	var low_share: int = sim.strategic_ai.market_opportunity(sim, "maker_b", "smartphone")
	var owned_share: int = sim.strategic_ai.market_opportunity(sim, "rival", "smartphone")
	check(low_share > owned_share, "Company realized share reduces opportunity urgency")
	var before: int = low_share
	sim.category_market.smartphones.units = 90
	sim.market.smartphone.local_units = 5
	check(sim.strategic_ai.market_opportunity(sim, "maker_b", "smartphone") < before, "Higher unmet and Local-held demand scores higher")
	var locked: Economy = fresh(2012)
	check("smartwatch" not in locked.strategic_ai.eligible_consumer_products(locked), "Era-locked product excluded")
	var plan: Dictionary = sim.strategic_ai.evaluate_month(sim)
	var rival_lines: Array = commands_of(plan, "add_line", "rival")
	check(not rival_lines.is_empty(), "AI uses spare retail assortment slot")
	for command: Dictionary in rival_lines:
		var f: SimFacility = sim.facility(command.facility)
		check(sim.catalog.supports_product(f.type_id, command.product) and sim.product_public(command.product), "Assortment product is public and supported")
		check(sim.command_error(command).is_empty(), "Assortment uses ordinary add_line command")
	var snapshot: Dictionary = sim.snapshot()
	for command: Dictionary in plan.commands: sim.queue_command(command)
	sim.process_commands()
	var old_player: Dictionary
	var new_player: Dictionary
	for company: Dictionary in snapshot.companies:
		if company.id == "player": old_player = company
	for company: Dictionary in sim.snapshot().companies:
		if company.id == "player": new_player = company
	check(old_player.cash == new_player.cash and old_player.staff_counts == new_player.staff_counts and old_player.known_technologies == new_player.known_technologies and old_player.advertising_budgets == new_player.advertising_budgets, "Strategic commands do not change player company state")
	check(sim.facility("20_player").assortment == snapshot.facilities.filter(func(f: Dictionary) -> bool: return f.id == "20_player")[0].assortment, "Strategic commands do not change player facilities")

func _capital_and_placement() -> void:
	var sim: Economy = fresh()
	var plan: Dictionary = sim.strategic_ai.evaluate_month(sim)
	check(commands_of(plan, "build_facility", "maker_b").size() == 1 and commands_of(plan, "build_facility", "rival").size() == 1, "Commercial AI selects one justified capital action")
	var first: Dictionary = commands_of(plan, "build_facility", "maker_b")[0]
	var second: Dictionary = commands_of(plan, "build_facility", "rival")[0]
	check(first.archetype == "corporate_headquarters" and second.archetype == "corporate_headquarters", "Missing HQ is high-priority investment")
	var da: Dictionary = sim.catalog.facility_types[first.archetype]
	var db: Dictionary = sim.catalog.facility_types[second.archetype]
	var overlap: bool = first.x < second.x + int(db.width) and first.x + int(da.width) > second.x and first.y < second.y + int(db.depth) and first.y + int(da.depth) > second.y
	check(not overlap, "Same-cycle planned footprints do not collide")
	for command: Dictionary in [first, second]: sim.queue_command(command)
	sim.process_commands()
	check(sim.headquarters("maker_b") != null and sim.headquarters("rival") != null, "AI constructs headquarters through command path")
	var next_plan: Dictionary = sim.strategic_ai.evaluate_month(sim)
	check(commands_of(next_plan, "build_facility", "maker_b").all(func(c: Dictionary) -> bool: return c.archetype != "corporate_headquarters"), "No duplicate headquarters")
	check(commands_of(next_plan, "build_facility", "rival").all(func(c: Dictionary) -> bool: return c.archetype != "corporate_headquarters"), "No duplicate rival headquarters")
	var no_retail: Array = sim.strategic_ai._owned_facilities(sim, "maker_b", "retail")
	var maker_capital: Dictionary = sim.strategic_ai._capital_command(sim, "maker_b", false, {})
	check(no_retail.is_empty() and not maker_capital.is_empty() and sim.catalog.facility_types[maker_capital.archetype].behavior == "research", "Commercial AI invests in one useful R&D center")
	var vertical: Dictionary = sim.strategic_ai._capital_command(sim, "rival", true, {})
	check(not vertical.is_empty() and sim.catalog.facility_types[vertical.archetype].behavior == "production" and vertical.product in sim.strategic_ai._sold_products(sim, "rival"), "Retailer can vertically integrate a sold product")
	var no_knowledge: Economy = fresh(2012)
	no_knowledge.companies.rival.known_technologies.erase("electronics")
	check(not no_knowledge.can_manufacture("rival", "laptop"), "Vertical integration still requires manufacturing knowledge")
	var gap: Economy = fresh()
	var processor: SimFacility = gap.facility("01_processors")
	gap.facilities.erase(processor)
	gap.city.plots.erase(processor.id)
	var gap_candidate: Dictionary = gap.strategic_ai._capital_command(gap, "maker_b", false, {})
	check(not gap_candidate.is_empty() and gap_candidate.product == "processor" and gap_candidate.archetype == "component_plant", "Missing recipe supplier triggers component capacity")
	check(not sim.strategic_ai._capital_command(sim, "maker_b", false, {}).get("product", "") == "processor", "Existing structural supplier avoids unnecessary component duplicate")

func _staff_research_warehouse_sourcing() -> void:
	var sim: Economy = fresh()
	var hq: SimFacility = add_build(sim, "rival", "corporate_headquarters")
	check(hq != null, "HQ fixture built")
	check(add_build(sim, "maker_b", "corporate_headquarters") != null, "Manufacturer HQ fixture built")
	var staffing: Array = sim.strategic_ai._staffing_commands(sim, "rival", sim.companies.rival.cash)
	var hires: int = 0
	for command: Dictionary in staffing:
		if command.type == "hire_staff": hires += int(command.quantity)
	check(hires == 5, "Multi-store retailer targets operations 2, marketing 2, finance 1")
	for command: Dictionary in staffing: sim.queue_command(command)
	sim.process_commands()
	check(sim.total_staff("rival") == 5 and sim.daily_payroll("rival") > 0, "Staffing applies through ordinary commands and payroll definitions")
	var poor: Economy = fresh()
	var poor_hq: SimFacility = add_build(poor, "rival", "corporate_headquarters")
	poor.companies.rival.cash = poor.strategic_ai.cash_reserve(poor.companies.rival.cash)
	check(poor_hq != null and poor.strategic_ai._staffing_commands(poor, "rival", poor.companies.rival.cash).is_empty(), "Staff hiring requires reserve plus 60 days payroll")
	var maker_cash: int = sim.companies.maker_b.cash
	var lab: SimFacility = add_build(sim, "maker_b", "research_center")
	check(lab != null, "AI R&D center fixture built through normal capex")
	check(maker_cash - sim.companies.maker_b.cash == int(sim.catalog.facility_types.research_center.cost), "Constructed strategic facility pays normal capex")
	var maker_choice: Dictionary = sim.strategic_ai.research_choice(sim, "maker_b", lab.id)
	check(not maker_choice.is_empty(), "Idle AI lab has a strategic project choice")
	if maker_choice.get("kind") != "technology":
		check(maker_choice.product in ["smartphone", "advanced_phone", "television", "earbuds"], "Continuous research targets actually manufactured products")
	var research_commands: Array = sim.strategic_ai.research_commands(sim)
	check(research_commands.any(func(c: Dictionary) -> bool: return c.company == "maker_b" and c.type == "assign_research"), "Idle lab receives prompt command-path assignment")
	add_build(sim, "maker_b", "component_plant", "battery")
	add_build(sim, "maker_b", "component_plant", "display")
	var warehouse_candidate: Dictionary = sim.strategic_ai._capital_command(sim, "maker_b", true, {})
	check(not warehouse_candidate.is_empty() and warehouse_candidate.archetype == "warehouse", "Network with at least three commercial facilities may build one warehouse")
	var small: Economy = fresh()
	check(small.strategic_ai._owned_commercial(small, "rival").size() < 3 or small.strategic_ai._capital_command(small, "rival", false, {}).archetype != "warehouse", "Small network does not prioritize warehouse")
	var warehouse: SimFacility = add_build(sim, "maker_b", "warehouse", "smartphone")
	check(warehouse != null, "Warehouse fixture built")
	check(sim.strategic_ai._capital_command(sim, "maker_b", true, {}).get("archetype", "") != "warehouse", "AI never duplicates its warehouse")
	var targets: Dictionary = sim.strategic_ai.warehouse_targets(sim, "maker_b", warehouse.id)
	var total: int = 0
	for quantity: int in targets.values(): total += quantity
	check(not targets.is_empty() and targets.size() <= Planner.MAX_WAREHOUSE_PRODUCTS and total <= warehouse.capacity, "Warehouse targets are relevant, bounded, and within capacity")
	var target_commands: Array = sim.strategic_ai._warehouse_target_commands(sim, "maker_b", warehouse.id, targets)
	for command: Dictionary in target_commands: sim.queue_command(command)
	sim.process_commands()
	var sourcing: Array = sim.strategic_ai._sourcing_commands(sim, "maker_b", warehouse.id, targets)
	check(sourcing.any(func(c: Dictionary) -> bool: return c.supplier == warehouse.id), "Downstream facility prefers configured valid owned warehouse")
	var automatic: Array = sim.strategic_ai._sourcing_commands(sim, "maker_b", "", {})
	check(automatic.all(func(c: Dictionary) -> bool: return c.supplier == ""), "No useful warehouse route returns sourcing to Automatic")

func _compatibility_and_separation() -> void:
	var sim: Economy = fresh()
	var player_staff_before: Dictionary = sim.companies.player.staff_counts.duplicate(true)
	var player_knowledge_before: Dictionary = sim.companies.player.known_technologies.duplicate(true)
	var local_before: Dictionary = sim.catalog.local_values("smartphone")
	var supplier_before: Array = sim.supplier_offers("20_player", "smartphone")
	sim.step()
	check(sim.companies.player.staff_counts == player_staff_before and sim.companies.player.known_technologies == player_knowledge_before, "Player company remains strategically untouched")
	check(sim.catalog.local_values("smartphone") == local_before, "Local remains unchanged")
	check(sim.strategic_trace.all(func(t: Dictionary) -> bool: return sim.companies[t.company].ai), "Trace contains AI companies only")
	check(sim.facility("20_player").suppliers.is_empty(), "Player sourcing remains unchanged")
	check(sim.facility("10_orion") != null and sim.headquarters("maker_a") == null, "Non-AI scenario company remains static")
	check(not sim.command_results.is_empty() and sim.command_results.all(func(r: Dictionary) -> bool: return r.accepted), "Strategic commands validate through ordinary FIFO")
	check(sim.invariant_errors().is_empty(), "Accounting and inventory invariants remain empty")
	check(sim.supplier_offers("20_player", "smartphone").size() >= supplier_before.size(), "Supplier ranking remains available and unmodified")
	var store: SimFacility = sim.facility("21_rival")
	var price: int = store.price
	for i: int in range(7): sim.step()
	check(store.price != price, "Existing weekly tactical pricing still operates")
	check(sim.companies.rival.advertising_budgets.smartphone >= 0, "Existing advertising policy still operates")
	check(sim.strategic_trace.size() > 0, "Strategic decisions expose a transient trace")
