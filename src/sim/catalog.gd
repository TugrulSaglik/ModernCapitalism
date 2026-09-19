class_name SimCatalog
extends RefCounted

var products: Dictionary = {}
var technologies: Dictionary = {}
var facility_types: Dictionary = {}
var scenario: Dictionary = {}
var version: int = 0
var errors: Array[String] = []
var categories: Dictionary = {}
var segments: Dictionary = {}

func load_data(path: String = "res://data/example_economy.json") -> bool:
	products.clear()
	technologies.clear()
	facility_types.clear()
	errors.clear()
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("Invalid catalog JSON: " + path)
		return false
	var root: Dictionary = parser.data
	categories.clear()
	segments.clear()
	_index(root.get("categories", []), categories)
	_index(root.get("segments", []), segments)
	version = int(root.get("version", 0))
	_index(root.get("products", []), products)
	_index(root.get("technologies", []), technologies)
	_index(root.get("facility_types", []), facility_types)
	scenario = root.get("scenario", {})
	for id: String in technologies:
		if float(technologies[id].get("year", -1)) != floor(float(technologies[id].get("year", -1))) or int(technologies[id].get("year", -1)) < 1900 or int(technologies[id].get("year", 0)) > 3000: errors.append("Invalid technology year: " + id)
		var tech: Dictionary = technologies[id]
		for field: String in ["research_work", "research_cost"]:
			if not _positive_integer(tech.get(field)): errors.append("Invalid research definition: " + id + "/" + field)
		if not tech.get("prerequisites") is Array:
			errors.append("Technology prerequisites must be an array: " + id)
			return false
		var seen: Array = []
		for prerequisite: Variant in tech.prerequisites:
			if not prerequisite is String or prerequisite in seen:
				errors.append("Invalid/duplicate prerequisite: " + id)
				return false
			seen.append(prerequisite)
	for id: String in technologies:
		_validate_technology(id, [])
	for id: String in categories:
		var c: Dictionary = categories[id]
		if not technologies.has(str(c.get("technology", ""))) or float(c.get("daily_demand", -1)) < 0 or float(c.get("purchase_frequency", -1)) < 0 or float(c.get("income_sensitivity", -1)) < 0: errors.append("Invalid category: " + id)
	if segments.is_empty(): errors.append("Consumer segments required")
	for id: String in segments:
		var s: Dictionary = segments[id]
		if not s.has("income_slope") or not s.get("category_preferences") is Dictionary or float(s.get("share", 0)) <= 0 or float(s.get("purchasing_power", 0)) <= 0 or float(s.get("price_sensitivity", 0)) <= 0 or float(s.get("quality_sensitivity", 0)) <= 0: errors.append("Invalid segment: " + id)
		for category: String in s.get("category_preferences", {}):
			if not categories.has(category) or float(s.category_preferences[category]) < 0: errors.append("Invalid segment preference: " + id)
	for id: String in products:
		var p: Dictionary = products[id]
		if not categories.has(str(p.get("category", ""))): errors.append("Unknown category: " + id)
		_validate_recipe(id, [])
		if not technologies.has(str(p.get("technology", ""))) or int(p.get("reference_price", 0)) <= 0 or int(p.get("conversion_cost", -1)) < 0 or int(p.get("daily_demand", -1)) < 0:
			errors.append("Invalid product: " + id)
		for input: String in p.get("inputs", {}):
			if not products.has(input) or int(p.inputs[input]) <= 0 or float(p.inputs[input]) != floor(float(p.inputs[input])) or input == id:
				errors.append("Invalid recipe input: " + id + "/" + input)
	var companies: Dictionary = {}
	_index(scenario.get("companies", []), companies)
	for id: String in companies:
		if int(companies[id].get("cash", -1)) < 0:
			errors.append("Invalid company cash: " + id)
	var facilities: Dictionary = {}
	_index(scenario.get("facilities", []), facilities)
	for id: String in facilities:
		var f: Dictionary = facilities[id]
		if not companies.has(str(f.get("company", ""))) or not supports_product(str(f.get("type", "")), str(f.get("product", ""))) or not facility_types.has(str(f.get("type", ""))) or int(f.get("capacity", 0)) <= 0 or (facility_types.get(str(f.get("type", "")), {}).get("behavior") != "research" and int(f.get("price", 0)) <= 0) or int(f.get("quality", 0)) < 1 or int(f.get("quality", 0)) > 100 or str(f.get("city", "")).is_empty():
			errors.append("Invalid facility: " + id)
	for id: String in facility_types:
		var f: Dictionary = facility_types[id]
		if f.get("behavior") == "research" and (not _positive_integer(f.get("research_rate")) or not f.get("products", []).is_empty()): errors.append("Invalid research facility: " + id)
		if f.get("behavior") == "retail":
			if int(f.get("slots", 0)) < 1 or not f.get("categories") is Array: errors.append("Retail slots/categories required: " + id)
			else:
				for product: String in f.get("products", []):
					if products.has(product) and products[product].category not in f.categories: errors.append("Disallowed retail category: " + id)
		if str(f.get("behavior", "")) not in ["production", "retail", "storage", "research"] or int(f.get("overhead", -1)) < 0 or int(f.get("width", 0)) < 1 or int(f.get("depth", 0)) < 1 or int(f.get("cost", 0)) <= 0 or int(f.get("capacity", 0)) <= 0:
			errors.append("Invalid facility type: " + id)
		if not f.get("products") is Array or (f.get("products", []).is_empty() and f.get("behavior") != "research"):
			errors.append("Facility type requires supported products: " + id)
		else:
			for product: Variant in f.products:
				if not product is String or not products.has(product):
					errors.append("Unknown archetype product: " + id)
	if scenario.has("city_layout") and not scenario.city_layout is Dictionary:
		errors.append("Invalid optional fixture layout")
	elif scenario.has("city_layout"):
		for id: String in facilities:
			var point: Variant = scenario.city_layout.get(id)
			if not point is Array or point.size() != 2:
				errors.append("Missing city position: " + id)
			else:
				for coordinate: Variant in point:
					if not (coordinate is int or coordinate is float) or float(coordinate) != floor(float(coordinate)):
						errors.append("Invalid city coordinate: " + id)
	if companies.is_empty() or products.is_empty() or scenario.get("starting_years", []).is_empty():
		errors.append("Catalog requires companies, products and starting years")
	var expanded: Dictionary = facilities.duplicate()
	_index(scenario.get("expanded_facilities", []), expanded)
	for id: String in expanded:
		var f: Dictionary = expanded[id]
		if not companies.has(str(f.get("company", ""))) or not facility_types.has(str(f.get("type", ""))) or not supports_product(str(f.get("type", "")), str(f.get("product", ""))):
			errors.append("Invalid expanded facility: " + id)
		elif not supports_product(str(f.type), str(f.get("product", ""))) or int(f.get("capacity", 0)) <= 0 or int(f.get("quality", 0)) < 1 or int(f.get("quality", 0)) > 100 or (facility_types.get(str(f.get("type", "")), {}).get("behavior") != "research" and int(f.get("price", 0)) <= 0):
			errors.append("Invalid expanded facility operation: " + id)
	return errors.is_empty()

