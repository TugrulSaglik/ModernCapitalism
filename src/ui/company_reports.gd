class_name CompanyReports
extends VBoxContainer

signal command_requested(command: Dictionary)

var session: GameSession
var tabs: TabBar
var periods: OptionButton
var products: OptionButton
var table: Tree
var context: Label
var advertising_budget: SpinBox
var apply_advertising: Button

func _ready() -> void:
	custom_minimum_size = Vector2(760, 510)
	tabs = TabBar.new()
	for title: String in ["Income Statement", "Balance Sheet", "Cash Flow", "Markets", "History", "Companies"]: tabs.add_tab(title)
	add_child(tabs)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	periods = OptionButton.new()
	for title: String in ["Current month", "Previous month", "Trailing 12 months", "Current year"]: periods.add_item(title)
	row.add_child(periods)
	products = OptionButton.new()
	row.add_child(products)
	advertising_budget = SpinBox.new()
	advertising_budget.min_value = 0
	advertising_budget.max_value = 1000000
	advertising_budget.step = 1
	advertising_budget.suffix = " $/day"
	row.add_child(advertising_budget)
	apply_advertising = Button.new()
	apply_advertising.text = "Queue advertising"
	apply_advertising.theme_type_variation = "PrimaryButton"
	row.add_child(apply_advertising)
	context = Label.new()
	context.clip_text = true
	context.custom_minimum_size.y = 52
	add_child(context)
	table = Tree.new()
	table.columns = 2
	table.hide_root = true
	table.column_titles_visible = true
	table.set_column_title(0, "Account / metric")
	table.set_column_title(1, "Amount")
	table.set_column_expand_ratio(0, 3)
	table.set_column_expand_ratio(1, 2)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(table)
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	periods.item_selected.connect(func(_index: int) -> void: refresh())
	products.item_selected.connect(func(_index: int) -> void: refresh())
	apply_advertising.pressed.connect(func() -> void:
		if products.selected >= 0:
			command_requested.emit({"type": "set_advertising_budget", "product": str(products.get_item_metadata(products.selected)), "budget": int(round(advertising_budget.value * 100.0))}))

static func money(cents: int) -> String:
	var parts: PackedStringArray = ("%.2f" % (absi(cents) / 100.0)).split(".")
	var whole: String = parts[0]
	var grouped: String = ""
	while whole.length() > 3:
		grouped = "," + whole.right(3) + grouped
		whole = whole.left(whole.length() - 3)
	return ("−$" if cents < 0 else "$") + whole + grouped + "." + parts[1]

func add_row(label: String, value: String, negative: bool = false) -> void:
	var row: TreeItem = table.create_item(table.get_root())
	row.set_text(0, label)
	row.set_text(1, value)
	row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
	if negative: row.set_custom_color(1, Color("e47777"))

func amount(label: String, value: int) -> void:
	add_row(label, money(value), value < 0)

func refresh() -> void:
	if session == null or table == null: return
	var sim: Economy = session.sim
	var owner: SimCompany = sim.companies[session.player_company]
	var p: Dictionary = FinancialReports.period(owner, sim.clock, ["current_month", "previous_month", "ttm", "year"][periods.selected])
	table.columns = 3 if tabs.current_tab == 3 else 2
	table.set_column_title(0, "Market / offer" if tabs.current_tab == 3 else "Account / metric")
	table.set_column_title(1, "Local" if tabs.current_tab == 3 else "Amount")
	if tabs.current_tab == 3:
		table.set_column_title(2, "Market average")
		table.set_column_expand_ratio(0, 3)
		table.set_column_expand_ratio(1, 2)
		table.set_column_expand_ratio(2, 2)
	table.clear()
	table.create_item()
	periods.visible = tabs.current_tab in [0, 2]
	products.visible = tabs.current_tab == 3
	advertising_budget.visible = tabs.current_tab == 3
	apply_advertising.visible = tabs.current_tab == 3
	context.text = owner.display_name + " • " + sim.clock.date_string() + "\n" + periods.get_item_text(periods.selected) + " • integer cents; current period includes activity through today."
	match tabs.current_tab:
		0:
			for pair: Array in [["Retail sales", "retail_revenue"], ["Wholesale sales", "wholesale_revenue"], ["REVENUE", "revenue"], ["Cost of goods sold", "cogs"], ["GROSS PROFIT", "gross_profit"], ["Freight / logistics", "freight"], ["Depreciation", "depreciation"], ["R&D research", "research_expense"], ["Advertising", "advertising_expense"], ["Payroll", "payroll_expense"], ["Other expenses / disposal losses", "other_expenses"], ["TOTAL OPERATING EXPENSES", "expenses"], ["OPERATING / NET PROFIT", "profit"]]: amount(pair[0], p[pair[1]])
			context.text += "\nNo tax or interest: net profit equals operating profit."
		1:
			context.text = owner.display_name + " • Balance sheet as of " + sim.clock.date_string()
			var b: Dictionary = FinancialReports.balance(sim, owner.id)
			for pair: Array in [["Cash", "cash"], ["On-hand inventory", "inventory"], ["Inventory in transit", "in_transit"], ["Fixed assets at cost", "fixed_cost"], ["Less accumulated depreciation", "accumulated_depreciation"], ["Net fixed assets", "net_fixed_assets"], ["TOTAL ASSETS", "assets"], ["Liabilities", "liabilities"], ["Contributed capital", "contributed_capital"], ["Retained earnings", "retained_earnings"], ["TOTAL EQUITY", "equity"]]: amount(pair[0], b[pair[1]])
			amount("Assets − liabilities − equity (must be zero)", int(b.assets) - int(b.liabilities) - int(b.equity))
		2:
			for pair: Array in [["OPENING CASH", "opening_cash"], ["Customer receipts", "revenue"], ["Inventory purchases (outflow)", "purchases"], ["Production conversion (outflow)", "production_cash"], ["Cash expenses incl. freight (outflow)", "cash_expenses"], ["NET OPERATING CASH", "operating_cash"], ["Construction / investing cash", "investing_cash"], ["Capital / financing cash", "financing_cash"], ["NET CASH MOVEMENT", "net_cash"], ["CLOSING CASH", "closing_cash"]]: amount(pair[0], p[pair[1]])
			amount("Opening + movement − closing (must be zero)", int(p.opening_cash) + int(p.net_cash) - int(p.closing_cash))
		3: _market(sim)
		4:
			context.text = owner.display_name + " • Monthly financial history\nNewest first; current month remains incomplete. Full records are retained in saves."
			var rows: Array[Dictionary] = owner.archived_months.duplicate()
			rows.append_array(owner.monthly_history)
			rows.reverse()
			for row: Dictionary in rows:
				add_row(str(row.month) + " • revenue / net profit", money(int(row.revenue)) + " / " + money(int(row.profit)), int(row.profit) < 0)
		5:
			context.text = "Company comparison • cumulative since scenario start\nRevenue includes wholesale transactions; summing firms does not measure consumer spending."
			for company: SimCompany in sim.companies.values():
				amount(company.display_name + " • cash", company.cash)
				amount("Revenue", company.revenue)
				amount("Accumulated profit", company.profit())

