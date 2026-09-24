class_name StrategicAI
extends RefCounted

# Milestone 8C's planner is deliberately stateless. Economy remains authoritative;
# this object only derives ordinary commands from the current completed state.
const MAX_WAREHOUSE_PRODUCTS: int = 6
const DIFFICULTY_IDS: Array[String] = ["relaxed", "standard", "competitive"]
const DIFFICULTY_PROFILES: Dictionary = {
	"relaxed": {
		"display_name": "Relaxed", "minimum_cash_reserve": 7500000, "reserve_divisor": 3,
		"opportunity_threshold": 70, "maximum_retailers": 2,
		"warehouse_commercial_threshold": 4, "staff_payroll_runway_days": 90,
		"description": "More conservative competitors that retain larger cash buffers and expand selectively.",
	},
	"standard": {
		"display_name": "Standard", "minimum_cash_reserve": 5000000, "reserve_divisor": 4,
		"opportunity_threshold": 40, "maximum_retailers": 3,
		"warehouse_commercial_threshold": 3, "staff_payroll_runway_days": 60,
		"description": "Baseline competitive behavior and capital discipline.",
	},
	"competitive": {
		"display_name": "Competitive", "minimum_cash_reserve": 3500000, "reserve_divisor": 5,
		"opportunity_threshold": 25, "maximum_retailers": 4,
		"warehouse_commercial_threshold": 2, "staff_payroll_runway_days": 45,
		"description": "More assertive competitors with smaller reserves and earlier expansion.",
	},
}

func valid_difficulty(difficulty: Variant) -> bool:
	return difficulty is String and DIFFICULTY_PROFILES.has(difficulty)

func difficulty_profile(difficulty: String = "standard") -> Dictionary:
	return DIFFICULTY_PROFILES.get(difficulty, {}).duplicate(true)

func difficulty_display_name(difficulty: String = "standard") -> String:
	return str(DIFFICULTY_PROFILES.get(difficulty, {}).get("display_name", ""))

func cash_reserve(cash: int, profile: Dictionary = DIFFICULTY_PROFILES.standard) -> int:
	@warning_ignore("integer_division")
	return maxi(int(profile.minimum_cash_reserve), cash / int(profile.reserve_divisor))

# Integer score based on currently observable demand. Category unmet demand and
# Local-held units raise urgency; the company's realized share lowers it.
func market_opportunity(sim, company_id: String, product: String, city_id: String = "") -> int:
	if not sim.catalog.products.has(product) or not sim.catalog.consumer_product(product): return -1000000
	var definition: Dictionary = sim.catalog.products[product]
	var categories: Dictionary = sim.category_market if city_id.is_empty() else sim.category_market_by_city.get(city_id, {})
	var markets: Dictionary = sim.market if city_id.is_empty() else sim.market_by_city.get(city_id, {})
	var category: Dictionary = categories.get(str(definition.category), {})
	var report: Dictionary = markets.get(product, {})
	var unmet: int = maxi(0, int(category.get("potential", 0)) - int(category.get("units", 0)))
	var local_units: int = int(report.get("local_units", 0))
	var realized: int = int(report.get("units", 0))
	var company_units: int = int(report.get("company_units", {}).get(company_id, 0))
	@warning_ignore("integer_division")
	var share_percent: int = company_units * 100 / realized if realized > 0 else 0
	return int(definition.daily_demand) * 4 + unmet * 2 + local_units * 3 - share_percent

func eligible_consumer_products(sim) -> Array[String]:
	var result: Array[String] = []
	var products: Array = sim.catalog.products.keys()
	products.sort()
	for product: String in products:
		if not sim.catalog.consumer_product(product) or not sim.product_public(product): continue
		for type_id: String in sim.catalog.facility_types:
			var definition: Dictionary = sim.catalog.facility_types[type_id]
			if definition.behavior == "retail" and sim.catalog.supports_product(type_id, product):
				result.append(product)
				break
	return result

