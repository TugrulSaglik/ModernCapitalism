class_name CompanyReports
extends VBoxContainer

signal command_requested(command: Dictionary)

const PERIOD_KEYS: Array[String] = ["current_month", "previous_month", "ttm", "year"]
const TAB_TITLES: Array[String] = ["Income Statement", "Balance Sheet", "Cash Flow", "Markets", "History", "Companies", "Finance", "Properties", "Trade"]

class ReportScroll:
	extends ScrollContainer
	func _get_minimum_size() -> Vector2:
		return Vector2(0, 250)

var session: GameSession
var tabs: TabBar
var periods: OptionButton
var products: OptionButton
var market_city: OptionButton
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
var report_controls: HBoxContainer
var market_content: VBoxContainer
var market_metadata: Label
var market_overview: Tree
var advertising_summary: Tree
var market_benchmark: Tree
var corporate_offers: Tree
var company_shares: Tree
var segment_potential: Tree
var finance_content: VBoxContainer
var securities_tree: Tree
var portfolio_tree: Tree
var security_details: Tree
var capital_tree: Tree
var prices_tree: Tree
var security_choice: OptionButton
var trade_quantity: SpinBox
var issue_quantity: SpinBox
var dividend_amount: SpinBox
var trade_content: VBoxContainer
var trade_city: OptionButton
var trade_product: OptionButton
var import_destination: OptionButton
var export_source: OptionButton
var import_quantity: SpinBox
var export_quantity: SpinBox
var trade_market_details: Label
var import_quote_details: Label
var export_quote_details: Label

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
	report_controls = HBoxContainer.new()
	report_controls.name = "ReportControls"
	add_child(report_controls)
	period_label = _control_label(report_controls, "REPORT PERIOD")
	periods = OptionButton.new()
	periods.custom_minimum_size.x = 210
	for title: String in ["Current month", "Previous month", "Trailing 12 months", "Current year"]:
		periods.add_item(title)
	report_controls.add_child(periods)
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
	_build_market_content()
	_build_finance_content()
	_build_trade_content()
	report_note = Label.new()
	report_note.theme_type_variation = "MetaLabel"
	report_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(report_note)
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	periods.item_selected.connect(func(_index: int) -> void: refresh())
	products.item_selected.connect(func(_index: int) -> void: refresh())
	market_city.item_selected.connect(func(_index: int) -> void: refresh())
	apply_advertising.pressed.connect(func() -> void:
		if products.selected >= 0:
			command_requested.emit({"type": "set_advertising_budget", "product": str(products.get_item_metadata(products.selected)), "budget": int(round(advertising_budget.value * 100.0))}))

func _build_market_content() -> void:
	market_content = VBoxContainer.new()
	market_content.name = "MarketsContent"
	market_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_content.add_theme_constant_override("separation", ModernUITheme.SPACE_3)
	report_scroll.add_child(market_content)
	_section_label(market_content, "PRODUCT")
	var city_row: HBoxContainer = HBoxContainer.new()
	market_content.add_child(city_row)
	_control_label(city_row, "LOCATION")
	market_city = OptionButton.new()
	market_city.name = "MarketLocationSelector"
	market_city.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_row.add_child(market_city)
	var product_row: HBoxContainer = HBoxContainer.new()
	market_content.add_child(product_row)
	market_label = _control_label(product_row, "PRODUCT")
	products = OptionButton.new()
	products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_row.add_child(products)
	market_metadata = Label.new()
	market_metadata.name = "ProductMetadata"
	market_metadata.theme_type_variation = "MetaLabel"
	market_content.add_child(market_metadata)

	_section_label(market_content, "MARKET OVERVIEW")
	market_overview = _market_tree(market_content, 2, ["Metric", "Current"], [4, 2])

	_section_label(market_content, "ADVERTISING / BRAND")
	advertising_summary = _market_tree(market_content, 2, ["Metric", "Current"], [4, 2])
	var budget_row: HBoxContainer = HBoxContainer.new()
	market_content.add_child(budget_row)
	_control_label(budget_row, "DAILY BUDGET")
	advertising_budget = SpinBox.new()
	advertising_budget.min_value = 0
	advertising_budget.max_value = 1000000
	advertising_budget.step = 0.01
	advertising_budget.prefix = "$ "
	advertising_budget.suffix = " / day"
	advertising_budget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	budget_row.add_child(advertising_budget)
	apply_advertising = Button.new()
	apply_advertising.text = "Queue budget"
	apply_advertising.theme_type_variation = "PrimaryButton"
	budget_row.add_child(apply_advertising)
	var advertising_note: Label = Label.new()
	advertising_note.theme_type_variation = "MetaLabel"
	advertising_note.text = "Funded advertising builds retained brand progress. Extended periods without funded advertising can reduce brand."
	advertising_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_content.add_child(advertising_note)

	_section_label(market_content, "LOCAL / MARKET BENCHMARK")
	market_benchmark = _market_tree(market_content, 3, ["Metric", "Local", "Market average"], [3, 2, 2])
	var share_note: Label = Label.new()
	share_note.theme_type_variation = "MetaLabel"
	share_note.text = "Shares describe realized purchases; no-purchase/unfilled demand is shown separately."
	share_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_content.add_child(share_note)

	_section_label(market_content, "CORPORATE OFFERS")
	corporate_offers = _market_tree(market_content, 6, ["Company / facility", "Price", "Quality", "Brand", "Sold", "Share"], [4, 2, 2, 1, 1, 2])

	_section_label(market_content, "REALIZED COMPANY SHARE")
	company_shares = _market_tree(market_content, 3, ["Seller", "Units", "Share"], [4, 2, 2])

	_section_label(market_content, "SEGMENT POTENTIAL")
	segment_potential = _market_tree(market_content, 2, ["Segment", "Potential"], [4, 2])
	market_content.hide()

