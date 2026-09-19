class_name SaveStore
extends RefCounted

const Simulation = preload("res://src/sim/economy.gd")
const FORMAT_VERSION: int = 2
const DATA_PATH: String = "res://data/example_economy.json"
var error: String = ""

# Tag integer values so JSON parsing never rounds a 64-bit cash or RNG value.
static func encode(value: Variant) -> Variant:
	if value is float:
		return {"$f64": var_to_bytes(value).hex_encode()}
	if value is int:
		return {"$i64": str(value)}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(encode(item))
		return result
	return value

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.get("$f64") is String:
			var bytes: PackedByteArray = str(value["$f64"]).hex_decode()
			if ((bytes.size() == 8 and str(value["$f64"]).begins_with("03000000")) or (bytes.size() == 12 and str(value["$f64"]).begins_with("03000100"))) and bytes.hex_encode() == value["$f64"]:
				var decoded_float: Variant = bytes_to_var(bytes)
				if decoded_float is float and is_finite(decoded_float):
					return decoded_float
		if value.size() == 1 and value.get("$i64") is String:
			var number: String = value["$i64"]
			if number.is_valid_int() and str(int(number)) == number:
				return int(number)
		var result: Dictionary = {}
		for key: String in value:
			result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(decode(item))
		return result
	return value

static func fingerprint() -> String:
	return FileAccess.get_file_as_string(DATA_PATH).sha256_text()

func write_file(path: String, state: Dictionary) -> bool:
	error = ""
	var envelope: Dictionary = {"format": "ModernCapitalism", "version": FORMAT_VERSION,
		"catalog_hash": fingerprint(), "engine": Engine.get_version_info().string, "session": state}
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		error = "Cannot create save directory."
		return false
	var file: FileAccess = FileAccess.open(absolute + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Cannot write save file."
		return false
	file.store_string(JSON.stringify(encode(envelope), "  ", true, true))
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK:
		error = "Save write failed; previous save retained."
		return false
	# Rename within the same directory: previous slot survives an incomplete write.
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		error = "Cannot replace save slot; temporary file retained."
		return false
	return true

func read_file(path: String) -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path):
		error = "Save slot does not exist."
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16000000:
		error = "Unreadable or oversized save file."
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Invalid save JSON."
		return {}
	var decoded: Variant = decode(parser.data)
	if not decoded is Dictionary or decoded.get("format") != "ModernCapitalism" or decoded.get("version") != FORMAT_VERSION or decoded.get("catalog_hash") != fingerprint() or decoded.get("engine") != Engine.get_version_info().string or not decoded.get("session") is Dictionary:
		error = "Incompatible save format, engine or catalog."
		return {}
	return decoded.session

# Require known keys/types before hydrating. Dynamic maps receive semantic checks below.
static func shape(value: Variant, template: Variant) -> bool:
	if typeof(value) != typeof(template):
		return false
	if value is Dictionary:
		for key: String in template:
			if not value.has(key) or not shape(value[key], template[key]):
				return false
	return true

static func nonnegative(value: Variant) -> bool:
	return value is int and value >= 0 and value <= 100000000000000