func evaluate_month(sim) -> Dictionary:
	var profile: Dictionary = difficulty_profile(sim.difficulty)
	var commands: Array[Dictionary] = []
	var trace: Array[Dictionary] = []
	var reserved: Dictionary = {}
	var company_ids: Array = sim.companies.keys()
	company_ids.sort()
	for company_id: String in company_ids:
		if not sim.ai_eligible(company_id): continue
		var assortment: Array[Dictionary] = _assortment_commands(sim, company_id, profile)
		commands.append_array(assortment)
		for command: Dictionary in assortment:
			trace.append(_trace(company_id, "ADD_LINE", str(command.product), market_opportunity(sim, company_id, str(command.product))))

		var capital: Dictionary = {}
		var city_ids: Array = sim.cities.keys()
		city_ids.sort()
		for city_id: String in city_ids:
			var candidate: Dictionary = _capital_command(sim, company_id, not assortment.is_empty(), reserved, profile, city_id)
			if candidate.is_empty(): candidate = _property_command(sim, company_id, reserved, profile, city_id)
			if candidate.is_empty(): continue
			if capital.is_empty() or int(candidate.get("priority", 0)) > int(capital.get("priority", 0)) or (int(candidate.get("priority", 0)) == int(capital.get("priority", 0)) and int(candidate.get("strategic_score", 0)) > int(capital.get("strategic_score", 0))): capital = candidate
		var post_capital_cash: int = int(sim.companies[company_id].cash)
		if not capital.is_empty():
			commands.append(capital)
			if capital.type == "build_facility":
				var definition: Dictionary = sim.catalog.facility_types[str(capital.archetype)]
				post_capital_cash -= int(definition.cost) + (0 if sim.cities[capital.city].generation.preset == "legacy" else sim.real_estates[capital.city].land_cost(sim, company_id, int(capital.x), int(capital.y), int(definition.width), int(definition.depth)))
				_reserve_footprint(sim, capital, reserved)
				trace.append(_trace(company_id, "BUILD", "%s/%s" % [capital.archetype, capital.get("product", "")], int(capital.get("strategic_score", 0))))
			else:
				var definition: Dictionary = sim.catalog.property_types[str(capital.property_type)]
				post_capital_cash -= int(definition.cost) + sim.real_estates[capital.city].land_cost(sim, company_id, int(capital.x), int(capital.y), int(definition.width), int(definition.depth))
				for cell: String in sim.real_estates[capital.city].cells(int(capital.x), int(capital.y), int(definition.width), int(definition.depth)): reserved[str(capital.city) + ":" + cell] = true
				trace.append(_trace(company_id, "PROPERTY", str(capital.property_type), int(capital.get("strategic_score", 0))))
			capital.erase("strategic_score")
			capital.erase("priority")

		commands.append_array(_staffing_commands(sim, company_id, post_capital_cash, profile))
		for city_id: String in city_ids:
			var warehouse: Dictionary = _owned_facility(sim, company_id, "storage", city_id)
			if not warehouse.is_empty():
				var targets: Dictionary = warehouse_targets(sim, company_id, str(warehouse.id))
				commands.append_array(_warehouse_target_commands(sim, company_id, str(warehouse.id), targets))
				commands.append_array(_sourcing_commands(sim, company_id, str(warehouse.id), targets, city_id))
			else:
				commands.append_array(_sourcing_commands(sim, company_id, "", {}, city_id))
	return {"commands": commands, "trace": trace}

func research_commands(sim) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var company_ids: Array = sim.companies.keys()
	company_ids.sort()
	for company_id: String in company_ids:
		if not sim.ai_eligible(company_id): continue
		var centers: Array = _owned_facilities(sim, company_id, "research")
		for center: Dictionary in centers:
			var facility = sim.facility(str(center.id))
			if not facility.operating or not facility.research_project.is_empty(): continue
			var project: Dictionary = research_choice(sim, company_id, facility.id)
			if not project.is_empty():
				result.append({"type": "assign_research", "company": company_id, "facility": facility.id, "project": project})
	return result

