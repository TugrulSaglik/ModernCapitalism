extends SceneTree

const Session = preload("res://src/session/game_session.gd")
const Store = preload("res://src/session/save_store.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func fresh(era: int = 2022) -> GameSession:
	var session: GameSession = Session.new()
	check(session.start(era, 42), "Start session")
	return session

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(Store.encode(a), "", true, true) == JSON.stringify(Store.encode(b), "", true, true)

func _initialize() -> void:
	_time_and_commands()
	_sourcing()
	_persistence()
	_debug()
	print("M2 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _time_and_commands() -> void:
	var a: GameSession = fresh()
	var b: GameSession = fresh()
	a.time.set_speed(0)
	check(a.time.advance(100.0, a.sim) == 0 and a.sim.clock.tick == 0, "Pause prevents progression")
	check(a.submit({"type": "set_price", "facility": "20_player", "price": 35000}), "Valid player price accepted")
	check(a.sim.facility("20_player").price == 31000, "Price waits for day boundary")
	b.submit({"type": "set_price", "facility": "20_player", "price": 35000})
	a.time.set_speed(1)
	for frame: int in range(100):
		a.time.advance(0.1, a.sim)
	b.time.set_speed(4)
	b.time.advance(2.5, b.sim)
	check(a.sim.clock.tick == 10 and same(a.sim.snapshot(), b.sim.snapshot()), "Different frame deltas/speeds give same ten ticks")
	check(a.sim.facility("20_player").price == 35000, "Price applied")
	for command: Dictionary in [
		{"type": "set_price", "facility": "20_player", "price": -1},
		{"type": "set_price", "facility": "20_player", "price": "oops"},
		{"type": "set_price", "facility": "21_rival", "price": 50},
		{"type": "set_price", "facility": "missing", "price": 50},
		{"type": "set_operating", "facility": "20_player", "operating": 1},
		{"type": "set_stock_days", "facility": "20_player", "days": 0},
		{"type": "cheat", "facility": "20_player"}]:
		check(not a.submit(command), "Invalid player command safely rejected")
	a.submit({"type": "set_operating", "facility": "20_player", "operating": false})
	a.sim.step()
	check(not a.sim.facility("20_player").active and a.sim.facility("20_player").sold_today == 0, "Suspend operation")
	check(a.sim.invariant_errors().is_empty(), "Managed operations balance")
	a.time.set_speed(16)
	check(a.time.advance(100.0, a.sim) == 64 and a.time.accumulator > 0.0, "Max speed bounds frame work and retains backlog")
	var tick: int = a.sim.clock.tick
	a.time.set_speed(0)
	a.time.advance(1.0, a.sim)
	check(a.sim.clock.tick == tick, "Pause also stops catch-up backlog")
	for speed: int in [1, 2, 4, 16]:
		var paced: GameSession = fresh()
		paced.time.set_speed(speed)
		check(paced.time.advance(1.0, paced.sim) == speed and paced.sim.clock.tick == speed, "%dx speed advances the advertised daily ticks" % speed)
	var toggled: GameSession = fresh()
	toggled.time.set_speed(4)
	toggled.time.toggle_pause()
	var paused_tick: int = toggled.sim.clock.tick
	toggled.time.advance(1.0, toggled.sim)
	toggled.time.toggle_pause()
	check(toggled.sim.clock.tick == paused_tick and toggled.time.speed == 4, "Pause toggle stops time and restores the prior speed")
	var low_price: GameSession = fresh()
	var high_price: GameSession = fresh()
	low_price.submit({"type": "set_price", "facility": "20_player", "price": 25000})
	high_price.submit({"type": "set_price", "facility": "20_player", "price": 60000})
	var low_units: int = 0
	var high_units: int = 0
	for day: int in range(60):
		low_price.sim.step()
		high_price.sim.step()
		low_units += low_price.sim.facility("20_player").sold_today
		high_units += high_price.sim.facility("20_player").sold_today
	check(low_units > high_units, "Lower player price produces more consumer sales under identical demand")

func _sourcing() -> void:
	var session: GameSession = fresh()
	var sim: Economy = session.sim
	var a: SimFacility = sim.facility("10_orion")
	var b: SimFacility = sim.facility("11_nova")
	for f: SimFacility in [a, b]:
		f.inventory.add("smartphone", 10, 1000)
		var owner: SimCompany = sim.companies[f.company_id]
		owner.spend(1000)
	a.price = 30000
	b.price = 24000
	a.quality = 50
	b.quality = 50
	check(sim.supplier_offers("20_player", "smartphone")[0].id == b.id, "Lower price wins")
	a.quality = 100
	check(sim.supplier_offers("20_player", "smartphone")[0].id == a.id, "Quality changes ranking")
	a.active = false
	check(sim.supplier_offers("20_player", "smartphone")[0].id == b.id, "Inactive offer excluded")
	a.active = true
	a.inventory.remove("smartphone", 10)
	check(sim.supplier_offers("20_player", "smartphone")[0].id == b.id, "Empty stock excluded")
	var before: Array[Dictionary] = sim.supplier_offers("20_player", "smartphone")
	sim.facilities.reverse()
	check(same(before, sim.supplier_offers("20_player", "smartphone")), "Source container order does not determine ranking")
	var manual: GameSession = fresh()
	check(manual.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": "11_nova"}), "Manual supplier accepted")
	manual.sim.step()
	check(manual.sim.facility("20_player").last_sources.smartphone[0].supplier == "11_nova", "Manual override purchases selected supplier")
	check(not manual.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": "01_processors"}), "Wrong-product supplier rejected")
	manual.sim.facility("11_nova").operating = false
	manual.sim.facility("20_player").stock_days = 7
	manual.sim.step()
	check(manual.sim.facility("20_player").last_sources.is_empty(), "Manual supplier stockout has no silent fallback")
	manual.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": ""})
	manual.sim.step()
	check(not manual.sim.facility("20_player").last_sources.is_empty(), "Return to automatic sourcing")
	# Reverse actual definition file arrays, not just runtime containers.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Store.DATA_PATH))
	data.scenario.facilities.reverse()
	data.scenario.companies.reverse()
	var file: FileAccess = FileAccess.open("res://.godot/reordered.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var original: GameSession = fresh()
	var reordered: Economy = Economy.new()
	check(reordered.initialize(42, 2022, "res://.godot/reordered.json"), "Load reordered definitions")
	for day: int in range(30):
		original.sim.step()
		reordered.step()
	check(same(original.sim.snapshot(), reordered.snapshot()), "Definition order leaves entire economy identical")

func _persistence() -> void:
	for era: int in [2012, 2022]:
		var session: GameSession = fresh(era)
		for day: int in range(90):
			session.sim.step()
		session.time.set_speed(0)
		session.submit({"type": "set_price", "facility": "20_player", "price": 32000})
		session.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": "11_nova"})
		var saved: Dictionary = session.snapshot()
		var path: String = "res://.godot/test-slot-%d.json" % era
		check(session.save_game(path), "Write named save slot")
		check(session.save_game(path), "Atomically replace existing save slot")
		for day: int in range(365):
			session.sim.step()
			check(session.sim.invariant_errors().is_empty(), "Continuation invariants")
		var expected: Dictionary = session.sim.snapshot()
		check(session.load_game(path), "Load saved session: " + session.message)
		check(same(saved, session.snapshot()), "Exact save/load round trip, pending commands included")
		check(session.sim.starting_year == era and session.sim.available("advanced_phone") == (era == 2022), "Era state survives save/load")
		for day: int in range(365):
			session.sim.step()
		check(same(expected, session.sim.snapshot()), "Save N=90 plus M=365 continuation equals uninterrupted run")
		var before: Dictionary = session.snapshot()
		var bad: FileAccess = FileAccess.open("res://.godot/bad-save.json", FileAccess.WRITE)
		bad.store_string("{broken")
		bad.close()
		check(not session.load_game("res://.godot/bad-save.json") and same(before, session.snapshot()), "Invalid file leaves session untouched")
		var store: SaveStore = Store.new()
		var invalid: Dictionary = saved.duplicate(true)
		invalid.economy.facilities[0].inventory.quantities["processor"] = -1
		store.write_file("res://.godot/bad-save.json", invalid)
		check(not session.load_game("res://.godot/bad-save.json") and same(before, session.snapshot()), "Negative inventory save rejected transactionally")
		invalid = saved.duplicate(true)
		invalid.economy.schema_version = 999
		store.write_file("res://.godot/bad-save.json", invalid)
		check(not session.load_game("res://.godot/bad-save.json"), "Incompatible schema rejected")

func _debug() -> void:
	var session: GameSession = fresh(2012)
	check(not session.debug_action("cash", 1000), "Locked debug rejected")
	check(not session.unlock_debug("wrong"), "Wrong password rejected")
	check(session.unlock_debug(DebugConfig.PASSWORD), "Sandbox debug unlocked")
	var player: SimCompany = session.sim.companies.player
	var rival_cash: int = session.sim.companies.rival.cash
	var cash: int = player.cash
	check(session.debug_action("cash", 100000) and player.cash == cash + 100000 and session.sim.companies.rival.cash == rival_cash, "Debug credits player only")
	check(session.debug_action("cash", -100000) and player.cash == cash, "Debug cash withdrawal")
	check(not session.debug_action("cash", -cash - 1), "Debug cannot overdraft")
	check(session.sim.invariant_errors().is_empty(), "Debug equity preserves accounting")
	check(session.debug_action("unlock") and session.sim.available("advanced_phone"), "Debug unlocks unavailable technology")
	check(session.save_game("res://.godot/debug-slot.json") and session.load_game("res://.godot/debug-slot.json"), "Save/load technology override")
	check(session.sim.available("advanced_phone") and not session.debug_unlocked, "Unlock effects persist; debug access does not")
	session.start(2012, 42, "tutorial")
	check(not session.unlock_debug(DebugConfig.PASSWORD) and not session.debug_action("unlock"), "Tutorial has no normal cheats")
	session.start()
	check(not session.debug_unlocked, "New session locks debug")
