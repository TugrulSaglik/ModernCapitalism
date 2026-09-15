class_name Economy
extends RefCounted

const Catalog = preload("res://src/sim/catalog.gd")
const Clock = preload("res://src/sim/sim_clock.gd")
const Company = preload("res://src/sim/company.gd")
const Facility = preload("res://src/sim/facility.gd")
const Demand = preload("res://src/sim/demand.gd")
const Sourcing = preload("res://src/sim/sourcing.gd")

var catalog: SimCatalog
var clock: SimClock
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var initial_seed: int
var starting_year: int
var companies: Dictionary = {}
var facilities: Array[SimFacility] = []
var pending_commands: Array[Dictionary] = []
var command_results: Array[Dictionary] = []
var market: Dictionary = {}
var cumulative_consumer_units: int = 0
var cumulative_consumer_revenue: int = 0
var unlocked_technologies: Array[String] = []
var debug_actions: Array[Dictionary] = []

func initialize(seed_value: int = 42, era: int = 2022, data_path: String = "res://data/example_economy.json") -> bool:
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
	rng.seed = seed_value
	clock = Clock.new(era)
	companies.clear()
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
	definitions = catalog.scenario.facilities.duplicate(true)
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for definition: Dictionary in definitions:
		var new_facility: SimFacility = Facility.new(definition)
		new_facility.active = catalog.available(new_facility.product_id, era)
		facilities.append(new_facility)
	return true

func facility(id: String) -> SimFacility:
	for candidate: SimFacility in facilities:
		if candidate.id == id:
			return candidate
	return null

func queue_command(command: Dictionary) -> void:
	pending_commands.append(command.duplicate(true))

func available(product: String) -> bool:
	return catalog.products.has(product) and (str(catalog.products[product].technology) in unlocked_technologies or catalog.available(product, clock.year))

func command_error(command: Dictionary) -> String:
	var target: SimFacility = facility(str(command.get("facility", "")))
	if target == null or target.company_id != str(command.get("company", "")):
		return "Unknown facility or company does not own it."
	match str(command.get("type", "")):
		"set_price":
			if not command.get("price") is int or int(command.price) <= 0 or int(command.price) > 100000000:
				return "Price must be integer cents between 1 and 100000000."
		"set_supplier":
			var product: String = str(command.get("product", ""))
			var inputs: Dictionary = catalog.products[target.product_id].inputs
			if not (product == target.product_id and _behavior(target) == "retail") and not inputs.has(product):
				return "Facility does not source that product."
			var supplier_id: String = str(command.get("supplier", ""))
			if supplier_id != "":
				var seller: SimFacility = facility(supplier_id)
				if seller == null or seller == target or seller.product_id != product or seller.city_id != target.city_id or _behavior(seller) != "production":
					return "Supplier cannot supply this product in this city."
		"set_operating":
			if not command.get("operating") is bool:
				return "Operating setting must be true or false."
		"set_stock_days":
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
				"set_price": target.price = int(command.price)
				"set_supplier": target.suppliers[str(command.product)] = str(command.get("supplier", ""))
				"set_operating": target.operating = bool(command.operating)
				"set_stock_days": target.stock_days = int(command.days)
		command_results.append({"command": command, "accepted": error.is_empty(), "error": error})
	pending_commands.clear()

func _ai_decisions() -> void:
	if clock.tick % 7 != 0:
		return
	for f: SimFacility in facilities:
		var owner: SimCompany = companies[f.company_id]
		if not owner.ai or _behavior(f) != "retail" or not available(f.product_id):
			continue
		var reference: int = int(catalog.products[f.product_id].reference_price)
		var change: int = -maxi(1, int(f.price * 0.02)) if f.inventory.quantity(f.product_id) > f.capacity else maxi(1, int(f.price * 0.01))
		queue_command({"type": "set_price", "company": owner.id, "facility": f.id,
			"price": clampi(f.price + change, int(reference * 1.10), int(reference * 1.60))})

func _behavior(f: SimFacility) -> String:
	return str(catalog.facility_types[f.type_id].behavior)

# Cash and inventory change together; same-company transfers use carrying value.
func trade(seller: SimFacility, buyer: SimFacility, product: String, requested: int) -> int:
	if requested <= 0 or seller == buyer or seller.city_id != buyer.city_id or seller.product_id != product or seller.price <= 0 or not available(product):
		return 0
	var selling_company: SimCompany = companies[seller.company_id]
	var buying_company: SimCompany = companies[buyer.company_id]
	var units: int = mini(requested, seller.inventory.quantity(product))
	if selling_company != buying_company:
		units = mini(units, int(buying_company.cash / seller.price))
	if units <= 0:
		return 0
	var cost: int = seller.inventory.remove(product, units)
	if selling_company == buying_company:
		buyer.inventory.add(product, units, cost)
	else:
		var payment: int = units * seller.price
		buying_company.spend(payment)
		selling_company.record_sale(payment, cost)
		buyer.inventory.add(product, units, payment)
	return units

