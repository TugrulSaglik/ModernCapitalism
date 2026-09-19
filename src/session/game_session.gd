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
var debug_unlocked: bool = false
var message: String = ""

func start(era: int = 2022, seed_value: int = 42, game_mode: String = "sandbox", city_settings: Dictionary = {}) -> bool:
	if game_mode not in ["sandbox", "tutorial"]:
		return false
	var candidate: Economy = Simulation.new()
	if not candidate.initialize(seed_value, era, SaveStore.DATA_PATH, city_settings):
		return false
	sim = candidate
	mode = game_mode
	time = TimeController.new()
	debug_unlocked = false
	message = "Session started. Commands take effect on the next day."
	return true

func submit(command: Dictionary) -> bool:
	var request: Dictionary = command.duplicate(true)
	request["company"] = player_company
	message = sim.command_error(request)
	if not message.is_empty():
		return false
	sim.queue_command(request)
	if str(request.type) in ["build_facility", "demolish_facility", "transfer"]:
		sim.process_commands()
		var result: Dictionary = sim.command_results.back()
		message = "Applied at current boundary: " + str(request.type) if result.accepted else str(result.error)
		return bool(result.accepted)
	message = "Queued for next day: " + str(request.type)
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
	return {"mode": mode, "player_company": player_company, "time": time.snapshot(), "economy": sim.snapshot()}

func save_game(path: String) -> bool:
	var store: SaveStore = Store.new()
	var success: bool = store.write_file(path, snapshot())
	message = "Saved: " + path if success else store.error
	return success

func load_game(path: String) -> bool:
	var store: SaveStore = Store.new()
	var state: Dictionary = store.read_file(path)
	if state.is_empty():
		message = store.error
		return false
	if not Store.shape(state, {"mode": "", "player_company": "", "time": time.snapshot(), "economy": {}}) or state.mode not in ["sandbox", "tutorial"] or state.player_company != "player":
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
	sim = candidate
	mode = state.mode
	player_company = state.player_company
	time = TimeController.new()
	time.speed = timing.speed
	time.last_speed = timing.last_speed
	time.seconds_per_day = timing.seconds_per_day
	time.accumulator = timing.accumulator
	debug_unlocked = false
	message = "Loaded: " + path + ". Debug access is locked."
	return true
