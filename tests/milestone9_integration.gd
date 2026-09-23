extends SceneTree

var failures: int = 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: GameSession = GameSession.new()
	check(session.start(2022, 42, "sandbox", {}, "standard"), "2022 Standard start")
	if session.sim == null:
		quit(1)
		return
	var sim: Economy = session.sim
	check(sim.equity_market.securities.rival.quote > 0, "public quote")
	check(session.submit({"type": "buy_shares", "target": "rival", "quantity": 500001}), "player acquisition")
	check(session.select_company("rival"), "manage subsidiary")
	check(not sim.ai_eligible("rival") and sim.ai_eligible("maker_b"), "StrategicAI suppression")
	check(session.submit({"type": "declare_dividend", "per_share": 1}), "subsidiary dividend")
	check(session.submit({"type": "set_price", "facility": "21_rival", "product": "smartphone", "price": 31000}), "subsidiary management command")
	for day: int in range(30): sim.step()
	check(sim.facility("21_rival").price == 31000, "subsidiary price applied")
	check(sim.equity_market.securities.rival.history.size() == 30, "daily quote history")
	check(sim.invariant_errors().is_empty(), "day 30 invariants")
	check(session.submit({"type": "issue_shares", "quantity": 250000}), "subsidiary issue")
	check(session.active_company == "player" and sim.ai_eligible("rival"), "dilution releases company to AI")
	check(session.submit({"type": "sell_shares", "target": "rival", "quantity": 250000}), "portfolio sale")
	check(session.submit({"type": "issue_shares", "quantity": 250000}), "player IPO")
	for day: int in range(30): sim.step()
	check(sim.invariant_errors().is_empty(), "day 60 invariants")
	var path: String = "res://.godot/m9-integration-save.json"
	check(session.save_game(path), "day 60 save")
	var resumed: GameSession = GameSession.new()
	check(resumed.start(2022, 42) and resumed.load_game(path), "day 60 load")
	check(resumed.snapshot() == session.snapshot(), "day 60 exact restore")
	for day: int in range(60):
		sim.step()
		resumed.sim.step()
	check(sim.clock.tick == 120, "120 days")
	check(sim.invariant_errors().is_empty() and resumed.sim.invariant_errors().is_empty(), "day 120 invariants")
	check(resumed.snapshot() == session.snapshot(), "exact deterministic continuation")
	check(sim.cumulative_consumer_units > 0, "economy continued")
	check(sim.equity_market.securities.rival.history.size() == 120, "public daily history")
	check(FinancialReports.balance(sim, "player").assets == FinancialReports.balance(sim, "player").equity, "player statements reconcile")
	check(FinancialReports.balance(sim, "rival").assets == FinancialReports.balance(sim, "rival").equity, "subsidiary statements reconcile")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("M9 INTEGRATION: 120 days, %d failures, player cash %d, rival AI %s" % [failures, sim.companies.player.cash, sim.ai_eligible("rival")])
	quit(1 if failures else 0)
