class_name Economy
extends RefCounted

const Catalog = preload("res://src/sim/catalog.gd")
const Clock = preload("res://src/sim/sim_clock.gd")
const Company = preload("res://src/sim/company.gd")
const Facility = preload("res://src/sim/facility.gd")
const Demand = preload("res://src/sim/demand.gd")
const Sourcing = preload("res://src/sim/sourcing.gd")
const StrategicAIPlanner = preload("res://src/sim/strategic_ai.gd")
const EquityMarketModel = preload("res://src/sim/equity_market.gd")

var catalog: SimCatalog
var clock: SimClock
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var initial_seed: int
var starting_year: int
var difficulty: String = "standard"
var companies: Dictionary = {}
var facilities: Array[SimFacility] = []
var pending_commands: Array[Dictionary] = []
var command_results: Array[Dictionary] = []
var market: Dictionary = {}
var category_market: Dictionary = {}
var market_history: Array[Dictionary] = []
var cumulative_consumer_units: int = 0
var cumulative_consumer_revenue: int = 0
var unlocked_technologies: Array[String] = []
var debug_actions: Array[Dictionary] = []
var city: CityMap = CityMap.new()
var logistics: Logistics = Logistics.new()
var strategic_ai: StrategicAI = StrategicAIPlanner.new()
var equity_market: EquityMarket = EquityMarketModel.new()
# Derived/debug-only trace. It is intentionally excluded from snapshots.
var strategic_trace: Array[Dictionary] = []

func ai_eligible(company_id: String) -> bool:
	return companies.has(company_id) and companies[company_id].ai and company_id not in equity_market.controlled_group("player")

func initialize(seed_value: int = 42, era: int = 2022, data_path: String = "res://data/example_economy.json", city_settings: Dictionary = {}, difficulty_id: String = "standard") -> bool:
	if not strategic_ai.valid_difficulty(difficulty_id):
		return false
	catalog = Catalog.new()
	if not catalog.load_data(data_path):
		push_error(str(catalog.errors))
		return false
	var supported_era: bool = false
	for year: Variant in catalog.scenario.starting_years:
		if int(year) == era:
			supported_era = true
	if not supported_era:
		return false
	initial_seed = seed_value
	starting_year = era
	difficulty = difficulty_id
	rng.seed = seed_value
	clock = Clock.new(era)
	companies.clear()
	logistics = Logistics.new()
	strategic_ai = StrategicAIPlanner.new()
	strategic_trace.clear()
	facilities.clear()
	pending_commands.clear()
	command_results.clear()
	market.clear()
	unlocked_technologies.clear()
	debug_actions.clear()
	cumulative_consumer_units = 0
	cumulative_consumer_revenue = 0
	var definitions: Array = catalog.scenario.companies.duplicate(true)
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for definition: Dictionary in definitions:
		companies[str(definition.id)] = Company.new(definition)
		for role: String in catalog.staff_roles:
			companies[str(definition.id)].staff_counts[role] = 0
		for product: String in catalog.products:
			if catalog.manufacturable_product(product):
				companies[str(definition.id)].product_quality_levels[product] = 0
				companies[str(definition.id)].process_efficiency_levels[product] = 0
			if catalog.consumer_product(product):
				companies[str(definition.id)].product_brands[product] = catalog.starting_brand(product)
				companies[str(definition.id)].advertising_budgets[product] = 0
				companies[str(definition.id)].advertising_progress[product] = 0
				companies[str(definition.id)].advertising_inactive_days[product] = 0
		for technology: String in catalog.technologies:
			if catalog.technology_public(technology, era): companies[str(definition.id)].known_technologies[technology] = -1
	equity_market.initialize(companies, clock.date_string())
	definitions = catalog.scenario.facilities.duplicate(true)
	if city_settings.get("preset", "procedural") != "legacy": definitions.append_array(catalog.scenario.get("expanded_facilities", []))
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for definition: Dictionary in definitions:
		var new_facility: SimFacility = Facility.new(definition)
		new_facility.active = can_configure(new_facility.company_id, new_facility.type_id, new_facility.product_id)
		facilities.append(new_facility)
		if city_settings.get("preset", "procedural") != "legacy":
			for product: String in catalog.scenario.get("assortments", {}).get(new_facility.id, []):
				if product_public(product) and product != new_facility.product_id: new_facility.assortment[product] = int(int(catalog.products[product].reference_price) * 1.3)
	city = CityMap.new()
	var success: bool = city.initialize(facilities, catalog, seed_value, city_settings)
	category_market.clear()
	market_history.clear()
	return success

func facility(id: String) -> SimFacility:
	for candidate: SimFacility in facilities:
		if candidate.id == id:
			return candidate
	return null

func queue_command(command: Dictionary) -> void:
	pending_commands.append(command.duplicate(true))

func product_public(product: String) -> bool:
	return catalog.products.has(product) and technology_public(str(catalog.products[product].technology))

func technology_public(technology: String) -> bool:
	if not catalog.technologies.has(technology): return false
	if technology not in unlocked_technologies and clock.year < int(catalog.technologies[technology].year): return false
	for prerequisite: String in catalog.technologies[technology].prerequisites:
		if not technology_public(prerequisite): return false
	return true

func can_manufacture(company: String, product: String) -> bool:
	return companies.has(company) and product_public(product) and companies[company].knows(str(catalog.products[product].technology))

# Resale/storage do not require recipe knowledge. Purchases never teach technology.
func can_configure(company: String, type_id: String, product: String) -> bool:
	if not companies.has(company) or not catalog.supports_product(type_id, product): return false
	var behavior: String = catalog.facility_types[type_id].behavior
	if catalog.productless_behavior(behavior): return true
	return can_manufacture(company, product) if behavior == "production" else product_public(product)