func _source(buyer: SimFacility, product: String, target: int) -> void:
	var manual: String = str(buyer.suppliers.get(product, ""))
	for offer: Dictionary in supplier_offers(buyer.id, product):
		if not offer.eligible or (manual != "" and str(offer.id) != manual):
			continue
		var missing: int = target - buyer.inventory.quantity(product)
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
	if not f.active or _behavior(f) != "production" or not available(f.product_id):
		return 0
	var definition: Dictionary = catalog.products[f.product_id]
	var inputs: Dictionary = definition.inputs
	# Limit finished stock to the facility's configured stock target.
	var units: int = mini(f.capacity - f.produced_today, maxi(0, f.capacity * f.stock_days - f.inventory.quantity(f.product_id)))
	var owner: SimCompany = companies[f.company_id]
	var conversion: int = int(definition.conversion_cost)
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
	for input: String in input_ids:
		output_cost += f.inventory.remove(input, units * int(inputs[input]))
	f.inventory.add(f.product_id, units, output_cost)
	f.produced_today += units
	return units

func consumer_sale(f: SimFacility, requested: int) -> int:
	if requested <= 0 or not f.active or _behavior(f) != "retail" or not available(f.product_id):
		return 0
	var units: int = mini(requested, mini(f.inventory.quantity(f.product_id), f.capacity - f.sold_today))
	if units <= 0:
		return 0
	var cost: int = f.inventory.remove(f.product_id, units)
	var owner: SimCompany = companies[f.company_id]
	owner.record_sale(units * f.price, cost)
	f.sold_today += units
	return units

func step() -> void:
	for owner: SimCompany in companies.values():
		owner.begin_day()
	market.clear()
	_ai_decisions()
	_apply_commands()
	for f: SimFacility in facilities:
		f.sold_today = 0
		f.produced_today = 0
		f.last_sources.clear()
		f.active = f.operating and available(f.product_id)
		if f.active:
			var owner: SimCompany = companies[f.company_id]
			f.active = owner.pay_expense(int(catalog.facility_types[f.type_id].overhead))
	for f: SimFacility in facilities:
		if not f.active or _behavior(f) != "production":
			continue
		var inputs: Dictionary = catalog.products[f.product_id].inputs
		var input_ids: Array = inputs.keys()
		input_ids.sort()
		for input: String in input_ids:
			_source(f, input, f.capacity * int(inputs[input]))
		produce(f)
	for f: SimFacility in facilities:
		if f.active and _behavior(f) == "retail":
			_source(f, f.product_id, f.capacity * f.stock_days)
	_clear_consumer_markets()
	for f: SimFacility in facilities:
		f.recent_sales.append({"tick": clock.tick, "units": f.sold_today, "revenue": f.sold_today * f.price, "produced": f.produced_today})
		if f.recent_sales.size() > 7:
			f.recent_sales.pop_front()
	clock.advance()

func _clear_consumer_markets() -> void:
	var product_ids: Array = catalog.products.keys()
	product_ids.sort()
	for product: String in product_ids:
		var definition: Dictionary = catalog.products[product]
		var potential: int = int(int(definition.daily_demand) * rng.randi_range(90, 110) / 100.0)
		if not available(product):
			continue
		var offers: Array[Dictionary] = []
		var stores: Array[SimFacility] = []
		for f: SimFacility in facilities:
			if f.active and _behavior(f) == "retail" and f.product_id == product:
				stores.append(f)
				offers.append({"price": f.price, "reference_price": int(definition.reference_price),
					"quality": f.quality, "stock": mini(f.capacity, f.inventory.quantity(product))})
		var allocation: Array[int] = Demand.allocate(potential, offers)
		var units: int = 0
		var revenue: int = 0
		var by_company: Dictionary = {}
		for index: int in range(stores.size()):
			var f: SimFacility = stores[index]
			var sold: int = consumer_sale(f, allocation[index])
			units += sold
			revenue += sold * f.price
			by_company[f.company_id] = int(by_company.get(f.company_id, 0)) + sold
		var shares: Dictionary = {}
		for id: String in by_company:
			shares[id] = float(by_company[id]) / units if units > 0 else 0.0
		market[product] = {"potential": potential, "units": units, "revenue": revenue,
			"average_price": float(revenue) / units if units > 0 else 0.0,
			"company_units": by_company, "market_share": shares}
		cumulative_consumer_units += units
		cumulative_consumer_revenue += revenue

func inventory_assets(company_id: String) -> int:
	var assets: int = 0
	for f: SimFacility in facilities:
		if f.company_id == company_id:
			assets += f.inventory.total_value()
	return assets

func invariant_errors() -> Array[String]:
	var errors: Array[String] = []
	for owner: SimCompany in companies.values():
		if owner.cash < 0 or owner.cash + inventory_assets(owner.id) != owner.capital + owner.profit():
			errors.append("Company balance: " + owner.id)
	for f: SimFacility in facilities:
		for product: String in f.inventory.quantities:
			if f.inventory.quantity(product) < 0 or f.inventory.value(product) < 0 or (f.inventory.quantity(product) == 0 and f.inventory.value(product) != 0):
				errors.append("Inventory balance: " + f.id + "/" + product)
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
	return {"schema_version": 2, "catalog_version": catalog.version,
		"scenario": str(catalog.scenario.id), "starting_year": starting_year,
		"seed": str(initial_seed), "rng_state": str(rng.state), "clock": clock.snapshot(),
		"companies": company_data, "facilities": facility_data,
		"pending_commands": pending_commands.duplicate(true),
		"command_results": command_results.duplicate(true), "market": market.duplicate(true),
		"unlocked_technologies": unlocked_technologies.duplicate(), "debug_actions": debug_actions.duplicate(true),
		"consumer_units": cumulative_consumer_units, "consumer_revenue": cumulative_consumer_revenue}
