class_name CityGenerator
extends RefCounted

const VERSION: int = 3
const STREET_SPACING: int = 8
const STREET_OFFSET: int = 4
# Wall-clock diagnostics are deliberately excluded from authoritative state.
static var last_timings: Dictionary = {}
const KINDS: Array[String] = ["downtown", "mixed", "residential", "suburban", "commercial", "industrial", "waterfront"]

static func generate(city: CityMap, seed_value: int, settings: Dictionary, facilities: Array[SimFacility], catalog: SimCatalog) -> bool:
	for field: String in settings:
		if field not in ["width", "depth", "preset", "profile_id", "archetype"]: return false
	if settings.get("preset", "procedural") != "procedural": return false
	var started: int = Time.get_ticks_msec()
	if settings.has("profile_id"):
		if not catalog.city_profiles.has(str(settings.profile_id)): return false
		city.profile = catalog.city_profiles[str(settings.profile_id)].duplicate(true)
	if city.profile.is_empty(): city.profile = CityProfiles.select(catalog.city_profiles, seed_value)[0]
	city.display_name = str(city.profile.display_name)
	var dimensions: Vector2i = CityProfiles.dimensions(city.profile, seed_value)
	var w: Variant = settings.get("width", dimensions.x)
	var d: Variant = settings.get("depth", dimensions.y)
	if not w is int or not d is int or w < 192 or w > 408 or d < 144 or d > 304: return false
	city.width = w
	city.depth = d
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var archetype: String = str(city.profile.terrain_bias) if rng.randf() < 0.65 else ["coast", "bay", "estuary", "river_city"][rng.randi_range(0, 3)]
	archetype = str(settings.get("archetype", archetype))
	if archetype not in ["coast", "bay", "estuary", "river_city"]: return false
	var orientation: String = ["north", "south", "east", "west"][rng.randi_range(0, 3)]
	var river: Dictionary = {}
	_terrain(city, rng, archetype, orientation, river)
	var centers: Array[Dictionary] = _centers(city, rng)
	var points: Array[Vector2i] = []
	for i: int in range(clampi(centers.size() * 2, 7, 20)):
		var center: Dictionary = centers[i % centers.size()]
		var p: Vector2i = Vector2i(int(center.x), int(center.y))
		if i >= centers.size(): p = _land_near(city, p + Vector2i(rng.randi_range(-20, 20), rng.randi_range(-16, 16)))
		points.append(p)
		city.districts["district_%d" % i] = {"name": ["Central Quarter", "Market Ward", "Garden Ward", "Outer Commons", "Business Quarter", "Works District", "Waterfront Ward"][i % 7] + (" %d" % (i / 7 + 1) if i >= 7 else ""), "character": KINDS[i % 7], "purchasing_power": clampi(90 + rng.randi_range(-15, 22) + (12 if i == 0 else 0), 65, 145), "population": 0, "capacity": 0, "average_land_value": 0}
	var port_site: Vector2i = _port_site(city, centers[0])
	if port_site.x < 0:
		printerr("11R no port site: ", city.id)
		return false
	points[6] = port_site
	var inward: Vector2 = Vector2(int(centers[0].x) - port_site.x, int(centers[0].y) - port_site.y).normalized() * 12.0
	points[5] = _land_near(city, port_site + Vector2i(int(inward.x), int(inward.y)))
	city.port = {"id": "port_" + city.id, "x": port_site.x, "y": port_site.y}
	last_timings = {"terrain_centers_ms": Time.get_ticks_msec() - started}
	var phase_start: int = Time.get_ticks_msec()
	_roads(city, centers, port_site, river, rng)
	last_timings.roads_ms = Time.get_ticks_msec() - phase_start
	if not city.road_structure_valid(): return false
	if not city.roads_connected():
		printerr("11R roads disconnected: ", city.id, " ", archetype)
		return false
	city.generation = {"version": VERSION, "seed": str(seed_value), "settings": {"width": w, "depth": d}, "preset": "procedural", "archetype": archetype, "orientation": orientation, "centers": centers, "street_spacing": STREET_SPACING}
	_parcels(city, centers, points, seed_value)
	if not city.valid_port():
		printerr("11R invalid port: ", city.id, " ", archetype, " ", port_site, " road=", city.is_road(port_site.x, port_site.y), " frontage=", city.touches_road(port_site.x, port_site.y), " water_edge=", city.port_water_reaches_edge(), " parcel=", city.parcels[CityMap.key(port_site.x, port_site.y)])
		return false
	phase_start = Time.get_ticks_msec()
	_facilities(city, facilities, catalog, centers, port_site, rng)
	last_timings.facilities_ms = Time.get_ticks_msec() - phase_start
	if city.plots.size() != facilities.size():
		printerr("11R facilities missing: ", city.id, " ", city.plots.size(), "/", facilities.size())
		return false
	phase_start = Time.get_ticks_msec()
	_ambient(city, catalog, centers, rng, seed_value)
	last_timings.properties_ms = Time.get_ticks_msec() - phase_start
	city.recalculate_population()
	last_timings.total_ms = Time.get_ticks_msec() - started
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
				var path_v: float = river_at + sin(p.x * 0.065 * 128.0 / span + river_phase) * along * 0.065 + sin(p.x * 0.14 * 128.0 / span + river_phase) * along * 0.015
				channel = absf(p.y - path_v) <= river_width * 0.5
			elif kind == "river_city":
				var path_y: float = city.depth * 0.5 + sin(x * 0.055 * 128.0 / city.width + river_phase) * city.depth * 0.085 + sin(x * 0.135 * 128.0 / city.width + phase) * city.depth * 0.02
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
	var count: int = clampi(city.width * city.depth / 10000 + 2, 4, 12)
	for i: int in range(count):
		var chosen: Vector2i = Vector2i(-1, -1)
		for attempt: int in range(100):
			var p: Vector2i = Vector2i(rng.randi_range(2, (city.width - 20) / 8) * 8 + 4, rng.randi_range(2, (city.depth - 20) / 8) * 8 + 4)
			if city.is_water(p.x, p.y): continue
			var apart: bool = true
			for center: Dictionary in result:
				if absi(p.x - int(center.x)) + absi(p.y - int(center.y)) < mini(city.width, city.depth) * 0.20: apart = false
			if apart:
				chosen = p
				break
		if chosen.x < 0: chosen = _land_near(city, Vector2i(12 + i * 17, 12 + i * 13))
		result.append({"x": chosen.x, "y": chosen.y, "kind": "primary" if i == 0 else ("industrial" if i == count - 1 else "secondary"), "radius": (20.0 + float(city.profile.compactness) * 8.0 + float(city.profile.reference_population_2025) / 4000000.0) * (1.0 if i == 0 else 0.72)})
	return result