func restore(state: Dictionary) -> Economy:
	error = "Invalid or inconsistent simulation state."
	var sim: Economy = Simulation.new()
	if not state.get("seed") is String or not str(state.seed).is_valid_int() or not state.get("starting_year") is int:
		return null
	# Initialize catalog and economic definitions with the small fixture; saved city
	# hydration below never depends on the current procedural generator.
	if not sim.initialize(int(state.seed), int(state.starting_year), DATA_PATH, {"preset": "legacy"}):
		return null
	if not shape(state, sim.snapshot()) or state.schema_version != 5 or state.catalog_version != sim.catalog.version or state.scenario != sim.catalog.scenario.id or not str(state.rng_state).is_valid_int():
		return null
	if state.companies.size() != sim.companies.size() or state.facilities.size() > 768:
		return null
	var facility_template: Dictionary = sim.facilities[0].snapshot()
	var restored: Array[SimFacility] = []
	var restored_ids: Dictionary = {}
	for item: Variant in state.facilities:
		if not shape(item, facility_template) or restored_ids.has(item.id) or not sim.companies.has(item.company) or not sim.catalog.facility_types.has(item.type) or not sim.catalog.products.has(item.product) or item.city != sim.city.id:
			return null
		var original: SimFacility = sim.facility(item.id)
		if original != null:
			if item.company != original.company_id or item.type != original.type_id or item.product != original.product_id or item.capacity != original.capacity or item.quality != original.quality:
				return null
		else:
			var definition: Dictionary = sim.catalog.facility_types[item.type]
			if not item.id.begins_with("built_") or not item.id.trim_prefix("built_").is_valid_int() or int(item.id.trim_prefix("built_")) < 1 or item.id != "built_%06d" % int(item.id.trim_prefix("built_")) or item.product not in definition.products or item.capacity != int(definition.capacity) or item.quality != 50:
				return null
		var created: SimFacility = SimFacility.new(item)
		restored.append(created)
		restored_ids[item.id] = true
	# Deleted scenario facilities are valid. All live IDs must exist before supplier validation.
	sim.facilities = restored
	sim.facilities.sort_custom(func(a: SimFacility, b: SimFacility) -> bool: return a.id < b.id)
	if not sim.city.restore(state.city, sim.facilities, sim.catalog):
		return null
	if sim.city.generation.seed != state.seed: return null
	var saved_clock: Dictionary = state.clock
	if not nonnegative(saved_clock.tick) or saved_clock.tick > 365000:
		return null
	# Derive calendar from tick instead of accepting impossible dates.
	for tick: int in range(saved_clock.tick):
		sim.clock.advance()
	if sim.clock.snapshot() != saved_clock:
		return null
	var seen: Dictionary = {}
	for item: Variant in state.companies:
		if not item is Dictionary or not sim.companies.has(str(item.get("id", ""))) or seen.has(item.id):
			return null
		seen[item.id] = true
		var owner: SimCompany = sim.companies[item.id]
		var template: Dictionary = owner.snapshot()
		template["inventory_assets"] = 0
		if not shape(item, template) or item.name != owner.display_name or item.ai != owner.ai:
			return null
		for field: String in ["cash", "revenue", "cogs", "expenses", "daily_revenue", "daily_cogs", "daily_expenses", "freight", "purchases", "depreciation"]:
			if not nonnegative(item[field]):
				return null
			owner.set(field, item[field])
		if absi(item.capital) > 100000000000000:
			return null
		owner.capital = item.capital
		if item.freight + item.depreciation > item.expenses or absi(item.recorded_profit) > 100000000000000 or item.daily_history.size() > 367 or item.monthly_history.size() > 13: return null
		owner.recorded_profit = item.recorded_profit
		var previous: String = ""
		for entry: Variant in item.daily_history:
			if not shape(entry, {"date": "", "profit": 0}) or entry.date <= previous or entry.date > sim.clock.date_string() or absi(entry.profit) > 100000000000000: return null
			previous = entry.date
			owner.daily_history.append(entry.duplicate(true))
		previous = ""
		for entry: Variant in item.monthly_history:
			if not shape(entry, {"month": "", "profit": 0}) or entry.month <= previous or entry.month > sim.clock.date_string().substr(0, 7) or absi(entry.profit) > 100000000000000: return null
			previous = entry.month
			owner.monthly_history.append(entry.duplicate(true))
	seen.clear()
	for item: Variant in state.facilities:
		if not item is Dictionary:
			return null
		var f: SimFacility = sim.facility(str(item.get("id", "")))
		if f == null or seen.has(f.id) or not shape(item, f.snapshot()):
			return null
		seen[f.id] = true
		if item.company != f.company_id or item.city != f.city_id or item.type != f.type_id or item.product != f.product_id or item.capacity != f.capacity or item.quality != f.quality or item.price <= 0 or item.price > 100000000 or item.stock_days < 1 or item.stock_days > 7:
			return null
		for field: String in ["sold_today", "produced_today"]:
			if not nonnegative(item[field]) or item[field] > f.capacity:
				return null
			f.set(field, item[field])
		f.price = item.price
		f.operating = item.operating
		f.active = item.active
		f.stock_days = item.stock_days
		if not nonnegative(item.asset_cost) or not nonnegative(item.asset_days) or item.asset_days > 3650 or not nonnegative(item.accumulated_depreciation) or item.accumulated_depreciation != item.asset_cost * item.asset_days / 3650: return null
		if item.asset_cost != (int(sim.catalog.facility_types[f.type_id].cost) if f.id.begins_with("built_") else 0): return null
		f.asset_cost = item.asset_cost
		f.asset_days = item.asset_days
		f.accumulated_depreciation = item.accumulated_depreciation
		for product: String in item.replenishment_targets:
			if not sim.command_error({"type": "set_warehouse_target", "company": f.company_id, "facility": f.id, "product": product, "quantity": item.replenishment_targets[product]}).is_empty(): return null
		f.replenishment_targets = item.replenishment_targets.duplicate(true)
		var quantities: Dictionary = item.inventory.quantities
		var costs: Dictionary = item.inventory.costs
		if quantities.size() != costs.size():
			return null
		for product: String in quantities:
			if not sim.catalog.products.has(product) or not costs.has(product) or not nonnegative(quantities[product]) or not nonnegative(costs[product]):
				return null
		f.inventory.quantities = quantities.duplicate(true)
		f.inventory.costs = costs.duplicate(true)
		for product: String in item.suppliers:
			if not item.suppliers[product] is String or not sim.command_error({"type": "set_supplier", "company": f.company_id, "facility": f.id, "product": product, "supplier": item.suppliers[product]}).is_empty():
				return null
		f.suppliers = item.suppliers.duplicate(true)
		if item.recent_sales.size() > 7:
			return null
		for sale: Variant in item.recent_sales:
			if not shape(sale, {"tick": 0, "units": 0, "revenue": 0, "produced": 0}):
				return null
			for value: Variant in sale.values():
				if not nonnegative(value):
					return null
			f.recent_sales.append(sale.duplicate(true))
		for product: String in item.last_sources:
			if not sim.catalog.products.has(product) or not item.last_sources[product] is Array:
				return null
			for source: Variant in item.last_sources[product]:
				if not shape(source, {"supplier": "", "units": 0, "price": 0, "quality": 0, "score": 0.0}) or sim.facility(source.supplier) == null:
					return null
		f.last_sources = item.last_sources.duplicate(true)
	if not _restore_logistics(sim, state.logistics): return null
	for technology: Variant in state.unlocked_technologies:
		if not technology is String or not sim.catalog.technologies.has(technology) or technology in sim.unlocked_technologies:
			return null
		sim.unlocked_technologies.append(technology)
	for command: Variant in state.pending_commands:
		if not command is Dictionary or not sim.command_error(command).is_empty():
			return null
		sim.queue_command(command)
	for result: Variant in state.command_results:
		if not shape(result, {"command": {}, "accepted": false, "error": ""}):
			return null
		sim.command_results.append(result.duplicate(true))
	for action: Variant in state.debug_actions:
		if not shape(action, {"tick": 0, "action": "", "amount": 0}):
			return null
		sim.debug_actions.append(action.duplicate(true))
	for product: String in state.market:
		var record: Variant = state.market[product]
		if not sim.catalog.products.has(product) or not shape(record, {"potential": 0, "units": 0, "revenue": 0, "average_price": 0.0, "company_units": {}, "market_share": {}}):
			return null
		for field: String in ["potential", "units", "revenue"]:
			if not nonnegative(record[field]):
				return null
		for id: String in record.company_units:
			if not sim.companies.has(id) or not nonnegative(record.company_units[id]):
				return null
		for id: String in record.market_share:
			if not sim.companies.has(id) or not record.market_share[id] is float or not is_finite(record.market_share[id]):
				return null
	if not nonnegative(state.consumer_units) or not nonnegative(state.consumer_revenue):
		return null
	sim.market = state.market.duplicate(true)
	sim.cumulative_consumer_units = state.consumer_units
	sim.cumulative_consumer_revenue = state.consumer_revenue
	sim.rng.state = int(state.rng_state)
	if not sim.invariant_errors().is_empty():
		return null
	# Derived account totals must agree too, not just the stored cash.
	for item: Dictionary in state.companies:
		var owner: SimCompany = sim.companies[item.id]
		if item.profit != owner.profit() or item.inventory_assets != sim.inventory_assets(owner.id) or item.daily_profit != owner.daily_revenue - owner.daily_cogs - owner.daily_expenses:
			return null
	error = ""
	return sim

