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
	return (FileAccess.get_file_as_string(DATA_PATH) + FileAccess.get_file_as_string(CityProfiles.PATH)).sha256_text()

func write_file(path: String, state: Dictionary, metadata: Dictionary = {}) -> bool:
	error = ""
	var envelope: Dictionary = {"format": "ModernCapitalism", "version": FORMAT_VERSION,
		"catalog_hash": fingerprint(), "engine": Engine.get_version_info().string, "session": state}
	envelope["metadata"] = metadata.duplicate(true)
	return _write_envelope(path, envelope)

func _write_envelope(path: String, envelope: Dictionary) -> bool:
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
	# Rename within the same directory: previous save survives an incomplete write.
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		error = "Cannot replace save file; temporary file retained."
		return false
	return true

func read_envelope(path: String) -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path):
		error = "Save file does not exist."
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 256000000:
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
	return decoded

func read_file(path: String) -> Dictionary:
	return read_envelope(path).get("session", {})

static func default_directory() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="): return argument.trim_prefix("--save-dir=")
	return "user://saves"

static func safe_filename(filename: String) -> bool:
	return not filename.is_empty() and filename == filename.get_file() and not "/" in filename and not "\\" in filename and not ":" in filename and filename.ends_with(".json")

static func fallback_label(filename: String) -> String:
	if filename in ["slot_1.json", "slot_2.json", "slot_3.json"]: return "Legacy Slot " + filename.substr(5, 1)
	return "Saved game — " + filename.get_basename().replace("_", " ")

func unique_filename(directory: String) -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	var suffix: int = 1
	while true:
		var filename: String = "save_%s_%03d.json" % [stamp, suffix]
		if not FileAccess.file_exists(directory.path_join(filename)) and not FileAccess.file_exists(directory.path_join(filename + ".tmp")): return filename
		suffix += 1
	return ""

func save_named(directory: String, filename: String, state: Dictionary, label: String) -> bool:
	if not safe_filename(filename):
		error = "Invalid save filename."
		return false
	var path: String = directory.path_join(filename)
	var metadata: Dictionary = {}
	if FileAccess.file_exists(path):
		var existing: Dictionary = read_envelope(path)
		if existing.get("metadata") is Dictionary: metadata = existing.metadata.duplicate(true)
	var now: String = Time.get_datetime_string_from_system()
	metadata["label"] = label.strip_edges().left(100)
	metadata["created_at"] = metadata.get("created_at", now)
	metadata["modified_at"] = now
	return write_file(path, state, metadata)

func rename_save(directory: String, filename: String, label: String) -> bool:
	if not safe_filename(filename) or label.strip_edges().is_empty():
		error = "Enter a save name."
		return false
	var path: String = directory.path_join(filename)
	var envelope: Dictionary = read_envelope(path)
	if envelope.is_empty(): return false
	var metadata: Dictionary = envelope.get("metadata", {}) if envelope.get("metadata", {}) is Dictionary else {}
	metadata["label"] = label.strip_edges().left(100)
	metadata["modified_at"] = Time.get_datetime_string_from_system()
	envelope["metadata"] = metadata
	# Preserve the exact decoded session; do not restore or reserialize an economy.
	return _write_envelope(path, envelope)

func delete_save(directory: String, filename: String) -> bool:
	error = ""
	if not safe_filename(filename):
		error = "Invalid save filename."
		return false
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename))) != OK:
		error = "Could not delete this save."
		return false
	return true

func discover(directory: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null: return result
	for filename: String in folder.get_files():
		if not safe_filename(filename): continue
		var path: String = directory.path_join(filename)
		var summary: Dictionary = inspect_file(path)
		summary["filename"] = filename
		summary["modified_unix"] = FileAccess.get_modified_time(path)
		summary["modified"] = Time.get_datetime_string_from_unix_time(int(summary.modified_unix), true)
		if not summary.has("label") or str(summary.label).strip_edges().is_empty(): summary["label"] = fallback_label(filename)
		result.append(summary)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.modified_unix == b.modified_unix: return str(a.filename) > str(b.filename)
		return a.modified_unix > b.modified_unix)
	return result