static func _port_site(city: CityMap, primary: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for y: int in range(2, city.depth - 2):
		for x: int in range(2, city.width - 2):
			if city.is_water(x, y) or not city.touches_water(x, y): continue
			if _port_anchor(city, Vector2i(x, y)).x < 0: continue
			var score: int = absi(x - int(primary.x)) + absi(y - int(primary.y))
			if score < 5: continue
			if score < best_score:
				best_score = score
				best = Vector2i(x, y)
	return best

# Ports sit on a planning corridor, with a short straight land-only access spur.
static func _port_anchor(city: CityMap, p: Vector2i) -> Vector2i:
	for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if delta.x != 0 and p.y % STREET_SPACING != STREET_OFFSET: continue
		if delta.y != 0 and p.x % STREET_SPACING != STREET_OFFSET: continue
		for step: int in range(1, STREET_SPACING + 1):
			var q: Vector2i = p + delta * step
			if q.x < 4 or q.y < 4 or q.x >= city.width - 4 or q.y >= city.depth - 4 or city.is_water(q.x, q.y): break
			if q.x % STREET_SPACING == STREET_OFFSET and q.y % STREET_SPACING == STREET_OFFSET: return q
	return Vector2i(-1, -1)

static func _segment(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var delta: Vector2i = Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	for i: int in range(absi(b.x - a.x) + absi(b.y - a.y) + 1): result.append(a + delta * i)
	return result

static func _draw_segment(city: CityMap, a: Vector2i, b: Vector2i, road_class: String) -> void:
	for p: Vector2i in _segment(a, b):
		# All hierarchy levels use identical one-cell centerlines.
		city.add_road(p.x, p.y, road_class, city.is_water(p.x, p.y))

static func _draw_path(city: CityMap, graph: AStar2D, a: int, b: int) -> void:
	var path: PackedInt64Array = graph.get_id_path(a, b)
	for i: int in range(1, path.size()):
		_draw_segment(city, Vector2i(graph.get_point_position(path[i - 1])), Vector2i(graph.get_point_position(path[i])), "major")

static func _roads(city: CityMap, centers: Array[Dictionary], port_site: Vector2i, river: Dictionary, rng: RandomNumberGenerator) -> void:
	# A coarse planning graph guarantees eight cells between parallel corridors.
	# Edges sample actual terrain; only the arterial pass may cross river water.
	var graph: AStar2D = AStar2D.new()
	var nodes: Dictionary = {}
	var land_edges: Dictionary = {}
	for y: int in range(4, city.depth - 4, STREET_SPACING):
		for x: int in range(4, city.width - 4, STREET_SPACING):
			if city.is_water(x, y) or Vector2i(x, y) == port_site: continue
			var node: int = y * city.width + x
			nodes[Vector2i(x, y)] = node
			graph.add_point(node, Vector2(x, y))
	for p: Vector2i in nodes:
		for delta: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var q: Vector2i = p + delta * STREET_SPACING
			if not nodes.has(q): continue
			var valid: bool = true
			var wet: bool = false
			for cell: Vector2i in _segment(p, q):
				if cell == port_site or (city.is_water(cell.x, cell.y) and not river.has(CityMap.key(cell.x, cell.y))): valid = false
				if city.is_water(cell.x, cell.y): wet = true
			if not valid: continue
			graph.connect_points(nodes[p], nodes[q])
			if wet:
				graph.set_point_weight_scale(nodes[q], 4.0)
			else:
				land_edges[Vector2i(nodes[p], nodes[q])] = true
				land_edges[Vector2i(nodes[q], nodes[p])] = true
	var anchors: Array[int] = []
	for center: Dictionary in centers:
		var node: int = graph.get_closest_point(Vector2(center.x, center.y))
		var p: Vector2i = Vector2i(graph.get_point_position(node))
		center.x = p.x
		center.y = p.y
		anchors.append(node)
	anchors.append(nodes[_port_anchor(city, port_site)])
	# Regional entrances, plus the center/industrial/port graph, share a sparse MST.
	anchors.append(graph.get_closest_point(Vector2(city.width - 8, city.depth / 2)))
	anchors.append(graph.get_closest_point(Vector2(city.width / 2, city.depth - 8)))
	var connected: Array[int] = [anchors[0]]
	var remaining: Array[int] = anchors.slice(1)
	while not remaining.is_empty():
		var best_a: int = connected[0]
		var best_b: int = remaining[0]
		var distance: float = INF
		for a: int in connected:
			for b: int in remaining:
				var candidate: float = graph.get_point_position(a).distance_squared_to(graph.get_point_position(b))
				if candidate < distance:
					distance = candidate
					best_a = a
					best_b = b
		_draw_path(city, graph, best_a, best_b)
		connected.append(best_b)
		remaining.erase(best_b)
	for i: int in range(2): _draw_path(city, graph, anchors[i], anchors[(i + 2) % centers.size()])
	var port_anchor: Vector2i = _port_anchor(city, port_site)
	var direction: Vector2i = Vector2i(signi(port_site.x - port_anchor.x), signi(port_site.y - port_anchor.y))
	_draw_segment(city, port_anchor, port_site - direction, "major")
	# Connected neighborhood grids expand in round-robin order. Outer rings omit
	# alternate cross streets: longer suburban blocks, with occasional dead ends.
	var queues: Array[Array] = []
	var visited: Array[Dictionary] = []
	var cursors: Array[int] = []
	var radii: Array[float] = []
	for i: int in range(centers.size()):
		queues.append([anchors[i]])
		visited.append({anchors[i]: true})
		cursors.append(0)
		radii.append(sqrt(city.width * city.depth * 0.28 / (centers.size() * PI)) * rng.randf_range(0.92, 1.12))
	# Secondary axes connect the planned neighborhood blocks before local infill.
	for i: int in range(centers.size()):
		var origin: Vector2i = Vector2i(graph.get_point_position(anchors[i]))
		for direction_value: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var previous: Vector2i = origin
			for step: int in range(1, int(radii[i] / STREET_SPACING) + 1):
				var next: Vector2i = origin + direction_value * step * STREET_SPACING
				if not nodes.has(next) or not land_edges.has(Vector2i(nodes[previous], nodes[next])): break
				_draw_segment(city, previous, next, "secondary")
				previous = next
	var budget: int = int((city.width * city.depth - city.water.size()) * 0.085)
	var pending: bool = true
	while pending and city.roads.size() < budget:
		pending = false
		for i: int in range(centers.size()):
			if cursors[i] >= queues[i].size(): continue
			pending = true
			var node: int = queues[i][cursors[i]]
			cursors[i] += 1
			var p: Vector2i = Vector2i(graph.get_point_position(node))
			for next: int in graph.get_point_connections(node):
				if not land_edges.has(Vector2i(node, next)): continue
				var q: Vector2i = Vector2i(graph.get_point_position(next))
				var distance: float = Vector2(q).distance_to(graph.get_point_position(anchors[i]))
				if distance > radii[i]: continue
				if distance > radii[i] * 0.65 and p.x != q.x and (p.y - 4) % 16 != 0: continue
				if city.roads.size() + STREET_SPACING > budget: break
				_draw_segment(city, p, q, "local")
				if not visited[i].has(next):
					visited[i][next] = true
					queues[i].append(next)

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
		var radius: float = float(c.get("radius", 24.0))
		var influence: float = maxf(0.0, 1.0 - Vector2(x - int(c.x), y - int(c.y)).length() / radius)
		density = maxf(density, influence * (1.0 if i == 0 else 0.85))
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
	var candidates: Array[Dictionary] = []
	for p: Vector2i in city.site_candidates(2, 2):
		var parcel: Dictionary = city.parcels[CityMap.key(p.x, p.y)]
		var character: String = str(city.districts[parcel.district].character)
		var density: float = _density(p.x, p.y, centers, character, true, bool(parcel.waterfront), seed_value)
		if character == "industrial" and rng.randf() < 0.85: continue
		# Coherent weighted ordering concentrates development, while leaving fringe
		# and industrial frontage vacant. Population, not a per-cell coin, stops it.
		var score: float = density + rng.randf_range(-0.12, 0.12)
		candidates.append({"p": p, "density": density, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var target: int = int(city.profile.reference_population_2025) / CityProfiles.RESIDENTS_PER_UNIT
	var residents: int = 0
	var jobs: int = 0
	var compactness: float = float(city.profile.compactness)
	for candidate: Dictionary in candidates:
		if residents >= target and jobs >= target / 2: break
		var p: Vector2i = candidate.p
		var density: float = float(candidate.density)
		var kind: String = "house"
		var roll: float = rng.randf()
		if residents >= target or (jobs < target / 2 and rng.randf() < 0.22):
			kind = "office" if density > 0.4 else "commercial"
		elif density > 0.68 and roll < compactness * 0.48: kind = "block"
		elif density > 0.42 and roll < compactness * 0.70: kind = "apartments"
		var definition: Dictionary = catalog.property_types[kind]
		if not city.placement_error(p.x, p.y, int(definition.width), int(definition.depth)).is_empty(): continue
		var id: String = "ambient_%03d_%03d" % [p.x, p.y]
		var capacity: int = int(definition.residential_capacity)
		var population: int = capacity * rng.randi_range(80, 95) / 100
		var parcel: Dictionary = city.parcels[CityMap.key(p.x, p.y)]
		city.ambient[id] = {"id": id, "kind": kind, "x": p.x, "y": p.y, "width": int(definition.width), "depth": int(definition.depth), "district": parcel.district, "capacity": capacity, "population": population, "height": int(definition.height), "tone": rng.randi_range(0, 4), "roof": rng.randi_range(0, 1), "orientation": rng.randi_range(0, 1), "owner": ""}
		city.register_footprint(id, p.x, p.y, int(definition.width), int(definition.depth))
		residents += population
		jobs += int(definition.job_capacity)
