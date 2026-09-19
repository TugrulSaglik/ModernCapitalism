extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a), "", true, true) == JSON.stringify(SaveStore.encode(b), "", true, true)

func build_command(kind: String = "electronics_store", x: int = 24, y: int = 18, product: String = "smartphone") -> Dictionary:
	return {"type": "build_facility", "archetype": kind, "product": product, "x": x, "y": y}

func fresh(era: int = 2022) -> GameSession:
	var session: GameSession = GameSession.new()
	check(session.start(era, 42, "sandbox", {"preset": "legacy"}), "Session starts")
	session.time.set_speed(0)
	return session

func _initialize() -> void:
	_construction()
	_queued_construction()
	_lifecycle_and_save()
	_replay_and_soak()
	print("M3 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _construction() -> void:
	var session: GameSession = fresh()
	var initial: Dictionary = session.snapshot()
	for command: Dictionary in [build_command("missing"), build_command("electronics_store", -1), build_command("electronics_store", 31), build_command("electronics_store", 3), build_command("electronics_store", 24, 6), build_command("electronics_store", 24, 0), build_command("electronics_store", 24, 18, "processor")]:
		check(not session.submit(command), "Invalid construction rejected: " + str(command))
		check(same(initial, session.snapshot()), "Rejected command has no state effects")
	var invalid: Dictionary = build_command()
	invalid.x = 24.5
	check(not session.submit(invalid), "Fractional coordinate rejected")
	invalid = build_command()
	invalid.city = "elsewhere"
	check(not session.submit(invalid), "Wrong city rejected")
	invalid = build_command()
	invalid.company = "unknown"
	check(not session.sim.command_error(invalid).is_empty(), "Unknown owner rejected by core")
	check(not session.debug_action("cash", 100), "Existing debug lock preserved")
	session.unlock_debug(DebugConfig.PASSWORD)
	session.debug_action("cash", -session.sim.companies.player.cash)
	check(not session.submit(build_command()), "Insufficient funds rejected")
	session.debug_action("cash", 20000000)
	var cash: int = session.sim.companies.player.cash
	var count: int = session.sim.facilities.size()
	invalid = build_command()
	invalid.company = "rival"
	check(session.submit(invalid), "Build while paused; session overrides forged owner")
	var f: SimFacility = session.sim.facility("built_000001")
	check(f != null and f.company_id == "player", "Constructed ownership and stable ID")
	check(session.sim.facilities.size() == count + 1 and session.sim.city.plots.has(f.id), "Facility exists in economy and map")
	check(session.sim.companies.player.cash == cash - 2000000, "Exact construction deduction")
	check(session.sim.clock.tick == 0, "Construction does not advance time")
	check(session.sim.invariant_errors().is_empty(), "Construction expenses preserve accounts")
	check(not session.submit(build_command()), "New occupancy prevents overlap")
	check(not session.submit({"type": "demolish_facility", "facility": "21_rival"}), "Rival demolition denied")
	check(session.submit({"type": "set_price", "facility": f.id, "price": 36000}), "New facility accepts management")
	check(session.submit(build_command("warehouse", 24, 10)), "Warehouse constructible")
	check(f.price == 36000 and session.sim.pending_commands.is_empty(), "Construction flushes earlier commands in FIFO order")
	check(session.sim._behavior(session.sim.facility("built_000002")) == "storage", "Warehouse passive storage role")
	# Keep this construction/market check independent of scarce upstream supply.
	f.inventory.add("smartphone", 48, 480000)
	session.sim.companies.player.spend(480000)
	var sold: int = 0
	var stocked: bool = false
	for day: int in range(30):
		session.sim.step()
		sold += f.sold_today
		stocked = stocked or f.inventory.total_value() > 0 or session.sim.logistics.incoming(f.id) > 0
	check(sold > 0 and stocked, "New retail joins delayed sourcing and consumer market")
	check(session.sim.facility("built_000002").produced_today == 0 and session.sim.facility("built_000002").sold_today == 0, "Warehouse never manufactures or retails")
	for kind: String in session.sim.catalog.facility_types:
		var separate: GameSession = fresh()
		var definition: Dictionary = separate.sim.catalog.facility_types[kind]
		check(separate.submit(build_command(kind, 24, 6 - int(definition.depth), definition.products[0])), "Archetype constructible: " + kind)
		var built: SimFacility = separate.sim.facility("built_000001")
		check(built.type_id == kind and built.capacity == int(definition.capacity) and separate.sim.city.plots[built.id].width == int(definition.width), "Archetype role/capacity/footprint: " + kind)
	var old: GameSession = fresh(2012)
	check(not old.submit(build_command("electronics_store", 24, 18, "advanced_phone")), "2012 advanced build blocked")
	check(old.submit(build_command()), "2012 ordinary build allowed")

func _lifecycle_and_save() -> void:
	var s: GameSession = fresh()
	s.submit(build_command())
	s.submit(build_command("assembly_plant", 24, 10))
	s.submit({"type": "set_stock_days", "facility": "built_000001", "days": 3})
	for day: int in range(10): s.sim.step()
	s.submit({"type": "set_supplier", "facility": "built_000001", "product": "smartphone", "supplier": "built_000002"})
	s.submit({"type": "set_operating", "facility": "built_000001", "operating": false})
	s.sim.step()
	check(not s.sim.facility("built_000001").active, "New facility suspension works")
	var saved: Dictionary = s.snapshot()
	check(s.save_game("res://.godot/m3-save.json"), "Save constructed city")
	for facility: SimFacility in s.sim.facilities: facility.operating = false
	for day: int in range(10): s.sim.step()
	s.submit({"type": "demolish_facility", "facility": "built_000002"})
	check(not s.sim.facility("built_000001").suppliers.has("smartphone"), "Demolition clears pinned suppliers")
	check(s.save_game("res://.godot/m3-demolished.json") and s.load_game("res://.godot/m3-demolished.json"), "Demolition cleans historical source references for persistence")
	s.submit(build_command("warehouse", 24, 10))
	var loaded: bool = s.load_game("res://.godot/m3-save.json")
	if not loaded: printerr("Restore diagnostic: ", s.message)
	check(loaded and same(saved, s.snapshot()), "Load restores exact city, IDs, settings and economy")
	var f: SimFacility = s.sim.facility("built_000001")
	for facility: SimFacility in s.sim.facilities: facility.operating = false
	for day: int in range(10): s.sim.step()
	var loss: int = f.inventory.total_value() + f.asset_cost - f.accumulated_depreciation
	var expenses: int = s.sim.companies.player.expenses
	var cash: int = s.sim.companies.player.cash
	check(loss > 0, "Demolition fixture has inventory")
	check(s.submit({"type": "demolish_facility", "facility": f.id}), "Owned facility demolished")
	check(s.sim.facility(f.id) == null and not s.sim.city.plots.has(f.id), "Demolition removes economic and city records")
	check(s.sim.companies.player.cash == cash and s.sim.companies.player.expenses == expenses + loss, "Inventory written off with no refund")
	check(s.sim.invariant_errors().is_empty(), "Demolition balances")
	check(s.submit(build_command()), "Vacated land reusable")
	check(s.sim.facility("built_000003") != null, "Demolition never reuses IDs")
	var store: SaveStore = SaveStore.new()
	for corruption: String in ["overlap", "owner", "road", "counter", "footprint", "missing"]:
		var bad: Dictionary = saved.economy.duplicate(true)
		match corruption:
			"overlap": bad.city.plots.built_000001.x = 3
			"owner": bad.city.plots.built_000001.owner = "rival"
			"road": bad.city.roads.clear()
			"counter": bad.city.next_facility = 1
			"footprint": bad.city.plots.built_000001.width = 20
			"missing": bad.city.plots.erase("built_000001")
		check(store.restore(bad) == null, "Corrupt city rejected: " + corruption)

func _queued_construction() -> void:
	var s: GameSession = fresh()
	var command: Dictionary = build_command()
	command.company = "player"
	s.sim.queue_command(command)
	s.sim.queue_command(command)
	check(s.save_game("res://.godot/m3-queued.json") and s.load_game("res://.godot/m3-queued.json"), "Pending construction survives save/load")
	var cash: int = s.sim.companies.player.cash
	s.sim.process_commands()
	check(s.sim.command_results.size() == 2 and s.sim.command_results[0].accepted and not s.sim.command_results[1].accepted, "Overlapping queued builds execute and reject in order")
	check(s.sim.companies.player.cash == cash - 2000000 and s.sim.city.next_facility == 2, "Rejected queued build consumes no cash or ID")
	var decoded: Variant = SaveStore.decode(SaveStore.encode(30371.185185185186))
	check(decoded is float and decoded == 30371.185185185186, "Float reports retain exact binary value")
	var detached: Dictionary = s.sim.city.snapshot()
	detached.plots.clear()
	check(s.sim.city.plots.size() == 10, "City snapshot is detached")

func _replay_and_soak() -> void:
	for era: int in [2012, 2022]:
		var a: GameSession = fresh(era)
		var b: GameSession = fresh(era)
		for s: GameSession in [a, b]:
			s.submit(build_command())
			s.submit(build_command("component_plant", 24, 3, "processor"))
			s.submit(build_command("warehouse", 24, 10))
			s.submit({"type": "demolish_facility", "facility": "built_000003"})
			s.submit({"type": "set_price", "facility": "built_000001", "price": 32000})
		check(same(a.sim.snapshot(), b.sim.snapshot()), "Deterministic construction replay")
		check(a.save_game("res://.godot/m3-replay.json") and b.load_game("res://.godot/m3-replay.json"), "Round trip with pending management")
		for day: int in range(3650):
			a.sim.step()
			b.sim.step()
			check(a.sim.invariant_errors().is_empty() and b.sim.invariant_errors().is_empty(), "Long run invariants %d/%d" % [era, day])
			if day % 365 == 0:
				check(same(a.sim.snapshot(), b.sim.snapshot()), "Long run deterministic continuation")
		check(same(a.sim.snapshot(), b.sim.snapshot()), "Final deterministic city/economy")
		print("M3 SOAK era=%d days=3650 date=%s consumer_units=%d revenue_cents=%d" % [era, a.sim.clock.date_string(), a.sim.cumulative_consumer_units, a.sim.cumulative_consumer_revenue])