# Read-only presentation summary for the save browser. This validates with
# the same envelope and simulation restoration paths used by a real load without
# mutating the running GameSession.
func inspect_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "empty", "reason": "Empty"}
	var envelope: Dictionary = read_envelope(path)
	var state: Dictionary = envelope.get("session", {})
	if state.is_empty():
		var kind: String = "incompatible" if error.begins_with("Incompatible") else "unreadable"
		return {"state": kind, "reason": error}
	var time_template: Dictionary = {"speed": 0, "last_speed": 0, "seconds_per_day": 0.0, "accumulator": 0.0}
	if not shape(state, {"mode": "", "player_company": "", "time": time_template, "economy": {}}) or state.mode not in ["sandbox", "tutorial"] or state.player_company != "player":
		return {"state": "unreadable", "reason": "Invalid session state."}
	var timing: Dictionary = state.time
	if timing.speed not in GameTime.SPEEDS or timing.last_speed not in [1, 2, 4, 16] or not is_finite(timing.seconds_per_day) or timing.seconds_per_day < 0.01 or timing.seconds_per_day > 60.0 or not is_finite(timing.accumulator) or timing.accumulator < 0.0 or timing.accumulator > 100000.0:
		return {"state": "unreadable", "reason": "Invalid time controller state."}
	var candidate: Economy = restore(state.economy)
	if candidate == null:
		return {"state": "unreadable", "reason": error}
	var guide: TutorialController = TutorialController.new()
	if not state.get("tutorial") is Dictionary or not guide.restore(state.tutorial) or not state.get("active_company") is String or state.active_company not in candidate.equity_market.controlled_group(state.player_company) or not candidate.cities.has(state.get("active_city", "")):
		return {"state":"unreadable", "reason":"Invalid session or tutorial state."}
	if state.mode == "sandbox" and guide.snapshot() != TutorialController.new().snapshot():
		return {"state":"unreadable", "reason":"Unexpected tutorial state in sandbox."}
	var company_name: String = "Player company"
	if candidate.companies.has(state.player_company): company_name = candidate.companies[state.player_company].display_name
	var absolute: String = ProjectSettings.globalize_path(path)
	var modified_unix: int = int(FileAccess.get_modified_time(absolute))
	return {
		"state": "valid",
		"label": str(envelope.metadata.get("label", "")) if envelope.get("metadata") is Dictionary else "",
		"city": candidate.cities[str(state.active_city)].display_name,
		"company": company_name,
		"date": candidate.clock.date_string(),
		"starting_year": int(state.economy.starting_year),
		"mode": str(state.mode),
		"difficulty": candidate.difficulty,
		"difficulty_name": candidate.strategic_ai.difficulty_display_name(candidate.difficulty),
		"modified": Time.get_datetime_string_from_unix_time(modified_unix, true) if modified_unix > 0 else "",
	}

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
	if not state.get("seed") is String or not str(state.seed).is_valid_int() or not state.get("starting_year") is int or not state.get("difficulty") is String:
		return null
	if not sim.strategic_ai.valid_difficulty(state.difficulty):
		return null
	# Initialize catalog and economic definitions with the small fixture; saved city
	# hydration below never depends on the current procedural generator.
	if not sim.initialize(int(state.seed), int(state.starting_year), DATA_PATH, {"preset": "legacy"}, state.difficulty):
		return null
	error = "Invalid regional header."
	if not shape(state, sim.snapshot()) or state.schema_version != 22 or state.difficulty != sim.difficulty or state.catalog_version != sim.catalog.version or state.scenario != sim.catalog.scenario.id or not str(state.rng_state).is_valid_int():
		return null
	var legacy: bool = state.cities.size() == 1
	if legacy and (not state.cities.has("metro") or not state.cities.metro.port.is_empty()): return null
	if not legacy and state.cities.size() != sim.catalog.scenario.regional_cities.size(): return null
	if state.real_estates.size() != state.cities.size() or not nonnegative(state.next_facility_id) or state.next_facility_id < 1 or state.next_facility_id >= 1000000: return null
	for definition: Dictionary in sim.catalog.scenario.regional_cities:
		var city_id: String = str(definition.id)
		if legacy and city_id != "metro": continue
		if not state.cities.has(city_id) or not state.real_estates.has(city_id): return null
		if city_id != "metro":
			var map: CityMap = CityMap.new()
			map.id = city_id
			map.display_name = str(definition.name)
			sim.cities[city_id] = map
			var estate: RealEstate = RealEstate.new()
			estate.city_id = city_id
			sim.real_estates[city_id] = estate
			sim.market_by_city[city_id] = {}
			sim.category_market_by_city[city_id] = {}
			sim.market_history_by_city[city_id] = []
	if state.companies.size() != sim.companies.size() or state.facilities.size() > 768:
		return null
	var facility_template: Dictionary = sim.facilities[0].snapshot()
	facility_template.assortment = {}
	var restored: Array[SimFacility] = []
	var restored_ids: Dictionary = {}
	var headquarters_owners: Dictionary = {}
	for item: Variant in state.facilities:
		if not shape(item, facility_template) or restored_ids.has(item.id) or not sim.companies.has(item.company) or not sim.catalog.facility_types.has(item.type) or not sim.catalog.supports_product(item.type, item.product) or not sim.cities.has(item.city):
			return null
		var original: SimFacility = sim.facility(item.id)
		if original == null:
			for definition: Dictionary in sim.catalog.scenario.get("expanded_facilities", []):
				if definition.id == item.id: original = SimFacility.new(definition)
		if original != null:
			if item.company != original.company_id or item.city != original.city_id or item.type != original.type_id or not sim.catalog.supports_product(item.type, item.product) or item.capacity != original.capacity or item.quality != original.quality:
				return null
		else:
			var definition: Dictionary = sim.catalog.facility_types[item.type]
			if not item.id.begins_with("built_") or not item.id.trim_prefix("built_").is_valid_int() or int(item.id.trim_prefix("built_")) < 1 or item.id != "built_%06d" % int(item.id.trim_prefix("built_")) or not sim.catalog.supports_product(item.type, item.product) or item.capacity != int(definition.capacity) or item.quality != 50:
				return null
		var created: SimFacility = SimFacility.new(item)
		# Make the saved HQ operating state available before daily-counter validation;
		# effective capacity depends on it, but never on transient `active`.
		created.operating = item.operating
		if str(sim.catalog.facility_types[item.type].behavior) == "headquarters":
			if headquarters_owners.has(item.company): return null
			headquarters_owners[item.company] = true
		restored.append(created)
		restored_ids[item.id] = true
	# Deleted scenario facilities are valid. All live IDs must exist before supplier validation.
	sim.facilities = restored
	sim.facilities.sort_custom(func(a: SimFacility, b: SimFacility) -> bool: return a.id < b.id)
	var restored_profiles: Dictionary = {}
	error = "Invalid regional maps or real estate."
	for city_id: String in sim.cities:
		error = "Invalid map: " + city_id
		var local_facilities: Array[SimFacility] = []
		for f: SimFacility in sim.facilities:
			if f.city_id == city_id: local_facilities.append(f)
		if not sim.cities[city_id].restore(state.cities[city_id], local_facilities, sim.catalog): return null
		if not legacy:
			var profile_id: String = str(sim.cities[city_id].profile.id)
			if restored_profiles.has(profile_id): return null
			restored_profiles[profile_id] = true
		sim.cities[city_id].population = state.cities[city_id].population.duplicate(true)
		error = "Invalid real estate: " + city_id
		if not sim.real_estates[city_id].restore_state(sim, state.real_estates[city_id]): return null
		error = "Invalid city seed: " + city_id
		var definition: Dictionary = sim.city_definition(city_id)
		if sim.cities[city_id].generation.seed != str(int(state.seed) + int(definition.seed_offset)): return null
	sim.city = sim.cities["metro"]
	sim.real_estate = sim.real_estates["metro"]
	sim.next_facility_id = state.next_facility_id
	for f: SimFacility in sim.facilities:
		if f.id.begins_with("built_") and int(f.id.trim_prefix("built_")) >= sim.next_facility_id: return null
	var saved_clock: Dictionary = state.clock
	error = "Invalid clock or company accounts."
	if not nonnegative(saved_clock.tick) or saved_clock.tick > 365000:
		return null
	# Derive calendar from tick instead of accepting impossible dates.
	for tick: int in range(saved_clock.tick):
		sim.clock.advance()
	if sim.clock.snapshot() != saved_clock:
		return null
	error = "Invalid company accounts."
	var seen: Dictionary = {}
	for item: Variant in state.companies:
		if not item is Dictionary or not sim.companies.has(str(item.get("id", ""))) or seen.has(item.id):
			return null
		seen[item.id] = true
		var owner: SimCompany = sim.companies[item.id]
		var template: Dictionary = owner.snapshot()
		template["inventory_assets"] = 0
		template.known_technologies = {}
		if not shape(item, template) or (item.id != "player" and item.name != owner.display_name) or item.name.strip_edges().is_empty() or item.name.length() > 48 or "\n" in item.name or "\r" in item.name or item.ai != owner.ai:
			return null
		if item.id == "player":
			if item.opening_cash not in SessionSetup.CAPITAL: return null
			owner.opening_cash = item.opening_cash
			owner.display_name = item.name
		for field: String in ["cash", "revenue", "cogs", "expenses", "daily_revenue", "daily_cogs", "daily_expenses", "freight", "purchases", "import_purchases", "export_revenue", "depreciation", "retail_revenue", "property_revenue", "property_maintenance", "production_cash", "cash_expenses", "capex", "land_capex", "property_capex", "research_expense", "advertising_expense", "payroll_expense", "equity_purchase_cash", "equity_sale_cash", "equity_issue_cash", "investment_income", "dividend_receipts", "dividends_paid"]:
			if not nonnegative(item[field]):
				return null
			owner.set(field, item[field])
		if not item.realized_investment_gain is int or absi(item.realized_investment_gain) > 100000000000000 or not item.ttm_profit_cached is int or absi(item.ttm_profit_cached) > 100000000000000: return null
		owner.realized_investment_gain = item.realized_investment_gain
		owner.ttm_profit_cached = item.ttm_profit_cached
		if item.staff_counts.size() != sim.catalog.staff_roles.size(): return null
		for role: String in item.staff_counts:
			if not sim.catalog.staff_roles.has(role) or not item.staff_counts[role] is int or item.staff_counts[role] < 0: return null
		owner.staff_counts = item.staff_counts.duplicate(true)
		if not item.staff_payroll_funded is bool or (item.staff_payroll_funded and owner.total_staff() == 0): return null
		owner.staff_payroll_funded = item.staff_payroll_funded
		if item.product_brands.size() != owner.product_brands.size(): return null
		for product: String in item.product_brands:
			if not owner.product_brands.has(product) or not item.product_brands[product] is int or item.product_brands[product] < 0 or item.product_brands[product] > 100: return null
		owner.product_brands = item.product_brands.duplicate(true)
		if item.advertising_budgets.size() != owner.advertising_budgets.size() or item.advertising_progress.size() != owner.advertising_progress.size() or item.advertising_inactive_days.size() != owner.advertising_inactive_days.size(): return null
		for product: String in owner.advertising_budgets:
			if not item.advertising_budgets.has(product) or not item.advertising_progress.has(product) or not item.advertising_inactive_days.has(product) or not item.advertising_budgets[product] is int or not item.advertising_progress[product] is int or not item.advertising_inactive_days[product] is int: return null
			if item.advertising_budgets[product] < 0 or item.advertising_budgets[product] > 100000000 or item.advertising_progress[product] < 0 or item.advertising_inactive_days[product] < 0: return null
		owner.advertising_budgets = item.advertising_budgets.duplicate(true)
		owner.advertising_progress = item.advertising_progress.duplicate(true)
		owner.advertising_inactive_days = item.advertising_inactive_days.duplicate(true)
		owner.known_technologies.clear()
		for technology: String in item.known_technologies:
			var acquired: Variant = item.known_technologies[technology]
			if not sim.catalog.technologies.has(technology) or not acquired is int or acquired < -1 or acquired > sim.clock.tick: return null
			if acquired == -1 and not sim.catalog.technology_public(technology, sim.starting_year): return null
			owner.known_technologies[technology] = acquired
		for technology: String in sim.catalog.technologies:
			if sim.catalog.technology_public(technology, sim.starting_year) and not owner.knows(technology): return null
		for technology: String in owner.known_technologies:
			for prerequisite: String in sim.catalog.technologies[technology].prerequisites:
				if not owner.knows(prerequisite): return null
		for technology: String in item.research_progress:
			var progress: Variant = item.research_progress[technology]
			if not sim.catalog.technologies.has(technology) or owner.knows(technology) or not nonnegative(progress) or progress <= 0 or progress >= int(sim.catalog.technologies[technology].research_work): return null
			for prerequisite: String in sim.catalog.technologies[technology].prerequisites:
				if not owner.knows(prerequisite): return null
		owner.research_progress = item.research_progress.duplicate(true)
		if item.product_quality_levels.size() != owner.product_quality_levels.size(): return null
		for product: String in item.product_quality_levels:
			var level: Variant = item.product_quality_levels[product]
			if not owner.product_quality_levels.has(product) or not level is int or level < 0 or level > sim.catalog.quality_max_level(): return null
		owner.product_quality_levels = item.product_quality_levels.duplicate(true)
		for product: String in item.product_quality_progress:
			var project_progress: Variant = item.product_quality_progress[product]
			if not owner.product_quality_levels.has(product) or not project_progress is Dictionary or not shape(project_progress, {"target_level": 0, "progress": 0}): return null
			var target: int = int(project_progress.target_level)
			var progress: int = int(project_progress.progress)
			if target != owner.product_quality_level(product) + 1 or target > sim.catalog.quality_max_level() or not nonnegative(progress) or progress <= 0 or progress >= sim.catalog.quality_research_work(target): return null
			if not owner.knows(str(sim.catalog.products[product].technology)): return null
		owner.product_quality_progress = item.product_quality_progress.duplicate(true)
		if item.process_efficiency_levels.size() != owner.process_efficiency_levels.size(): return null
		for product: String in item.process_efficiency_levels:
			var level: Variant = item.process_efficiency_levels[product]
			if not owner.process_efficiency_levels.has(product) or not level is int or level < 0 or level > sim.catalog.efficiency_max_level(): return null
			if level > 0 and (not sim.product_public(product) or not sim.catalog.manufacturable_product(product) or not owner.knows(str(sim.catalog.products[product].technology))): return null
		owner.process_efficiency_levels = item.process_efficiency_levels.duplicate(true)
		for product: String in item.process_efficiency_progress:
			var project_progress: Variant = item.process_efficiency_progress[product]
			if not owner.process_efficiency_levels.has(product) or not project_progress is Dictionary or not shape(project_progress, {"target_level": 0, "progress": 0}): return null
			var target: int = int(project_progress.target_level)
			var progress: int = int(project_progress.progress)
			if target != owner.process_efficiency_level(product) + 1 or target > sim.catalog.efficiency_max_level() or not nonnegative(progress) or progress <= 0 or progress >= sim.catalog.efficiency_research_work(target): return null
			if not owner.knows(str(sim.catalog.products[product].technology)): return null
		owner.process_efficiency_progress = item.process_efficiency_progress.duplicate(true)
		if absi(item.capital) > 100000000000000:
			return null
		owner.capital = item.capital
		if item.opening_cash != owner.opening_cash or item.retail_revenue + item.property_revenue + item.export_revenue > item.revenue or item.import_purchases > item.purchases: return null
		for field: String in item.recorded_accounts:
			if not owner.accounts().has(field) or not item.recorded_accounts[field] is int: return null
		owner.recorded_accounts = item.recorded_accounts.duplicate(true)
		for entry: Variant in item.archived_months:
			if not shape(entry, {"month": "", "profit": 0}): return null
			owner.archived_months.append(entry.duplicate(true))
		if item.freight + item.depreciation + item.research_expense + item.advertising_expense + item.payroll_expense > item.expenses or item.research_expense + item.advertising_expense + item.payroll_expense > item.cash_expenses or absi(item.recorded_profit) > 100000000000000 or item.daily_history.size() > 367 or item.monthly_history.size() > 13: return null
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
		if not _valid_financial_history(owner): return null
	error = "Invalid facility state."
	seen.clear()
	for item: Variant in state.facilities:
		if not item is Dictionary:
			return null
		var f: SimFacility = sim.facility(str(item.get("id", "")))
		if f == null or seen.has(f.id) or not shape(item, f.snapshot()):
			return null
		seen[f.id] = true
		var productless: bool = sim.catalog.productless_behavior(sim._behavior(f))
		if item.company != f.company_id or item.city != f.city_id or item.type != f.type_id or item.product != f.product_id or item.capacity != f.capacity or item.quality != f.quality or (item.price <= 0 and not productless) or item.price > 100000000 or item.stock_days < 1 or item.stock_days > 7:
			return null
		for field: String in ["sold_today", "produced_today"]:
			if not nonnegative(item[field]) or item[field] > sim.effective_capacity(f):
				return null
			f.set(field, item[field])
		f.price = item.price
		f.assortment.clear()
		if item.assortment.is_empty() and not productless: return null
		if sim._behavior(f) == "retail" and item.assortment.size() > int(sim.catalog.facility_types[f.type_id].slots): return null
		for product: String in item.assortment:
			if product not in sim.catalog.facility_types[f.type_id].products or not item.assortment[product] is int or item.assortment[product] <= 0 or item.assortment[product] > 100000000: return null
			f.assortment[product] = item.assortment[product]
		if not f.assortment.has(f.product_id) and not productless: return null
		if productless and (not item.assortment.is_empty() or item.price != 0 or not item.inventory.quantities.is_empty() or not item.suppliers.is_empty() or not item.replenishment_targets.is_empty() or not item.line_sales.is_empty() or not item.line_today.is_empty() or item.sold_today != 0 or item.produced_today != 0): return null
		if sim._behavior(f) == "headquarters" and not item.research_project.is_empty(): return null
		for product: String in item.line_sales:
			if not sim.catalog.products.has(product) or not shape(item.line_sales[product], {"units": 0, "revenue": 0, "cogs": 0}): return null
			for value: Variant in item.line_sales[product].values():
				if not nonnegative(value): return null
		f.line_sales = item.line_sales.duplicate(true)
		if not _valid_product_sales(sim, item.line_today) or item.product_history.size() > 7: return null
		f.line_today = item.line_today.duplicate(true)
		for record: Variant in item.product_history:
			if not shape(record, {"tick": 0, "products": {}}) or not nonnegative(record.tick) or not _valid_product_sales(sim, record.products): return null
			f.product_history.append(record.duplicate(true))
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
		var points: Dictionary = item.inventory.quality_points
		if quantities.size() != costs.size() or quantities.size() != points.size():
			return null
		for product: String in quantities:
			if not sim.catalog.products.has(product) or not costs.has(product) or not nonnegative(quantities[product]) or not nonnegative(costs[product]):
				return null
			if not points.has(product) or not nonnegative(points[product]) or points[product] < quantities[product] or points[product] > quantities[product] * 100 or (quantities[product] == 0 and costs[product] != 0): return null
		f.inventory.quality_points = points.duplicate(true)
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
				if not shape(source, {"supplier": "", "units": 0, "price": 0, "quality": 0, "score": 0.0}) or (sim.facility(source.supplier) == null and source.supplier != "import:" + f.city_id):
					return null
		f.last_sources = item.last_sources.duplicate(true)
	error = "Invalid regional shipments."
	if not _restore_logistics(sim, state.logistics): return null
	for technology: Variant in state.unlocked_technologies:
		if not technology is String or not sim.catalog.technologies.has(technology) or technology in sim.unlocked_technologies:
			return null
		sim.unlocked_technologies.append(technology)
	for item: Dictionary in state.facilities:
		var f: SimFacility = sim.facility(item.id)
		if not item.research_project.is_empty():
			if sim._behavior(f) != "research" or not sim.research_project_error(f.company_id, item.research_project).is_empty(): return null
			f.research_project = item.research_project.duplicate(true)
	for owner: SimCompany in sim.companies.values():
		for technology: String in owner.research_progress:
			if not sim.technology_public(technology): return null
		for product: String in owner.product_quality_progress:
			if not sim.product_public(product) or not owner.knows(str(sim.catalog.products[product].technology)): return null
		for product: String in owner.process_efficiency_progress:
			if not sim.product_public(product) or not sim.catalog.manufacturable_product(product) or not owner.knows(str(sim.catalog.products[product].technology)): return null
		for technology: String in owner.known_technologies:
			if not sim.technology_public(technology): return null
			for prerequisite: String in sim.catalog.technologies[technology].prerequisites:
				if int(owner.known_technologies[prerequisite]) > int(owner.known_technologies[technology]): return null
	if not state.equity_market is Dictionary or state.equity_market.size() != sim.companies.size(): return null
	for id: String in sim.companies:
		if not state.equity_market.has(id) or not shape(state.equity_market[id], sim.equity_market.securities[id]): return null
		var security: Dictionary = state.equity_market[id]
		if security.company != id or not security.public is bool or not nonnegative(security.outstanding) or security.outstanding < 1 or not nonnegative(security.founder) or not nonnegative(security.float) or not nonnegative(security.quote) or security.quote < 1 or not security.holdings is Dictionary or not security.history is Array: return null
		for holder: String in security.holdings:
			if not sim.companies.has(holder) or holder == id or not shape(security.holdings[holder], {"shares": 0, "cost": 0}) or not nonnegative(security.holdings[holder].shares) or security.holdings[holder].shares == 0 or not nonnegative(security.holdings[holder].cost): return null
		for row: Variant in security.history:
			if not shape(row, {"date": "", "price": 0}) or not nonnegative(row.price) or row.price < 1 or not _valid_share_date(row.date) or row.date > sim.clock.date_string(): return null
	sim.equity_market.securities = state.equity_market.duplicate(true)
	if not sim.equity_market.invariant_errors(sim.companies).is_empty(): return null
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
		error = "Invalid regional markets."
		if not _valid_market(sim, product, state.market[product]): return null
	if not nonnegative(state.consumer_units) or not nonnegative(state.consumer_revenue):
		return null
	sim.market = state.market.duplicate(true)
	for category: String in state.category_market:
		if not sim.catalog.categories.has(category) or not _valid_category(sim, state.category_market[category]): return null
		var units: int = 0
		var revenue: int = 0
		var local_units: int = 0
		var local_revenue: int = 0
		for product: String in sim.market:
			if sim.catalog.products[product].category == category:
				units += int(sim.market[product].units)
				revenue += int(sim.market[product].revenue)
				local_units += int(sim.market[product].local_units)
				if sim.catalog.consumer_product(product): local_revenue += int(sim.market[product].local_units) * int(sim.catalog.local_values(product).price)
		if units != int(state.category_market[category].units) or revenue != int(state.category_market[category].revenue): return null
		if local_units != int(state.category_market[category].local_units) or local_revenue != int(state.category_market[category].local_revenue): return null
	sim.category_market = state.category_market.duplicate(true)
	if state.market_history.size() > 90: return null
	for entry: Variant in state.market_history:
		if not shape(entry, {"date": "", "categories": {}}): return null
		if entry.date > sim.clock.date_string() or (not sim.market_history.is_empty() and entry.date <= sim.market_history.back().date): return null
		for category: String in entry.categories:
			if not sim.catalog.categories.has(category) or not _valid_category(sim, entry.categories[category]): return null
		sim.market_history.append(entry.duplicate(true))
	if state.market_by_city.size() != sim.cities.size() or state.category_market_by_city.size() != sim.cities.size() or state.market_history_by_city.size() != sim.cities.size(): return null
	for city_id: String in sim.cities:
		if not state.market_by_city.has(city_id) or not state.category_market_by_city.has(city_id) or not state.market_history_by_city.has(city_id): return null
		if not state.market_by_city[city_id] is Dictionary or not state.category_market_by_city[city_id] is Dictionary or not state.market_history_by_city[city_id] is Array: return null
		for product: String in state.market_by_city[city_id]:
			if not _valid_market(sim, product, state.market_by_city[city_id][product]): return null
		for category: String in state.category_market_by_city[city_id]:
			if not sim.catalog.categories.has(category) or not _valid_category(sim, state.category_market_by_city[city_id][category]): return null
			var units: int = 0
			var revenue: int = 0
			var local_units: int = 0
			var local_revenue: int = 0
			for product: String in state.market_by_city[city_id]:
				if sim.catalog.products[product].category != category: continue
				var product_market: Dictionary = state.market_by_city[city_id][product]
				units += int(product_market.units)
				revenue += int(product_market.revenue)
				local_units += int(product_market.local_units)
				if sim.catalog.consumer_product(product): local_revenue += int(product_market.local_units) * int(sim.catalog.local_values(product).price)
			var category_market: Dictionary = state.category_market_by_city[city_id][category]
			if units != int(category_market.units) or revenue != int(category_market.revenue) or local_units != int(category_market.local_units) or local_revenue != int(category_market.local_revenue): return null
		if state.market_history_by_city[city_id].size() > 90: return null
		var previous_date: String = ""
		for entry: Variant in state.market_history_by_city[city_id]:
			if not shape(entry, {"date": "", "categories": {}}) or entry.date <= previous_date or entry.date > sim.clock.date_string(): return null
			for category: String in entry.categories:
				if not sim.catalog.categories.has(category) or not _valid_category(sim, entry.categories[category]): return null
			previous_date = entry.date
	sim.market_by_city = state.market_by_city.duplicate(true)
	sim.category_market_by_city = state.category_market_by_city.duplicate(true)
	sim.market_history_by_city = state.market_history_by_city.duplicate(true)
	ConsumerMarket.aggregate(sim)
	if sim.market != state.market or sim.category_market != state.category_market: return null
	error = "Invalid regional trade."
	if not _restore_regional_trade(sim, state.regional_trade): return null
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