func research_choice(sim, company_id: String, except_facility: String = "") -> Dictionary:
	var profile: Dictionary = difficulty_profile(sim.difficulty)
	var relevant_products: Dictionary = {}
	for f in sim.facilities:
		if f.company_id != company_id: continue
		if sim._behavior(f) == "retail":
			for product: String in f.line_ids(): relevant_products[product] = true
		elif sim._behavior(f) == "production":
			relevant_products[f.product_id] = true
			for input: String in sim.catalog.products[f.product_id].inputs: relevant_products[input] = true
	for product: String in eligible_consumer_products(sim):
		if market_opportunity(sim, company_id, product) >= int(profile.opportunity_threshold): relevant_products[product] = true

	var technologies: Array[Dictionary] = []
	for technology: String in sim.catalog.technologies:
		var project: Dictionary = sim.technology_project(technology)
		if not sim.research_project_error(company_id, project, except_facility).is_empty(): continue
		var relevance: int = 0
		for product: String in relevant_products:
			if str(sim.catalog.products[product].technology) == technology:
				relevance += 1000 + maxi(0, market_opportunity(sim, company_id, product))
		if relevance > 0:
			technologies.append({"project": project, "relevance": relevance, "year": int(sim.catalog.technologies[technology].year), "id": technology})
	technologies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.relevance != b.relevance: return int(a.relevance) > int(b.relevance)
		if a.year != b.year: return int(a.year) < int(b.year)
		return str(a.id) < str(b.id))
	if not technologies.is_empty(): return technologies[0].project

	var continuous: Array[Dictionary] = []
	for f in sim.facilities:
		if f.company_id != company_id or sim._behavior(f) != "production": continue
		var product: String = f.product_id
		for project: Dictionary in [sim.product_quality_project(company_id, product), sim.process_efficiency_project(company_id, product)]:
			if sim.research_project_error(company_id, project, except_facility).is_empty():
				var level: int = sim.companies[company_id].product_quality_level(product) if project.kind == "product_quality" else sim.companies[company_id].process_efficiency_level(product)
				continuous.append({"project": project, "score": market_opportunity(sim, company_id, product), "level": level, "product": product, "kind": str(project.kind)})
	continuous.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score: return int(a.score) > int(b.score)
		if a.level != b.level: return int(a.level) < int(b.level)
		if a.product != b.product: return str(a.product) < str(b.product)
		return str(a.kind) == "product_quality" and str(b.kind) == "process_efficiency")
	return {} if continuous.is_empty() else continuous[0].project

func warehouse_targets(sim, company_id: String, warehouse_id: String) -> Dictionary:
	var warehouse = sim.facility(warehouse_id)
	if warehouse == null or warehouse.company_id != company_id or sim._behavior(warehouse) != "storage": return {}
	var requirements: Dictionary = {}
	for f in sim.facilities:
		if f.company_id != company_id or f.id == warehouse_id or f.city_id != warehouse.city_id: continue
		if sim._behavior(f) == "retail":
			for product: String in f.line_ids():
				requirements[product] = int(requirements.get(product, 0)) + sim.retail_replenishment_target(f)
		elif sim._behavior(f) == "production":
			for input: String in sim.catalog.products[f.product_id].inputs:
				requirements[input] = int(requirements.get(input, 0)) + sim.production_input_target(f, input)
	var ranked: Array[Dictionary] = []
	for product: String in requirements:
		ranked.append({"product": product, "requirement": int(requirements[product]), "opportunity": market_opportunity(sim, company_id, product) if sim.catalog.consumer_product(product) else 0})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.requirement != b.requirement: return int(a.requirement) > int(b.requirement)
		if a.opportunity != b.opportunity: return int(a.opportunity) > int(b.opportunity)
		return str(a.product) < str(b.product))
	if ranked.size() > MAX_WAREHOUSE_PRODUCTS: ranked.resize(MAX_WAREHOUSE_PRODUCTS)
	var total_weight: int = 0
	for item: Dictionary in ranked: total_weight += int(item.requirement)
	var targets: Dictionary = {}
	var remaining: int = warehouse.capacity
	for index: int in range(ranked.size()):
		var item: Dictionary = ranked[index]
		var slots_left: int = ranked.size() - index
		var quantity: int = remaining if slots_left == 1 else mini(remaining - (slots_left - 1), maxi(1, warehouse.capacity * int(item.requirement) / maxi(1, total_weight)))
		targets[str(item.product)] = quantity
		remaining -= quantity
	return targets

