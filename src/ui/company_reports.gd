class_name CompanyReports
extends VBoxContainer

signal command_requested(command: Dictionary)

const PERIOD_KEYS: Array[String] = ["current_month", "previous_month", "ttm", "year"]
const TAB_TITLES: Array[String] = ["Income Statement", "Balance Sheet", "Cash Flow", "Markets", "History", "Companies"]

class ReportScroll:
	extends ScrollContainer
	func _get_minimum_size() -> Vector2:
		return Vector2(0, 250)

var session: GameSession
var tabs: TabBar
var periods: OptionButton
var products: OptionButton
var table: Tree
var context: Label
var advertising_budget: SpinBox
var apply_advertising: Button
var company_name: Label
var company_date: Label
var company_context: Label
var report_title: Label
var report_subtitle: Label
var report_note: Label
var period_label: Label
var market_label: Label
var report_scroll: ScrollContainer

func _ready() -> void:
	custom_minimum_size = Vector2(760, 510)
	add_theme_constant_override("separation", ModernUITheme.SPACE_2)
	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	header.add_child(identity)
	company_name = Label.new()
	company_name.theme_type_variation = "TitleLabel"
	identity.add_child(company_name)
	company_context = Label.new()
	company_context.theme_type_variation = "MetaLabel"
	company_context.text = "Financial performance, position and company context"
	identity.add_child(company_context)
	company_date = Label.new()
	company_date.theme_type_variation = "ValueLabel"
	company_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(company_date)
	tabs = TabBar.new()
	for title: String in TAB_TITLES:
		tabs.add_tab(title)
	add_child(tabs)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "ReportControls"
	add_child(controls)
	period_label = _control_label(controls, "REPORT PERIOD")
	periods = OptionButton.new()
	periods.custom_minimum_size.x = 210
	for title: String in ["Current month", "Previous month", "Trailing 12 months", "Current year"]:
		periods.add_item(title)
	controls.add_child(periods)
	market_label = _control_label(controls, "PRODUCT")
	products = OptionButton.new()
	products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(products)
	advertising_budget = SpinBox.new()
	advertising_budget.min_value = 0
	advertising_budget.max_value = 1000000
	advertising_budget.step = 1
	advertising_budget.suffix = " $/day"
	controls.add_child(advertising_budget)
	apply_advertising = Button.new()
	apply_advertising.text = "Queue advertising"
	apply_advertising.theme_type_variation = "PrimaryButton"
	controls.add_child(apply_advertising)
	var report_heading: VBoxContainer = VBoxContainer.new()
	report_heading.add_theme_constant_override("separation", 0)
	add_child(report_heading)
	report_title = Label.new()
	report_title.theme_type_variation = "SectionLabel"
	report_heading.add_child(report_title)
	report_subtitle = Label.new()
	report_subtitle.theme_type_variation = "MetaLabel"
	report_heading.add_child(report_subtitle)
	context = report_subtitle
	report_scroll = ReportScroll.new()
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(report_scroll)
	table = Tree.new()
	table.hide_root = true
	table.column_titles_visible = true
	table.scroll_vertical_enabled = false
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(table)
	report_note = Label.new()
	report_note.theme_type_variation = "MetaLabel"
	report_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(report_note)
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	periods.item_selected.connect(func(_index: int) -> void: refresh())
	products.item_selected.connect(func(_index: int) -> void: refresh())
	apply_advertising.pressed.connect(func() -> void:
		if products.selected >= 0:
			command_requested.emit({"type": "set_advertising_budget", "product": str(products.get_item_metadata(products.selected)), "budget": int(round(advertising_budget.value * 100.0))}))

func _control_label(parent: Control, text_value: String) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.theme_type_variation = "MetricLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

static func money(cents: int) -> String:
	var parts: PackedStringArray = ("%.2f" % (absi(cents) / 100.0)).split(".")
	var whole: String = parts[0]
	var grouped: String = ""
	while whole.length() > 3:
		grouped = "," + whole.right(3) + grouped
		whole = whole.left(whole.length() - 3)
	return ("−$" if cents < 0 else "$") + whole + grouped + "." + parts[1]

func add_row(label: String, value: String, negative: bool = false, kind: String = "row", raw_value: Variant = null) -> TreeItem:
	var row: TreeItem = table.create_item(table.get_root())
	row.set_text(0, label)
	row.set_text(1, value)
	row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
	row.set_metadata(0, kind)
	if raw_value != null:
		row.set_metadata(1, raw_value)
	if negative:
		row.set_custom_color(1, ModernUITheme.NEGATIVE)
	_style_row(row, kind)
	return row

func amount(label: String, value: int, kind: String = "row") -> TreeItem:
	return add_row(label, money(value), value < 0, kind, value)

