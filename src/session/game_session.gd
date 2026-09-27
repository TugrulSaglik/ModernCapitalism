class_name GameSession
extends RefCounted

const Simulation = preload("res://src/sim/economy.gd")
const TimeController = preload("res://src/session/game_time.gd")
const Store = preload("res://src/session/save_store.gd")
const Debug = preload("res://src/session/debug_config.gd")
var sim: Economy
var time: GameTime = TimeController.new()
var mode: String = "sandbox"
var player_company: String = "player"
var active_company: String = "player"
var active_city: String = "metro"
var debug_unlocked: bool = false
var message: String = ""
var tutorial: TutorialController = TutorialController.new()

func start_setup(config: Dictionary, game_mode: String = "sandbox") -> bool:
	var catalog: SimCatalog = SimCatalog.new()
	if not catalog.load_data(): return false
	message = SessionSetup.error(config, catalog.city_profiles)
	if not message.is_empty() or game_mode not in ["sandbox", "tutorial"]: return false
	if game_mode == "tutorial" and config != SessionSetup.tutorial():
		message = "Tutorial requires the fixed setup."
		return false
	var cities: Dictionary = {}
	if not config.city_profiles.is_empty(): cities.profiles = config.city_profiles.duplicate()
	if not start(config.era, config.seed, game_mode, cities, config.difficulty):
		message = "Could not initialize the selected cities."
		return false
	var owner: SimCompany = sim.companies[player_company]
	owner.display_name = config.company_name.strip_edges()
	owner.cash = config.starting_capital
	owner.capital = owner.cash
	owner.opening_cash = owner.cash
	sim.equity_market.initialize(sim.companies, sim.clock.date_string())
	time.set_speed(0)
	return true

func setup_summary() -> String:
	var names: PackedStringArray = []
	for map: CityMap in sim.cities.values():
		names.append(map.display_name + " — " + str(map.profile.get("country", "")))
	return "%s • %d • %s • Seed %d\n%s" % [mode.capitalize(), sim.starting_year, sim.difficulty.capitalize(), sim.initial_seed, " / ".join(names)]


func start(era: int = 2022, seed_value: int = 42, game_mode: String = "sandbox", city_settings: Dictionary = {}, difficulty: String = "standard") -> bool:
	if game_mode not in ["sandbox", "tutorial"]:
		return false
	var candidate: Economy = Simulation.new()
	if not candidate.strategic_ai.valid_difficulty(difficulty) or not candidate.initialize(seed_value, era, SaveStore.DATA_PATH, city_settings, difficulty):
		return false
	sim = candidate
	active_company = player_company
	active_city = "metro"
	mode = game_mode
	tutorial = TutorialController.new()
	time = TimeController.new()
	debug_unlocked = false
	message = "Session started. Commands take effect on the next day."
	return true

func submit(command: Dictionary) -> bool:
	var request: Dictionary = command.duplicate(true)
	_refresh_active_company()
	request["company"] = active_company
	if str(request.get("type", "")) in ["build_facility", "buy_land", "acquire_property", "develop_property", "demolish_property", "redevelop_property"]:
		request["city"] = str(request.get("city", active_city))
	message = sim.command_error(request)
	if not message.is_empty():
		return false
	sim.queue_command(request)
	if str(request.type) in ["build_facility", "demolish_facility", "buy_land", "acquire_property", "develop_property", "demolish_property", "redevelop_property", "transfer", "import_goods", "export_goods", "hire_staff", "dismiss_staff", "buy_shares", "sell_shares", "issue_shares", "declare_dividend"]:
		sim.process_commands()
		var result: Dictionary = sim.command_results.back()
		_refresh_active_company()
		message = "Action completed." if result.accepted else str(result.error)
		return bool(result.accepted)
	message = "Change scheduled for the next day."
	return true

func unlock_debug(password: String) -> bool:
	debug_unlocked = mode == "sandbox" and password == Debug.PASSWORD
	message = "Debug unlocked for this session." if debug_unlocked else "Debug unavailable or incorrect password."
	return debug_unlocked

