class_name CityGenerator
extends RefCounted

const VERSION: int = 2
const DEFAULTS: Dictionary = {"width": 128, "depth": 96}
const KINDS: Array[String] = ["downtown", "mixed", "residential", "suburban", "commercial", "industrial", "waterfront"]

static func generate(city: CityMap, seed_value: int, settings: Dictionary, facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	for field: String in settings:
		if field not in ["width", "depth", "preset"]: return false
	if settings.get("preset", "procedural") != "procedural": return false
	var w: Variant = settings.get("width", DEFAULTS.width)
	var d: Variant = settings.get("depth", DEFAULTS.depth)
	if not w is int or not d is int or w < 96 or w > 192 or d < 72 or d > 144: return false
	city.width = w
	city.depth = d
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var archetype: String = ["coast", "bay", "estuary", "river_city"][rng.randi_range(0, 3)]
	var orientation: String = ["north", "south", "east", "west"][rng.randi_range(0, 3)]
	var river: Dictionary = {}
	_terrain(city, rng, archetype, orientation, river)
	var centers: Array[Dictionary] = _centers(city, rng)
	var points: Array[Vector2i] = []
	for i: int in range(7):
		var center: Dictionary = centers[i % centers.size()]
		var p: Vector2i = Vector2i(int(center.x), int(center.y))
		if i >= centers.size(): p = _land_near(city, p + Vector2i(rng.randi_range(-20, 20), rng.randi_range(-16, 16)))
		points.append(p)
		city.districts["district_%d" % i] = {"name": ["Central Quarter", "Market Ward", "Garden Ward", "Outer Commons", "Business Quarter", "Works District", "Waterfront Ward"][i], "character": KINDS[i], "purchasing_power": clampi(90 + rng.randi_range(-15, 22) + (12 if i == 0 else 0), 65, 145), "population": 0, "capacity": 0, "average_land_value": 0}
	var port_site: Vector2i = _port_site(city, centers[0])
	if port_site.x < 0:
		printerr("11R no port site: ", city.id)
		return false
	points[6] = port_site
	var inward: Vector2 = Vector2(int(centers[0].x) - port_site.x, int(centers[0].y) - port_site.y).normalized() * 12.0
	points[5] = _land_near(city, port_site + Vector2i(int(inward.x), int(inward.y)))
	city.port = {"id": "port_" + city.id, "x": port_site.x, "y": port_site.y}
	_roads(city, centers, port_site, river, rng)
	if not city.roads_connected():
		printerr("11R roads disconnected: ", city.id, " ", archetype)
		return false
	city.generation = {"version": VERSION, "seed": str(seed_value), "settings": {"width": w, "depth": d}, "preset": "procedural", "archetype": archetype, "orientation": orientation, "centers": centers}
	_parcels(city, centers, points, seed_value)
	if not city.valid_port():
		printerr("11R invalid port: ", city.id, " ", archetype, " ", port_site, " road=", city.is_road(port_site.x, port_site.y), " frontage=", city.touches_road(port_site.x, port_site.y), " water_edge=", city.port_water_reaches_edge(), " parcel=", city.parcels[CityMap.key(port_site.x, port_site.y)])
		return false
	_facilities(city, facilities, catalog, centers, port_site, rng)
	if city.plots.size() != facilities.size():
		printerr("11R facilities missing: ", city.id, " ", city.plots.size(), "/", facilities.size())
		return false
	_ambient(city, catalog, centers, rng, seed_value)
	city.recalculate_population()
	return city.population.total > 0

static func _coast_xy(x: int, y: int, w: int, d: int, side: String) -> Vector2i:
	match side:
		"north": return Vector2i(y, x)
		"south": return Vector2i(d - 1 - y, x)
		"west": return Vector2i(x, y)
		_: return Vector2i(w - 1 - x, y)

static func _terrain(city: CityMap, rng: RandomNumberGenerator, kind: String, side: String, river: Dictionary) -> void:
	var along: int = city.width if side in ["north", "south"] else city.depth
	var span: int = city.depth if side in ["north", "south"] else city.width
	var phase: float = rng.randf_range(-3.0, 3.0)
	var bay_at: float = rng.randf_range(0.32, 0.68) * along
	var cape_at: float = rng.randf_range(0.15, 0.85) * along
	var river_at: float = rng.randf_range(0.38, 0.62) * along
	var river_phase: float = rng.randf_range(-2.0, 2.0)
	var river_width: int = rng.randi_range(2, 4)
	for y: int in range(city.depth):
		for x: int in range(city.width):
			var p: Vector2i = _coast_xy(x, y, city.width, city.depth, side)
			var shore: float = span * 0.16 + sin(p.y * 0.075 + phase) * span * 0.035 + sin(p.y * 0.17 + phase * 1.7) * span * 0.018
			if kind in ["bay", "estuary"]: shore += exp(-pow((p.y - bay_at) / (along * 0.16), 2.0)) * span * 0.16
			if kind == "bay": shore -= exp(-pow((p.y - cape_at) / (along * 0.13), 2.0)) * span * 0.10
			var sea: bool = kind != "river_city" and p.x < clampf(shore, span * 0.06, span * 0.39)
			var channel: bool = false
			if kind == "estuary":
				var path_v: float = river_at + sin(p.x * 0.065 + river_phase) * along * 0.065 + sin(p.x * 0.14 + river_phase) * along * 0.015
				channel = absf(p.y - path_v) <= river_width * 0.5
			elif kind == "river_city":
				var path_y: float = city.depth * 0.5 + sin(x * 0.055 + river_phase) * city.depth * 0.085 + sin(x * 0.135 + phase) * city.depth * 0.02
				channel = absf(y - path_y) <= river_width * 0.5
			if sea or channel:
				city.add_water(x, y)
				if channel: river[CityMap.key(x, y)] = true

static func _land_near(city: CityMap, target: Vector2i) -> Vector2i:
	for radius: int in range(maxi(city.width, city.depth)):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var p: Vector2i = target + Vector2i(dx, dy)
				if p.x >= 3 and p.y >= 3 and p.x < city.width - 3 and p.y < city.depth - 3 and not city.is_water(p.x, p.y): return p
	return Vector2i(-1, -1)

static func _centers(city: CityMap, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = clampi(city.width * city.depth / 3000, 3, 6)
	for i: int in range(count):
		var chosen: Vector2i = Vector2i(-1, -1)
		for attempt: int in range(100):
			var p: Vector2i = _land_near(city, Vector2i(rng.randi_range(12, city.width - 13), rng.randi_range(12, city.depth - 13)))
			var apart: bool = true
			for center: Dictionary in result:
				if absi(p.x - int(center.x)) + absi(p.y - int(center.y)) < mini(city.width, city.depth) * 0.20: apart = false
			if apart:
				chosen = p
				break
		if chosen.x < 0: chosen = _land_near(city, Vector2i(12 + i * 17, 12 + i * 13))
		result.append({"x": chosen.x, "y": chosen.y, "kind": "primary" if i == 0 else ("industrial" if i == count - 1 else "secondary")})
	return result

static func _port_site(city: CityMap, primary: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for y: int in range(2, city.depth - 2):
		for x: int in range(2, city.width - 2):
			if city.is_water(x, y) or not city.touches_water(x, y): continue
			var score: int = absi(x - int(primary.x)) + absi(y - int(primary.y))
			if score < 5: continue
			if score < best_score:
				best_score = score
				best = Vector2i(x, y)
	return best

static func _route(city: CityMap, grid: AStarGrid2D, from: Vector2i, to: Vector2i, river: Dictionary) -> void:
	for p: Vector2i in grid.get_id_path(from, to): city.add_road(p.x, p.y, "major", river.has(CityMap.key(p.x, p.y)))

static func _roads(city: CityMap, centers: Array[Dictionary], port_site: Vector2i, river: Dictionary, rng: RandomNumberGenerator) -> void:
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, city.width, city.depth)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	grid.set_point_solid(port_site)
	for y: int in range(city.depth):
		for x: int in range(city.width):
			if city.is_water(x, y):
				if river.has(CityMap.key(x, y)): grid.set_point_weight_scale(Vector2i(x, y), 12.0)
				else: grid.set_point_solid(Vector2i(x, y))
	var primary: Vector2i = Vector2i(int(centers[0].x), int(centers[0].y))
	for i: int in range(1, centers.size()): _route(city, grid, primary, Vector2i(int(centers[i].x), int(centers[i].y)), river)
	var port_neighbor: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1000000
	for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var p: Vector2i = port_site + delta
		if p.x < 0 or p.y < 0 or p.x >= city.width or p.y >= city.depth or city.is_water(p.x, p.y): continue
		var distance: int = absi(p.x - primary.x) + absi(p.y - primary.y)
		if distance < best_distance:
			best_distance = distance
			port_neighbor = p
	if port_neighbor.x >= 0: _route(city, grid, primary, port_neighbor, river)
	for target: Vector2i in [Vector2i(city.width - 3, primary.y), Vector2i(primary.x, city.depth - 3)]: _route(city, grid, primary, _land_near(city, target), river)
	# Every local branch starts on the existing network and stops at water.
	for center: Dictionary in centers:
		var anchor: Vector2i = Vector2i(int(center.x), int(center.y))
		var nearby: Array[Vector2i] = []
		for road: String in city.roads:
			var parts: PackedStringArray = road.split(",")
			var p: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
			if absi(p.x - anchor.x) + absi(p.y - anchor.y) < 22 and not city.is_water(p.x, p.y): nearby.append(p)
		for branch: int in range(120 if center.kind == "primary" else 75):
			if nearby.is_empty(): break
			var start: Vector2i = nearby[rng.randi_range(0, nearby.size() - 1)]
			var direction: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]
			for step: int in range(1, rng.randi_range(5, 15) + 1):
				var p: Vector2i = start + direction * step
				if p.x < 2 or p.y < 2 or p.x >= city.width - 2 or p.y >= city.depth - 2 or city.is_water(p.x, p.y) or p == port_site: break
				city.add_road(p.x, p.y)
				nearby.append(p)

static func _district(x: int, y: int, points: Array[Vector2i], seed_value: int) -> int:
	var best: int = 0
	var score: float = INF
	for i: int in range(points.size()):
		var p: Vector2i = points[i]
		var dx: float = x + sin(y * 0.09 + i * 1.7 + seed_value * 0.01) * 5.0 - p.x
		var dy: float = y + sin(x * 0.08 + i * 2.1) * 4.0 - p.y
		var distance: float = dx * dx + dy * dy
		if distance < score:
			score = distance
			best = i
	return best

static func _density(x: int, y: int, centers: Array[Dictionary], character: String, access: bool, waterfront: bool, seed_value: int) -> float:
	var density: float = 0.0
	for i: int in range(centers.size()):
		var c: Dictionary = centers[i]
		var radius: float = 23.0 if i == 0 else 16.0
		var influence: float = maxf(0.0, 1.0 - Vector2(x - int(c.x), y - int(c.y)).length() / radius)
		density = maxf(density, influence * (1.0 if i == 0 else 0.75))
	density += sin(x * 0.12 + seed_value * 0.001) * sin(y * 0.10 - seed_value * 0.002) * 0.09
	if character == "downtown": density += 0.12
	if character == "industrial": density -= 0.18
	if waterfront: density += 0.08
	if access: density += 0.08
	return clampf(density, 0.0, 1.0)

static func _parcels(city: CityMap, centers: Array[Dictionary], points: Array[Vector2i], seed_value: int) -> void:
	for y: int in range(city.depth):
		for x: int in range(city.width):
			var k: String = CityMap.key(x, y)
			var water: bool = city.is_water(x, y)
			var road: bool = city.is_road(x, y)
			var access: bool = city.touches_road(x, y)
			var waterfront: bool = not water and city.touches_water(x, y)
			var district_id: String = "district_%d" % _district(x, y, points, seed_value)
			var character: String = str(city.districts[district_id].character)
			var density: float = _density(x, y, centers, character, access, waterfront, seed_value)
			var value: int = 0 if water or road else clampi(int(4500 + density * 21000 + (3500 if access else 0) + (4200 if waterfront else 0) + (int(city.districts[district_id].purchasing_power) - 90) * 60), 1000, 49000)
			city.parcels[k] = {"id": "parcel_" + k, "terrain": "water" if water else "land", "district": district_id, "road_access": access, "waterfront": waterfront, "port_eligible": waterfront and access and not road and x > 0 and x < city.width - 1 and y > 0 and y < city.depth - 1, "land_value": value, "zoning": "unrestricted"}

static func _facilities(city: CityMap, facilities: Array[SimFacility], catalog: SimCatalog, centers: Array[Dictionary], port_site: Vector2i, rng: RandomNumberGenerator) -> void:
	var site_cache: Dictionary = {}
	for f: SimFacility in facilities:
		var definition: Dictionary = catalog.facility_types[f.type_id]
		var footprint: String = "%d,%d" % [int(definition.width), int(definition.depth)]
		if not site_cache.has(footprint): site_cache[footprint] = city.valid_sites(int(definition.width), int(definition.depth))
		var candidates: Array[Vector2i] = site_cache[footprint]
		if candidates.is_empty(): return
		var index: int = int(f.company_id.hash() & 0x7fffffff) % centers.size()
		var target: Vector2i = Vector2i(int(centers[index].x), int(centers[index].y))
		if str(definition.behavior) in ["production", "storage"]: target = Vector2i(int(lerpf(target.x, port_site.x, 0.35)), int(lerpf(target.y, port_site.y, 0.35)))
		var best: Vector2i = candidates[0]
		var best_score: float = INF
		for attempt: int in range(mini(400, candidates.size())):
			var p: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			if not city.placement_error(p.x, p.y, int(definition.width), int(definition.depth)).is_empty(): continue
			var separation: int = 1000
			for plot: Dictionary in city.plots.values(): separation = mini(separation, absi(p.x - int(plot.x)) + absi(p.y - int(plot.y)))
			var score: float = Vector2(p - target).length() + maxf(0, 10 - separation) * 4.0
			if score < best_score:
				best_score = score
				best = p
		if best_score == INF:
			for p: Vector2i in candidates:
				if city.placement_error(p.x, p.y, int(definition.width), int(definition.depth)).is_empty():
					best = p
					best_score = 0.0
					break
		if best_score == INF: return
		city.occupy(f, best.x, best.y, definition)

static func _ambient(city: CityMap, catalog: SimCatalog, centers: Array[Dictionary], rng: RandomNumberGenerator, seed_value: int) -> void:
	for y: int in range(2, city.depth - 3):
		for x: int in range(2, city.width - 3):
			var parcel: Dictionary = city.parcels[CityMap.key(x, y)]
			if parcel.terrain == "water" or not parcel.road_access: continue
			var character: String = str(city.districts[parcel.district].character)
			var density: float = _density(x, y, centers, character, true, bool(parcel.waterfront), seed_value)
			var chance: float = 0.18 + density * 0.80
			if character == "industrial": chance *= 0.32
			if rng.randf() > chance: continue
			var kind: String = "house"
			var roll: float = rng.randf()
			if density > 0.65: kind = "block" if roll < 0.42 else ("apartments" if roll < 0.75 else "office")
			elif density > 0.32: kind = "apartments" if roll < 0.42 else ("house" if roll < 0.73 else ("commercial" if roll < 0.88 else "office"))
			elif roll > 0.85: kind = "commercial"
			if character == "commercial" and kind == "house": kind = "commercial"
			var definition: Dictionary = catalog.property_types[kind]
			if not city.placement_error(x, y, int(definition.width), int(definition.depth)).is_empty(): continue
			var id: String = "ambient_%03d_%03d" % [x, y]
			var capacity: int = int(definition.residential_capacity)
			city.ambient[id] = {"id": id, "kind": kind, "x": x, "y": y, "width": int(definition.width), "depth": int(definition.depth), "district": parcel.district, "capacity": capacity, "population": capacity * rng.randi_range(80, 95) / 100, "height": int(definition.height), "tone": rng.randi_range(0, 4), "roof": rng.randi_range(0, 1), "orientation": rng.randi_range(0, 1), "owner": ""}
			city.register_footprint(id, x, y, int(definition.width), int(definition.depth))