func _build_finance_content() -> void:
	finance_content = VBoxContainer.new()
	finance_content.name = "FinanceContent"
	finance_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finance_content.add_theme_constant_override("separation", ModernUITheme.SPACE_3)
	report_scroll.add_child(finance_content)
	_section_label(finance_content, "MARKET / SECURITIES")
	securities_tree = _market_tree(finance_content, 7, ["Company", "Status", "Price", "Market cap", "Shares", "Float", "TTM profit"], [3, 1, 1, 2, 2, 2, 2])
	var row: HBoxContainer = HBoxContainer.new()
	finance_content.add_child(row)
	_control_label(row, "SELECTED SECURITY")
	security_choice = OptionButton.new()
	security_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(security_choice)
	security_choice.item_selected.connect(func(_index: int) -> void: refresh())
	security_details = _market_tree(finance_content, 2, ["Metric", "Value"], [3, 2])
	_section_label(finance_content, "TRADE AGAINST PUBLIC FLOAT")
	var trade_row: HBoxContainer = HBoxContainer.new()
	finance_content.add_child(trade_row)
	trade_quantity = _finance_input(trade_row, "Shares", 1000000)
	var buy_button: Button = Button.new()
	buy_button.text = "Buy shares"
	trade_row.add_child(buy_button)
	buy_button.pressed.connect(func() -> void: _trade("buy_shares"))
	var sell_button: Button = Button.new()
	sell_button.text = "Sell shares"
	trade_row.add_child(sell_button)
	sell_button.pressed.connect(func() -> void: _trade("sell_shares"))
	_section_label(finance_content, "CORPORATE PORTFOLIO")
	portfolio_tree = _market_tree(finance_content, 7, ["Company", "Shares", "Ownership", "Cost", "Value", "Unrealized P/L", "Control"], [3, 2, 2, 2, 2, 2, 2])
	_section_label(finance_content, "CAPITAL STRUCTURE")
	capital_tree = _market_tree(finance_content, 2, ["Metric", "Value"], [3, 2])
	var issue_row: HBoxContainer = HBoxContainer.new()
	finance_content.add_child(issue_row)
	issue_quantity = _finance_input(issue_row, "New shares", 1000000)
	var issue_button: Button = Button.new()
	issue_button.text = "Go public / issue shares"
	issue_button.name = "IssueShares"
	issue_row.add_child(issue_button)
	issue_button.pressed.connect(func() -> void: command_requested.emit({"type": "issue_shares", "quantity": int(issue_quantity.value)}))
	var dividend_row: HBoxContainer = HBoxContainer.new()
	finance_content.add_child(dividend_row)
	dividend_amount = _finance_input(dividend_row, "Dividend cents/share", 1000000)
	var dividend_button: Button = Button.new()
	dividend_button.text = "Declare dividend"
	dividend_button.name = "DeclareDividend"
	dividend_row.add_child(dividend_button)
	dividend_button.pressed.connect(func() -> void: command_requested.emit({"type": "declare_dividend", "per_share": int(dividend_amount.value)}))
	_section_label(finance_content, "RECENT DAILY PRICES")
	prices_tree = _market_tree(finance_content, 2, ["Date", "Price"], [3, 2])
	finance_content.hide()

