class_name CityGenerator
extends RefCounted

# Generator version is metadata; saves store the result, never regenerate it.
const VERSION: int = 1
const DEFAULTS: Dictionary = {"width": 48, "depth": 36}

static func generate(city: CityMap, seed_value: int, settings: Dictionary, facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	for field: String in settings:
		if field not in ["width", "depth", "preset"]: return false
	if settings.get("preset", "procedural") != "procedural": return false
	var w: Variant = settings.get("width", DEFAULTS.width)
	var d: Variant = settings.get("depth", DEFAULTS.depth)
	if not w is int or not d is int or w < 40 or w > 96 or d < 30 or d > 72: return false
	city.width = w
	city.depth = d
	city.generation = {"version": VERSION, "seed": str(seed_value), "settings": {"width": w, "depth": d}, "preset": "procedural"}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	# A bounded random walk creates a connected mainland and continuous eastern sea.
	var coast: Array[int] = []
	var edge: int = int(w * 0.80) + rng.randi_range(-2, 2)
	for y: int in range(d):
		if y % 3 == 0: edge = clampi(edge + rng.randi_range(-2, 2), int(w * 0.68), int(w * 0.88))
		coast.append(edge)
		for x: int in range(edge, w): city.water.append(CityMap.key(x, y))
	var rows: Array[int] = []
	var row: int = rng.randi_range(4, 6)
	while row < d - 2:
		rows.append(row)
		row += rng.randi_range(7, 9)
	var columns: Array[int] = [3]
	var col: int = 3 + rng.randi_range(7, 9)
	while col < int(coast.min()) - 2:
		columns.append(col)
		col += rng.randi_range(7, 9)
	for y: int in range(1, d - 1):
		for x: int in range(2, coast[y]):
			if y in rows or x in columns:
				var k: String = CityMap.key(x, y)
				city.roads.append(k)
				city.road_classes[k] = "major" if x == columns[1] or y == rows[rows.size() / 2] else "local"
	city.districts = {
		"west": {"name": "West Gardens", "character": "residential", "purchasing_power": 90, "population": 0, "capacity": 0, "average_land_value": 0},
		"center": {"name": "Central Quarter", "character": "mixed", "purchasing_power": 110, "population": 0, "capacity": 0, "average_land_value": 0},
		"coast": {"name": "Harbor District", "character": "waterfront", "purchasing_power": 100, "population": 0, "capacity": 0, "average_land_value": 0}}
	for y: int in range(d):
		for x: int in range(w):
			var k: String = CityMap.key(x, y)
			var water: bool = k in city.water
			var access: bool = city.touches_road(x, y)
			var waterfront: bool = not water and city.touches_water(x, y)
			var district: String = "west" if x < w * 0.27 else ("center" if x < w * 0.57 else "coast")
			var central: int = maxi(0, 16 - absi(x - int(w * 0.42)) - absi(y - d / 2))
			city.parcels[k] = {"id": "parcel_" + k, "terrain": "water" if water else "land", "district": district,
				"road_access": access, "waterfront": waterfront, "port_eligible": waterfront and access and k not in city.roads and y > 0 and y < d - 1,
				"land_value": 0 if water or k in city.roads else 5000 + central * 900 + (6000 if access else 0) + (8000 if waterfront else 0),
				"zoning": "unrestricted"}
	# Reserve the economic sites first. Max-min separation distributes competitors.
	for f: SimFacility in facilities:
		var definition: Dictionary = catalog.facility_types[f.type_id]
		var candidates: Array[Vector2i] = city.valid_sites(int(definition.width), int(definition.depth))
		if candidates.is_empty(): return false
		var best: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var score: int = -1
		for attempt: int in range(40):
			var p: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			var separation: int = 1000
			for placed: Dictionary in city.plots.values():
				separation = mini(separation, absi(p.x - int(placed.x)) + absi(p.y - int(placed.y)))
			if separation > score:
				score = separation
				best = p
		city.occupy(f, best.x, best.y, definition)
	if not city.establish_port(): return false
	# Cheap properties, not companies/facilities: capacity and appearance only.
	for y: int in range(1, d - 2):
		for x: int in range(1, w - 2):
			if rng.randi_range(0, 99) > 66: continue
			var density: float = 1.0 - Vector2((x - w * 0.42) / (w * 0.5), (y - d * 0.5) / (d * 0.6)).length()
			var kind: String = "house"
			if density > 0.55: kind = "block" if rng.randi_range(0, 2) == 0 else "apartments"
			elif density > 0.25: kind = "apartments" if rng.randi_range(0, 2) == 0 else "house"
			if rng.randi_range(0, 5) == 0: kind = "office" if density > 0.4 else "commercial"
			var definition: Dictionary = catalog.property_types[kind]
			if not city.placement_error(x, y, definition.width, definition.depth).is_empty(): continue
			# Preserve occasional large vacant frontages for later player construction.
			if (x / 7 + y / 7) % 4 == 0: continue
			var id: String = "ambient_%03d_%03d" % [x, y]
			var capacity: int = int(definition.residential_capacity)
			city.ambient[id] = {"id": id, "kind": kind, "x": x, "y": y, "width": int(definition.width), "depth": int(definition.depth),
				"district": city.parcels[CityMap.key(x, y)].district, "capacity": capacity, "population": capacity * rng.randi_range(80, 95) / 100,
				"height": int(definition.height), "tone": rng.randi_range(0, 4), "roof": rng.randi_range(0, 1), "orientation": rng.randi_range(0, 1), "owner": ""}
	city.recalculate_population()
	return true
