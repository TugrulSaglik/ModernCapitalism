class_name CityMap
extends RefCounted

# Integer cells and stable facility IDs are authoritative, never scene nodes.
var id: String = "metro"
var display_name: String = "Metro City"
var width: int = 32
var depth: int = 24
var roads: Array[String] = []
var plots: Dictionary = {}
var next_facility: int = 1
var _route_cache: Dictionary = {}
var _cached_roads: Array[String] = []
var water: Array[String] = []
var road_classes: Dictionary = {}
var parcels: Dictionary = {}
var districts: Dictionary = {}
var ambient: Dictionary = {}
var generation: Dictionary = {"version": 0, "seed": "42", "settings": {}, "preset": "legacy"}
var population: Dictionary = {"total": 5000, "capacity": 5000, "purchasing_power": 100}

func initialize(facilities: Array[SimFacility], catalog: SimCatalog, seed_value: int = 42, settings: Dictionary = {}) -> bool:
	roads.clear()
	water.clear()
	plots.clear()
	parcels.clear()
	districts.clear()
	ambient.clear()
	road_classes.clear()
	_route_cache.clear()
	_cached_roads.clear()
	next_facility = 1
	if settings.get("preset", "procedural") != "legacy":
		return CityGenerator.generate(self, seed_value, settings, facilities, catalog)
	width = 32
	depth = 24
	generation = {"version": 0, "seed": str(seed_value), "settings": {}, "preset": "legacy"}
	population = {"total": 5000, "capacity": 5000, "purchasing_power": 100}
	for y: int in range(depth):
		for x: int in range(width):
			if y in [6, 13, 20] or x in [1, 30]:
				roads.append(key(x, y))
	var layout: Dictionary = catalog.scenario.get("city_layout", {})
	for f: SimFacility in facilities:
		if not layout.has(f.id): return false
		var point: Array = layout[f.id]
		var definition: Dictionary = catalog.facility_types[f.type_id]
		if not placement_error(int(point[0]), int(point[1]), int(definition.width), int(definition.depth)).is_empty():
			return false
		occupy(f, int(point[0]), int(point[1]), definition)
	return true