func technology_project(technology: String) -> Dictionary:
	return {"kind": "technology", "technology": technology}

func product_quality_project(company: String, product: String) -> Dictionary:
	var level: int = companies[company].product_quality_level(product) if companies.has(company) else 0
	return {"kind": "product_quality", "product": product, "target_level": level + 1}

func process_efficiency_project(company: String, product: String) -> Dictionary:
	var level: int = companies[company].process_efficiency_level(product) if companies.has(company) else 0
	return {"kind": "process_efficiency", "product": product, "target_level": level + 1}

func project_equal(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("kind", "")) != str(b.get("kind", "")): return false
	if a.get("kind") == "technology": return str(a.get("technology", "")) == str(b.get("technology", ""))
	return str(a.get("product", "")) == str(b.get("product", "")) and int(a.get("target_level", -1)) == int(b.get("target_level", -2))

func project_work(project: Dictionary) -> int:
	if project.get("kind") == "technology": return int(catalog.technologies.get(str(project.get("technology", "")), {}).get("research_work", 0))
	if project.get("kind") == "product_quality": return catalog.quality_research_work(int(project.get("target_level", 0)))
	if project.get("kind") == "process_efficiency": return catalog.efficiency_research_work(int(project.get("target_level", 0)))
	return 0

func project_cost(project: Dictionary) -> int:
	if project.get("kind") == "technology": return int(catalog.technologies.get(str(project.get("technology", "")), {}).get("research_cost", 0))
	if project.get("kind") == "product_quality": return catalog.quality_research_cost(int(project.get("target_level", 0)))
	if project.get("kind") == "process_efficiency": return catalog.efficiency_research_cost(int(project.get("target_level", 0)))
	return 0

func project_progress(owner: SimCompany, project: Dictionary) -> int:
	if project.get("kind") == "technology": return int(owner.research_progress.get(str(project.get("technology", "")), 0))
	if project.get("kind") == "product_quality": return int(owner.product_quality_progress.get(str(project.get("product", "")), {}).get("progress", 0))
	return int(owner.process_efficiency_progress.get(str(project.get("product", "")), {}).get("progress", 0))

func project_name(project: Dictionary) -> String:
	if project.get("kind") == "technology": return str(project.get("technology", "")).replace("_", " ")
	if project.get("kind") == "product_quality": return "Improve %s Quality (Level %d)" % [str(project.get("product", "")).replace("_", " "), int(project.get("target_level", 0))]
	if project.get("kind") == "process_efficiency": return "Improve %s Process Efficiency (Level %d)" % [str(project.get("product", "")).replace("_", " "), int(project.get("target_level", 0))]
	return "Unknown project"

func conversion_cost_at_level(product: String, level: int) -> int:
	if not catalog.products.has(product): return 0
	var base: int = int(catalog.products[product].conversion_cost)
	if base == 0: return 0
	var bounded_level: int = clampi(level, 0, catalog.efficiency_max_level())
	@warning_ignore("integer_division")
	return maxi(1, base * (100 - catalog.conversion_cost_reduction(bounded_level)) / 100)

func effective_conversion_cost(company: String, product: String) -> int:
	if not companies.has(company): return 0
	return conversion_cost_at_level(product, companies[company].process_efficiency_level(product))

func research_project_error(company: String, project: Dictionary, except_facility: String = "") -> String:
	if not companies.has(company): return "Unknown company."
	var owner: SimCompany = companies[company]
	var kind: String = str(project.get("kind", ""))
	if kind == "technology":
		if project.size() != 2 or not project.get("technology") is String: return "Invalid technology project."
		var technology: String = str(project.technology)
		if not catalog.technologies.has(technology): return "Unknown technology."
		if not technology_public(technology): return "Not publicly available."
		if owner.knows(technology): return "Already known."
		for prerequisite: String in catalog.technologies[technology].prerequisites:
			if not owner.knows(prerequisite): return "Requires knowledge: " + prerequisite
	elif kind == "product_quality":
		if project.size() != 3 or not project.get("product") is String or not project.get("target_level") is int: return "Invalid product-quality project."
		var product: String = str(project.product)
		var target: int = int(project.target_level)
		if not catalog.products.has(product): return "Unknown product."
		if not catalog.manufacturable_product(product): return "Product has no compatible manufacturing facility."
		if not product_public(product): return "Product is not publicly available."
		if not owner.knows(str(catalog.products[product].technology)): return "Requires manufacturing knowledge."
		var level: int = owner.product_quality_level(product)
		if level >= catalog.quality_max_level(): return "Maximum quality level reached."
		if target != level + 1 or target < 1 or target > catalog.quality_max_level(): return "Target must be the next quality level."
	elif kind == "process_efficiency":
		if project.size() != 3 or not project.get("product") is String or not project.get("target_level") is int: return "Invalid process-efficiency project."
		var product: String = str(project.product)
		var target: int = int(project.target_level)
		if not catalog.products.has(product): return "Unknown product."
		if not catalog.manufacturable_product(product): return "Product has no compatible manufacturing facility."
		if not product_public(product): return "Product is not publicly available."
		if not owner.knows(str(catalog.products[product].technology)): return "Requires manufacturing knowledge."
		var level: int = owner.process_efficiency_level(product)
		if level >= catalog.efficiency_max_level(): return "Maximum process-efficiency level reached."
		if target != level + 1 or target < 1 or target > catalog.efficiency_max_level(): return "Target must be the next process-efficiency level."
	else:
		return "Unknown research project kind."
	for f: SimFacility in facilities:
		if f.company_id == company and f.id != except_facility and not f.research_project.is_empty() and project_equal(f.research_project, project): return "Assigned to " + f.id
	return ""