func _build_trade_content() -> void:
	trade_content = VBoxContainer.new()
	trade_content.name = "RegionalTradeContent"
	trade_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_content.add_theme_constant_override("separation", ModernUITheme.SPACE_3)
	report_scroll.add_child(trade_content)
	var location_row: HBoxContainer = HBoxContainer.new()
	trade_content.add_child(location_row)
	_control_label(location_row, "CITY")
	trade_city = OptionButton.new()
	trade_city.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_row.add_child(trade_city)
	var product_row: HBoxContainer = HBoxContainer.new()
	trade_content.add_child(product_row)
	_control_label(product_row, "PRODUCT")
	trade_product = OptionButton.new()
	trade_product.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_row.add_child(trade_product)
	trade_market_details = Label.new()
	trade_market_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_content.add_child(trade_market_details)
	_section_label(trade_content, "IMPORT")
	var import_row: HBoxContainer = HBoxContainer.new()
	trade_content.add_child(import_row)
	_control_label(import_row, "DESTINATION")
	import_destination = OptionButton.new()
	import_destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_row.add_child(import_destination)
	import_quantity = _finance_input(import_row, "UNITS", 100)
	import_quantity.value = 1
	import_quote_details = Label.new()
	trade_content.add_child(import_quote_details)
	var import_button: Button = Button.new()
	import_button.name = "ImportGoodsButton"
	import_button.text = "Import goods"
	import_button.theme_type_variation = "PrimaryButton"
	trade_content.add_child(import_button)
	import_button.pressed.connect(func() -> void:
		if import_destination.selected >= 0 and trade_product.selected >= 0:
			command_requested.emit({"type": "import_goods", "facility": str(import_destination.get_item_metadata(import_destination.selected)), "product": str(trade_product.get_item_metadata(trade_product.selected)), "quantity": int(import_quantity.value)}))
	_section_label(trade_content, "EXPORT")
	var export_row: HBoxContainer = HBoxContainer.new()
	trade_content.add_child(export_row)
	_control_label(export_row, "SOURCE")
	export_source = OptionButton.new()
	export_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_row.add_child(export_source)
	export_quantity = _finance_input(export_row, "UNITS", 10000)
	export_quantity.value = 1
	export_quote_details = Label.new()
	trade_content.add_child(export_quote_details)
	var export_button: Button = Button.new()
	export_button.name = "ExportGoodsButton"
	export_button.text = "Export goods"
	export_button.theme_type_variation = "PrimaryButton"
	trade_content.add_child(export_button)
	export_button.pressed.connect(func() -> void:
		if export_source.selected >= 0 and trade_product.selected >= 0:
			command_requested.emit({"type": "export_goods", "facility": str(export_source.get_item_metadata(export_source.selected)), "product": str(trade_product.get_item_metadata(trade_product.selected)), "quantity": int(export_quantity.value)}))
	trade_city.item_selected.connect(func(_index: int) -> void: refresh())
	trade_product.item_selected.connect(func(_index: int) -> void: refresh())
	import_destination.item_selected.connect(func(_index: int) -> void: refresh())
	export_source.item_selected.connect(func(_index: int) -> void: refresh())
	import_quantity.value_changed.connect(func(_value: float) -> void: refresh())
	export_quantity.value_changed.connect(func(_value: float) -> void: refresh())
	trade_content.hide()

func _finance_input(parent: HBoxContainer, label_text: String, maximum: int) -> SpinBox:
	_control_label(parent, label_text)
	var input: SpinBox = SpinBox.new()
	input.min_value = 1
	input.max_value = maximum
	input.step = 1
	input.rounded = true
	input.value = 1
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(input)
	return input

func _trade(action: String) -> void:
	if security_choice.selected < 0: return
	command_requested.emit({"type": action, "target": str(security_choice.get_item_metadata(security_choice.selected)), "quantity": int(trade_quantity.value)})

func _section_label(parent: Control, text_value: String) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.theme_type_variation = "SectionLabel"
	parent.add_child(label)
	return label

func _market_tree(parent: Control, columns: int, titles: Array[String], ratios: Array[int]) -> Tree:
	var result: Tree = Tree.new()
	result.hide_root = true
	result.column_titles_visible = true
	result.scroll_vertical_enabled = false
	result.scroll_horizontal_enabled = false
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.columns = columns
	for column: int in range(columns):
		result.set_column_title(column, titles[column])
		result.set_column_expand_ratio(column, ratios[column])
		result.set_column_clip_content(column, true)
	parent.add_child(result)
	return result

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
	var owner: SimCompany = sim.companies[session.active_company]
	company_name.text = owner.display_name
	company_date.text = sim.clock.date_string()
	var report_tab: int = tabs.current_tab
	var period_visible: bool = report_tab in [0, 2]
	var market_visible: bool = report_tab == 3
	period_label.visible = period_visible
	periods.visible = period_visible
	report_controls.visible = period_visible
	table.visible = not market_visible and report_tab not in [6, 8]
	market_content.visible = market_visible
	finance_content.visible = report_tab == 6
	trade_content.visible = report_tab == 8
	table.tooltip_text = ""
	match report_tab:
		0: _income_statement(owner, sim.clock)
		1: _balance_sheet(sim, owner)
		2: _cash_flow(owner, sim.clock)
		3: _market(sim)
		4: _history(owner, sim.clock)
		5: _companies(sim)
		6: _finance(sim, owner)
		7: _properties(sim, owner)
		8: _trade_report(sim, owner)