func outflow_amount(label: String, value: int, kind: String = "row") -> TreeItem:
	return add_row(label, money(-value), value > 0, kind, value)

func _section(label: String) -> TreeItem:
	return add_row(label, "", false, "section")

func _style_row(row: TreeItem, kind: String) -> void:
	match kind:
		"section":
			row.set_custom_color(0, ModernUITheme.ACCENT)
			row.set_custom_font_size(0, 13)
			for column: int in range(table.columns):
				row.set_custom_bg_color(column, ModernUITheme.SURFACE_RAISED)
		"group":
			row.set_custom_color(0, ModernUITheme.TEXT_MUTED)
		"subtotal":
			row.set_custom_color(0, ModernUITheme.TEXT)
			row.set_custom_color(1, ModernUITheme.TEXT)
			for column: int in range(table.columns):
				row.set_custom_bg_color(column, ModernUITheme.SURFACE_HIGH.darkened(0.18))
		"total":
			row.set_custom_color(0, ModernUITheme.HIGHLIGHT)
			row.set_custom_font_size(0, 15)
			row.set_custom_font_size(1, 15)
			for column: int in range(table.columns):
				row.set_custom_bg_color(column, ModernUITheme.SURFACE_HIGH)
		"reconciliation_ok":
			row.set_custom_color(0, ModernUITheme.TEXT_MUTED)
			row.set_custom_color(1, ModernUITheme.TEXT_MUTED)
		"reconciliation_warning":
			row.set_custom_color(0, ModernUITheme.WARNING)
			row.set_custom_color(1, ModernUITheme.NEGATIVE)

func _setup_table(columns: int, titles: Array[String], ratios: Array[int]) -> void:
	table.columns = columns
	for column: int in range(columns):
		table.set_column_title(column, titles[column])
		table.set_column_expand_ratio(column, ratios[column])
		table.set_column_clip_content(column, true)
	table.clear()
	table.create_item()

func _set_report(title_value: String, subtitle_value: String, note_value: String = "") -> void:
	report_title.text = title_value
	report_subtitle.text = subtitle_value
	report_note.text = note_value
	report_note.visible = not note_value.is_empty()

func refresh() -> void:
	if session == null or table == null:
		return
	var sim: Economy = session.sim
	var owner: SimCompany = sim.companies[session.player_company]
	company_name.text = owner.display_name
	company_date.text = sim.clock.date_string()
	var report_tab: int = tabs.current_tab
	var period_visible: bool = report_tab in [0, 2]
	var market_visible: bool = report_tab == 3
	period_label.visible = period_visible
	periods.visible = period_visible
	market_label.visible = market_visible
	products.visible = market_visible
	advertising_budget.visible = market_visible
	apply_advertising.visible = market_visible
	table.tooltip_text = ""
	match report_tab:
		0: _income_statement(owner, sim.clock)
		1: _balance_sheet(sim, owner)
		2: _cash_flow(owner, sim.clock)
		3:
			_setup_table(3, ["Market / offer", "Local", "Market average"], [3, 2, 2])
			_market(sim)
		4: _history(owner, sim.clock)
		5: _companies(sim)

func _income_statement(owner: SimCompany, clock: SimClock) -> void:
	var period: Dictionary = FinancialReports.period(owner, clock, PERIOD_KEYS[periods.selected])
	_setup_table(2, ["Account", "Amount"], [5, 2])
	_set_report("Income Statement", periods.get_item_text(periods.selected), "No tax or interest; net profit equals operating profit.")
	_section("REVENUE")
	amount("Retail sales", int(period.retail_revenue))
	amount("Wholesale sales", int(period.wholesale_revenue))
	amount("Total revenue", int(period.revenue), "subtotal")
	_section("COST OF GOODS SOLD")
	amount("Cost of goods sold", int(period.cogs))
	amount("Gross profit", int(period.gross_profit), "total")
	_section("OPERATING EXPENSES")
	amount("Freight / logistics", int(period.freight))
	amount("Depreciation", int(period.depreciation))
	amount("R&D research", int(period.research_expense))
	amount("Advertising", int(period.advertising_expense))
	amount("Payroll", int(period.payroll_expense))
	amount("Other expenses / disposal losses", int(period.other_expenses))
	amount("Total operating expenses", int(period.expenses), "subtotal")
	amount("Operating / net profit", int(period.profit), "total")