func _restore_regional_trade(sim: Economy, state: Dictionary) -> bool:
	if not shape(state, sim.regional_trade.snapshot()) or not state.day_tick is int or state.day_tick < -1 or state.day_tick > sim.clock.tick or state.day_tick < sim.clock.tick - 1 or state.history.size() > 90: return false
	for mode: String in ["import", "export"]:
		var usage: Dictionary = state.import_used if mode == "import" else state.export_used
		for key: String in usage:
			var parts: PackedStringArray = key.split(":")
			if parts.size() != 2 or not sim.cities.has(parts[0]) or not sim.catalog.products.has(parts[1]) or not nonnegative(usage[key]): return false
			var cap: int = RegionalTrade.IMPORT_CAP if mode == "import" else sim.regional_trade.export_cap(sim, parts[0], parts[1])
			if usage[key] > cap: return false
	var previous_date: String = ""
	for entry: Variant in state.history:
		if not shape(entry, {"date": "", "cities": {}}) or entry.date <= previous_date or entry.date > sim.clock.date_string(): return false
		previous_date = entry.date
		for city_id: String in entry.cities:
			if not sim.cities.has(city_id) or not entry.cities[city_id] is Dictionary: return false
			for product: String in entry.cities[city_id]:
				var row: Variant = entry.cities[city_id][product]
				if not sim.catalog.products.has(product) or not shape(row, {"import_units": 0, "import_value": 0, "export_units": 0, "export_value": 0}): return false
				for value: Variant in row.values():
					if not nonnegative(value): return false
	sim.regional_trade.day_tick = state.day_tick
	sim.regional_trade.import_used = state.import_used.duplicate(true)
	sim.regional_trade.export_used = state.export_used.duplicate(true)
	sim.regional_trade.history.clear()
	for entry: Dictionary in state.history: sim.regional_trade.history.append(entry.duplicate(true))
	return true

