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

func build_headquarters(session: GameSession, company: String = "player") -> SimFacility:
	var definition: Dictionary = session.sim.catalog.facility_types.corporate_headquarters
	var sites: Array[Vector2i] = session.sim.city.valid_sites(definition.width, definition.depth)
	if sites.is_empty(): return null
	var command: Dictionary = {"type": "build_facility", "company": company, "archetype": "corporate_headquarters", "product": "", "x": sites[0].x, "y": sites[0].y}
	if company == session.player_company:
		check(session.submit(command), "Build player headquarters")
	else:
		session.sim.queue_command(command)
		session.sim.process_commands()
	return session.sim.headquarters(company)

func hire(session: GameSession, headquarters: SimFacility, role: String, quantity: int = 1) -> bool:
	return session.submit({"type": "hire_staff", "facility": headquarters.id, "role": role, "quantity": quantity})

func build_facility(session: GameSession, type_id: String, product: String) -> SimFacility:
	var definition: Dictionary = session.sim.catalog.facility_types[type_id]
	var site: Vector2i = session.sim.city.valid_sites(definition.width, definition.depth)[0]
	var next_id: String = "built_%06d" % session.sim.city.next_facility
	check(session.submit({"type": "build_facility", "archetype": type_id, "product": product, "x": site.x, "y": site.y}), "Build " + type_id)
	return session.sim.facility(next_id)

func suspend_other_player_facilities(session: GameSession, headquarters: SimFacility) -> void:
	for f: SimFacility in session.sim.facilities:
		if f.company_id == "player" and f != headquarters: f.operating = false

