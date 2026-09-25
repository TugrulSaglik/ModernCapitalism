class_name CityProfiles
extends RefCounted

const PATH: String = "res://data/city_profiles.json"
const RESIDENTS_PER_UNIT: int = 1000

static func valid(p: Variant) -> bool:
	if not p is Dictionary: return false
	for field: String in ["id", "display_name", "country", "population_source", "region"]:
		if not p.get(field) is String or str(p[field]).is_empty(): return false
	for field: String in ["reference_population_2025", "population_year", "latitude", "longitude", "compactness", "aspect_bias"]:
		if not (p.get(field) is int or p.get(field) is float) or not is_finite(float(p[field])): return false
	return p.reference_population_2025 > 0 and p.reference_population_2025 == floor(p.reference_population_2025) and p.population_year == 2025 and absf(p.latitude) <= 90 and absf(p.longitude) <= 180 and p.compactness >= 0.2 and p.compactness <= 1.0 and p.aspect_bias >= 0.8 and p.aspect_bias <= 1.2 and p.get("terrain_bias") in ["coast", "bay", "estuary", "river_city"]

static func select(pool: Dictionary, seed_value: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Dictionary] = []
	# Disjoint strata guarantee diversity and at most one 25M+ city.
	for bounds: Vector2i in [Vector2i(15000000, 100000000), Vector2i(7000000, 15000000), Vector2i(1000000, 7000000)]:
		var candidates: Array[String] = []
		for id: String in pool:
			var pop: int = int(pool[id].reference_population_2025)
			if pop >= bounds.x and pop < bounds.y: candidates.append(id)
		candidates.sort()
		if candidates.is_empty(): return []
		result.append(pool[candidates[rng.randi_range(0, candidates.size() - 1)]].duplicate(true))
	return result

static func dimensions(profile: Dictionary, seed_value: int) -> Vector2i:
	var pop: int = int(profile.reference_population_2025)
	var base: Vector2i = Vector2i(192, 144)
	if pop >= 25000000: base = Vector2i(384, 288)
	elif pop >= 15000000: base = Vector2i(320, 240)
	elif pop >= 7000000: base = Vector2i(256, 192)
	elif pop >= 3000000: base = Vector2i(224, 168)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var aspect: float = sqrt(float(profile.aspect_bias)) * rng.randf_range(0.96, 1.04)
	var footprint: float = 1.0 + (0.65 - float(profile.compactness)) * 0.10
	return Vector2i(clampi(roundi(base.x * aspect * footprint / 8) * 8, 192, 408), clampi(roundi(base.y / aspect * footprint / 8) * 8, 144, 304))

static func population_text(units: int, legacy: bool = false) -> String:
	return str(units) if legacy else "%.2fM" % (units / 1000.0)