func _income_statement(owner: SimCompany, clock: SimClock) -> void:
	var period: Dictionary = FinancialReports.period(owner, clock, PERIOD_KEYS[periods.selected])
	_setup_table(2, ["Account", "Amount"], [5, 2])
	_set_report("Income Statement", periods.get_item_text(periods.selected), "Investment results are shown separately from product sales.")
	_section("REVENUE")
	amount("Retail sales", int(period.retail_revenue))
	amount("Domestic wholesale sales", int(period.wholesale_revenue))
	amount("Export sales", int(period.export_revenue))
	amount("Property rent", int(period.property_revenue))
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
	amount("Property maintenance", int(period.property_maintenance))
	amount("Other expenses / disposal losses", int(period.other_expenses))
	amount("Total operating expenses", int(period.expenses), "subtotal")
	amount("Operating profit", int(period.revenue) - int(period.cogs) - int(period.expenses), "subtotal")
	_section("INVESTMENT RESULTS")
	amount("Dividend income", int(period.investment_income))
	amount("Realized investment gain / loss", int(period.realized_investment_gain))
	amount("Net profit", int(period.profit), "total")

func _balance_sheet(sim: Economy, owner: SimCompany) -> void:
	var balance: Dictionary = FinancialReports.balance(sim, owner.id)
	_setup_table(2, ["Account", "Amount"], [5, 2])
	_set_report("Balance Sheet", "As of " + sim.clock.date_string())
	_section("ASSETS")
	add_row("Current / liquid", "", false, "group")
	amount("Cash", int(balance.cash))
	amount("On-hand inventory", int(balance.inventory))
	amount("Inventory in transit", int(balance.in_transit))
	amount("Equity investments at cost", int(balance.equity_investments))
	amount("Land at cost", int(balance.land))
	amount("Property buildings at cost", int(balance.property_cost))
	outflow_amount("Less property depreciation", int(balance.property_depreciation))
	amount("Net property buildings", int(balance.net_property), "subtotal")
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
	outflow_amount("Construction", int(period.capex))
	outflow_amount("Land acquisition", int(period.land_capex))
	outflow_amount("Property development/acquisition", int(period.property_capex))
	outflow_amount("Share purchases", int(period.equity_purchase_cash))
	amount("Share sale proceeds", int(period.equity_sale_cash))
	amount("Dividend receipts", int(period.dividend_receipts))
	amount("Net investing cash", int(period.investing_cash), "subtotal")
	_section("FINANCING ACTIVITIES")
	amount("Share issue proceeds", int(period.equity_issue_cash))
	outflow_amount("Dividends paid", int(period.dividends_paid))
	amount("Net financing cash", int(period.financing_cash), "subtotal")
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
	_setup_table(6, ["Company", "Cash", "Revenue", "Profit", "Status", "Market cap"], [3, 2, 2, 2, 1, 2])
	_set_report("Company Comparison", "Cumulative since scenario start", "Revenue includes wholesale transactions; summing firms does not measure consumer spending.")
	for company: SimCompany in sim.companies.values():
		var item: TreeItem = table.create_item(table.get_root())
		var is_player: bool = company.id == session.active_company
		item.set_text(0, company.display_name + ("  •  YOU" if is_player else ""))
		item.set_text(1, money(company.cash))
		item.set_text(2, money(company.revenue))
		item.set_text(3, money(company.profit()))
		var security: Dictionary = sim.equity_market.securities[company.id]
		item.set_text(4, "Public" if security.public else "Private")
		item.set_text(5, money(int(security.quote) * int(security.outstanding)))
		for column: int in range(1, 4):
			item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_metadata(0, company.id)
		item.set_metadata(1, company.cash)
		item.set_metadata(2, company.revenue)
		item.set_metadata(3, company.profit())
		if is_player:
			item.set_custom_color(0, ModernUITheme.ACCENT)
			for column: int in range(6):
				item.set_custom_bg_color(column, ModernUITheme.SURFACE_RAISED)
		if company.profit() < 0:
			item.set_custom_color(3, ModernUITheme.NEGATIVE)