# Compatibility API for callers that inspect technology eligibility directly.
func research_error(company: String, technology: String, except_facility: String = "") -> String:
	return research_project_error(company, technology_project(technology), except_facility)

func _research() -> void:
	# End-of-day completion: capability becomes operational on the next tick.
	for f: SimFacility in facilities:
		if _behavior(f) != "research" or not f.active or f.research_project.is_empty(): continue
		var project: Dictionary = f.research_project
		if not research_project_error(f.company_id, project, f.id).is_empty(): continue
		var owner: SimCompany = companies[f.company_id]
		var cost: int = project_cost(project)
		if not owner.pay_expense(cost): continue
		owner.research_expense += cost
		var progress: int = project_progress(owner, project) + effective_research_rate(f)
		if progress >= project_work(project):
			if project.kind == "technology":
				owner.known_technologies[str(project.technology)] = clock.tick
				owner.research_progress.erase(str(project.technology))
			elif project.kind == "product_quality":
				owner.product_quality_levels[str(project.product)] = int(project.target_level)
				owner.product_quality_progress.erase(str(project.product))
			else:
				owner.process_efficiency_levels[str(project.product)] = int(project.target_level)
				owner.process_efficiency_progress.erase(str(project.product))
			f.research_project = {}
		elif project.kind == "technology": owner.research_progress[str(project.technology)] = progress
		elif project.kind == "product_quality": owner.product_quality_progress[str(project.product)] = {"target_level": int(project.target_level), "progress": progress}
		else: owner.process_efficiency_progress[str(project.product)] = {"target_level": int(project.target_level), "progress": progress}

func _ai_research() -> void:
	for command: Dictionary in strategic_ai.research_commands(self): queue_command(command)

func command_error(command: Dictionary) -> String:
	if str(command.get("type", "")) in ["buy_shares", "sell_shares", "issue_shares", "declare_dividend"]:
		return equity_market.command_error(command, companies)
	if str(command.get("type", "")) == "build_facility":
		return construction_error(command)
	if str(command.get("type", "")) == "set_advertising_budget":
		var company: String = str(command.get("company", ""))
		var product: String = str(command.get("product", ""))
		if not companies.has(company): return "Unknown company."
		if not catalog.products.has(product): return "Unknown product."
		if not catalog.consumer_product(product): return "Advertising requires a consumer product."
		if not product_public(product): return "Product is not publicly available."
		if not command.get("budget") is int or int(command.budget) < 0 or int(command.budget) > 100000000:
			return "Daily advertising budget must be integer cents between 0 and 100000000."
		return ""
	var target: SimFacility = facility(str(command.get("facility", "")))
	if target == null or target.company_id != str(command.get("company", "")):
		return "Unknown facility or company does not own it."
	match str(command.get("type", "")):
		"hire_staff", "dismiss_staff":
			if _behavior(target) != "headquarters" or target != headquarters(target.company_id): return "Select the company's live corporate headquarters."
			var role: String = str(command.get("role", ""))
			if not catalog.staff_roles.has(role): return "Unknown staff role."
			if not command.get("quantity") is int or int(command.quantity) <= 0: return "Staff quantity must be a positive integer."
			var quantity: int = int(command.quantity)
			if command.type == "hire_staff":
				if not target.operating: return "Resume headquarters before hiring staff."
				if total_staff(target.company_id) + quantity > staff_capacity(target.company_id): return "Headquarters staff capacity exceeded."
			elif staff_count(target.company_id, role) < quantity:
				return "Cannot dismiss more staff than employed in this role."
		"assign_research":
			if _behavior(target) != "research": return "Select an R&D facility."
			var project_value: Variant = command.get("project", technology_project(str(command.get("technology", ""))))
			if not project_value is Dictionary: return "Invalid research project."
			var project: Dictionary = project_value
			return research_project_error(target.company_id, project, target.id)
		"stop_research":
			if _behavior(target) != "research": return "Select an R&D facility."
		"add_line", "remove_line", "set_production":
			var product: String = str(command.get("product", ""))
			var definition: Dictionary = catalog.facility_types[target.type_id]
			if not can_configure(target.company_id, target.type_id, product): return "Unsupported, era-locked or unknown company technology."
			if command.type == "set_production":
				if _behavior(target) != "production": return "Select a factory."
			else:
				if _behavior(target) != "retail": return "Select a retailer."
				if command.type == "add_line":
					if target.assortment.has(product) or target.assortment.size() >= int(definition.slots): return "Product already listed or assortment full."
					if catalog.products[product].category not in definition.categories: return "Category not permitted."
				elif not target.assortment.has(product) or target.assortment.size() <= 1: return "Keep at least one product line."
		"set_warehouse_target":
			if _behavior(target) != "storage" or not catalog.products.has(str(command.get("product", ""))) or not command.get("quantity") is int or command.quantity < 0 or command.quantity > target.capacity: return "Choose a warehouse product target within capacity."
		"demolish_facility":
			if _behavior(target) == "headquarters" and total_staff(target.company_id) > 0: return "Dismiss all staff before demolishing headquarters."
			for shipment: Dictionary in logistics.shipments:
				if shipment.status == "in_transit" and (shipment.source == target.id or shipment.destination == target.id): return "Wait for active shipments before demolition."
		"transfer":
			var destination: SimFacility = facility(str(command.get("destination", "")))
			var product: String = str(command.get("product", ""))
			if destination == null or destination == target or destination.company_id != target.company_id: return "Choose another owned destination."
			if catalog.productless_behavior(_behavior(target)) or catalog.productless_behavior(_behavior(destination)): return "Productless facilities cannot send or receive inventory."
			if not command.get("quantity") is int or command.quantity <= 0 or command.quantity > target.inventory.quantity(product): return "Quantity exceeds available stock."
			if logistics.free_capacity(self, destination) < command.quantity: return "Destination capacity is reserved or full."
			var quote: Dictionary = logistics.quote(self, target.id, destination.id, command.quantity)
			if quote.distance < 0 or target.city_id != destination.city_id: return "No road route."
			if companies[target.company_id].cash < quote.freight: return "Insufficient freight funds."
			if not product_public(product): return "Product unavailable."
		"set_price":
			if catalog.productless_behavior(_behavior(target)): return "This facility has no product price."
			if _behavior(target) == "retail" and not target.assortment.has(str(command.get("product", target.product_id))): return "Product is not in assortment."
			if _behavior(target) != "retail" and str(command.get("product", target.product_id)) != target.product_id: return "Price applies to the configured product."
			if not command.get("price") is int or int(command.price) <= 0 or int(command.price) > 100000000:
				return "Price must be integer cents between 1 and 100000000."
		"set_supplier":
			var product: String = str(command.get("product", ""))
			var inputs: Dictionary = catalog.products.get(target.product_id, {}).get("inputs", {})
			if not (target.assortment.has(product) and _behavior(target) == "retail") and not (_behavior(target) == "production" and inputs.has(product)) and not (_behavior(target) == "storage" and catalog.products.has(product)):
				return "Facility does not source that product."
			var supplier_id: String = str(command.get("supplier", ""))
			if supplier_id != "":
				var seller: SimFacility = facility(supplier_id)
				if seller == null or seller == target or seller.city_id != target.city_id or not ((seller.product_id == product and _behavior(seller) == "production") or (_behavior(seller) == "storage" and seller.company_id == target.company_id and _behavior(target) != "storage")):
					return "Supplier cannot supply this product in this city."
		"set_operating":
			if not command.get("operating") is bool:
				return "Operating setting must be true or false."
		"set_stock_days":
			if catalog.productless_behavior(_behavior(target)): return "This facility has no stock target."
			if not command.get("days") is int or int(command.days) < 1 or int(command.days) > 7:
				return "Stock target must be 1–7 days."
		_:
			return "Unknown management command."
	return ""

