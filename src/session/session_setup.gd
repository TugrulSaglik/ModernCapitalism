class_name SessionSetup
extends RefCounted

const CAPITAL: Array[int] = [10000000, 20000000, 50000000, 100000000]

static func defaults() -> Dictionary:
	return {"company_name":"Player Electronics", "era":2022, "difficulty":"standard", "seed":42, "city_profiles":[], "starting_capital":20000000}

static func tutorial() -> Dictionary:
	return {"company_name":"Learning Company", "era":2022, "difficulty":"standard", "seed":12022, "city_profiles":["istanbul", "sydney", "vancouver"], "starting_capital":100000000}

static func error(config: Dictionary, profiles: Dictionary) -> String:
	if not SaveStore.shape(config, defaults()): return "Incomplete setup."
	if config.company_name.strip_edges().is_empty() or config.company_name.length() > 48 or "\n" in config.company_name or "\r" in config.company_name: return "Enter a company name of 1–48 characters."
	if config.era not in [2012, 2022] or config.difficulty not in StrategicAI.DIFFICULTY_IDS: return "Invalid era or difficulty."
	if config.seed < 0 or config.seed > 2147483647 or config.starting_capital not in CAPITAL: return "Invalid seed or starting capital."
	if config.city_profiles.size() not in [0, 3]: return "Choose exactly three cities."
	var seen: Dictionary = {}
	for id: Variant in config.city_profiles:
		if not id is String or not profiles.has(id) or seen.has(id): return "Choose three unique city profiles."
		seen[id] = true
	return ""