func _properties(sim: Economy, owner: SimCompany) -> void:
	_setup_table(9, ["Property", "City", "Type", "District", "Land basis", "Building NBV", "Occupancy", "Gross rent", "Net rent"], [3, 2, 2, 2, 2, 2, 2, 2, 2])
	_set_report("Properties", "Owned portfolio and city growth", "Land and buildings are carried at cost; rent estimates use current property value and occupancy.")
	var p: Dictionary = sim.cities[session.active_city].population
	_section("CITY OVERVIEW")
	var map: CityMap = sim.cities[session.active_city]
	add_row("City", map.display_name + ", " + str(map.profile.get("country", "")))
	add_row("Population", map.population_text())
	add_row("Housing capacity", map.population_text(int(p.get("housing_capacity", p.capacity))))
	add_row("Workforce / jobs", "%s / %s" % [map.population_text(int(p.get("workforce", 0))), map.population_text(int(p.get("jobs", 0)))])
	add_row("Employed / unemployed", "%s / %s" % [map.population_text(int(p.get("employed", 0))), map.population_text(int(p.get("unemployed", 0)))])
	add_row("Purchasing power", "%d%%" % int(p.purchasing_power))
	_section("PORTFOLIO")
	var gross_total: int = 0
	var land_total: int = 0
	var building_total: int = 0
	var vacant_cells: int = 0
	var vacant_basis: int = 0
	var city_ids: Array = sim.cities.keys()
	city_ids.sort()
	for city_id: String in city_ids:
		var estate: RealEstate = sim.real_estates[city_id]
		land_total += estate.land_assets(owner.id)
		building_total += estate.building_assets(owner.id)
		var ids: Array = estate.properties.keys()
		ids.sort()
		for id: String in ids:
			var b: Dictionary = estate.properties[id]
			if b.owner != owner.id: continue
			var definition: Dictionary = sim.catalog.property_types[str(b.type)]
			var land_basis: int = 0
			for cell: String in b.land_cells: land_basis += int(estate.land[cell].basis)
			var capacity: int = int(definition.residential_capacity) if definition.use == "residential" else int(definition.job_capacity)
			var occupied: int = int(b.population) if definition.use == "residential" else int(b.occupied_jobs)
			var gross: int = estate.gross_rent(sim, b)
			gross_total += gross
			var row: TreeItem = table.create_item(table.get_root())
			var values: Array[String] = [DisplayLabels.property_label(sim, city_id, b), sim.cities[city_id].display_name, str(definition.name), DisplayLabels.district(sim.cities[city_id], str(b.district)), money(land_basis), money(int(b.building_cost) - int(b.depreciation)), "%s / %s" % [sim.cities[city_id].population_text(occupied), sim.cities[city_id].population_text(capacity)], money(gross), money(gross - gross * 25 / 100)]
			for column: int in range(values.size()): row.set_text(column, values[column])
		for cell: String in estate.land:
			var holding: Dictionary = estate.land[cell]
			if holding.owner != owner.id: continue
			var occupied: bool = false
			for b: Dictionary in estate.properties.values():
				if cell in b.land_cells: occupied = true
			for plot: Dictionary in sim.cities[city_id].plots.values():
				if cell in estate.cells(int(plot.x), int(plot.y), int(plot.width), int(plot.depth)): occupied = true
			if not occupied:
				vacant_cells += 1
				vacant_basis += int(holding.basis)
	_section("SUMMARY")
	add_row("Vacant owned land", "%d cells • %s" % [vacant_cells, money(vacant_basis)])
	amount("Land at cost", land_total)
	amount("Property buildings net", building_total)
	amount("Monthly gross rent", gross_total)
	amount("Monthly maintenance", gross_total * 25 / 100)

func _rebuild_choices(choice: OptionButton, entries: Array[Dictionary], preferred: String) -> String:
	var current: String = preferred
	if choice.selected >= 0: current = str(choice.get_item_metadata(choice.selected))
	choice.clear()
	for entry: Dictionary in entries:
		choice.add_item(str(entry.name))
		choice.set_item_metadata(choice.item_count - 1, str(entry.id))
		if str(entry.id) == current: choice.select(choice.item_count - 1)
	if choice.selected < 0 and choice.item_count > 0: choice.select(0)
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""