func _apply_commands() -> void:
	command_results.clear()
	for command: Dictionary in pending_commands:
		var target: SimFacility = facility(str(command.get("facility", "")))
		var error: String = command_error(command)
		if error.is_empty():
			match str(command.type):
				"buy_shares", "sell_shares", "issue_shares", "declare_dividend": equity_market.apply(command, companies)
				"hire_staff":
					var role: String = str(command.role)
					companies[str(command.company)].staff_counts[role] = staff_count(str(command.company), role) + int(command.quantity)
				"dismiss_staff":
					var role: String = str(command.role)
					companies[str(command.company)].staff_counts[role] = staff_count(str(command.company), role) - int(command.quantity)
				"set_advertising_budget": companies[str(command.company)].advertising_budgets[str(command.product)] = int(command.budget)
				"assign_research":
					var project: Dictionary = command.get("project", technology_project(str(command.get("technology", ""))))
					target.research_project = project.duplicate(true)
				"stop_research": target.research_project = {}
				"set_warehouse_target": target.replenishment_targets[command.product] = command.quantity
				"build_facility": _construct(command)
				"demolish_facility": _demolish(target)
				"transfer": logistics.dispatch(self, target, facility(command.destination), command.product, command.quantity)
				"add_line": target.assortment[command.product] = int(int(catalog.products[command.product].reference_price) * 1.3)
				"remove_line":
					target.assortment.erase(command.product)
					target.suppliers.erase(command.product)
					if target.product_id == command.product:
						target.product_id = target.line_ids()[0]
						target.price = int(target.assortment[target.product_id])
				"set_production":
					for buyer: SimFacility in facilities:
						for product: String in buyer.suppliers.keys():
							if buyer.suppliers[product] == target.id and product != command.product: buyer.suppliers.erase(product)
					target.product_id = command.product
					target.price = int(catalog.products[command.product].reference_price)
					target.suppliers.clear()
					target.assortment = {target.product_id: target.price}
				"set_price":
					var product: String = str(command.get("product", target.product_id))
					target.assortment[product] = int(command.price)
					if product == target.product_id: target.price = int(command.price)
				"set_supplier": target.suppliers[str(command.product)] = str(command.get("supplier", ""))
				"set_operating": target.operating = bool(command.operating)
				"set_stock_days": target.stock_days = int(command.days)
		command_results.append({"command": command, "accepted": error.is_empty(), "error": error})
	pending_commands.clear()

# Hosts may explicitly flush the FIFO at a between-day boundary, without a tick.
func process_commands() -> void:
	_apply_commands()
	record_history()

func construction_error(command: Dictionary) -> String:
	if not companies.has(str(command.get("company", ""))):
		return "Unknown construction owner."
	if city.next_facility >= 1000000:
		return "Facility ID limit reached."
	var type_id: String = str(command.get("archetype", ""))
	if not catalog.facility_types.has(type_id):
		return "Unknown facility archetype."
	var definition: Dictionary = catalog.facility_types[type_id]
	if str(definition.behavior) == "headquarters" and headquarters(str(command.company)) != null:
		return "Company already owns a corporate headquarters."
	var product: String = str(command.get("product", ""))
	if not can_configure(str(command.company), type_id, product):
		return "Product is unsupported or era locked."
	if command.get("city", "metro") != city.id or not command.get("x") is int or not command.get("y") is int:
		return "Choose integer cells in this city."
	var error: String = city.placement_error(command.x, command.y, int(definition.width), int(definition.depth))
	if not error.is_empty():
		return error
	if companies[str(command.company)].cash < int(definition.cost):
		return "Insufficient cash for construction."
	return ""