func _assortment_commands(sim, company_id: String, profile: Dictionary = DIFFICULTY_PROFILES.standard) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in _owned_facilities(sim, company_id, "retail"):
		var f = sim.facility(str(item.id))
		var definition: Dictionary = sim.catalog.facility_types[f.type_id]
		if f.assortment.size() >= int(definition.slots): continue
		var candidates: Array[Dictionary] = []
		for product: String in eligible_consumer_products(sim):
			if f.assortment.has(product) or not sim.catalog.supports_product(f.type_id, product): continue
			var score: int = market_opportunity(sim, company_id, product, f.city_id)
			if score >= int(profile.opportunity_threshold): candidates.append({"product": product, "score": score})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score) if a.score != b.score else str(a.product) < str(b.product))
		if not candidates.is_empty(): result.append({"type": "add_line", "company": company_id, "facility": f.id, "product": str(candidates[0].product)})
	return result

func _capital_command(sim, company_id: String, assortment_added: bool, reserved: Dictionary, profile: Dictionary, city_id: String) -> Dictionary:
	var owner = sim.companies[company_id]
	var candidates: Array[Dictionary] = []
	var commercials: Array = _owned_commercial(sim, company_id, city_id)
	# Structural input gaps outrank elective investment, but an existing physical
	# producer counts as a supply path even when it is temporarily out of stock.
	for f in sim.facilities:
		if f.company_id != company_id or f.city_id != city_id or sim._behavior(f) != "production": continue
		var inputs: Array = sim.catalog.products[f.product_id].inputs.keys()
		inputs.sort()
		for input: String in inputs:
			if _has_structural_supplier(sim, f.id, input) or _owns_production(sim, company_id, input) or not sim.can_manufacture(company_id, input): continue
			var archetype: String = _production_archetype(sim, input)
			if not archetype.is_empty(): candidates.append({"priority": 600, "score": sim.production_input_target(f, input), "archetype": archetype, "product": input})
	if not _owned_commercial(sim, company_id).is_empty() and sim.headquarters(company_id) == null and city_id == "metro":
		var hq_type: String = _cheapest_type(sim, "headquarters")
		if not hq_type.is_empty(): candidates.append({"priority": 500, "score": commercials.size(), "archetype": hq_type, "product": ""})
	if not _owned_commercial(sim, company_id).is_empty() and _owned_facilities(sim, company_id, "research").is_empty() and not research_choice(sim, company_id).is_empty() and city_id == "metro":
		var research_type: String = _cheapest_type(sim, "research")
		if not research_type.is_empty(): candidates.append({"priority": 400, "score": 0, "archetype": research_type, "product": ""})
	for product: String in _sold_products(sim, company_id, city_id):
		if not _owns_production(sim, company_id, product) and sim.can_manufacture(company_id, product):
			var score: int = market_opportunity(sim, company_id, product, city_id)
			var archetype: String = _production_archetype(sim, product)
			if score >= int(profile.opportunity_threshold) and not archetype.is_empty(): candidates.append({"priority": 300, "score": score, "archetype": archetype, "product": product})
	var retailers: Array = _owned_facilities(sim, company_id, "retail", city_id)
	if not assortment_added and retailers.size() < int(profile.maximum_retailers):
		var served: Dictionary = {}
		for item: Dictionary in retailers:
			for product: String in sim.facility(str(item.id)).line_ids(): served[product] = true
		var opportunities: Array[Dictionary] = []
		for product: String in eligible_consumer_products(sim):
			if not served.has(product): opportunities.append({"product": product, "score": market_opportunity(sim, company_id, product, city_id)})
		opportunities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score) if a.score != b.score else str(a.product) < str(b.product))
		if not opportunities.is_empty() and int(opportunities[0].score) >= int(profile.opportunity_threshold):
			var retail_type: String = _retail_archetype(sim, str(opportunities[0].product))
			if not retail_type.is_empty(): candidates.append({"priority": 200, "score": int(opportunities[0].score), "archetype": retail_type, "product": str(opportunities[0].product)})
	if commercials.size() >= int(profile.warehouse_commercial_threshold) and _owned_facilities(sim, company_id, "storage", city_id).is_empty():
		var storage_type: String = _cheapest_type(sim, "storage")
		if not storage_type.is_empty(): candidates.append({"priority": 100, "score": commercials.size(), "archetype": storage_type, "product": str(sim.catalog.facility_types[storage_type].products[0])})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority: return int(a.priority) > int(b.priority)
		if a.score != b.score: return int(a.score) > int(b.score)
		if a.archetype != b.archetype: return str(a.archetype) < str(b.archetype)
		return str(a.product) < str(b.product))
	var reserve: int = cash_reserve(owner.cash, profile)
	for candidate: Dictionary in candidates:
		var site: Vector2i = _placement_for(sim, company_id, str(candidate.archetype), str(candidate.product), reserved, city_id)
		if site.x < 0: continue
		var definition: Dictionary = sim.catalog.facility_types[str(candidate.archetype)]
		var cost: int = int(definition.cost) + (0 if sim.cities[city_id].generation.preset == "legacy" else sim.real_estates[city_id].land_cost(sim, company_id, site.x, site.y, int(definition.width), int(definition.depth)))
		if owner.cash - cost < reserve: continue
		return {"type": "build_facility", "company": company_id, "city": city_id, "archetype": str(candidate.archetype), "product": str(candidate.product), "x": site.x, "y": site.y, "strategic_score": int(candidate.score), "priority": int(candidate.priority)}
	return {}