func _valid_category(sim: Economy, row: Variant) -> bool:
	if not shape(row, {"potential": 0, "units": 0, "revenue": 0, "local_units": 0, "local_revenue": 0, "segments": {}}): return false
	for field: String in ["potential", "units", "revenue", "local_units", "local_revenue"]:
		if not nonnegative(row[field]): return false
	if row.units > row.potential or row.local_units > row.units or row.local_revenue > row.revenue: return false
	var total: int = 0
	for segment: String in row.segments:
		if not sim.catalog.segments.has(segment) or not nonnegative(row.segments[segment]): return false
		total += int(row.segments[segment])
	return total == row.potential

func _valid_product_sales(sim: Economy, sales: Dictionary) -> bool:
	for product: String in sales:
		if not sim.catalog.products.has(product) or not shape(sales[product], {"units": 0, "revenue": 0, "cogs": 0}): return false
		for value: Variant in sales[product].values():
			if not nonnegative(value): return false
	return true

func _valid_financial_history(owner: SimCompany) -> bool:
	if owner.recorded_accounts.is_empty(): return owner.monthly_history.is_empty() and owner.daily_history.is_empty() and owner.archived_months.is_empty()
	if not shape(owner.recorded_accounts, owner.accounts()): return false
	var all_months: Array[Dictionary] = owner.archived_months.duplicate()
	all_months.append_array(owner.monthly_history)
	var totals: Dictionary = {}
	for field: String in owner.accounts(): totals[field] = 0
	var previous_cash: int = owner.opening_cash
	var previous_month: String = ""
	for row: Dictionary in all_months:
		if not shape(row, owner.accounts()) or not shape(row, {"opening_cash": 0, "closing_cash": 0}) or str(row.month) <= previous_month: return false
		if int(row.opening_cash) != previous_cash or int(row.opening_cash) + int(row.cash) != int(row.closing_cash): return false
		if int(row.revenue) - int(row.cogs) - int(row.expenses) + int(row.investment_income) + int(row.realized_investment_gain) != int(row.profit): return false
		if int(row.retail_revenue) + int(row.wholesale_revenue) + int(row.property_revenue) + int(row.export_revenue) != int(row.revenue): return false
		if int(row.revenue) - int(row.purchases) - int(row.production_cash) - int(row.cash_expenses) - int(row.capex) - int(row.land_capex) - int(row.property_capex) - int(row.equity_purchase_cash) + int(row.equity_sale_cash) + int(row.dividend_receipts) + int(row.capital) - int(row.dividends_paid) != int(row.cash): return false
		for field: String in totals: totals[field] += int(row[field])
		previous_cash = int(row.closing_cash)
		previous_month = row.month
	for field: String in totals:
		var opening: int = owner.opening_cash if field in ["cash", "capital"] else 0
		if int(totals[field]) + opening != int(owner.recorded_accounts[field]): return false
	if owner.recorded_profit != int(owner.recorded_accounts.profit): return false
	for row: Dictionary in owner.daily_history:
		if not shape(row, owner.accounts()) or not shape(row, {"opening_cash": 0, "closing_cash": 0}): return false
		if int(row.revenue) - int(row.cogs) - int(row.expenses) + int(row.investment_income) + int(row.realized_investment_gain) != int(row.profit) or int(row.opening_cash) + int(row.cash) != int(row.closing_cash): return false
	return true