func _balance_sheet(sim: Economy, owner: SimCompany) -> void:
	var balance: Dictionary = FinancialReports.balance(sim, owner.id)
	_setup_table(2, ["Account", "Amount"], [5, 2])
	_set_report("Balance Sheet", "As of " + sim.clock.date_string())
	_section("ASSETS")
	add_row("Current / liquid", "", false, "group")
	amount("Cash", int(balance.cash))
	amount("On-hand inventory", int(balance.inventory))
	amount("Inventory in transit", int(balance.in_transit))
	add_row("Fixed assets", "", false, "group")
	amount("Fixed assets at cost", int(balance.fixed_cost))
	outflow_amount("Less accumulated depreciation", int(balance.accumulated_depreciation))
	amount("Net fixed assets", int(balance.net_fixed_assets), "subtotal")
	amount("Total assets", int(balance.assets), "total")
	_section("LIABILITIES")
	amount("Liabilities", int(balance.liabilities))
	_section("EQUITY")
	amount("Contributed capital", int(balance.contributed_capital))
	amount("Retained earnings", int(balance.retained_earnings))
	amount("Total equity", int(balance.equity), "subtotal")
	_section("RECONCILIATION")
	var difference: int = int(balance.assets) - int(balance.liabilities) - int(balance.equity)
	amount("Assets − liabilities − equity", difference, "reconciliation_ok" if difference == 0 else "reconciliation_warning")

func _cash_flow(owner: SimCompany, clock: SimClock) -> void:
	var period: Dictionary = FinancialReports.period(owner, clock, PERIOD_KEYS[periods.selected])
	_setup_table(2, ["Cash flow", "Amount"], [5, 2])
	_set_report("Cash Flow", periods.get_item_text(periods.selected), "Outflows are shown as negative amounts.")
	amount("Opening cash", int(period.opening_cash), "total")
	_section("OPERATING ACTIVITIES")
	amount("Customer receipts", int(period.revenue))
	outflow_amount("Inventory purchases", int(period.purchases))
	outflow_amount("Production conversion", int(period.production_cash))
	outflow_amount("Cash expenses including freight", int(period.cash_expenses))
	amount("Net operating cash", int(period.operating_cash), "subtotal")
	_section("INVESTING ACTIVITIES")
	amount("Construction / investing cash", int(period.investing_cash), "subtotal")
	_section("FINANCING ACTIVITIES")
	amount("Capital / financing cash", int(period.financing_cash), "subtotal")
	amount("Net cash movement", int(period.net_cash), "total")
	amount("Closing cash", int(period.closing_cash), "total")
	_section("RECONCILIATION")
	var difference: int = int(period.opening_cash) + int(period.net_cash) - int(period.closing_cash)
	amount("Opening + movement − closing", difference, "reconciliation_ok" if difference == 0 else "reconciliation_warning")

func _history(owner: SimCompany, clock: SimClock) -> void:
	_setup_table(3, ["Month", "Revenue", "Net profit"], [3, 2, 2])
	_set_report("Monthly Financial History", "Newest first", "The current month is incomplete and updates through today.")
	var rows: Array[Dictionary] = owner.archived_months.duplicate(true)
	rows.append_array(owner.monthly_history.duplicate(true))
	rows.reverse()
	if rows.is_empty():
		var empty: TreeItem = table.create_item(table.get_root())
		empty.set_text(0, "No completed monthly history yet.")
		empty.set_custom_color(0, ModernUITheme.TEXT_MUTED)
		empty.set_metadata(0, "empty")
		return
	var current_month: String = clock.date_string().substr(0, 7)
	for record: Dictionary in rows:
		var month: String = str(record.get("month", "—"))
		var is_current: bool = month == current_month
		var item: TreeItem = table.create_item(table.get_root())
		item.set_text(0, month + ("  •  CURRENT" if is_current else ""))
		item.set_text(1, money(int(record.get("revenue", 0))))
		item.set_text(2, money(int(record.get("profit", 0))))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_metadata(0, "history_current" if is_current else "history")
		item.set_metadata(1, int(record.get("revenue", 0)))
		item.set_metadata(2, int(record.get("profit", 0)))
		if is_current:
			item.set_custom_color(0, ModernUITheme.ACCENT)
		if int(record.get("profit", 0)) < 0:
			item.set_custom_color(2, ModernUITheme.NEGATIVE)

func _companies(sim: Economy) -> void:
	_setup_table(4, ["Company", "Cash", "Revenue", "Accumulated profit"], [3, 2, 2, 2])
	_set_report("Company Comparison", "Cumulative since scenario start", "Revenue includes wholesale transactions; summing firms does not measure consumer spending.")
	for company: SimCompany in sim.companies.values():
		var item: TreeItem = table.create_item(table.get_root())
		var is_player: bool = company.id == session.player_company
		item.set_text(0, company.display_name + ("  •  YOU" if is_player else ""))
		item.set_text(1, money(company.cash))
		item.set_text(2, money(company.revenue))
		item.set_text(3, money(company.profit()))
		for column: int in range(1, 4):
			item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_metadata(0, company.id)
		item.set_metadata(1, company.cash)
		item.set_metadata(2, company.revenue)
		item.set_metadata(3, company.profit())
		if is_player:
			item.set_custom_color(0, ModernUITheme.ACCENT)
			for column: int in range(4):
				item.set_custom_bg_color(column, ModernUITheme.SURFACE_RAISED)
		if company.profit() < 0:
			item.set_custom_color(3, ModernUITheme.NEGATIVE)