func _restore_logistics(sim: Economy, state: Dictionary) -> bool:
	for field: String in sim.logistics.config:
		if not nonnegative(state.config[field]) or state.config[field] > 1000000: return false
	if state.config.cells_per_day < 1 or not nonnegative(state.next_id) or state.next_id < 1: return false
	sim.logistics.config = state.config.duplicate(true)
	var previous: int = 0
	for s: Variant in state.shipments:
		if not shape(s, {"id": 0, "company": "", "source": "", "destination": "", "product": "", "quantity": 0, "value": 0, "departure": 0, "arrival": 0, "transport_cost": 0, "distance": 0, "status": ""}): return false
		if not sim.companies.has(s.company) or not sim.catalog.products.has(s.product) or s.status not in ["in_transit", "delivered"] or s.id <= previous or s.id >= state.next_id: return false
		for field: String in ["quantity", "value", "departure", "arrival", "transport_cost", "distance"]:
			if not nonnegative(s[field]): return false
		if s.quantity < 1 or s.arrival <= s.departure or s.departure > sim.clock.tick: return false
		if s.status == "in_transit":
			var source: SimFacility = sim.facility(s.source)
			var destination: SimFacility = sim.facility(s.destination)
			if source == null or destination == null or source == destination or destination.company_id != s.company or s.arrival < sim.clock.tick: return false
			var quote: Dictionary = sim.logistics.quote(sim, s.source, s.destination, s.quantity)
			if s.distance != quote.distance or s.transport_cost != quote.freight or s.arrival != s.departure + quote.lead_days: return false
		elif s.arrival > sim.clock.tick: return false
		previous = s.id
		sim.logistics.shipments.append(s.duplicate(true))
	sim.logistics.next_id = state.next_id
	return true