func _restore_logistics(sim: Economy, state: Dictionary) -> bool:
	for field: String in sim.logistics.config:
		if not nonnegative(state.config[field]) or state.config[field] > 1000000: return false
	if state.config.cells_per_day < 1 or not nonnegative(state.next_id) or state.next_id < 1: return false
	sim.logistics.config = state.config.duplicate(true)
	var previous: int = 0
	for s: Variant in state.shipments:
		if not shape(s, {"id": 0, "company": "", "source": "", "destination": "", "product": "", "quantity": 0, "value": 0, "quality_points": 0, "departure": 0, "arrival": 0, "transport_cost": 0, "distance": 0, "status": "", "mode": "", "source_city": "", "destination_city": "", "source_port": "", "destination_port": "", "regional_distance": 0}): return false
		if not sim.companies.has(s.company) or not sim.catalog.products.has(s.product) or s.status not in ["in_transit", "delivered", "exported"] or s.mode not in ["local", "regional", "import", "export"] or s.id <= previous or s.id >= state.next_id: return false
		for field: String in ["quantity", "value", "departure", "arrival", "transport_cost", "distance", "regional_distance"]:
			if not nonnegative(s[field]): return false
		if not nonnegative(s.quality_points) or s.quality_points < s.quantity or s.quality_points > s.quantity * 100: return false
		if s.quantity < 1 or s.arrival <= s.departure or s.departure > sim.clock.tick: return false
		var live_source: SimFacility = sim.facility(s.source)
		var live_destination: SimFacility = sim.facility(s.destination)
		if not sim.cities.has(s.source_city) or not sim.cities.has(s.destination_city): return false
		if s.mode == "local" and (s.source_city != s.destination_city or not s.source_port.is_empty() or not s.destination_port.is_empty() or s.regional_distance != 0): return false
		if s.mode == "regional" and (s.source_city == s.destination_city or s.source_port != sim.cities[s.source_city].port.get("id", "") or s.destination_port != sim.cities[s.destination_city].port.get("id", "") or s.regional_distance != sim.regional_distance(s.source_city, s.destination_city)): return false
		if live_source != null and sim.catalog.productless_behavior(sim._behavior(live_source)): return false
		if live_destination != null and sim.catalog.productless_behavior(sim._behavior(live_destination)): return false
		if s.mode in ["import", "export"]:
			var endpoint: SimFacility = live_destination if s.mode == "import" else live_source
			if endpoint == null or endpoint.company_id != s.company or endpoint.city_id != s.source_city or endpoint.city_id != s.destination_city or s.source_port != sim.cities[endpoint.city_id].port.get("id", "") or s.destination_port != s.source_port: return false
			if s.mode == "import" and s.source != "import:" + endpoint.city_id: return false
			if s.mode == "export" and s.destination != "export:" + endpoint.city_id: return false
			if s.mode == "import" and s.status not in ["in_transit", "delivered"]: return false
			if s.mode == "export" and (s.status != "exported" or s.value != 0): return false
			var trade_quote: Dictionary = sim.regional_trade.quote(sim, endpoint.id, s.product, s.quantity, s.mode)
			if trade_quote.is_empty() or s.distance != trade_quote.distance or s.transport_cost != trade_quote.freight or s.regional_distance != trade_quote.external_leg or s.arrival != s.departure + trade_quote.lead_days: return false
			if s.mode == "import" and (s.quality_points != s.quantity * 50 or s.value != s.quantity * trade_quote.price): return false
		elif s.status == "in_transit":
			var source: SimFacility = live_source
			var destination: SimFacility = live_destination
			if source == null or destination == null or source == destination or destination.company_id != s.company or s.arrival < sim.clock.tick: return false
			var quote: Dictionary = sim.logistics.quote(sim, s.source, s.destination, s.quantity)
			if s.mode != quote.mode or s.source_city != source.city_id or s.destination_city != destination.city_id or s.regional_distance != quote.regional_leg or s.distance != quote.distance or s.transport_cost != quote.freight or s.arrival != s.departure + quote.lead_days: return false
		elif s.arrival > sim.clock.tick: return false
		previous = s.id
		sim.logistics.shipments.append(s.duplicate(true))
	sim.logistics.next_id = state.next_id
	return true

