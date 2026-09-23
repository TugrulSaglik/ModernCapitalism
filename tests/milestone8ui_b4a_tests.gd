extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _row(reports: CompanyReports, label: String) -> TreeItem:
	for item: TreeItem in reports.table.get_root().get_children():
		if item.get_text(0) == label:
			return item
	return null

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	for day: int in range(3):
		screen.session.sim.step()
	var reports: CompanyReports = screen.reports
	var owner: SimCompany = screen.session.sim.companies.player
	var clock: SimClock = screen.session.sim.clock
	reports.refresh()

	check(reports.tabs.tab_count == 7 and reports.company_name.text == "Player Electronics" and reports.company_date.text == clock.date_string(), "Company header and seven report tabs")
	var period: Dictionary = FinancialReports.period(owner, clock, "current_month")
	check(_row(reports, "Total revenue").get_metadata(1) == period.revenue, "Income revenue is exact")
	check(_row(reports, "Gross profit").get_metadata(1) == period.gross_profit and _row(reports, "Gross profit").get_metadata(0) == "total", "Income gross profit hierarchy and value")
	check(_row(reports, "Total operating expenses").get_metadata(1) == period.expenses and _row(reports, "Net profit").get_metadata(1) == period.profit, "Income expense and profit values")
	check(CompanyReports.money(-123456) == "−$1,234.56", "Negative money formatting")

	var previous: Dictionary = {"month": "%04d-%02d" % [clock.year - 1 if clock.month == 1 else clock.year, 12 if clock.month == 1 else clock.month - 1], "revenue": 765432, "retail_revenue": 500000, "profit": -12345, "opening_cash": 1000000, "closing_cash": 987655}
	owner.monthly_history.push_front(previous)
	reports.periods.select(1)
	reports.refresh()
	check(_row(reports, "Total revenue").get_metadata(1) == 765432 and _row(reports, "Net profit").get_text(1) == "−$123.45", "Previous-month selector changes exact report period")
	reports.periods.select(0)

	reports.tabs.current_tab = 1
	reports.refresh()
	var balance: Dictionary = FinancialReports.balance(screen.session.sim, owner.id)
	check(_row(reports, "Cash").get_metadata(1) == balance.cash and _row(reports, "On-hand inventory").get_metadata(1) == balance.inventory and _row(reports, "Inventory in transit").get_metadata(1) == balance.in_transit, "Balance liquid assets exact")
	check(_row(reports, "Fixed assets at cost").get_metadata(1) == balance.fixed_cost and _row(reports, "Less accumulated depreciation").get_metadata(1) == balance.accumulated_depreciation and _row(reports, "Net fixed assets").get_metadata(1) == balance.net_fixed_assets, "Balance fixed assets exact")
	check(_row(reports, "Liabilities").get_metadata(1) == balance.liabilities and _row(reports, "Total equity").get_metadata(1) == balance.equity, "Balance liabilities and equity exact")
	check(_row(reports, "Assets − liabilities − equity").get_metadata(1) == int(balance.assets) - int(balance.liabilities) - int(balance.equity), "Balance reconciliation exact")

	reports.tabs.current_tab = 2
	reports.refresh()
	period = FinancialReports.period(owner, clock, "current_month")
	for label_and_key: Array in [["Opening cash", "opening_cash"], ["Customer receipts", "revenue"], ["Inventory purchases", "purchases"], ["Production conversion", "production_cash"], ["Cash expenses including freight", "cash_expenses"], ["Net operating cash", "operating_cash"], ["Net investing cash", "investing_cash"], ["Net financing cash", "financing_cash"], ["Net cash movement", "net_cash"], ["Closing cash", "closing_cash"]]:
		check(_row(reports, label_and_key[0]).get_metadata(1) == period[label_and_key[1]], "Cash flow exact: " + label_and_key[0])
	check(_row(reports, "Opening + movement − closing").get_metadata(1) == int(period.opening_cash) + int(period.net_cash) - int(period.closing_cash), "Cash-flow reconciliation exact")
	check(_row(reports, "Inventory purchases").get_text(1).begins_with("−$") or int(period.purchases) == 0, "Cash outflow sign is explicit")

	owner.archived_months = [{"month": "2021-12", "revenue": 100, "profit": 10}]
	owner.monthly_history = [{"month": "2022-01", "revenue": 200, "profit": -20}, {"month": clock.date_string().substr(0, 7), "revenue": 300, "profit": 30}]
	reports.tabs.current_tab = 4
	reports.refresh()
	var history: Array[TreeItem] = reports.table.get_root().get_children()
	check(history.size() == 3 and history[0].get_text(0).contains("CURRENT") and history[2].get_text(0) == "2021-12", "History is newest first with current incomplete month")
	check(history[0].get_metadata(1) == 300 and history[1].get_metadata(2) == -20, "Archived and current history values are exact")
	owner.archived_months.clear()
	owner.monthly_history.clear()
	reports.refresh()
	check(reports.table.get_root().get_child(0).get_text(0) == "No completed monthly history yet.", "History empty state is explicit")

	reports.tabs.current_tab = 5
	reports.refresh()
	var companies: Array[TreeItem] = reports.table.get_root().get_children()
	check(companies.size() == screen.session.sim.companies.size(), "Company comparison has one row per company")
	var player_row: TreeItem
	for item: TreeItem in companies:
		var company: SimCompany = screen.session.sim.companies[str(item.get_metadata(0))]
		check(item.get_metadata(1) == company.cash and item.get_metadata(2) == company.revenue and item.get_metadata(3) == company.profit(), "Company comparison values exact for " + company.id)
		if company.id == "player":
			player_row = item
	check(player_row != null and player_row.get_text(0).contains("YOU"), "Player company is identifiable without ranking")

	reports.tabs.current_tab = 3
	reports.refresh()
	check(reports.products.item_count > 0 and reports.advertising_budget.visible and reports.apply_advertising.visible, "Markets controls remain available")
	var selected_product: Variant = reports.products.get_item_metadata(reports.products.selected)
	reports.tabs.current_tab = 0
	reports.refresh()
	reports.tabs.current_tab = 3
	reports.refresh()
	check(reports.products.get_item_metadata(reports.products.selected) == selected_product, "Markets product selection survives tab changes")
	var emitted: Array[Dictionary] = []
	reports.command_requested.connect(func(command: Dictionary) -> void: emitted.append(command))
	reports.advertising_budget.value = 12.0
	reports.apply_advertising.pressed.emit()
	check(not emitted.is_empty() and emitted.back() == {"type": "set_advertising_budget", "product": str(selected_product), "budget": 1200}, "Advertising command emission remains exact")

	screen._show_company()
	await process_frame
	reports.tabs.current_tab = 0
	reports.refresh()
	await process_frame
	check(screen.overview.visible and screen.world_input_blocked(), "Company dialog opens modally and blocks world input")
	check(reports.report_scroll.get_v_scroll_bar().visible and reports.report_scroll.get_v_scroll_bar().max_value > reports.report_scroll.get_v_scroll_bar().page, "Long financial statements remain vertically accessible")
	var horizontal_overflow: bool = false
	for scrollbar: Node in reports.table.find_children("*", "HScrollBar", true, false):
		horizontal_overflow = horizontal_overflow or (scrollbar as HScrollBar).visible
	check(screen.overview.size.x <= 800.0 and screen.overview.size.y <= 650.0 and not horizontal_overflow, "Company dialog fits 800 by 650 without horizontal overflow")
	print("8UI-B4A TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