# Explicit developer API at the current between-ticks boundary. Equity, not revenue.
func debug_action(action: String, amount: int = 0) -> bool:
	if mode != "sandbox" or not debug_unlocked:
		message = "Debug is locked."
		return false
	var owner: SimCompany = sim.companies[player_company]
	match action:
		"cash":
			if absi(amount) > 1000000000 or owner.cash + amount < 0:
				message = "Cash adjustment exceeds limit or available cash."
				return false
			owner.cash += amount
			owner.capital += amount
		"unlock":
			sim.unlocked_technologies.assign(sim.catalog.technologies.keys())
			sim.unlocked_technologies.sort()
		"advance":
			if amount < 1 or amount > 3650:
				message = "Advance between 1 and 3650 days."
				return false
			for day: int in range(amount):
				sim.step()
		_:
			return false
	sim.record_history()
	sim.debug_actions.append({"tick": sim.clock.tick, "action": action, "amount": amount})
	message = "Debug action applied: " + action
	return true

func snapshot() -> Dictionary:
	_refresh_active_company()
	return {"tutorial": tutorial.snapshot(), "mode": mode, "player_company": player_company, "active_company": active_company, "active_city": active_city, "time": time.snapshot(), "economy": sim.snapshot()}

func select_city(city_id: String) -> bool:
	if not sim.cities.has(city_id):
		message = "Unknown city."
		return false
	active_city = city_id
	message = "Viewing " + sim.cities[city_id].display_name + "."
	return true

func controlled_companies() -> Array[String]:
	return sim.equity_market.controlled_group(player_company)

func select_company(company_id: String) -> bool:
	if company_id not in controlled_companies():
		message = "Company is outside the player's controlled group."
		return false
	active_company = company_id
	message = "Managing " + sim.companies[company_id].display_name + "."
	return true

func _refresh_active_company() -> void:
	if sim != null and active_company not in controlled_companies(): active_company = player_company

func save_game(path: String) -> bool:
	var store: SaveStore = Store.new()
	var success: bool = store.write_file(path, snapshot())
	message = "Game saved." if success else store.error
	return success

func load_game(path: String) -> bool:
	var store: SaveStore = Store.new()
	var state: Dictionary = store.read_file(path)
	if state.is_empty():
		message = store.error
		return false
	if not Store.shape(state, {"mode": "", "player_company": "", "active_company": "", "active_city": "", "time": time.snapshot(), "economy": {}}) or state.mode not in ["sandbox", "tutorial"] or state.player_company != "player":
		message = "Invalid session state."
		return false
	var timing: Dictionary = state.time
	if timing.speed not in GameTime.SPEEDS or timing.last_speed not in [1, 2, 4, 16] or not is_finite(timing.seconds_per_day) or timing.seconds_per_day < 0.01 or timing.seconds_per_day > 60.0 or not is_finite(timing.accumulator) or timing.accumulator < 0.0 or timing.accumulator > 100000.0:
		message = "Invalid time controller state."
		return false
	var candidate: Economy = store.restore(state.economy)
	if candidate == null:
		message = store.error
		return false
	if not state.active_company is String or state.active_company not in candidate.equity_market.controlled_group(state.player_company):
		message = "Invalid active company."
		return false
	if not candidate.cities.has(state.active_city):
		message = "Invalid active city."
		return false
	var guide: TutorialController = TutorialController.new()
	if not state.get("tutorial") is Dictionary or not guide.restore(state.tutorial):
		message = "Invalid tutorial progress."
		return false
	if state.mode == "sandbox" and guide.snapshot() != TutorialController.new().snapshot():
		message = "Unexpected tutorial state in sandbox."
		return false
	sim = candidate
	tutorial = guide
	mode = state.mode
	player_company = state.player_company
	active_company = state.active_company
	active_city = state.active_city
	time = TimeController.new()
	time.speed = timing.speed
	time.last_speed = timing.last_speed
	time.seconds_per_day = timing.seconds_per_day
	time.accumulator = timing.accumulator
	debug_unlocked = false
	message = "Saved game loaded."
	return true