func _validate_recipe(id: String, visiting: Array[String]) -> void:
	if id in visiting:
		errors.append("Recipe cycle: " + id)
		return
	if not products.has(id): return
	var next: Array[String] = visiting.duplicate()
	next.append(id)
	for input: String in products[id].get("inputs", {}): _validate_recipe(input, next)

func _index(entries: Array, target: Dictionary) -> void:
	for entry: Variant in entries:
		if not entry is Dictionary or str(entry.get("id", "")).is_empty():
			errors.append("Definition requires an ID")
			continue
		var id: String = str(entry.id)
		if target.has(id):
			errors.append("Duplicate ID: " + id)
		target[id] = entry

func _validate_technology(id: String, visiting: Array[String]) -> void:
	if id in visiting:
		errors.append("Technology cycle: " + id)
		return
	if not technologies.has(id):
		errors.append("Missing technology: " + id)
		return
	var next: Array[String] = visiting.duplicate()
	next.append(id)
	for prerequisite: String in technologies[id].get("prerequisites", []):
		_validate_technology(prerequisite, next)

func technology_public(id: String, year: int) -> bool:
	if not technologies.has(id) or year < int(technologies[id].year):
		return false
	for prerequisite: String in technologies[id].get("prerequisites", []):
		if not technology_public(prerequisite, year):
			return false
	return true

func product_public(product: String, year: int) -> bool:
	return products.has(product) and technology_public(str(products[product].technology), year)

static func _positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value > 0 and value <= 100000000

func supports_product(type_id: String, product: String) -> bool:
	if not facility_types.has(type_id): return false
	var definition: Dictionary = facility_types[type_id]
	return product.is_empty() if definition.behavior == "research" else product in definition.get("products", []) and products.has(product)