func _construct(command: Dictionary) -> void:
	var definition: Dictionary = catalog.facility_types[str(command.archetype)]
	var owner: SimCompany = companies[str(command.company)]
	owner.spend(int(definition.cost))
	owner.capex += int(definition.cost)
	var product: String = str(command.get("product", ""))
	var price: int = int(catalog.products.get(product, {}).get("reference_price", 0))
	if definition.behavior == "retail":
		price = int(price * 1.3)
	var f: SimFacility = Facility.new({"id": "built_%06d" % city.next_facility,
		"company": owner.id, "city": city.id, "type": str(command.archetype),
		"product": product, "capacity": int(definition.capacity), "price": price, "quality": 50})
	city.next_facility += 1
	f.asset_cost = int(definition.cost)
	facilities.append(f)
	facilities.sort_custom(func(a: SimFacility, b: SimFacility) -> bool: return a.id < b.id)
	city.occupy(f, command.x, command.y, definition)

func _demolish(f: SimFacility) -> void:
	var owner: SimCompany = companies[f.company_id]
	var loss: int = f.inventory.total_value() + f.asset_cost - f.accumulated_depreciation
	owner.expenses += loss
	owner.daily_expenses += loss
	facilities.erase(f)
	city.plots.erase(f.id)
	for other: SimFacility in facilities:
		for product: String in other.suppliers.keys():
			if other.suppliers[product] == f.id:
				other.suppliers.erase(product)
		for product: String in other.last_sources.keys():
			other.last_sources[product] = other.last_sources[product].filter(func(source: Dictionary) -> bool: return source.supplier != f.id)

func _ai_decisions() -> void:
	if clock.day == 1:
		var plan: Dictionary = strategic_ai.evaluate_month(self)
		strategic_trace = plan.trace
		for command: Dictionary in plan.commands: queue_command(command)
	if clock.tick % 7 != 0:
		return
	for f: SimFacility in facilities:
		var owner: SimCompany = companies[f.company_id]
		if not ai_eligible(owner.id) or _behavior(f) != "retail" or not product_public(f.product_id):
			continue
		for product: String in f.line_ids():
			if not product_public(product): continue
			var reference: int = int(catalog.products[product].reference_price)
			var price: int = f.line_price(product)
			var change: int = -maxi(1, int(price * 0.02)) if f.inventory.quantity(product) > f.capacity else maxi(1, int(price * 0.01))
			queue_command({"type": "set_price", "company": owner.id, "facility": f.id, "product": product,
				"price": clampi(price + change, int(reference * 1.10), int(reference * 1.60))})
	_ai_advertising_decisions()

func _ai_advertising_eligible(company_id: String, product: String) -> bool:
	if not ai_eligible(company_id) or not product_public(product) or not catalog.consumer_product(product):
		return false
	for f: SimFacility in facilities:
		if f.company_id != company_id or _behavior(f) != "retail" or not f.assortment.has(product):
			continue
		if f.inventory.quantity(product) > 0 or logistics.incoming(f.id, product) > 0:
			return true
		for record: Dictionary in f.product_history:
			if int(record.get("products", {}).get(product, {}).get("units", 0)) > 0:
				return true
	return false

func _ai_advertising_decisions() -> void:
	var company_ids: Array = companies.keys()
	company_ids.sort()
	for company_id: String in company_ids:
		var owner: SimCompany = companies[company_id]
		if not ai_eligible(owner.id):
			continue
		var candidates: Array[Dictionary] = []
		var products: Array = owner.advertising_budgets.keys()
		products.sort()
		for product: String in products:
			if not product_public(product):
				continue
			var local_brand: int = int(catalog.local_values(product).brand)
			var gap: int = local_brand - owner.brand(product)
			if gap > 0 and _ai_advertising_eligible(company_id, product):
				var threshold: int = advertising_threshold(product, owner.brand(product))
				@warning_ignore("integer_division")
				var desired: int = (threshold + 29) / 30
				candidates.append({"product": product, "gap": gap, "desired": desired})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.gap) > int(b.gap) if a.gap != b.gap else str(a.product) < str(b.product))
		@warning_ignore("integer_division")
		var remaining: int = owner.cash / 1000
		var budgets: Dictionary = {}
		for candidate: Dictionary in candidates:
			var budget: int = mini(int(candidate.desired), remaining)
			budgets[str(candidate.product)] = budget
			remaining -= budget
		for product: String in products:
			if not product_public(product):
				continue
			queue_command({"type": "set_advertising_budget", "company": company_id, "product": product,
				"budget": int(budgets.get(product, 0))})

func _behavior(f: SimFacility) -> String:
	return str(catalog.facility_types[f.type_id].behavior)

func headquarters(company_id: String) -> SimFacility:
	for f: SimFacility in facilities:
		if f.company_id == company_id and _behavior(f) == "headquarters": return f
	return null

func staff_count(company_id: String, role: String) -> int:
	return companies[company_id].staff_count(role) if companies.has(company_id) else 0

func total_staff(company_id: String) -> int:
	return companies[company_id].total_staff() if companies.has(company_id) else 0

func staff_capacity(company_id: String) -> int:
	var hq: SimFacility = headquarters(company_id)
	return int(catalog.facility_types[hq.type_id].staff_capacity) if hq != null else 0

