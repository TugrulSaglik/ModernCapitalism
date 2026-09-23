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
	var session: GameSession = GameSession.new()
	check(session.start(2022, 42, "sandbox", {"preset": "legacy"}), "Session starts")
	session.time.set_speed(0)
	return session

func build(session: GameSession, type_id: String, product: String = "") -> SimFacility:
	var definition: Dictionary = session.sim.catalog.facility_types[type_id]
	var sites: Array[Vector2i] = session.sim.city.valid_sites(definition.width, definition.depth)
	if sites.is_empty(): return null
	var id: String = "built_%06d" % session.sim.city.next_facility
	check(session.submit({"type": "build_facility", "archetype": type_id, "product": product, "x": sites[0].x, "y": sites[0].y}), "Build " + type_id)
	return session.sim.facility(id)

func hq_with_staff(session: GameSession, role: String, quantity: int = 1) -> SimFacility:
	var hq: SimFacility = build(session, "corporate_headquarters")
	check(session.submit({"type": "hire_staff", "facility": hq.id, "role": role, "quantity": quantity}), "Hire " + role)
	return hq

func activate(session: GameSession) -> void:
	session.sim.companies.player.staff_payroll_funded = true

func isolate(session: GameSession, keep: Array[SimFacility]) -> void:
	for f: SimFacility in session.sim.facilities: f.operating = f in keep

func stock_recipe(session: GameSession, factory: SimFacility, days: int = 10) -> void:
	for input: String in session.sim.catalog.products[factory.product_id].inputs:
		factory.inventory.add(input, days * 100 * int(session.sim.catalog.products[factory.product_id].inputs[input]), 0, 50)

func _initialize() -> void:
	_catalog_and_activation()
	_operations()
	_marketing()
	_research()
	_finance_and_accounting()
	_persistence()
	await _ui()
	print("M8B3 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog_and_activation() -> void:
	var session: GameSession = fresh()
	var sim: Economy = session.sim
	check(sim.catalog.version == 9 and sim.snapshot().schema_version == 17 and SaveStore.FORMAT_VERSION == 2, "Catalog 9 / schema 17 / format 2")
	var expected: Dictionary = {
		"operations_manager": ["operations_capacity_percent", 10, 30],
		"marketing_manager": ["advertising_progress_percent", 10, 30],
		"research_manager": ["research_rate_percent", 10, 30],
		"finance_manager": ["facility_overhead_reduction_percent", 5, 15],
	}
	for role_id: String in expected:
		var role: Dictionary = sim.catalog.staff_roles[role_id]
		check([role.effect, role.effect_per_staff, role.effect_cap_percent] == expected[role_id], "Configured effect " + role_id)
	check(not sim.staff_effects_active("player") and sim.staff_effect_percent("player", "operations_manager") == 0, "No staff means no effects")
	var hq: SimFacility = hq_with_staff(session, "operations_manager")
	check(not sim.staff_effects_active("player"), "Staff without funded payroll inactive")
	activate(session)
	check(sim.staff_effects_active("player") and sim.staff_effect_percent("player", "operations_manager") == 10, "Funded staff and operating HQ active")
	hq.operating = false
	check(not sim.staff_effects_active("player") and sim.staff_effect_percent("player", "operations_manager") == 0, "Suspended HQ disables funded effects")
	var owner: SimCompany = sim.companies.player
	owner.cash = 4999
	sim.step()
	check(not owner.staff_payroll_funded and owner.staff_count("operations_manager") == 1 and owner.payroll_expense == 0, "Failed all-or-nothing payroll leaves staff and disables effects")
	hq.operating = true
	owner.cash = 100000
	sim.step()
	check(owner.staff_payroll_funded and sim.staff_effects_active("player"), "Resume plus next funded payroll reactivates effects")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveStore.DATA_PATH))
	for corruption: String in ["kind", "per", "cap", "order", "bounds", "duplicate"]:
		var data: Dictionary = raw.duplicate(true)
		match corruption:
			"kind": data.staff_roles[0].effect = "unknown"
			"per": data.staff_roles[0].effect_per_staff = 0
			"cap": data.staff_roles[0].effect_cap_percent = 1.5
			"order": data.staff_roles[0].effect_cap_percent = 5
			"bounds": data.staff_roles[0].effect_cap_percent = 101
			"duplicate": data.staff_roles[0].effect = data.staff_roles[1].effect
		var path: String = "res://.godot/m8b3-invalid.json"
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not SimCatalog.new().load_data(path), "Reject invalid staff effect " + corruption)