func _trade_report(sim: Economy, owner: SimCompany) -> void:
	_set_report("Regional Trade", "Public ports connect the company's facilities to the external market.", "Import purchases are inventory; exports are product sales. Freight is an operating expense.")
	var city_entries: Array[Dictionary] = []
	var city_ids: Array = sim.cities.keys()
	city_ids.sort()
	for city_id: String in city_ids: city_entries.append({"id": city_id, "name": sim.cities[city_id].display_name})
	var city_id: String = _rebuild_choices(trade_city, city_entries, session.active_city)
	var product_entries: Array[Dictionary] = []
	var product_ids: Array = sim.catalog.products.keys()
	product_ids.sort()
	for product: String in product_ids:
		if sim.product_public(product): product_entries.append({"id": product, "name": sim.catalog.products[product].name})
	var product: String = _rebuild_choices(trade_product, product_entries, "smartphone")
	if city_id.is_empty() or product.is_empty():
		trade_market_details.text = "No external market is available."
		return
	var import_remaining: int = sim.regional_trade.import_remaining(sim, city_id, product)
	var export_remaining: int = sim.regional_trade.export_remaining(sim, city_id, product)
	trade_market_details.text = "EXTERNAL MARKET  •  %s\nImport %s / unit  •  Quality 50  •  Remaining supply %d\nExport %s / unit  •  Remaining demand %d" % [sim.cities[city_id].display_name, money(sim.regional_trade.import_price(sim, product)), import_remaining, money(sim.regional_trade.export_price(sim, product)), export_remaining]
	var destinations: Array[Dictionary] = []
	var sources: Array[Dictionary] = []
	for f: SimFacility in sim.facilities:
		if f.company_id != owner.id or f.city_id != city_id: continue
		if sim.can_receive(f, product) and not sim.regional_trade.quote(sim, f.id, product, 1, "import").is_empty(): destinations.append({"id": f.id, "name": DisplayLabels.facility(sim, f)})
		if f.inventory.quantity(product) > 0 and not sim.regional_trade.quote(sim, f.id, product, 1, "export").is_empty(): sources.append({"id": f.id, "name": DisplayLabels.facility(sim, f) + " • " + str(f.inventory.quantity(product)) + " units"})
	var destination: String = _rebuild_choices(import_destination, destinations, "")
	var source: String = _rebuild_choices(export_source, sources, "")
	if destination.is_empty(): import_quote_details.text = "No compatible destination facility in this city."
	else:
		var q: Dictionary = sim.regional_trade.quote(sim, destination, product, int(import_quantity.value), "import")
		import_quote_details.text = "Goods %s  •  Freight %s  •  Total %s  •  %d days" % [money(int(q.price) * int(q.quantity)), money(int(q.freight)), money(int(q.price) * int(q.quantity) + int(q.freight)), int(q.lead_days)]
	if source.is_empty(): export_quote_details.text = "No stocked source facility in this city."
	else:
		var q: Dictionary = sim.regional_trade.quote(sim, source, product, int(export_quantity.value), "export")
		export_quote_details.text = "Revenue %s  •  Freight %s  •  Net cash before COGS %s  •  %d days" % [money(int(q.price) * int(q.quantity)), money(int(q.freight)), money(int(q.price) * int(q.quantity) - int(q.freight)), int(q.lead_days)]

func _finance(sim: Economy, owner: SimCompany) -> void:
	_set_report("Corporate Finance", "Managing " + owner.display_name, "Deterministic end-of-day fundamental quotes. Unrealized gains are informational, not profit.")
	var selected: String = ""
	if security_choice.selected >= 0: selected = str(security_choice.get_item_metadata(security_choice.selected))
	security_choice.clear()
	var ids: Array = sim.companies.keys()
	ids.sort()
	for id: String in ids:
		security_choice.add_item(sim.companies[id].display_name)
		security_choice.set_item_metadata(security_choice.item_count - 1, id)
		if id == selected: security_choice.select(security_choice.item_count - 1)
	if security_choice.selected < 0: security_choice.select(0)
	selected = str(security_choice.get_item_metadata(security_choice.selected))
	for target: Tree in [securities_tree, portfolio_tree, security_details, capital_tree, prices_tree]:
		_clear_market_tree(target)
	for id: String in ids:
		var security: Dictionary = sim.equity_market.securities[id]
		var company: SimCompany = sim.companies[id]
		_tree_row(securities_tree, [company.display_name, "Public" if security.public else "Private", money(int(security.quote)), money(int(security.quote) * int(security.outstanding)), str(security.outstanding), str(security.float), money(company.ttm_profit_cached)])
		var position_value: Dictionary = sim.equity_market.position(owner.id, id)
		if int(position_value.shares) > 0:
			var value: int = int(position_value.shares) * int(security.quote)
			_tree_row(portfolio_tree, [company.display_name, str(position_value.shares), "%.4f%%" % sim.equity_market.ownership_percent(owner.id, id), money(int(position_value.cost)), money(value), money(value - int(position_value.cost)), "CONTROLLED" if sim.equity_market.controls(owner.id, id) else "—"])
	var chosen: Dictionary = sim.equity_market.securities[selected]
	var holding: Dictionary = sim.equity_market.position(owner.id, selected)
	var market_value: int = int(holding.shares) * int(chosen.quote)
	var average_cost: float = float(holding.cost) / float(holding.shares) if int(holding.shares) > 0 else 0.0
	for values: Array in [["Price", money(int(chosen.quote))], ["Public float", str(chosen.float)], ["Holding", str(holding.shares)], ["Ownership", "%.4f%%" % sim.equity_market.ownership_percent(owner.id, selected)], ["Average cost / share", "$%.2f" % (average_cost / 100.0)], ["Market value", money(market_value)], ["Unrealized P/L", money(market_value - int(holding.cost))], ["Controller", _controller_name(sim, selected)]]:
		_tree_row(security_details, values)
	var own: Dictionary = sim.equity_market.securities[owner.id]
	var corporate_shares: int = int(own.outstanding) - int(own.founder) - int(own.float)
	for values: Array in [["Status", "Public" if own.public else "Private"], ["Shares outstanding", str(own.outstanding)], ["Founder shares", str(own.founder)], ["Public float", str(own.float)], ["Corporate-held shares", str(corporate_shares)], ["Controller", _controller_name(sim, owner.id)]]:
		_tree_row(capital_tree, values)
	var history: Array = chosen.history.duplicate()
	history.reverse()
	for index: int in range(mini(15, history.size())):
		_tree_row(prices_tree, [str(history[index].date), money(int(history[index].price))])
	_size_market_tree(securities_tree, ids.size())
	_size_market_tree(portfolio_tree, maxi(1, portfolio_tree.get_root().get_child_count()))
	_size_market_tree(security_details, 8)
	_size_market_tree(capital_tree, 6)
	_size_market_tree(prices_tree, mini(15, history.size()))
	var issue_button: Button = finance_content.find_child("IssueShares", true, false)
	issue_button.text = "Issue shares" if own.public else "Go public / issue shares"

