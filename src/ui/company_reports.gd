class_name CompanyReports
extends VBoxContainer

var session: GameSession
var tabs: TabBar
var periods: OptionButton
var products: OptionButton
var table: Tree
var context: Label

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
	if negative: row.set_custom_color(1, Color("ff9494"))

func amount(label: String, value: int) -> void:
	add_row(label, money(value), value < 0)

func refresh() -> void:
	if session == null or table == null: return
	var sim: Economy = session.sim
	var owner: SimCompany = sim.companies[session.player_company]
	var p: Dictionary = FinancialReports.period(owner, sim.clock, ["current_month", "previous_month", "ttm", "year"][periods.selected])
	table.clear()
	table.create_item()
	periods.visible = tabs.current_tab in [0, 2]
	products.visible = tabs.current_tab == 3
	context.text = owner.display_name + " • " + sim.clock.date_string() + "\n" + periods.get_item_text(periods.selected) + " • integer cents; current period includes activity through today."
	match tabs.current_tab:
		0:
			for pair: Array in [["Retail sales", "retail_revenue"], ["Wholesale sales", "wholesale_revenue"], ["REVENUE", "revenue"], ["Cost of goods sold", "cogs"], ["GROSS PROFIT", "gross_profit"], ["Freight / logistics", "freight"], ["Depreciation", "depreciation"], ["Other expenses / disposal losses", "other_expenses"], ["TOTAL OPERATING EXPENSES", "expenses"], ["OPERATING / NET PROFIT", "profit"]]: amount(pair[0], p[pair[1]])
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

func _market(sim: Economy) -> void:
	if products.item_count == 0:
		var ids: Array = sim.catalog.products.keys()
		ids.sort()
		for id: String in ids:
			products.add_item(sim.catalog.products[id].name)
			products.set_item_metadata(products.item_count - 1, id)
	var product: String = str(products.get_item_metadata(products.selected))
	var definition: Dictionary = sim.catalog.products[product]
	var category: Dictionary = sim.category_market.get(definition.category, {})
	var m: Dictionary = sim.market.get(product, {})
	context.text = "%s • %s • %s\nResidents %d • segments %s" % [definition.name, definition.category, "Available" if sim.available(product) else "Era locked", sim.city.population.total, str(ConsumerMarket.populations(sim))]
	add_row("Category demand / units sold (last completed day)", "%d / %d" % [category.get("potential", 0), category.get("units", 0)])
	for segment: String in category.get("segments", {}): add_row(sim.catalog.segments[segment].name + " • potential", str(category.segments[segment]))
	add_row("Product units sold", str(m.get("units", 0)))
	amount("Average realized price", int(m.get("average_price", 0)))
	for company: String in m.get("market_share", {}): add_row(sim.companies[company].display_name + " • product share", "%.1f%%" % (float(m.market_share[company]) * 100))
	for f: SimFacility in sim.facilities:
		if sim._behavior(f) == "retail" and f.assortment.has(product): add_row(f.id + " • stock / quality / price", "%d / Q%d / %s" % [f.inventory.quantity(product), f.quality, money(f.line_price(product))])
	var units: int = 0
	for row: Dictionary in sim.market_history: units += int(row.categories.get(definition.category, {}).get("units", 0))
	add_row("Category sales in retained 90-day history", str(units))