func _property_command(sim, company_id: String, reserved: Dictionary, profile: Dictionary, city_id: String) -> Dictionary:
	var city: CityMap = sim.cities[city_id]
	var estate: RealEstate = sim.real_estates[city_id]
	if city.generation.preset == "legacy": return {}
	var population: Dictionary = city.population
	var housing: int = int(population.housing_capacity)
	var people: int = int(population.total)
	var workforce: int = int(population.workforce)
	var jobs: int = int(population.jobs)
	var type_id: String = ""
	if housing > 0 and people * 100 > housing * 90 and jobs * 2 > people + 40:
		type_id = "block" if people * 100 > housing * 94 else "apartments"
	elif jobs * 2 < housing * 95 / 100 and jobs - workforce < 60:
		type_id = "office" if housing - people > 120 else "commercial"
	if type_id.is_empty(): return {}
	var definition: Dictionary = sim.catalog.property_types[type_id]
	var owner = sim.companies[company_id]
	var reserve: int = cash_reserve(owner.cash, profile)
	for y: int in range(city.depth - int(definition.depth) + 1):
		for x: int in range(city.width - int(definition.width) + 1):
			if _reserved_overlap(x, y, int(definition.width), int(definition.depth), reserved, city_id): continue
			var command: Dictionary = {"type": "develop_property", "company": company_id, "city": city_id, "property_type": type_id, "x": x, "y": y}
			if not sim.property_command_error(command).is_empty(): continue
			var cost: int = int(definition.cost) + estate.land_cost(sim, company_id, x, y, int(definition.width), int(definition.depth))
			if owner.cash - cost >= reserve:
				command["strategic_score"] = housing - people if type_id in ["apartments", "block"] else workforce - jobs
				command["priority"] = 50
				return command
	return {}
	return {}

