extends SceneTree

const CASES: Array[Dictionary] = [
	{"era": 2022, "difficulty": "relaxed", "days": 730},
	{"era": 2022, "difficulty": "standard", "days": 730},
	{"era": 2022, "difficulty": "competitive", "days": 730},
	{"era": 2012, "difficulty": "standard", "days": 1095},
	{"era": 2012, "difficulty": "competitive", "days": 1095},
]

var failures: int = 0

func fail(label: String) -> void:
	failures += 1
	printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func _initialize() -> void:
	for item: Dictionary in CASES:
		_run_case(int(item.era), str(item.difficulty), int(item.days))
	print("M8D BALANCE MATRIX RESULT: %d cases, %d failures" % [CASES.size(), failures])
	quit(0 if failures == 0 else 1)

func _run_case(era: int, difficulty: String, days: int) -> void:
	var a: Economy = Economy.new()
	var b: Economy = Economy.new()
	if not a.initialize(42, era, SaveStore.DATA_PATH, {}, difficulty) or not b.initialize(42, era, SaveStore.DATA_PATH, {}, difficulty):
		fail("Initialize %d/%s" % [era, difficulty])
		return
	var starting_retailers: Dictionary = {}
	for company_id: String in ["maker_b", "rival"]:
		starting_retailers[company_id] = a.strategic_ai._owned_facilities(a, company_id, "retail").size()
	var invalid_commands: int = 0
	var maximum_pending: int = 0
	for day: int in range(days):
		a.step()
		b.step()
		maximum_pending = maxi(maximum_pending, a.pending_commands.size())
		for result: Dictionary in a.command_results:
			if not result.accepted: invalid_commands += 1
		if not a.invariant_errors().is_empty() or not b.invariant_errors().is_empty():
			fail("Invariant failure day %d %d/%s: %s" % [day, era, difficulty, a.invariant_errors()])
			return
		for owner: SimCompany in a.companies.values():
			if owner.cash < 0:
				fail("Negative cash day %d %s" % [day, owner.id])
				return
	if not same(a.snapshot(), b.snapshot()): fail("Deterministic repeat %d/%s" % [era, difficulty])
	if maximum_pending != 0 or not a.pending_commands.is_empty(): fail("Pending command accumulation %d/%s" % [era, difficulty])
	if invalid_commands != 0: fail("Invalid strategic commands %d/%s count=%d" % [era, difficulty, invalid_commands])
	var max_retailers: int = int(a.strategic_ai.difficulty_profile(difficulty).maximum_retailers)
	var invalid_facilities: int = 0
	var total_facilities: int = a.facilities.size()
	var ai_summary: Dictionary = {}
	for company_id: String in ["maker_b", "rival"]:
		var behaviors: Dictionary = {}
		var active_lines: Dictionary = {}
		var hq_count: int = 0
		var warehouse_count: int = 0
		var research_count: int = 0
		for f: SimFacility in a.facilities:
			if f.company_id != company_id: continue
			var behavior: String = a._behavior(f)
			behaviors[behavior] = int(behaviors.get(behavior, 0)) + 1
			if behavior == "headquarters": hq_count += 1
			elif behavior == "storage": warehouse_count += 1
			elif behavior == "research": research_count += 1
			elif behavior == "retail":
				for product: String in f.line_ids(): active_lines[product] = true
			if f.id.begins_with("built_") and not a.can_configure(company_id, f.type_id, f.product_id): invalid_facilities += 1
		# The full scenario starts rival with three stores. A difficulty cap below
		# that cannot remove existing stores; it must prevent further construction.
		if int(behaviors.get("retail", 0)) > maxi(int(starting_retailers[company_id]), max_retailers): fail("Retail cap %d/%s/%s" % [era, difficulty, company_id])
		if hq_count > 1: fail("Duplicate HQ %d/%s/%s" % [era, difficulty, company_id])
		if warehouse_count > 1: fail("Duplicate warehouse %d/%s/%s" % [era, difficulty, company_id])
		if research_count > 1: fail("Duplicate R&D %d/%s/%s" % [era, difficulty, company_id])
		var owner: SimCompany = a.companies[company_id]
		var quality_levels: int = 0
		var process_levels: int = 0
		for value: int in owner.product_quality_levels.values(): quality_levels += value
		for value: int in owner.process_efficiency_levels.values(): process_levels += value
		var brands: Array[int] = []
		for product: String in owner.product_brands: brands.append(int(owner.product_brands[product]))
		var brand_total: int = 0
		for value: int in brands: brand_total += value
		ai_summary[company_id] = {
			"cash": owner.cash, "cumulative_profit": owner.profit(), "facilities": behaviors,
			"staff": owner.total_staff(), "known_technologies": owner.known_technologies.size(),
			"quality_levels_total": quality_levels, "process_levels_total": process_levels,
			"active_product_lines": active_lines.size(),
			"brand_min": brands.min(), "brand_max": brands.max(), "brand_average": float(brand_total) / float(brands.size()),
			"warehouse": warehouse_count > 0, "headquarters": hq_count > 0, "research_center": research_count > 0,
		}
	if invalid_facilities != 0: fail("Era-invalid built facilities %d/%s" % [era, difficulty])
	var local_units: int = 0
	var realized_units: int = 0
	for report: Dictionary in a.market.values():
		local_units += int(report.get("local_units", 0))
		realized_units += int(report.get("units", 0))
	var aggregate: Dictionary = {
		"consumer_purchases": a.cumulative_consumer_units,
		"current_local_units": local_units,
		"current_realized_units": realized_units,
		"total_facilities": total_facilities,
		"pending_commands": a.pending_commands.size(),
		"invalid_commands": invalid_commands,
		"invariant_errors": a.invariant_errors(),
	}
	print("M8D BALANCE era=%d difficulty=%s days=%d ai=%s aggregate=%s" % [era, difficulty, days, JSON.stringify(ai_summary), JSON.stringify(aggregate)])