func staff_effects_active(company_id: String) -> bool:
	# Payroll precedes ordinary facility activation, so the authoritative gate is
	# the live HQ's configured operating state, never its transient `active` flag.
	if not companies.has(company_id): return false
	var owner: SimCompany = companies[company_id]
	var hq: SimFacility = headquarters(company_id)
	return owner.total_staff() > 0 and owner.staff_payroll_funded and hq != null and hq.operating

func staff_effect_percent(company_id: String, role_or_effect: String) -> int:
	if not staff_effects_active(company_id): return 0
	var role_id: String = role_or_effect if catalog.staff_roles.has(role_or_effect) else ""
	if role_id.is_empty():
		for candidate: String in catalog.staff_roles:
			if str(catalog.staff_roles[candidate].effect) == role_or_effect:
				role_id = candidate
				break
	if role_id.is_empty(): return 0
	var role: Dictionary = catalog.staff_roles[role_id]
	return mini(staff_count(company_id, role_id) * int(role.effect_per_staff), int(role.effect_cap_percent))

func effective_capacity(f: SimFacility) -> int:
	if f == null or _behavior(f) not in ["production", "retail"]: return f.capacity if f != null else 0
	var bonus: int = staff_effect_percent(f.company_id, "operations_capacity_percent")
	@warning_ignore("integer_division")
	return maxi(f.capacity, f.capacity * (100 + bonus) / 100)

func effective_research_rate(f: SimFacility) -> int:
	if f == null or _behavior(f) != "research": return 0
	var base: int = int(catalog.facility_types[f.type_id].research_rate)
	var bonus: int = staff_effect_percent(f.company_id, "research_rate_percent")
	@warning_ignore("integer_division")
	return maxi(base, base * (100 + bonus) / 100)

func effective_overhead(f: SimFacility) -> int:
	if f == null: return 0
	var base: int = int(catalog.facility_types[f.type_id].overhead)
	if base == 0: return 0
	var reduction: int = staff_effect_percent(f.company_id, "facility_overhead_reduction_percent")
	@warning_ignore("integer_division")
	return maxi(1, base * (100 - reduction) / 100)

func production_input_target(f: SimFacility, input: String) -> int:
	if f == null or _behavior(f) != "production": return 0
	return effective_capacity(f) * f.stock_days * int(catalog.products[f.product_id].inputs.get(input, 0))

func retail_replenishment_target(f: SimFacility) -> int:
	if f == null or _behavior(f) != "retail" or f.assortment.is_empty(): return 0
	@warning_ignore("integer_division")
	return maxi(1, effective_capacity(f) * f.stock_days / f.assortment.size())

func daily_payroll(company_id: String) -> int:
	if not companies.has(company_id): return 0
	var total: int = 0
	for role: String in catalog.staff_roles:
		total += staff_count(company_id, role) * int(catalog.staff_roles[role].daily_salary)
	return total

func _payroll() -> void:
	var company_ids: Array = companies.keys()
	company_ids.sort()
	for company_id: String in company_ids:
		var owner: SimCompany = companies[company_id]
		var amount: int = daily_payroll(company_id)
		owner.staff_payroll_funded = false
		if amount > 0 and owner.pay_expense(amount):
			owner.payroll_expense += amount
			owner.staff_payroll_funded = true

func trade(seller: SimFacility, buyer: SimFacility, product: String, requested: int) -> int:
	return logistics.dispatch(self, seller, buyer, product, requested)

func _source(buyer: SimFacility, product: String, target: int) -> void:
	var manual: String = str(buyer.suppliers.get(product, ""))
	for offer: Dictionary in supplier_offers(buyer.id, product):
		if not offer.eligible or (manual != "" and str(offer.id) != manual):
			continue
		var missing: int = target - buyer.inventory.quantity(product) - logistics.incoming(buyer.id, product)
		if missing <= 0:
			break
		var bought: int = trade(facility(str(offer.id)), buyer, product, missing)
		if bought > 0:
			if not buyer.last_sources.has(product):
				buyer.last_sources[product] = []
			buyer.last_sources[product].append({"supplier": str(offer.id), "units": bought, "price": int(offer.price), "quality": int(offer.quality), "score": float(offer.score)})

func supplier_offers(buyer_id: String, product: String) -> Array[Dictionary]:
	var buyer: SimFacility = facility(buyer_id)
	return Sourcing.offers(self, buyer, product) if buyer != null else []

func produce(f: SimFacility) -> int:
	if not f.active or _behavior(f) != "production" or not can_manufacture(f.company_id, f.product_id):
		return 0
	var definition: Dictionary = catalog.products[f.product_id]
	var inputs: Dictionary = definition.inputs
	# Limit finished stock to the facility's configured stock target.
	var daily_capacity: int = effective_capacity(f)
	var units: int = mini(daily_capacity - f.produced_today, maxi(0, daily_capacity * f.stock_days - f.inventory.quantity(f.product_id)))
	var owner: SimCompany = companies[f.company_id]
	var conversion: int = effective_conversion_cost(f.company_id, f.product_id)
	if conversion > 0:
		units = mini(units, int(owner.cash / conversion))
	var input_ids: Array = inputs.keys()
	input_ids.sort()
	for input: String in input_ids:
		units = mini(units, int(f.inventory.quantity(input) / int(inputs[input])))
	if units <= 0:
		return 0
	var output_cost: int = units * conversion
	owner.spend(output_cost)
	owner.production_cash += output_cost
	var input_points: int = 0
	var input_units: int = 0
	for input: String in input_ids:
		var consumed: int = units * int(inputs[input])
		var removed: Dictionary = f.inventory.remove_pooled(input, consumed)
		output_cost += int(removed.cost)
		input_points += int(removed.quality_points)
		input_units += consumed
	# Product quality R&D improves the owner's design/manufacturing capability for
	# newly created goods only. Physical inventory is never rewritten.
	var quality_level: int = owner.product_quality_level(f.product_id)
	var effective_process_quality: int = clampi(f.quality + catalog.quality_bonus(quality_level), 1, 100)
	# Equal weight for effective process/design capability and unit-weighted components.
	@warning_ignore("integer_division")
	var output_quality: int = effective_process_quality if input_units == 0 else (effective_process_quality + input_points / input_units) / 2
	f.inventory.add(f.product_id, units, output_cost, clampi(output_quality, 1, 100))
	f.produced_today += units
	return units