func _staffing_commands(sim, company_id: String, available_cash: int, profile: Dictionary = DIFFICULTY_PROFILES.standard) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var hq = sim.headquarters(company_id)
	if hq == null or not hq.operating: return result
	var production_count: int = _owned_facilities(sim, company_id, "production").size()
	var retail_count: int = _owned_facilities(sim, company_id, "retail").size()
	var research_count: int = _owned_facilities(sim, company_id, "research").size()
	var targets: Dictionary = {
		"operations_manager": 2 if production_count + retail_count > 0 else 0,
		"marketing_manager": (2 if retail_count > 1 else 1) if retail_count > 0 else 0,
		"research_manager": 2 if research_count > 0 else 0,
		"finance_manager": 1 if production_count + retail_count > 0 else 0,
	}
	var roles: Array = sim.catalog.staff_roles.keys()
	roles.sort()
	var desired: Dictionary = {}
	var capacity_left: int = sim.staff_capacity(company_id)
	for role: String in roles:
		desired[role] = mini(int(targets.get(role, 0)), capacity_left)
		capacity_left -= int(desired[role])
	var resulting_payroll: int = 0
	for role: String in roles: resulting_payroll += int(desired[role]) * int(sim.catalog.staff_roles[role].daily_salary)
	var can_hire: bool = available_cash >= cash_reserve(sim.companies[company_id].cash, profile) + resulting_payroll * int(profile.staff_payroll_runway_days)
	for role: String in roles:
		var current: int = sim.staff_count(company_id, role)
		var target: int = int(desired[role])
		if current > target:
			result.append({"type": "dismiss_staff", "company": company_id, "facility": hq.id, "role": role, "quantity": current - target})
		elif current < target and can_hire:
			result.append({"type": "hire_staff", "company": company_id, "facility": hq.id, "role": role, "quantity": target - current})
	return result

