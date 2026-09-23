extends SceneTree

var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: GameSession = GameSession.new()
	check(session.start(2022, 42), "start")
	if session.sim == null:
		quit(1)
		return
	var sim: Economy = session.sim
	var equity: EquityMarket = sim.equity_market
	check(sim.snapshot().schema_version == 17, "schema 17")
	check(equity.securities.player.public == false and equity.securities.player.founder == 1000000, "private root")
	for id: String in ["components", "maker_a", "maker_b", "rival"]:
		var security: Dictionary = equity.securities[id]
		check(security.public and security.outstanding == 1000000 and security.founder == 400000 and security.float == 600000, "public initial " + id)
	check(equity.invariant_errors(sim.companies).is_empty(), "initial registry")
	var cap_fixture: EquityMarket = EquityMarket.new()
	cap_fixture.initialize(sim.companies, sim.clock.date_string())
	cap_fixture.securities.rival.founder = 100000
	cap_fixture.securities.rival.float = 900000
	check(cap_fixture.command_error({"type": "buy_shares", "company": "player", "target": "rival", "quantity": 750001}, sim.companies).contains("75%"), "corporate ownership cap")
	check(equity.securities.rival.quote == 20, "book equity quote")
	var valuation_owner: SimCompany = SimCompany.new({"id": "valuation", "name": "Valuation", "ai": false, "cash": 20000000})
	valuation_owner.ttm_profit_cached = 4000000
	check(equity.price(valuation_owner, 1000000) == 40, "earnings price case")
	valuation_owner.capital = -5000000
	valuation_owner.ttm_profit_cached = -1000000
	check(equity.price(valuation_owner, 1000000) == 10, "negative profit floor")
	var quote_clock: SimClock = SimClock.new(2022)
	var quote_fixture: EquityMarket = EquityMarket.new()
	quote_fixture.initialize(sim.companies, quote_clock.date_string())
	for day: int in range(380):
		quote_fixture.update_quotes(sim.companies, quote_clock.date_string())
		quote_clock.advance()
	check(quote_fixture.securities.rival.history.size() == 367, "bounded daily price history")
	check(not session.submit({"type": "buy_shares", "target": "player", "quantity": 1}), "private cannot trade")
	check(not session.submit({"type": "buy_shares", "target": "rival", "quantity": 600001}), "float limit")
	check(not session.submit({"type": "buy_shares", "target": "player", "quantity": 1}), "self/private protection")
	check(not session.submit({"type": "buy_shares", "target": "rival", "quantity": 1.5}), "integer shares")
	check(not session.select_company("rival"), "no minority management")
	var player: SimCompany = sim.companies.player
	var rival: SimCompany = sim.companies.rival
	var opening_target_cash: int = rival.cash
	check(session.submit({"type": "buy_shares", "target": "rival", "quantity": 500001}), "majority purchase")
	check(player.cash == 9999980 and rival.cash == opening_target_cash, "secondary cash flows")
	check(equity.position("player", "rival").shares == 500001 and equity.position("player", "rival").cost == 10000020, "holding and cost")
	check(equity.securities.rival.float == 99999 and equity.controls("player", "rival"), "majority control")
	check(equity.securities.rival.quote == 20, "trade does not move target quote")
	check(equity.ownership_percent("player", "rival") > 50.0 and not equity.controls("player", "maker_a"), "ownership threshold")
	check(sim.invariant_errors().is_empty(), "post acquisition invariant")
	check(FinancialReports.balance(sim, "player").equity_investments == 10000020, "investment balance asset")
	check(FinancialReports.balance(sim, "player").assets == FinancialReports.balance(sim, "player").equity, "balance reconciliation")
	check(not sim.ai_eligible("rival") and sim.ai_eligible("maker_b"), "AI control suppression")
	check(session.select_company("rival") and session.active_company == "rival", "manage subsidiary")
	var active_path: String = "res://.godot/m9-active-save.json"
	check(session.save_game(active_path), "save active subsidiary")
	var active_restored: GameSession = GameSession.new()
	check(active_restored.start(2022, 42) and active_restored.load_game(active_path) and active_restored.active_company == "rival", "restore active subsidiary")
	var invalid_active: Dictionary = session.snapshot()
	invalid_active.active_company = "maker_a"
	var active_store: SaveStore = SaveStore.new()
	check(active_store.write_file(active_path, invalid_active) and not active_restored.load_game(active_path), "reject unauthorized active company")
	if FileAccess.file_exists(active_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(active_path))
	var before_dividend: int = rival.cash
	check(session.submit({"type": "declare_dividend", "per_share": 1}), "declare dividend")
	check(rival.cash == before_dividend - 1000000 and rival.dividends_paid == 1000000, "issuer dividend")
	check(player.cash == 10499981 and player.investment_income == 500001 and player.dividend_receipts == 500001, "recipient dividend")
	check(FinancialReports.balance(sim, "rival").retained_earnings == rival.profit() - 1000000, "retained earnings")
	var before_issue: int = rival.cash
	check(not session.submit({"type": "issue_shares", "quantity": 250001}), "issuance limit")
	check(session.submit({"type": "issue_shares", "quantity": 250000}), "follow-on issue")
	check(equity.securities.rival.outstanding == 1250000 and equity.securities.rival.float == 349999, "issue registry")
	check(rival.cash == before_issue + 5000000 and rival.equity_issue_cash == 5000000, "issue cash capital")
	check(not equity.controls("player", "rival") and session.active_company == "player" and sim.ai_eligible("rival"), "dilution loses control and resumes AI")
	check(not session.select_company("rival"), "diluted subsidiary read only")
	var auth: GameSession = GameSession.new()
	check(auth.start(2022, 29), "authorization fixture")
	check(auth.submit({"type": "buy_shares", "company": "rival", "target": "maker_a", "quantity": 1}), "finance command accepted for active company")
	check(auth.sim.equity_market.position("player", "maker_a").shares == 1 and auth.sim.equity_market.position("rival", "maker_a").shares == 0, "submitted company cannot bypass active authorization")
	var before_sale: int = player.cash
	check(session.submit({"type": "sell_shares", "target": "rival", "quantity": 250000}), "sell shares")
	check(player.cash == before_sale + 5000000 and equity.position("player", "rival").shares == 250001, "sale proceeds and shares")
	check(equity.position("player", "rival").cost == 5000020 and player.realized_investment_gain == 0, "weighted average cost")
	check(equity.securities.rival.float == 599999 and sim.invariant_errors().is_empty(), "sale registry invariant")
	check(session.submit({"type": "issue_shares", "quantity": 250000}), "root IPO")
	check(equity.securities.player.public and equity.securities.player.outstanding == 1250000 and equity.securities.player.float == 250000, "private becomes public")
	check(not session.submit({"type": "buy_shares", "target": "player", "quantity": 1}), "public company self-trading rejected")
	check(sim.invariant_errors().is_empty(), "IPO balance")
	var period: Dictionary = FinancialReports.period(player, sim.clock)
	check(period.equity_purchase_cash == 10000020 and period.equity_sale_cash == 5000000 and period.dividend_receipts == 500001 and period.equity_issue_cash == 5000000, "cash flow finance accounts")
	check(period.opening_cash + period.net_cash == period.closing_cash, "cash flow reconciliation")
	check(period.investing_cash == -4500019 and period.financing_cash == 5000000, "cash flow classification")
	check(period.investment_income == 500001 and period.realized_investment_gain == 0, "income statement investment lines")
	var path: String = "res://.godot/m9-focused-save.json"
	check(session.save_game(path), "save")
	var restored: GameSession = GameSession.new()
	check(restored.start(2022, 42) and restored.load_game(path), "load")
	check(restored.snapshot() == session.snapshot(), "exact state restore")
	var store: SaveStore = SaveStore.new()
	var corrupt: Dictionary = sim.snapshot()
	corrupt.equity_market.rival.float += 1
	check(store.restore(corrupt) == null, "invalid registry rejected")
	corrupt = sim.snapshot()
	corrupt.equity_market.rival.holdings.player.shares = 1.5
	check(store.restore(corrupt) == null, "fractional holding rejected")
	corrupt = sim.snapshot()
	corrupt.equity_market.rival.holdings.player.cost = -1
	check(store.restore(corrupt) == null, "negative cost rejected")
	corrupt = sim.snapshot()
	corrupt.equity_market.rival.history.append({"date": "2099-01-01", "price": 20})
	check(store.restore(corrupt) == null, "future quote rejected")
	corrupt = sim.snapshot()
	corrupt.equity_market.rival.history[0].date = "2022-00-01"
	check(store.restore(corrupt) == null, "malformed quote date rejected")
	corrupt = sim.snapshot()
	corrupt.schema_version = 16
	check(store.restore(corrupt) == null, "old schema rejected")
	var graph: EquityMarket = EquityMarket.new()
	graph.initialize(sim.companies, "2022-01-01")
	graph.securities.maker_a.holdings.player = {"shares": 500001, "cost": 1}
	graph.securities.maker_a.float = 99999
	graph.securities.maker_b.holdings.maker_a = {"shares": 500001, "cost": 1}
	graph.securities.maker_b.float = 99999
	graph.securities.player.holdings.maker_b = {"shares": 500001, "cost": 1}
	graph.securities.player.founder = 499999
	check("maker_b" in graph.controlled_group("player"), "transitive control")
	check(graph.controlled_group("player").size() <= 5, "cycle traversal finite")
	graph.securities.maker_a.holdings.player.shares = 500000
	graph.securities.maker_a.float = 100000
	check(not graph.controls("player", "maker_a"), "exact half does not control")
	var weighted: GameSession = GameSession.new()
	check(weighted.start(2022, 7), "cost-basis fixture")
	var weighted_equity: EquityMarket = weighted.sim.equity_market
	check(weighted.submit({"type": "buy_shares", "target": "rival", "quantity": 100}), "first cost lot")
	weighted_equity.securities.rival.quote = 30
	check(weighted.submit({"type": "buy_shares", "target": "rival", "quantity": 100}), "second cost lot")
	check(weighted_equity.position("player", "rival").cost == 5000, "aggregate weighted cost")
	weighted_equity.securities.rival.quote = 40
	check(weighted.submit({"type": "sell_shares", "target": "rival", "quantity": 80}), "partial weighted sale")
	check(weighted_equity.position("player", "rival").cost == 3000 and weighted.sim.companies.player.realized_investment_gain == 1200, "proportional basis and realized gain")
	weighted_equity.securities.rival.quote = 10
	check(weighted.submit({"type": "sell_shares", "target": "rival", "quantity": 120}), "close position")
	check(weighted_equity.position("player", "rival").cost == 0 and not weighted_equity.securities.rival.holdings.has("player"), "zero position clears cost")
	check(weighted.sim.companies.player.realized_investment_gain == -600, "realized loss reduces profit")
	weighted.sim.step()
	check(FinancialReports.period(weighted.sim.companies.player, weighted.sim.clock, "ttm").equity_purchase_cash == 5000, "TTM finance history")
	check(FinancialReports.period(weighted.sim.companies.player, weighted.sim.clock, "current_month").equity_sale_cash == 4400, "monthly finance history")
	var chain: GameSession = GameSession.new()
	check(chain.start(2022, 19), "transitive fixture")
	check(chain.submit({"type": "buy_shares", "target": "rival", "quantity": 500001}) and chain.select_company("rival"), "parent acquisition")
	check(chain.submit({"type": "buy_shares", "target": "maker_b", "quantity": 500001}), "subsidiary acquisition")
	check("maker_b" in chain.controlled_companies() and chain.select_company("maker_b"), "transitive player subsidiary")
	var suppressed_plan: Dictionary = chain.sim.strategic_ai.evaluate_month(chain.sim)
	var suppressed: bool = true
	for command: Dictionary in suppressed_plan.commands:
		if command.company in ["rival", "maker_b"]: suppressed = false
	for command: Dictionary in chain.sim.strategic_ai.research_commands(chain.sim):
		if command.company in ["rival", "maker_b"]: suppressed = false
	check(suppressed, "StrategicAI emits no commands for controlled companies")
	var archetype: Dictionary = chain.sim.catalog.facility_types.convenience_store
	var built: bool = false
	for site: Vector2i in chain.sim.city.valid_sites(int(archetype.width), int(archetype.depth)):
		var build: Dictionary = {"type": "build_facility", "archetype": "convenience_store", "product": "detergent", "x": site.x, "y": site.y}
		if chain.sim.command_error(build.merged({"company": "maker_b"})).is_empty():
			var before_build: int = chain.sim.companies.player.cash
			built = chain.submit(build)
			check(chain.sim.companies.player.cash == before_build and chain.sim.facilities.back().company_id == "maker_b", "Build uses active subsidiary")
			break
	check(built, "subsidiary can construct")
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var reports: CompanyReports = screen.reports
	check(reports.tabs.get_tab_title(6) == "Finance", "Finance tab")
	reports.tabs.current_tab = 6
	reports.refresh()
	check(reports.securities_tree.get_root().get_child_count() == 5, "securities UI")
	check(reports.capital_tree.get_root().get_child_count() == 6, "capital UI")
	check(screen.managed_company_selector.item_count == 1, "initial company selector")
	check(screen.session.submit({"type": "buy_shares", "target": "rival", "quantity": 500001}), "UI session acquisition")
	screen.refresh()
	check(screen.managed_company_selector.item_count == 2, "subsidiary appears in selector")
	reports.refresh()
	check(reports.portfolio_tree.get_root().get_child_count() == 1 and reports.portfolio_tree.get_root().get_child(0).get_text(6) == "CONTROLLED", "portfolio UI control row")
	var rival_index: int = -1
	for index: int in range(screen.managed_company_selector.item_count):
		if screen.managed_company_selector.get_item_metadata(index) == "rival": rival_index = index
	check(rival_index >= 0, "subsidiary selector item")
	if rival_index >= 0:
		screen.managed_company_selector.select(rival_index)
		screen.managed_company_selector.item_selected.emit(rival_index)
	check(screen.session.active_company == "rival" and screen.company_name_label.text == "Metro Electronics", "active subsidiary UI")
	check(screen.inspector.session.active_company == "rival", "facility management context")
	reports.refresh()
	check(reports.company_name.text == "Metro Electronics", "reports follow active company")
	for tab_index: int in range(reports.tabs.tab_count):
		reports.tabs.current_tab = tab_index
		reports.refresh()
	check(reports.tabs.tab_count == 7, "ordinary company tabs retain access")
	reports.tabs.current_tab = 6
	reports.refresh()
	var ui_commands: Array[Dictionary] = []
	reports.command_requested.connect(func(command: Dictionary) -> void: ui_commands.append(command))
	reports.security_choice.select(4)
	reports.trade_quantity.value = 7
	reports._trade("buy_shares")
	check(not ui_commands.is_empty() and ui_commands.back().type == "buy_shares" and ui_commands.back().quantity == 7, "Finance buy UI command")
	reports._trade("sell_shares")
	check(ui_commands.back().type == "sell_shares", "Finance sell UI command")
	reports.issue_quantity.value = 8
	reports.finance_content.find_child("IssueShares", true, false).pressed.emit()
	check(ui_commands.back().type == "issue_shares" and ui_commands.back().quantity == 8, "Finance issue UI command")
	reports.dividend_amount.value = 2
	reports.finance_content.find_child("DeclareDividend", true, false).pressed.emit()
	check(ui_commands.back().type == "declare_dividend" and ui_commands.back().per_share == 2, "Finance dividend UI command")
	screen.queue_free()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("M9 FOCUSED: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
