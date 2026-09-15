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
