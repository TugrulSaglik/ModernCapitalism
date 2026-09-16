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

func initialize(facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	for y: int in range(depth):
		for x: int in range(width):
			if y in [6, 13, 20] or x in [1, 30]:
				roads.append(key(x, y))
	var layout: Dictionary = catalog.scenario.city_layout
	for f: SimFacility in facilities:
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
	if x < 0 or y < 0 or x + w > width or y + d > depth:
		return "Footprint is outside city bounds."
	var access: bool = false
	for cy: int in range(y, y + d):
		for cx: int in range(x, x + w):
			if key(cx, cy) in roads:
				return "Road cells cannot be built on."
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if key(cx + offset.x, cy + offset.y) in roads:
					access = true
	for p: Dictionary in plots.values():
		if x < int(p.x) + int(p.width) and x + w > int(p.x) and y < int(p.y) + int(p.depth) and y + d > int(p.y):
			return "Footprint overlaps an existing facility."
	return "" if access else "Footprint must touch a road."

func occupy(f: SimFacility, x: int, y: int, definition: Dictionary) -> void:
	plots[f.id] = {"x": x, "y": y, "width": int(definition.width), "depth": int(definition.depth), "owner": f.company_id}

func snapshot() -> Dictionary:
	return {"id": id, "name": display_name, "width": width, "depth": depth,
		"terrain": "grass", "roads": roads.duplicate(), "plots": plots.duplicate(true), "next_facility": next_facility}

# Validate against the immutable map foundation, then reconstruct occupancy.
func restore(state: Dictionary, facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	if not _fields_match(state, snapshot()) or state.id != id or state.name != display_name or state.width != width or state.depth != depth or state.terrain != "grass" or state.roads != roads or state.next_facility < 1 or state.next_facility > 1000000 or state.plots.size() != facilities.size():
		return false
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

static func _fields_match(value: Variant, template: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for field: String in template:
		if not value.has(field) or typeof(value[field]) != typeof(template[field]):
			return false
	return true