func comparison(label: String, local: String, average: String) -> void:
	var row: TreeItem = add_row(label, local)
	row.set_text(2, average)
	row.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)

func _market(sim: Economy) -> void:
	if products.item_count == 0:
		var ids: Array = sim.catalog.products.keys()
		ids.sort()
		for id: String in ids:
			if not sim.catalog.consumer_product(id):
				continue
			products.add_item(sim.catalog.products[id].name)
			products.set_item_metadata(products.item_count - 1, id)
	var product: String = str(products.get_item_metadata(products.selected))
	var definition: Dictionary = sim.catalog.products[product]
	var owner: SimCompany = sim.companies[session.player_company]
	advertising_budget.set_value_no_signal(int(owner.advertising_budgets[product]) / 100.0)
	var category: Dictionary = sim.category_market.get(definition.category, {})
	var market: Dictionary = sim.market.get(product, ConsumerMarket.empty_report())
	var local: Dictionary = ConsumerMarket.local_offer(sim, product)
	var realized: bool = int(market.units) > 0
	_set_report("Markets", "%s • %s • %s" % [definition.name, definition.category, "Public" if sim.product_public(product) else "Era locked"], "Category potential %d / purchased %d • no purchase or unfilled %d" % [category.get("potential", 0), category.get("units", 0), int(category.get("potential", 0)) - int(category.get("units", 0))])
	comparison("Price", money(local.price) if not local.is_empty() else "—", money(int(round(market.average_price))) if realized else "—")
	comparison("Quality", str(local.quality) if not local.is_empty() else "—", "%.1f" % market.average_quality if realized else "—")
	comparison("Brand", str(local.brand) if not local.is_empty() else "—", "%.1f" % market.average_brand if realized else "—")
	comparison("Overall / 100", "%.1f" % ConsumerDemand.overall(local.price, definition.reference_price, local.quality, local.brand) if not local.is_empty() else "—", "%.1f" % market.average_overall if realized else "—")
	comparison("Units / realized share", "%d / %.1f%%" % [market.local_units, market.local_share * 100] if not local.is_empty() else "—", "%d / 100%%" % market.units if realized else "—")
	comparison("Your company brand", str(owner.brand(product)), "")
	comparison("Advertising budget / day", money(int(owner.advertising_budgets[product])), "")
	comparison("Advertising progress / next point", "%s / %s" % [money(int(owner.advertising_progress[product])), money(sim.advertising_threshold(product, owner.brand(product))) if owner.brand(product) < 100 else "MAX"], "")
	comparison("Inactive advertising days", str(owner.advertising_inactive_days[product]), "")
	comparison("CORPORATE OFFERS", "Price / stock quality", "Brand / sold / share")
	if sim.product_public(product):
		for facility: SimFacility in sim.facilities:
			if sim._behavior(facility) != "retail" or not facility.assortment.has(product):
				continue
			var sold: int = int(facility.line_today.get(product, {}).get("units", 0))
			var share: float = float(sold) / int(market.units) if realized else 0.0
			comparison(sim.companies[facility.company_id].display_name + " • " + facility.id, money(facility.line_price(product)) + " / " + facility.inventory.quality_text(product), "%d / %d / %.1f%%" % [sim.companies[facility.company_id].brand(product), sold, share * 100])
	comparison("COMPANY PRODUCT SHARES", "All retailers combined", "")
	for company: String in market.market_share:
		comparison(sim.companies[company].display_name, "%.1f%%" % (float(market.market_share[company]) * 100), "")
	var segments: Array[String] = []
	for segment: String in category.get("segments", {}):
		segments.append("%s %d" % [segment, category.segments[segment]])
	for index: int in range(0, segments.size(), 3):
		comparison("Potential: " + segments[index], segments[index + 1] if index + 1 < segments.size() else "", segments[index + 2] if index + 2 < segments.size() else "")
	var units: int = 0
	for record: Dictionary in sim.market_history:
		units += int(record.categories.get(definition.category, {}).get("units", 0))
	comparison("Category 90-day units (incl. Local)", str(units), "")
	table.tooltip_text = "Completed-day sales include Local; outside/no-purchase has no share. Corporate prices and quality describe current stock. Averages weight completed-day sales. Overall averages three scores: price competitiveness, quality and brand."
