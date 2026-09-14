class_name Economy
extends RefCounted

const Catalog = preload("res://src/sim/catalog.gd")
const Clock = preload("res://src/sim/sim_clock.gd")
const Company = preload("res://src/sim/company.gd")
const Facility = preload("res://src/sim/facility.gd")
const Demand = preload("res://src/sim/demand.gd")

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

func _apply_commands() -> void:
	command_results.clear()
	for command: Dictionary in pending_commands:
		var target: SimFacility = facility(str(command.get("facility", "")))
		var accepted: bool = false
		if str(command.get("type", "")) == "set_price" and target != null:
			var price: int = int(command.get("price", 0))
			if target.company_id == str(command.get("company", "")) and price > 0 and price <= 100000000:
				target.price = price
				accepted = true
		command_results.append({"command": command, "accepted": accepted})
	pending_commands.clear()

func _ai_decisions() -> void:
	if clock.tick % 7 != 0:
		return
	for f: SimFacility in facilities:
		var owner: SimCompany = companies[f.company_id]
		if not owner.ai or _behavior(f) != "retail" or not catalog.available(f.product_id, clock.year):
			continue
		var reference: int = int(catalog.products[f.product_id].reference_price)
		var change: int = -maxi(1, int(f.price * 0.02)) if f.inventory.quantity(f.product_id) > f.capacity else maxi(1, int(f.price * 0.01))
		queue_command({"type": "set_price", "company": owner.id, "facility": f.id,
			"price": clampi(f.price + change, int(reference * 1.10), int(reference * 1.60))})

func _behavior(f: SimFacility) -> String:
	return str(catalog.facility_types[f.type_id].behavior)

# Cash and inventory change together; same-company transfers use carrying value.
func trade(seller: SimFacility, buyer: SimFacility, product: String, requested: int) -> int:
	if requested <= 0 or seller == buyer or seller.city_id != buyer.city_id or seller.product_id != product or seller.price <= 0 or not catalog.available(product, clock.year):
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
	for seller: SimFacility in facilities:
		if not seller.active or _behavior(seller) != "production":
			continue
		var missing: int = target - buyer.inventory.quantity(product)
		if missing <= 0:
			break
		trade(seller, buyer, product, missing)

func produce(f: SimFacility) -> int:
	if not f.active or _behavior(f) != "production" or not catalog.available(f.product_id, clock.year):
		return 0
	var definition: Dictionary = catalog.products[f.product_id]
	var inputs: Dictionary = definition.inputs
	# Limit finished stock to two days of capacity, preventing endless accumulation.
	var units: int = mini(f.capacity - f.produced_today, maxi(0, f.capacity * 2 - f.inventory.quantity(f.product_id)))
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
	if requested <= 0 or not f.active or _behavior(f) != "retail" or not catalog.available(f.product_id, clock.year):
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
		f.active = catalog.available(f.product_id, clock.year)
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
			_source(f, f.product_id, f.capacity * 2)
	_clear_consumer_markets()
	clock.advance()

func _clear_consumer_markets() -> void:
	var product_ids: Array = catalog.products.keys()
	product_ids.sort()
	for product: String in product_ids:
		var definition: Dictionary = catalog.products[product]
		var potential: int = int(int(definition.daily_demand) * rng.randi_range(90, 110) / 100.0)
		if not catalog.available(product, clock.year):
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
	return {"schema_version": 1, "catalog_version": catalog.version,
		"scenario": str(catalog.scenario.id), "starting_year": starting_year,
		"seed": str(initial_seed), "rng_state": str(rng.state), "clock": clock.snapshot(),
		"companies": company_data, "facilities": facility_data,
		"pending_commands": pending_commands.duplicate(true),
		"command_results": command_results.duplicate(true), "market": market.duplicate(true),
		"consumer_units": cumulative_consumer_units, "consumer_revenue": cumulative_consumer_revenue}