func _operations() -> void:
	var session: GameSession = fresh()
	var hq: SimFacility = hq_with_staff(session, "operations_manager")
	var factory: SimFacility = build(session, "assembly_plant", "smartphone")
	var store: SimFacility = session.sim.facility("20_player")
	activate(session)
	check(session.sim.effective_capacity(factory) == 19 and session.sim.effective_capacity(store) == 26, "One manager uses exact floored production and retail formula")
	stock_recipe(session, factory)
	factory.active = true
	check(session.sim.produce(factory) == 19 and factory.produced_today == 19 and session.sim.produce(factory) == 0, "Production exceeds base and stops at effective capacity")
	store.inventory.add("smartphone", 100, 100000, 50)
	store.active = true
	check(session.sim.consumer_sale(store, 100, "smartphone") == 26 and store.sold_today == 26 and session.sim.consumer_sale(store, 1, "smartphone") == 0, "Retail exceeds base and stops at effective checkout capacity")
	check(session.sim.production_input_target(factory, "processor") == 19 * factory.stock_days and session.sim.retail_replenishment_target(store) == 26 * store.stock_days, "Input and replenishment targets use effective capacity")
	var warehouse_definition: Dictionary = session.sim.catalog.facility_types.warehouse
	var warehouse: SimFacility = SimFacility.new({"id": "test_warehouse", "company": "player", "city": "metro", "type": "warehouse", "product": "smartphone", "capacity": warehouse_definition.capacity, "price": 1, "quality": 50})
	check(session.sim.effective_capacity(warehouse) == warehouse.capacity and session.sim.staff_capacity("player") == int(session.sim.catalog.facility_types.corporate_headquarters.staff_capacity), "Warehouse storage and HQ staffing capacity unchanged")
	session.sim.companies.player.staff_counts.operations_manager = 8
	check(session.sim.staff_effect_percent("player", "operations_manager") == 30 and session.sim.effective_capacity(factory) == 23 and session.sim.effective_capacity(store) == 31, "Operations bonus caps at 30 percent")
	check(hq.capacity == int(session.sim.catalog.facility_types.corporate_headquarters.capacity), "HQ base facility capacity is not mutated")

func _marketing() -> void:
	var session: GameSession = fresh()
	hq_with_staff(session, "marketing_manager")
	activate(session)
	var owner: SimCompany = session.sim.companies.player
	owner.advertising_budgets.smartphone = 100
	var cash: int = owner.cash
	var threshold: int = session.sim.advertising_threshold("smartphone", owner.brand("smartphone"))
	var local: Dictionary = session.sim.catalog.local_values("smartphone").duplicate(true)
	session.sim._advertise()
	check(cash - owner.cash == 100 and owner.advertising_expense == 100, "Marketing does not change advertising cash expense")
	check(owner.advertising_progress.smartphone == 110, "One marketing manager gives 10 percent effective progress")
	check(session.sim.advertising_threshold("smartphone", owner.brand("smartphone")) == threshold and session.sim.catalog.local_values("smartphone") == local, "Threshold, brand formula and Local remain unchanged")
	owner.staff_counts.marketing_manager = 8
	owner.advertising_progress.smartphone = 0
	session.sim._advertise()
	check(owner.advertising_progress.smartphone == 130, "Marketing bonus caps at 30 percent")
	owner.staff_payroll_funded = false
	owner.advertising_progress.smartphone = 0
	session.sim._advertise()
	check(owner.advertising_progress.smartphone == 100, "Inactive marketing uses exact base progress")