func _controller_name(sim: Economy, target: String) -> String:
	var id: String = sim.equity_market.controller(target)
	return sim.companies[id].display_name if not id.is_empty() else "None"

func _market(sim: Economy) -> void:
	if market_city.item_count == 0:
		market_city.add_item("Regional total")
		market_city.set_item_metadata(0, "")
		var city_ids: Array = sim.cities.keys()
		city_ids.sort()
		for city_id: String in city_ids:
			market_city.add_item(sim.cities[city_id].display_name)
			market_city.set_item_metadata(market_city.item_count - 1, city_id)
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
	var owner: SimCompany = sim.companies[session.active_company]
	advertising_budget.set_value_no_signal(int(owner.advertising_budgets[product]) / 100.0)
	var location: String = str(market_city.get_item_metadata(market_city.selected))
	var categories: Dictionary = sim.category_market if location.is_empty() else sim.category_market_by_city[location]
	var markets: Dictionary = sim.market if location.is_empty() else sim.market_by_city[location]
	var history: Array = sim.market_history if location.is_empty() else sim.market_history_by_city[location]
	var category: Dictionary = categories.get(definition.category, {})
	var market: Dictionary = markets.get(product, ConsumerMarket.empty_report())
	var local: Dictionary = ConsumerMarket.local_offer(sim, product)
	var realized: bool = int(market.units) > 0
	var public: bool = sim.product_public(product)
	_set_report("Markets", "Product-market performance and advertising management")
	market_metadata.text = "%s\nCategory: %s  •  %s\nProduct ID: %s" % [definition.name, _catalog_name(sim.catalog.categories, str(definition.category)), "PUBLIC" if public else "ERA LOCKED", product]
	advertising_budget.set_value_no_signal(int(owner.advertising_budgets[product]) / 100.0)
	advertising_budget.editable = public
	apply_advertising.disabled = not public
	apply_advertising.tooltip_text = "" if public else "Advertising is unavailable until this product becomes public."

	var history_units: int = 0
	for record: Dictionary in history:
		history_units += int(record.categories.get(definition.category, {}).get("units", 0))
	_fill_tree(market_overview, [
		["Category potential", str(int(category.get("potential", 0))), int(category.get("potential", 0))],
		["Purchased", str(int(category.get("units", 0))), int(category.get("units", 0))],
		["No purchase / unfilled", str(maxi(0, int(category.get("potential", 0)) - int(category.get("units", 0)))), maxi(0, int(category.get("potential", 0)) - int(category.get("units", 0)))],
		["Product units sold", str(int(market.units)) if realized else "No realized sales today", int(market.units)],
		["Local share", "%.1f%%" % (float(market.local_share) * 100.0) if realized else "—", float(market.local_share)],
		["90-day category activity", "%d units • includes Local" % history_units if not history.is_empty() else "No market history yet", history_units],
	])

	var brand: int = owner.brand(product)
	var progress: int = int(owner.advertising_progress[product])
	var threshold_text: String = "MAX" if brand >= 100 else money(sim.advertising_threshold(product, brand))
	_fill_tree(advertising_summary, [
		["Current company brand", "%d / 100" % brand, brand],
		["Daily advertising budget", money(int(owner.advertising_budgets[product])), int(owner.advertising_budgets[product])],
		["Progress toward next brand point", "MAX" if brand >= 100 else "%s accumulated / %s required" % [money(progress), threshold_text], progress],
		["Next threshold", threshold_text, -1 if brand >= 100 else sim.advertising_threshold(product, brand)],
		["Inactive advertising days", str(int(owner.advertising_inactive_days[product])), int(owner.advertising_inactive_days[product])],
	])

	_fill_tree(market_benchmark, [
		["Price", money(int(local.price)) if not local.is_empty() else "No Local offer", money(int(round(market.average_price))) if realized else "—"],
		["Quality", str(int(local.quality)) if not local.is_empty() else "—", "%.1f" % float(market.average_quality) if realized else "—"],
		["Brand", str(int(local.brand)) if not local.is_empty() else "—", "%.1f" % float(market.average_brand) if realized else "—"],
		["Overall / 100", "%.1f" % ConsumerDemand.overall(local.price, definition.reference_price, local.quality, local.brand) if not local.is_empty() else "—", "%.1f" % float(market.average_overall) if realized else "—"],
		["Units / realized share", "%d / %.1f%%" % [int(market.local_units), float(market.local_share) * 100.0] if not local.is_empty() and realized else "—", "%d / 100.0%%" % int(market.units) if realized else "No realized sales today"],
	])

	_clear_market_tree(corporate_offers)
	var offer_count: int = 0
	if public:
		for facility: SimFacility in sim.facilities:
			if not location.is_empty() and facility.city_id != location: continue
			if sim._behavior(facility) != "retail" or not facility.assortment.has(product):
				continue
			var sold: int = int(facility.line_today.get(product, {}).get("units", 0))
			var share: float = float(sold) / int(market.units) if realized else 0.0
			var company: SimCompany = sim.companies[facility.company_id]
			var offer: TreeItem = _tree_row(corporate_offers, [
				"%s%s • %s • %s" % [company.display_name, " • YOU" if company.id == session.active_company else "", sim.catalog.facility_types[facility.type_id].name, DisplayLabels.facility_location(sim, facility)],
				money(facility.line_price(product)), facility.inventory.quality_text(product), str(company.brand(product)), str(sold), "%.1f%%" % (share * 100.0) if realized else "—"
			], [facility.id, facility.line_price(product), facility.inventory.quality(product), company.brand(product), sold, share])
			if company.id == session.active_company:
				for column: int in range(corporate_offers.columns): offer.set_custom_bg_color(column, ModernUITheme.SURFACE_RAISED)
				offer.set_custom_color(0, ModernUITheme.ACCENT)
			offer_count += 1
	if offer_count == 0:
		_tree_row(corporate_offers, ["No corporate offers currently carry this product.", "", "", "", "", ""], ["empty"])
	_size_market_tree(corporate_offers, maxi(1, offer_count))

	_clear_market_tree(company_shares)
	if realized:
		_tree_row(company_shares, ["Local", str(int(market.local_units)), "%.1f%%" % (float(market.local_share) * 100.0)], ["local", int(market.local_units), float(market.local_share)])
		var company_ids: Array = market.market_share.keys()
		company_ids.sort()
		for company_id: String in company_ids:
			_tree_row(company_shares, [sim.companies[company_id].display_name, str(int(market.company_units.get(company_id, 0))), "%.1f%%" % (float(market.market_share[company_id]) * 100.0)], [company_id, int(market.company_units.get(company_id, 0)), float(market.market_share[company_id])])
	else:
		_tree_row(company_shares, ["No realized sales today.", "0", "—"], ["empty", 0, 0.0])
	_size_market_tree(company_shares, maxi(1, company_shares.get_root().get_child_count()))

	_clear_market_tree(segment_potential)
	var segment_ids: Array = category.get("segments", {}).keys()
	segment_ids.sort()
	if segment_ids.is_empty():
		_tree_row(segment_potential, ["No segment demand is available.", "—"], ["empty", 0])
	else:
		for segment_id: String in segment_ids:
			_tree_row(segment_potential, [_catalog_name(sim.catalog.segments, segment_id), str(int(category.segments[segment_id]))], [segment_id, int(category.segments[segment_id])])
	_size_market_tree(segment_potential, maxi(1, segment_ids.size()))

func _catalog_name(definitions: Dictionary, id: String) -> String:
	return str(definitions.get(id, {"name": id.replace("_", " ").capitalize()}).name)

func _clear_market_tree(target: Tree) -> void:
	target.clear()
	target.create_item()

func _tree_row(target: Tree, values: Array, metadata: Array = []) -> TreeItem:
	var row: TreeItem = target.create_item(target.get_root())
	for column: int in range(mini(values.size(), target.columns)):
		row.set_text(column, str(values[column]))
		if column > 0: row.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
		if column < metadata.size(): row.set_metadata(column, metadata[column])
	return row

func _fill_tree(target: Tree, rows: Array) -> void:
	_clear_market_tree(target)
	for values: Array in rows:
		var row: TreeItem = _tree_row(target, values.slice(0, target.columns))
		if target.columns == 2 and values.size() > 2:
			row.set_metadata(1, values[2])
	_size_market_tree(target, rows.size())

func _size_market_tree(target: Tree, rows: int) -> void:
	target.custom_minimum_size.y = 34 + rows * 27
