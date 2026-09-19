class_name SimCatalog
extends RefCounted

var products: Dictionary = {}
var technologies: Dictionary = {}
var facility_types: Dictionary = {}
var scenario: Dictionary = {}
var version: int = 0
var errors: Array[String] = []

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
	version = int(root.get("version", 0))
	_index(root.get("products", []), products)
	_index(root.get("technologies", []), technologies)
	_index(root.get("facility_types", []), facility_types)
	scenario = root.get("scenario", {})
	for id: String in technologies:
		_validate_technology(id, [])
	for id: String in products:
		var p: Dictionary = products[id]
		if not technologies.has(str(p.get("technology", ""))) or int(p.get("reference_price", 0)) <= 0 or int(p.get("conversion_cost", -1)) < 0 or int(p.get("daily_demand", -1)) < 0:
			errors.append("Invalid product: " + id)
		for input: String in p.get("inputs", {}):
			if not products.has(input) or int(p.inputs[input]) <= 0 or input == id:
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
		if not companies.has(str(f.get("company", ""))) or not products.has(str(f.get("product", ""))) or not facility_types.has(str(f.get("type", ""))) or int(f.get("capacity", 0)) <= 0 or int(f.get("price", 0)) <= 0 or int(f.get("quality", 0)) < 1 or int(f.get("quality", 0)) > 100 or str(f.get("city", "")).is_empty():
			errors.append("Invalid facility: " + id)
	for id: String in facility_types:
		var f: Dictionary = facility_types[id]
		if str(f.get("behavior", "")) not in ["production", "retail", "storage"] or int(f.get("overhead", -1)) < 0 or int(f.get("width", 0)) < 1 or int(f.get("depth", 0)) < 1 or int(f.get("cost", 0)) <= 0 or int(f.get("capacity", 0)) <= 0:
			errors.append("Invalid facility type: " + id)
		if not f.get("products") is Array or f.get("products", []).is_empty():
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
	return errors.is_empty()

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

func technology_available(id: String, year: int) -> bool:
	if not technologies.has(id) or year < int(technologies[id].year):
		return false
	for prerequisite: String in technologies[id].get("prerequisites", []):
		if not technology_available(prerequisite, year):
			return false
	return true

func available(product: String, year: int) -> bool:
	return products.has(product) and technology_available(str(products[product].technology), year)