func _research_fixture(kind: String) -> Dictionary:
	var session: GameSession = fresh()
	hq_with_staff(session, "research_manager")
	var lab: SimFacility = build(session, "research_center")
	activate(session)
	lab.active = true
	var owner: SimCompany = session.sim.companies.player
	var project: Dictionary
	if kind == "technology":
		owner.known_technologies.erase("smart_home")
		project = session.sim.technology_project("smart_home")
	elif kind == "product_quality": project = session.sim.product_quality_project("player", "smartphone")
	else: project = session.sim.process_efficiency_project("player", "smartphone")
	lab.research_project = project
	return {"session": session, "lab": lab, "owner": owner, "project": project}

func _research() -> void:
	var rates: Dictionary = {}
	for count: int in [0, 1, 2, 3, 8]:
		var session: GameSession = fresh()
		var hq: SimFacility = build(session, "corporate_headquarters")
		if count > 0:
			session.sim.companies.player.staff_counts.research_manager = count
			activate(session)
		var lab: SimFacility = build(session, "research_center")
		rates[count] = session.sim.effective_research_rate(lab)
	check(rates == {0: 10, 1: 11, 2: 12, 3: 13, 8: 13}, "Research rate is base 10, exact 10 percent steps, capped at 13")
	for kind: String in ["technology", "product_quality", "process_efficiency"]:
		var fixture: Dictionary = _research_fixture(kind)
		var session: GameSession = fixture.session
		var owner: SimCompany = fixture.owner
		var project: Dictionary = fixture.project
		var cash: int = owner.cash
		session.sim._research()
		check(cash - owner.cash == session.sim.project_cost(project) and owner.research_expense == session.sim.project_cost(project), "Research cost unchanged for " + kind)
		check(session.sim.project_progress(owner, project) == 11, "Research manager advances " + kind + " by 11")
	var deterministic_a: Dictionary = _research_fixture("product_quality")
	var deterministic_b: Dictionary = _research_fixture("product_quality")
	deterministic_a.session.sim._research()
	deterministic_b.session.sim._research()
	check(same(deterministic_a.session.sim.snapshot(), deterministic_b.session.sim.snapshot()), "Research completion path remains deterministic")

func _finance_and_accounting() -> void:
	var session: GameSession = fresh()
	var hq: SimFacility = hq_with_staff(session, "finance_manager")
	var factory: SimFacility = build(session, "assembly_plant", "smartphone")
	activate(session)
	check(session.sim.effective_overhead(factory) == 17100 and session.sim.effective_overhead(hq) == 2375, "One finance manager reduces ordinary facility and HQ overhead by 5 percent")
	session.sim.companies.player.staff_counts.finance_manager = 8
	check(session.sim.staff_effect_percent("player", "finance_manager") == 15 and session.sim.effective_overhead(factory) == 15300, "Finance reduction caps at 15 percent")
	session.sim.companies.player.staff_counts.finance_manager = 1
	var owner: SimCompany = session.sim.companies.player
	owner.advertising_budgets.smartphone = 100
	var lab: SimFacility = build(session, "research_center")
	lab.research_project = session.sim.product_quality_project("player", "smartphone")
	isolate(session, [hq, factory, lab])
	var payroll_before: int = owner.payroll_expense
	var advertising_before: int = owner.advertising_expense
	var research_before: int = owner.research_expense
	var production_cost: int = session.sim.effective_conversion_cost("player", "smartphone")
	var depreciation_before: int = factory.accumulated_depreciation
	session.sim.step()
	var period: Dictionary = FinancialReports.period(owner, session.sim.clock)
	check(owner.payroll_expense - payroll_before == 5500, "Finance effect does not reduce payroll")
	check(owner.advertising_expense - advertising_before == 100, "Finance effect does not reduce advertising")
	check(owner.research_expense - research_before == session.sim.project_cost(session.sim.product_quality_project("player", "smartphone")), "Finance effect does not reduce research project cost")
	check(session.sim.effective_conversion_cost("player", "smartphone") == production_cost, "Finance effect does not reduce production conversion cost")
	check(factory.accumulated_depreciation - depreciation_before == factory.asset_cost / 3650, "Finance effect does not reduce depreciation")
	check(period.other_expenses == 2375 + 17100 + 475, "Actual reduced HQ, production and R&D overhead reaches ordinary expense")
	check(session.sim.invariant_errors().is_empty() and FinancialReports.balance(session.sim, "player").retained_earnings == owner.profit(), "Accounting identity remains exact with management effects")