func _initialize() -> void:
	_staff_data_and_commands()
	_payroll_and_accounting()
	_demolition_and_separation()
	_persistence()
	await _ui()
	print("M8B2 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _staff_data_and_commands() -> void:
	var session: GameSession = fresh()
	var sim: Economy = session.sim
	check(sim.catalog.version == 9 and sim.snapshot().schema_version == 17 and SaveStore.FORMAT_VERSION == 2, "Catalog 9 / schema 17 / save format 2")
	var expected: Dictionary = {"operations_manager": ["Operations manager", 5000], "marketing_manager": ["Marketing manager", 5000], "research_manager": ["R&D manager", 6000], "finance_manager": ["Finance manager", 5500]}
	check(sim.catalog.staff_roles.size() == 4, "Four staff roles load")
	for role: String in expected:
		var definition: Dictionary = sim.catalog.staff_roles.get(role, {})
		check(definition.get("name") == expected[role][0] and definition.get("daily_salary") is int and definition.get("daily_salary") == expected[role][1], "Role definition: " + role)
	check(sim.catalog.facility_types.corporate_headquarters.staff_capacity == 8, "Headquarters capacity is eight")
	for owner: SimCompany in sim.companies.values():
		check(owner.staff_counts.size() == 4 and owner.total_staff() == 0, owner.id + " initializes every role at zero")
	var no_hq: Dictionary = {"type": "hire_staff", "company": "player", "facility": "20_player", "role": "operations_manager", "quantity": 1}
	check(not sim.command_error(no_hq).is_empty(), "Cannot hire without headquarters")
	var hq: SimFacility = build_headquarters(session)
	check(hire(session, hq, "operations_manager", 2) and sim.staff_count("player", "operations_manager") == 2, "Paused hiring applies at the between-day boundary")
	check(hire(session, hq, "marketing_manager", 3) and hire(session, hq, "research_manager", 3), "Multiple roles share capacity")
	check(sim.total_staff("player") == 8 and sim.daily_payroll("player") == 43000, "Counts and combined configured payroll are exact")
	check(not hire(session, hq, "finance_manager"), "Capacity cannot exceed eight")
	check(not session.submit({"type": "hire_staff", "facility": hq.id, "role": "unknown", "quantity": 1}), "Unknown role rejected")
	check(not session.submit({"type": "hire_staff", "facility": hq.id, "role": "operations_manager", "quantity": 0}) and not session.submit({"type": "hire_staff", "facility": hq.id, "role": "operations_manager", "quantity": -1}), "Nonpositive quantities rejected")
	check(session.submit({"type": "set_operating", "facility": hq.id, "operating": false}), "Suspend headquarters queued")
	sim.process_commands()
	check(not hq.operating and not hire(session, hq, "finance_manager"), "Hiring while suspended rejected")
	check(session.submit({"type": "dismiss_staff", "facility": hq.id, "role": "operations_manager", "quantity": 1}) and sim.staff_count("player", "operations_manager") == 1, "Dismissal works while suspended and decrements exact role")
	check(not session.submit({"type": "dismiss_staff", "facility": hq.id, "role": "finance_manager", "quantity": 1}), "Dismissal below zero rejected")
	var rival_hq: SimFacility = build_headquarters(session, "rival")
	check(not session.submit({"type": "hire_staff", "facility": rival_hq.id, "role": "finance_manager", "quantity": 1}), "Player cannot hire at another company's headquarters")
	check(not session.submit({"type": "hire_staff", "facility": "20_player", "role": "finance_manager", "quantity": 1}), "Non-headquarters facility rejected")

func _payroll_and_accounting() -> void:
	var session: GameSession = fresh()
	var hq: SimFacility = build_headquarters(session)
	suspend_other_player_facilities(session, hq)
	check(hire(session, hq, "research_manager") and hire(session, hq, "finance_manager", 2), "Payroll fixture hired")
	var owner: SimCompany = session.sim.companies.player
	var cash: int = owner.cash
	session.sim.step()
	check(cash - owner.cash == 6000 + 2 * 5500 + 2250, "Combined payroll and finance-adjusted HQ overhead paid exactly")
	check(owner.payroll_expense == 17000 and owner.cash_expenses >= 19250 and owner.expenses >= 19250, "Payroll increases payroll, cash and operating expenses")
	var period: Dictionary = FinancialReports.period(owner, session.sim.clock)
	check(period.payroll_expense == 17000 and period.other_expenses == 2250, "Income statement separates payroll from headquarters overhead")
	check(period.operating_cash == period.revenue - period.purchases - period.production_cash - period.cash_expenses, "Operating cash flow includes payroll")
	check(period.profit == period.revenue - period.cogs - period.expenses and owner.ttm_profit(session.sim.clock) == period.profit, "Profit and TTM include payroll")
	check(FinancialReports.balance(session.sim, "player").retained_earnings == owner.profit() and session.sim.invariant_errors().is_empty(), "Retained earnings and balance identity reconcile")
	var first_cash: int = owner.cash
	session.sim.step()
	check(first_cash - owner.cash == 19250 and owner.payroll_expense == 34000, "Payroll repeats every day")
	check(not owner.monthly_history.is_empty() and int(owner.monthly_history.back().payroll_expense) == 34000, "Monthly history carries payroll")
	hq.operating = false
	var overhead_before: int = int(FinancialReports.period(owner, session.sim.clock).other_expenses)
	var payroll_before: int = owner.payroll_expense
	session.sim.step()
	check(owner.payroll_expense == payroll_before + 17000 and int(FinancialReports.period(owner, session.sim.clock).other_expenses) == overhead_before, "Suspended headquarters still pays payroll but avoids building overhead")
	var priority: GameSession = fresh()
	var priority_hq: SimFacility = build_headquarters(priority)
	suspend_other_player_facilities(priority, priority_hq)
	hire(priority, priority_hq, "operations_manager")
	var priority_owner: SimCompany = priority.sim.companies.player
	priority_owner.cash = 5000
	priority_owner.advertising_budgets.smartphone = 5000
	priority.sim.step()
	check(priority_owner.payroll_expense == 5000 and priority_owner.advertising_expense == 0 and priority_owner.cash == 0, "Payroll is funded before advertising")
	var poor: GameSession = fresh()
	var poor_hq: SimFacility = build_headquarters(poor)
	suspend_other_player_facilities(poor, poor_hq)
	hire(poor, poor_hq, "research_manager")
	var poor_owner: SimCompany = poor.sim.companies.player
	poor_owner.cash = 5999
	poor.sim.step()
	check(poor_owner.payroll_expense == 0 and poor_owner.cash >= 0, "Unaffordable payroll pays zero and never overdrafts")
	check(poor.sim.staff_count("player", "research_manager") == 1, "Failed payroll retains employees")

func _demolition_and_separation() -> void:
	var session: GameSession = fresh()
	var hq: SimFacility = build_headquarters(session)
	hire(session, hq, "marketing_manager", 2)
	check(not session.submit({"type": "demolish_facility", "facility": hq.id}) and session.message.contains("Dismiss all staff"), "Staffed headquarters demolition rejected clearly")
	check(session.submit({"type": "dismiss_staff", "facility": hq.id, "role": "marketing_manager", "quantity": 2}), "All staff dismissed")
	check(session.submit({"type": "demolish_facility", "facility": hq.id}) and session.sim.headquarters("player") == null and session.sim.total_staff("player") == 0, "Empty headquarters demolition succeeds")
	check(build_headquarters(session) != null, "Replacement headquarters may be built")
	var staffed: GameSession = fresh()
	var control: GameSession = fresh()
	var staffed_hq: SimFacility = build_headquarters(staffed)
	var control_hq: SimFacility = build_headquarters(control)
	var staffed_factory: SimFacility = build_facility(staffed, "assembly_plant", "smartphone")
	var control_factory: SimFacility = build_facility(control, "assembly_plant", "smartphone")
	var staffed_lab: SimFacility = build_facility(staffed, "research_center", "")
	var control_lab: SimFacility = build_facility(control, "research_center", "")
	hire(staffed, staffed_hq, "operations_manager")
	var staffed_project: Dictionary = staffed.sim.product_quality_project("player", "smartphone")
	var control_project: Dictionary = control.sim.product_quality_project("player", "smartphone")
	check(staffed.submit({"type": "assign_research", "facility": staffed_lab.id, "project": staffed_project}) and control.submit({"type": "assign_research", "facility": control_lab.id, "project": control_project}), "Assign identical research projects")
	check(staffed.submit({"type": "set_advertising_budget", "product": "smartphone", "budget": 1000}) and control.submit({"type": "set_advertising_budget", "product": "smartphone", "budget": 1000}), "Set identical advertising")
	staffed.sim.companies.player.cash += 1000000
	staffed.sim.companies.player.capital += 1000000
	control.sim.companies.player.cash += 1000000
	control.sim.companies.player.capital += 1000000
	staffed.sim.step()
	control.sim.step()
	var staffed_store: SimFacility = staffed.sim.facility("20_player")
	var control_store: SimFacility = control.sim.facility("20_player")
	check(same(staffed_factory.inventory.snapshot(), control_factory.inventory.snapshot()) and same(staffed_store.inventory.snapshot(), control_store.inventory.snapshot()) and same(staffed.sim.market, control.sim.market), "Staff do not change production, quality, consumer demand or market clearing")
	var staffed_owner: SimCompany = staffed.sim.companies.player
	var control_owner: SimCompany = control.sim.companies.player
	check(staffed_owner.product_quality_levels == control_owner.product_quality_levels and staffed_owner.process_efficiency_levels == control_owner.process_efficiency_levels and staffed_owner.research_progress == control_owner.research_progress, "Staff do not change quality, process or research")
	check(staffed_owner.product_brands == control_owner.product_brands and staffed_owner.advertising_progress == control_owner.advertising_progress, "Staff do not change advertising growth or brand")

func _persistence() -> void:
	var session: GameSession = fresh()
	var hq: SimFacility = build_headquarters(session)
	hire(session, hq, "operations_manager", 2)
	hire(session, hq, "finance_manager")
	hq.operating = false
	session.sim.step()
	var state: Dictionary = session.sim.snapshot()
	var restored: Economy = SaveStore.new().restore(state)
	check(restored != null and same(state, restored.snapshot()), "Staffed suspended company restores exactly")
	if restored != null:
		session.sim.step()
		restored.step()
		check(same(session.sim.snapshot(), restored.snapshot()), "Payroll continuation is deterministic")
	var bad_role: Dictionary = state.duplicate(true)
	for company: Dictionary in bad_role.companies:
		if company.id == "player":
			company.staff_counts.erase("operations_manager")
			company.staff_counts.unknown_role = 2
	check(SaveStore.new().restore(bad_role) == null, "Unknown role in save rejected")
	var negative: Dictionary = state.duplicate(true)
	for company: Dictionary in negative.companies:
		if company.id == "player": company.staff_counts.operations_manager = -1
	check(SaveStore.new().restore(negative) == null, "Negative staff count rejected")
	var fractional: Dictionary = state.duplicate(true)
	for company: Dictionary in fractional.companies:
		if company.id == "player": company.staff_counts.operations_manager = 1.5
	check(SaveStore.new().restore(fractional) == null, "Fractional staff count rejected")
	var over_capacity: Dictionary = state.duplicate(true)
	for company: Dictionary in over_capacity.companies:
		if company.id == "player": company.staff_counts.operations_manager = 9
	check(SaveStore.new().restore(over_capacity) == null, "Over-capacity staff state rejected")
	var orphan: GameSession = fresh()
	var orphan_hq: SimFacility = build_headquarters(orphan)
	hire(orphan, orphan_hq, "operations_manager")
	orphan.sim._demolish(orphan_hq)
	check(SaveStore.new().restore(orphan.sim.snapshot()) == null, "Staff without headquarters rejected")
	var old_schema: Dictionary = state.duplicate(true)
	old_schema.schema_version = 14
	check(SaveStore.new().restore(old_schema) == null, "Schema 14 rejected under schema 15")

func _ui() -> void:
	var screen: Control = preload("res://src/ui/game_screen.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var hq: SimFacility = build_headquarters(screen.session)
	hire(screen.session, hq, "operations_manager")
	screen.city.sync(screen.session.sim.snapshot())
	screen.select_facility(hq.id)
	await process_frame
	var panel: FacilityPanel = screen.inspector
	check((panel.staffing_metrics.capacity as Label).text == "1 / 8 employed" and (panel.staffing_metrics.payroll as Label).text == "$50.00/day", "HQ inspector shows staff capacity and payroll")
	for name: String in ["Operations manager", "Marketing manager", "R&D manager", "Finance manager"]:
		check(_all_text(panel.staffing_roles).contains(name), "HQ inspector shows " + name)
	check(panel.staff_role.item_count == 4 and panel.hire_staff.visible and panel.dismiss_staff.visible, "Four roles selectable with Hire/Dismiss controls")
	var chosen: int = -1
	for index: int in range(panel.staff_role.item_count):
		if panel.staff_role.get_item_metadata(index) == "operations_manager": chosen = index
	panel.staff_role.select(chosen)
	panel.refresh()
	check(not panel.hire_staff.disabled and not panel.dismiss_staff.disabled and panel.demolish.disabled, "Owned staffed HQ enables staffing and blocks demolition")
	panel.hire_staff.pressed.emit()
	check(screen.session.sim.staff_count("player", "operations_manager") == 2, "Hire button submits correct command")
	panel.dismiss_staff.pressed.emit()
	check(screen.session.sim.staff_count("player", "operations_manager") == 1, "Dismiss button submits correct command")
	screen.reports.refresh()
	var report_has_payroll: bool = false
	var report_row: TreeItem = screen.reports.table.get_root().get_first_child()
	while report_row != null:
		if report_row.get_text(0) == "Payroll": report_has_payroll = true
		report_row = report_row.get_next()
	check(report_has_payroll, "Income Statement exposes payroll separately")
	hq.operating = false
	panel.refresh()
	check(panel.hire_staff.disabled and not panel.dismiss_staff.disabled, "Suspension disables Hire but leaves Dismiss available")
	screen.queue_free()

func _all_text(node: Node) -> String:
	var result: PackedStringArray = []
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append(_all_text(child))
	return " ".join(result)