func _warehouse_target_commands(sim, company_id: String, warehouse_id: String, targets: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var warehouse = sim.facility(warehouse_id)
	var products: Dictionary = {}
	for product: String in warehouse.replenishment_targets: products[product] = true
	for product: String in targets: products[product] = true
	var ids: Array = products.keys()
	ids.sort()
	for product: String in ids:
		var quantity: int = int(targets.get(product, 0))
		if int(warehouse.replenishment_targets.get(product, -1)) != quantity:
			result.append({"type": "set_warehouse_target", "company": company_id, "facility": warehouse_id, "product": product, "quantity": quantity})
	return result

func _sourcing_commands(sim, company_id: String, warehouse_id: String, targets: Dictionary, city_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in _owned_commercial(sim, company_id):
		var f = sim.facility(str(item.id))
		if f.city_id != city_id: continue
		var products: Array = f.line_ids() if sim._behavior(f) == "retail" else sim.catalog.products[f.product_id].inputs.keys()
		products.sort()
		for product: String in products:
			var supplier: String = ""
			if not warehouse_id.is_empty() and int(targets.get(product, 0)) > 0 and sim.cities[city_id].road_distance(warehouse_id, f.id) >= 0: supplier = warehouse_id
			if str(f.suppliers.get(product, "")) != supplier:
				result.append({"type": "set_supplier", "company": company_id, "facility": f.id, "product": product, "supplier": supplier})
	return result

func _placement_for(sim, company_id: String, type_id: String, product: String, reserved: Dictionary, city_id: String) -> Vector2i:
	var definition: Dictionary = sim.catalog.facility_types[type_id]
	var city: CityMap = sim.cities[city_id]
	var sites: Array[Dictionary] = []
	for point: Vector2i in city.valid_sites(int(definition.width), int(definition.depth)):
		if _reserved_overlap(point.x, point.y, int(definition.width), int(definition.depth), reserved, city_id): continue
		var command: Dictionary = {"type": "build_facility", "company": company_id, "city": city_id, "archetype": type_id, "product": product, "x": point.x, "y": point.y}
		if not sim.construction_error(command).is_empty(): continue
		var distance: int = 0
		var found: bool = false
		for f in sim.facilities:
			if f.company_id != company_id or f.city_id != city_id or not city.plots.has(f.id): continue
			var plot: Dictionary = city.plots[f.id]
			var d: int = absi(point.x - int(plot.x)) + absi(point.y - int(plot.y))
			if not found or d < distance: distance = d
			found = true
		sites.append({"point": point, "distance": distance if found else 0})
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.distance != b.distance: return int(a.distance) < int(b.distance)
		if a.point.y != b.point.y: return int(a.point.y) < int(b.point.y)
		return int(a.point.x) < int(b.point.x))
	return Vector2i(-1, -1) if sites.is_empty() else sites[0].point

func _reserved_overlap(x: int, y: int, width: int, depth: int, reserved: Dictionary, city_id: String) -> bool:
	for cy: int in range(y, y + depth):
		for cx: int in range(x, x + width):
			if reserved.has(city_id + ":%d,%d" % [cx, cy]): return true
	return false

func _reserve_footprint(sim, command: Dictionary, reserved: Dictionary) -> void:
	var definition: Dictionary = sim.catalog.facility_types[str(command.archetype)]
	for y: int in range(int(command.y), int(command.y) + int(definition.depth)):
		for x: int in range(int(command.x), int(command.x) + int(definition.width)):
			reserved[str(command.city) + ":%d,%d" % [x, y]] = true

func _owned_facilities(sim, company_id: String, behavior: String, city_id: String = "") -> Array:
	var result: Array = []
	for f in sim.facilities:
		if f.company_id == company_id and sim._behavior(f) == behavior and (city_id.is_empty() or f.city_id == city_id): result.append({"id": f.id})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return result

func _owned_facility(sim, company_id: String, behavior: String, city_id: String = "") -> Dictionary:
	var facilities: Array = _owned_facilities(sim, company_id, behavior, city_id)
	return {} if facilities.is_empty() else facilities[0]

func _owned_commercial(sim, company_id: String, city_id: String = "") -> Array:
	var result: Array = _owned_facilities(sim, company_id, "production", city_id)
	result.append_array(_owned_facilities(sim, company_id, "retail", city_id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return result

func _sold_products(sim, company_id: String, city_id: String = "") -> Array[String]:
	var found: Dictionary = {}
	for item: Dictionary in _owned_facilities(sim, company_id, "retail", city_id):
		for product: String in sim.facility(str(item.id)).line_ids(): found[product] = true
	var result: Array[String] = []
	for product: String in found: result.append(product)
	result.sort()
	return result

func _owns_production(sim, company_id: String, product: String) -> bool:
	for f in sim.facilities:
		if f.company_id == company_id and sim._behavior(f) == "production" and f.product_id == product: return true
	return false

func _has_structural_supplier(sim, buyer_id: String, product: String) -> bool:
	var buyer = sim.facility(buyer_id)
	for seller in sim.facilities:
		if seller == buyer: continue
		if (sim._behavior(seller) == "production" and seller.product_id == product) or (sim._behavior(seller) == "storage" and seller.company_id == buyer.company_id and int(seller.replenishment_targets.get(product, 0)) > 0):
			if sim.logistics.quote(sim, seller.id, buyer.id, 1).distance >= 0: return true
	return false

func _production_archetype(sim, product: String) -> String:
	var candidates: Array[String] = []
	for type_id: String in sim.catalog.facility_types:
		if sim.catalog.facility_types[type_id].behavior == "production" and sim.catalog.supports_product(type_id, product): candidates.append(type_id)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = int(sim.catalog.facility_types[a].cost)
		var cb: int = int(sim.catalog.facility_types[b].cost)
		return a < b if ca == cb else ca < cb)
	return "" if candidates.is_empty() else candidates[0]

func _retail_archetype(sim, product: String) -> String:
	var candidates: Array[String] = []
	for type_id: String in sim.catalog.facility_types:
		if sim.catalog.facility_types[type_id].behavior == "retail" and sim.catalog.supports_product(type_id, product): candidates.append(type_id)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var da: Dictionary = sim.catalog.facility_types[a]
		var db: Dictionary = sim.catalog.facility_types[b]
		var left: int = int(da.capacity) * int(db.cost)
		var right: int = int(db.capacity) * int(da.cost)
		if left != right: return left > right
		if da.cost != db.cost: return int(da.cost) < int(db.cost)
		return a < b)
	return "" if candidates.is_empty() else candidates[0]

func _cheapest_type(sim, behavior: String) -> String:
	var candidates: Array[String] = []
	for type_id: String in sim.catalog.facility_types:
		if sim.catalog.facility_types[type_id].behavior == behavior: candidates.append(type_id)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = int(sim.catalog.facility_types[a].cost)
		var cb: int = int(sim.catalog.facility_types[b].cost)
		return a < b if ca == cb else ca < cb)
	return "" if candidates.is_empty() else candidates[0]

func _trace(company_id: String, action: String, subject: String, score: int) -> Dictionary:
	return {"company": company_id, "action": action, "subject": subject, "score": score}