func consumer_sale(f: SimFacility, requested: int, product: String = "") -> int:
	if product.is_empty(): product = f.product_id
	if requested <= 0 or not f.active or _behavior(f) != "retail" or not product_public(product) or not f.assortment.has(product): return 0
	var units: int = mini(requested, mini(f.inventory.quantity(product), effective_capacity(f) - f.sold_today))
	if units <= 0: return 0
	var cost: int = f.inventory.remove(product, units)
	var amount: int = units * f.line_price(product)
	var owner: SimCompany = companies[f.company_id]
	owner.record_sale(amount, cost)
	owner.retail_revenue += amount
	f.sold_today += units
	var line: Dictionary = f.line_sales.get(product, {"units": 0, "revenue": 0, "cogs": 0})
	line.units += units
	line.revenue += amount
	line.cogs += cost
	f.line_sales[product] = line
	var today: Dictionary = f.line_today.get(product, {"units": 0, "revenue": 0, "cogs": 0})
	today.units += units
	today.revenue += amount
	today.cogs += cost
	f.line_today[product] = today
	return units

func step() -> void:
	record_history()
	for owner: SimCompany in companies.values():
		owner.begin_day()
	_ai_decisions()
	_ai_research()
	_apply_commands()
	market.clear()
	_payroll()
	_advertise()
	logistics.deliver(self)
	for f: SimFacility in facilities:
		if f.asset_cost > 0 and f.asset_days < 3650:
			f.asset_days += 1
			var accumulated: int = f.asset_cost * f.asset_days / 3650
			var expense: int = accumulated - f.accumulated_depreciation
			f.accumulated_depreciation = accumulated
			var company: SimCompany = companies[f.company_id]
			company.expenses += expense
			company.daily_expenses += expense
			company.depreciation += expense
	for f: SimFacility in facilities:
		f.sold_today = 0
		f.line_today.clear()
		f.produced_today = 0
		f.last_sources.clear()
		var has_available_line: bool = false
		for product: String in f.line_ids(): has_available_line = has_available_line or product_public(product)
		f.active = f.operating and (can_manufacture(f.company_id, f.product_id) if _behavior(f) == "production" else (has_available_line or _behavior(f) in ["storage", "research", "headquarters"]))
		if f.active:
			var owner: SimCompany = companies[f.company_id]
			f.active = owner.pay_expense(effective_overhead(f))
	for f: SimFacility in facilities:
		if not f.active or _behavior(f) != "production":
			continue
		var inputs: Dictionary = catalog.products[f.product_id].inputs
		var input_ids: Array = inputs.keys()
		input_ids.sort()
		for input: String in input_ids:
			_source(f, input, production_input_target(f, input))
		produce(f)
	for f: SimFacility in facilities:
		if f.active and _behavior(f) == "retail":
			for product: String in f.line_ids():
				if product_public(product): _source(f, product, retail_replenishment_target(f))
		elif f.active and _behavior(f) == "storage":
			var products: Array = f.replenishment_targets.keys()
			products.sort()
			for product: String in products: _source(f, product, int(f.replenishment_targets[product]))
	_clear_consumer_markets()
	_research()
	for f: SimFacility in facilities:
		f.recent_sales.append({"tick": clock.tick, "units": f.sold_today, "revenue": f.sold_today * f.price, "produced": f.produced_today})
		var retail_revenue: int = 0
		for record: Dictionary in f.line_today.values(): retail_revenue += int(record.revenue)
		f.recent_sales.back().revenue = retail_revenue
		f.product_history.append({"tick": clock.tick, "products": f.line_today.duplicate(true)})
		if f.product_history.size() > 7: f.product_history.pop_front()
		if f.recent_sales.size() > 7:
			f.recent_sales.pop_front()
	record_history()
	_update_equity_quotes()
	clock.advance()
	record_history()

func _update_equity_quotes() -> void:
	for owner: SimCompany in companies.values(): owner.ttm_profit_cached = owner.ttm_profit(clock)
	equity_market.update_quotes(companies, clock.date_string())

func advertising_threshold(product: String, brand: int) -> int:
	# Equivalent to reference_price * (2 + brand / 10), retaining tenths with integers.
	return int(catalog.products[product].reference_price) * (20 + clampi(brand, 0, 100)) / 10

func _advertise() -> void:
	var company_ids: Array = companies.keys()
	company_ids.sort()
	for company_id: String in company_ids:
		var owner: SimCompany = companies[company_id]
		var products: Array = owner.advertising_budgets.keys()
		products.sort()
		for product: String in products:
			if not product_public(product): continue
			var budget: int = int(owner.advertising_budgets[product])
			if budget <= 0 or not owner.pay_expense(budget):
				var inactive_days: int = int(owner.advertising_inactive_days[product]) + 1
				owner.advertising_inactive_days[product] = inactive_days
				if inactive_days > 30 and inactive_days % 30 == 0:
					owner.product_brands[product] = maxi(0, owner.brand(product) - 1)
				continue
			owner.advertising_inactive_days[product] = 0
			owner.advertising_expense += budget
			var bonus: int = staff_effect_percent(company_id, "advertising_progress_percent")
			@warning_ignore("integer_division")
			var effective_progress: int = budget * (100 + bonus) / 100
			owner.advertising_progress[product] = int(owner.advertising_progress[product]) + effective_progress
			while owner.brand(product) < 100:
				var threshold: int = advertising_threshold(product, owner.brand(product))
				if int(owner.advertising_progress[product]) < threshold: break
				owner.advertising_progress[product] = int(owner.advertising_progress[product]) - threshold
				owner.product_brands[product] = owner.brand(product) + 1