func _valid_market(sim: Economy, product: String, record: Variant) -> bool:
	if not sim.catalog.products.has(product) or not shape(record, ConsumerMarket.empty_report()): return false
	for field: String in ["potential", "units", "revenue", "local_units", "quality_total", "brand_total"]:
		if not nonnegative(record[field]): return false
	var units: int = record.local_units
	if record.local_units > 0 and not sim.catalog.consumer_product(product): return false
	for id: String in record.company_units:
		if not sim.companies.has(id) or not nonnegative(record.company_units[id]): return false
		units += int(record.company_units[id])
	if units != record.units or units > record.potential or record.quality_total < units or record.quality_total > 100 * units or record.brand_total > 100 * units: return false
	if units == 0 and record.revenue != 0: return false
	var expected: Dictionary = record.duplicate(true)
	ConsumerMarket.finish_report(expected, int(sim.catalog.products[product].reference_price))
	for field: String in ["average_price", "average_quality", "average_brand", "average_overall", "local_share", "market_share"]:
		if expected[field] != record[field]: return false
	return true

func _valid_share_date(value: String) -> bool:
	if value.length() != 10 or value.substr(4, 1) != "-" or value.substr(7, 1) != "-": return false
	var year_text: String = value.substr(0, 4)
	var month_text: String = value.substr(5, 2)
	var day_text: String = value.substr(8, 2)
	if not year_text.is_valid_int() or not month_text.is_valid_int() or not day_text.is_valid_int(): return false
	var year: int = int(year_text)
	var month: int = int(month_text)
	var day: int = int(day_text)
	if year < 1 or month < 1 or month > 12: return false
	var days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and year % 4 == 0 and (year % 100 != 0 or year % 400 == 0): return day >= 1 and day <= 29
	return day >= 1 and day <= days[month - 1]