func _persistence() -> void:
	var session: GameSession = fresh()
	hq_with_staff(session, "operations_manager")
	var factory: SimFacility = build(session, "assembly_plant", "smartphone")
	activate(session)
	factory.produced_today = session.sim.effective_capacity(factory)
	var store: SimFacility = session.sim.facility("20_player")
	store.sold_today = session.sim.effective_capacity(store)
	var state: Dictionary = session.sim.snapshot()
	var restored: Economy = SaveStore.new().restore(state)
	check(restored != null and same(state, restored.snapshot()), "Funded flag and effective-capacity counters restore exactly")
	if restored != null:
		session.sim.step()
		restored.step()
		check(same(session.sim.snapshot(), restored.snapshot()), "Deterministic continuation after staffed load")
	var malformed: Dictionary = state.duplicate(true)
	for company: Dictionary in malformed.companies:
		if company.id == "player": company.staff_payroll_funded = "yes"
	check(SaveStore.new().restore(malformed) == null, "Malformed funded flag rejected")
	var no_staff_funded: Dictionary = state.duplicate(true)
	for company: Dictionary in no_staff_funded.companies:
		if company.id == "player":
			company.staff_counts.operations_manager = 0
			company.staff_payroll_funded = true
	check(SaveStore.new().restore(no_staff_funded) == null, "Funded flag without staff rejected")
	var impossible: Dictionary = state.duplicate(true)
	for facility: Dictionary in impossible.facilities:
		if facility.id == factory.id: facility.produced_today = session.sim.effective_capacity(factory) + 1
	check(SaveStore.new().restore(impossible) == null, "Counter above applicable effective capacity rejected")
	var old_schema: Dictionary = state.duplicate(true)
	old_schema.schema_version = 14
	check(SaveStore.new().restore(old_schema) == null, "Schema 14 rejected under schema 15")

func _ui() -> void:
	var screen: Control = preload("res://src/ui/game_screen.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var hq: SimFacility = hq_with_staff(screen.session, "operations_manager", 2)
	screen.session.sim.companies.player.staff_counts.marketing_manager = 1
	screen.session.sim.companies.player.staff_counts.research_manager = 2
	screen.session.sim.companies.player.staff_counts.finance_manager = 1
	activate(screen.session)
	screen.city.sync(screen.session.sim.snapshot())
	screen.select_facility(hq.id)
	await process_frame
	var text: String = _all_text(screen.inspector.staffing_roles)
	check(screen.inspector.staffing_status.text.contains("ACTIVE") and text.contains("Operations manager") and text.contains("Current +20%"), "HQ inspector shows active operations effect")
	check(text.contains("Marketing manager") and text.contains("Current +10%") and text.contains("R&D manager") and text.contains("Current +20%"), "HQ inspector shows marketing and R&D effects")
	check(text.contains("Finance manager") and text.contains("Current −5%"), "HQ inspector shows finance effect")
	hq.operating = false
	screen.inspector.refresh()
	check(screen.inspector.staffing_status.text.contains("INACTIVE") and screen.inspector.staffing_status.text.contains("headquarters suspended"), "HQ suspension reason is readable")
	check(screen.inspector.staffing_roles.get_child_count() == 4, "HQ effect rows have adequate compact structure")
	screen.queue_free()

func _all_text(node: Node) -> String:
	var result: PackedStringArray = []
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append(_all_text(child))
	return " ".join(result)