func _clear_consumer_markets() -> void:
	ConsumerMarket.clear(self)

func inventory_assets(company_id: String) -> int:
	var assets: int = logistics.assets(company_id)
	for f: SimFacility in facilities:
		if f.company_id == company_id:
			assets += f.inventory.total_value()
	return assets

func invariant_errors() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(equity_market.invariant_errors(companies))
	var headquarters_owners: Dictionary = {}
	var previous_id: int = 0
	for shipment: Dictionary in logistics.shipments:
		if int(shipment.id) <= previous_id or int(shipment.id) >= logistics.next_id or int(shipment.quantity) <= 0 or int(shipment.value) < 0 or int(shipment.transport_cost) < 0:
			errors.append("Shipment quantities or ID")
		previous_id = int(shipment.id)
		if shipment.status == "in_transit":
			var destination: SimFacility = facility(shipment.destination)
			if destination == null or facility(shipment.source) == null or destination.company_id != shipment.company or int(shipment.arrival) < clock.tick:
				errors.append("Shipment endpoint or arrival")
	for owner: SimCompany in companies.values():
		if owner.staff_counts.size() != catalog.staff_roles.size(): errors.append("Staff role map: " + owner.id)
		for role: String in owner.staff_counts:
			if not catalog.staff_roles.has(role) or not owner.staff_counts[role] is int or int(owner.staff_counts[role]) < 0: errors.append("Staff count: " + owner.id + "/" + role)
		if owner.total_staff() > 0 and (headquarters(owner.id) == null or owner.total_staff() > staff_capacity(owner.id)): errors.append("Staff headquarters/capacity: " + owner.id)
		if owner.staff_payroll_funded and owner.total_staff() == 0: errors.append("Funded payroll without staff: " + owner.id)
		if owner.cash < 0 or owner.cash + inventory_assets(owner.id) + fixed_assets(owner.id) + equity_market.investment_cost(owner.id) != owner.capital + owner.profit() - owner.dividends_paid:
			errors.append("Company balance: " + owner.id)
	for f: SimFacility in facilities:
		if _behavior(f) == "headquarters":
			if headquarters_owners.has(f.company_id): errors.append("Duplicate headquarters: " + f.company_id)
			headquarters_owners[f.company_id] = true
		if catalog.productless_behavior(_behavior(f)) and (not f.product_id.is_empty() or not f.assortment.is_empty() or not f.inventory.quantities.is_empty() or not f.suppliers.is_empty() or not f.replenishment_targets.is_empty()):
			errors.append("Productless facility state: " + f.id)
		if _behavior(f) == "storage" and logistics.used(f) + logistics.incoming(f.id) > f.capacity:
			errors.append("Warehouse capacity: " + f.id)
		if f.produced_today > effective_capacity(f) or f.sold_today > effective_capacity(f):
			errors.append("Daily facility capacity: " + f.id)
		for product: String in f.inventory.quantities:
			if f.inventory.points(product) < f.inventory.quantity(product) or f.inventory.points(product) > f.inventory.quantity(product) * 100 or f.inventory.quantity(product) < 0 or f.inventory.value(product) < 0 or (f.inventory.quantity(product) == 0 and f.inventory.value(product) != 0):
				errors.append("Inventory balance: " + f.id + "/" + product)
	for shipment: Dictionary in logistics.shipments:
		if int(shipment.quality_points) < int(shipment.quantity) or int(shipment.quality_points) > int(shipment.quantity) * 100:
			errors.append("Shipment quality: " + str(shipment.id))
	return errors

func snapshot() -> Dictionary:
	var company_data: Array[Dictionary] = []
	for owner: SimCompany in companies.values():
		var record: Dictionary = owner.snapshot()
		record["inventory_assets"] = inventory_assets(owner.id)
		company_data.append(record)
	var facility_data: Array[Dictionary] = []
	for f: SimFacility in facilities:
		facility_data.append(f.snapshot())
	return {"schema_version": 17, "equity_market": equity_market.snapshot(), "difficulty": difficulty, "category_market": category_market.duplicate(true), "market_history": market_history.duplicate(true), "logistics": logistics.snapshot(), "catalog_version": catalog.version, "city": city.snapshot(),
		"scenario": str(catalog.scenario.id), "starting_year": starting_year,
		"seed": str(initial_seed), "rng_state": str(rng.state), "clock": clock.snapshot(),
		"companies": company_data, "facilities": facility_data,
		"pending_commands": pending_commands.duplicate(true),
		"command_results": command_results.duplicate(true), "market": market.duplicate(true),
		"unlocked_technologies": unlocked_technologies.duplicate(), "debug_actions": debug_actions.duplicate(true),
		"consumer_units": cumulative_consumer_units, "consumer_revenue": cumulative_consumer_revenue}

func fixed_assets(company: String) -> int:
	var value: int = 0
	for f: SimFacility in facilities:
		if f.company_id == company: value += f.asset_cost - f.accumulated_depreciation
	return value

func record_history() -> void:
	for owner: SimCompany in companies.values():
		owner.record_history(clock)
		if not owner.monthly_history.is_empty(): owner.monthly_history.back()["balance"] = FinancialReports.balance(self, owner.id)