static func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func road_access(id_value: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not plots.has(id_value): return result
	var p: Dictionary = plots[id_value]
	for y: int in range(p.y - 1, p.y + p.depth + 1):
		for x: int in range(p.x - 1, p.x + p.width + 1):
			if (x >= p.x and x < p.x + p.width) or (y >= p.y and y < p.y + p.depth):
				if key(x, y) in roads: result.append(Vector2i(x, y))
	return result

func road_distance(source: String, destination: String) -> int:
	if _cached_roads != roads:
		_route_cache.clear()
		_cached_roads = roads.duplicate()
	var cache_key: String = str([source, destination, plots.get(source), plots.get(destination)])
	if _route_cache.has(cache_key): return int(_route_cache[cache_key])
	var queue: Array[Vector2i] = road_access(source)
	var targets: Array[Vector2i] = road_access(destination)
	var distances: Dictionary = {}
	var road_set: Dictionary = {}
	for road: String in roads: road_set[road] = true
	for point: Vector2i in queue: distances[point] = 0
	var index: int = 0
	while index < queue.size():
		var point: Vector2i = queue[index]
		index += 1
		if point in targets:
			_route_cache[cache_key] = int(distances[point]) + 2
			return int(_route_cache[cache_key])
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + offset
			if not distances.has(next) and road_set.has(key(next.x, next.y)):
				distances[next] = int(distances[point]) + 1
				queue.append(next)
	_route_cache[cache_key] = -1
	return -1

func placement_error(x: int, y: int, w: int, d: int) -> String:
	if w < 1 or d < 1 or x < 0 or y < 0 or x + w > width or y + d > depth:
		return "Footprint is outside city bounds."
	var access: bool = false
	for cy: int in range(y, y + d):
		for cx: int in range(x, x + w):
			if key(cx, cy) in water:
				return "Water cannot support normal facilities."
			if key(cx, cy) in roads:
				return "Road cells cannot be built on."
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if key(cx + offset.x, cy + offset.y) in roads:
					access = true
	for p: Dictionary in plots.values() + ambient.values():
		if x < int(p.x) + int(p.width) and x + w > int(p.x) and y < int(p.y) + int(p.depth) and y + d > int(p.y):
			return "Footprint overlaps an existing property."
	return "" if access else "Footprint must touch a road."

func occupy(f: SimFacility, x: int, y: int, definition: Dictionary) -> void:
	plots[f.id] = {"x": x, "y": y, "width": int(definition.width), "depth": int(definition.depth), "owner": f.company_id}

func snapshot() -> Dictionary:
	return {"id": id, "name": display_name, "width": width, "depth": depth,
		"terrain": "grass", "roads": roads.duplicate(), "plots": plots.duplicate(true), "next_facility": next_facility,
		"water": water.duplicate(), "road_classes": road_classes.duplicate(true), "parcels": parcels.duplicate(true),
		"districts": districts.duplicate(true), "ambient": ambient.duplicate(true), "generation": generation.duplicate(true), "population": population.duplicate(true)}

# Validate against the immutable map foundation, then reconstruct occupancy.
func restore(state: Dictionary, facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	if not _fields_match(state, snapshot()) or state.id != id or state.name != display_name or state.terrain != "grass" or state.next_facility < 1 or state.next_facility > 1000000 or state.plots.size() != facilities.size():
		return false
	if not restore_foundation(state): return false
	plots.clear()
	for f: SimFacility in facilities:
		var p: Variant = state.plots.get(f.id)
		var definition: Dictionary = catalog.facility_types[f.type_id]
		if not _fields_match(p, {"x": 0, "y": 0, "width": 0, "depth": 0, "owner": ""}) or p.owner != f.company_id or p.width != int(definition.width) or p.depth != int(definition.depth):
			return false
		if not placement_error(p.x, p.y, p.width, p.depth).is_empty():
			return false
		occupy(f, p.x, p.y, definition)
	next_facility = state.next_facility
	for f: SimFacility in facilities:
		if f.id.begins_with("built_") and int(f.id.trim_prefix("built_")) >= next_facility:
			return false
	return true

func touches_road(x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if key(x + offset.x, y + offset.y) in roads: return true
	return false

func touches_water(x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if key(x + offset.x, y + offset.y) in water: return true
	return false

func valid_sites(w: int, d: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(depth - d + 1):
		for x: int in range(width - w + 1):
			if placement_error(x, y, w, d).is_empty(): result.append(Vector2i(x, y))
	return result

func parcel_info(x: int, y: int) -> Dictionary:
	var result: Dictionary = parcels.get(key(x, y), {}).duplicate(true)
	result["occupant"] = ""
	for collection: Dictionary in [plots, ambient]:
		for object_id: String in collection:
			var p: Dictionary = collection[object_id]
			if x >= p.x and x < p.x + p.width and y >= p.y and y < p.y + p.depth: result.occupant = object_id
	return result

func recalculate_population() -> void:
	var weighted: int = 0
	population = {"total": 0, "capacity": 0, "purchasing_power": 100}
	for district: Dictionary in districts.values():
		district.population = 0
		district.capacity = 0
	for b: Dictionary in ambient.values():
		population.total += int(b.population)
		population.capacity += int(b.capacity)
		districts[b.district].population += int(b.population)
		districts[b.district].capacity += int(b.capacity)
		weighted += int(b.population) * int(districts[b.district].purchasing_power)
	if population.total > 0: population.purchasing_power = weighted / int(population.total)
	for id_value: String in districts:
		var value: int = 0
		var count: int = 0
		for p: Dictionary in parcels.values():
			if p.district == id_value and p.land_value > 0:
				value += int(p.land_value)
				count += 1
		districts[id_value].average_land_value = value / maxi(1, count)

func roads_connected() -> bool:
	if roads.is_empty(): return false
	var road_set: Dictionary = {}
	for r: String in roads: road_set[r] = true
	var seen: Dictionary = {roads[0]: true}
	var queue: Array[String] = [roads[0]]
	var index: int = 0
	while index < queue.size():
		var parts: PackedStringArray = queue[index].split(",")
		index += 1
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var k: String = key(int(parts[0]) + delta.x, int(parts[1]) + delta.y)
			if road_set.has(k) and not seen.has(k):
				seen[k] = true
				queue.append(k)
	return seen.size() == roads.size()

# Hydrate authoritative data; generation is deliberately not called on load.
func restore_foundation(state: Dictionary) -> bool:
	if not _fields_match(state.generation, {"version": 0, "seed": "", "settings": {}, "preset": ""}) or not str(state.generation.seed).is_valid_int(): return false
	if state.generation.preset == "legacy":
		if state.generation.version != 0 or not state.generation.settings.is_empty() or not state.road_classes.is_empty(): return false
		if state.width != 32 or state.depth != 24 or not state.water.is_empty() or not state.parcels.is_empty() or not state.ambient.is_empty() or not state.districts.is_empty() or state.population != {"total": 5000, "capacity": 5000, "purchasing_power": 100}: return false
		var expected: Array[String] = []
		for y: int in range(24):
			for x: int in range(32):
				if y in [6, 13, 20] or x in [1, 30]: expected.append(key(x, y))
		if state.roads != expected: return false
	else:
		if state.generation.preset != "procedural" or state.generation.version != 1 or state.width < 40 or state.width > 96 or state.depth < 30 or state.depth > 72 or state.parcels.size() != state.width * state.depth: return false
		if state.generation.settings != {"width": state.width, "depth": state.depth}: return false
	width = state.width
	depth = state.depth
	water.clear()
	roads.clear()
	for pair: Array in [[state.water, water], [state.roads, roads]]:
		for value: Variant in pair[0]:
			if not value is String: return false
			var parts: PackedStringArray = value.split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var x: int = int(parts[0])
			var y: int = int(parts[1])
			if x < 0 or y < 0 or x >= width or y >= depth or value != key(x, y) or value in pair[1]: return false
			pair[1].append(value)
	for r: String in roads:
		if r in water: return false
	if not roads_connected(): return false
	generation = state.generation.duplicate(true)
	road_classes = state.road_classes.duplicate(true)
	districts = state.districts.duplicate(true)
	parcels = state.parcels.duplicate(true)
	population = state.population.duplicate(true)
	ambient.clear()
	plots.clear()
	if generation.preset == "legacy": return true
	if water.is_empty() or water.size() >= width * depth / 2 or districts.is_empty() or districts.size() > 32 or road_classes.size() != roads.size(): return false
	for r: String in roads:
		if road_classes.get(r) not in ["major", "local"]: return false
	for district: Variant in districts.values():
		if not _fields_match(district, {"name": "", "character": "", "purchasing_power": 0, "population": 0, "capacity": 0, "average_land_value": 0}) or district.purchasing_power < 50 or district.purchasing_power > 200: return false
	for y: int in range(depth):
		for x: int in range(width):
			var k: String = key(x, y)
			var p: Variant = parcels.get(k)
			if not _fields_match(p, {"id": "", "terrain": "", "district": "", "road_access": false, "waterfront": false, "port_eligible": false, "land_value": 0, "zoning": ""}): return false
			if p.id != "parcel_" + k or not districts.has(p.district) or p.terrain != ("water" if k in water else "land") or p.road_access != touches_road(x, y) or p.waterfront != (k not in water and touches_water(x, y)): return false
			if p.port_eligible != (p.waterfront and p.road_access and k not in roads and y > 0 and y < depth - 1) or p.land_value < 0 or p.land_value > 50000: return false
			if (k in roads or k in water) != (p.land_value == 0): return false
	for object_id: String in state.ambient:
		var b: Variant = state.ambient[object_id]
		if not _fields_match(b, {"id": "", "kind": "", "x": 0, "y": 0, "width": 0, "depth": 0, "district": "", "capacity": 0, "population": 0, "height": 0, "tone": 0, "roof": 0, "orientation": 0, "owner": ""}): return false
		if b.id != object_id or object_id != "ambient_%03d_%03d" % [b.x, b.y] or not CityGenerator.KINDS.has(b.kind) or not b.owner.is_empty(): return false
		var definition: Dictionary = CityGenerator.KINDS[b.kind]
		if b.width != definition.width or b.depth != definition.depth or b.capacity != definition.capacity or b.height != definition.height or b.population < 0 or b.population > b.capacity or b.tone < 0 or b.tone > 4 or b.roof not in [0, 1] or b.orientation not in [0, 1]: return false
		if not placement_error(b.x, b.y, b.width, b.depth).is_empty() or b.district != parcels[key(b.x, b.y)].district: return false
		ambient[object_id] = b.duplicate(true)
	recalculate_population()
	return population == state.population and districts == state.districts

static func _fields_match(value: Variant, template: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for field: String in template:
		if not value.has(field) or typeof(value[field]) != typeof(template[field]):
			return false
	return true