func comparison(label: String, local: String, average: String) -> void:
	add_row(label, local)
	var row: TreeItem = table.get_root().get_children().back()
	row.set_text(2, average)
	row.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)

func _market(sim: Economy) -> void:
	if products.item_count == 0:
		var ids: Array = sim.catalog.products.keys()
		ids.sort()
		for id: String in ids:
			if not sim.catalog.consumer_product(id): continue
			products.add_item(sim.catalog.products[id].name)
			products.set_item_metadata(products.item_count - 1, id)
	var product: String = str(products.get_item_metadata(products.selected))
	var definition: Dictionary = sim.catalog.products[product]
	var owner: SimCompany = sim.companies[session.player_company]
	advertising_budget.set_value_no_signal(int(owner.advertising_budgets[product]) / 100.0)
	var category: Dictionary = sim.category_market.get(definition.category, {})
	var m: Dictionary = sim.market.get(product, ConsumerMarket.empty_report())
	var local: Dictionary = ConsumerMarket.local_offer(sim, product)
	var realized: bool = int(m.units) > 0
	context.text = "%s • %s • %s
Category potential %d / purchased %d • no purchase or unfilled %d" % [definition.name, definition.category, "Public" if sim.product_public(product) else "Era locked", category.get("potential", 0), category.get("units", 0), int(category.get("potential", 0)) - int(category.get("units", 0))]
	comparison("Price", money(local.price) if not local.is_empty() else "—", money(int(round(m.average_price))) if realized else "—")
	comparison("Quality", str(local.quality) if not local.is_empty() else "—", "%.1f" % m.average_quality if realized else "—")
	comparison("Brand", str(local.brand) if not local.is_empty() else "—", "%.1f" % m.average_brand if realized else "—")
	comparison("Overall / 100", "%.1f" % ConsumerDemand.overall(local.price, definition.reference_price, local.quality, local.brand) if not local.is_empty() else "—", "%.1f" % m.average_overall if realized else "—")
	comparison("Units / realized share", "%d / %.1f%%" % [m.local_units, m.local_share * 100] if not local.is_empty() else "—", "%d / 100%%" % m.units if realized else "—")
	comparison("Your company brand", str(owner.brand(product)), "")
	comparison("Advertising budget / day", money(int(owner.advertising_budgets[product])), "")
	comparison("Advertising progress / next point", "%s / %s" % [money(int(owner.advertising_progress[product])), money(sim.advertising_threshold(product, owner.brand(product))) if owner.brand(product) < 100 else "MAX"], "")
	comparison("Inactive advertising days", str(owner.advertising_inactive_days[product]), "")
	comparison("CORPORATE OFFERS", "Price / stock quality", "Brand / sold / share")
	if sim.product_public(product):
		for f: SimFacility in sim.facilities:
			if sim._behavior(f) != "retail" or not f.assortment.has(product): continue
			var sold: int = int(f.line_today.get(product, {}).get("units", 0))
			var share: float = float(sold) / int(m.units) if realized else 0.0
			comparison(sim.companies[f.company_id].display_name + " • " + f.id, money(f.line_price(product)) + " / " + f.inventory.quality_text(product), "%d / %d / %.1f%%" % [sim.companies[f.company_id].brand(product), sold, share * 100])
	comparison("COMPANY PRODUCT SHARES", "All retailers combined", "")
	for company: String in m.market_share:
		comparison(sim.companies[company].display_name, "%.1f%%" % (float(m.market_share[company]) * 100), "")
	var segments: Array[String] = []
	for segment: String in category.get("segments", {}):
		segments.append("%s %d" % [segment, category.segments[segment]])
	for index: int in range(0, segments.size(), 3):
		comparison("Potential: " + segments[index], segments[index + 1] if index + 1 < segments.size() else "", segments[index + 2] if index + 2 < segments.size() else "")
	var units: int = 0
	for row: Dictionary in sim.market_history: units += int(row.categories.get(definition.category, {}).get("units", 0))
	comparison("Category 90-day units (incl. Local)", str(units), "")
	table.tooltip_text = "Completed-day sales include Local; outside/no-purchase has no share. Corporate prices and quality describe current stock. Averages weight completed-day sales. Overall averages three scores: price competitiveness, quality, brand."
