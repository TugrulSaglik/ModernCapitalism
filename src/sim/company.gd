class_name SimCompany
extends RefCounted

var id: String
var display_name: String
var ai: bool
var opening_cash: int
var cash: int
var capital: int
var revenue: int = 0
var cogs: int = 0
var expenses: int = 0
var daily_revenue: int = 0
var daily_cogs: int = 0
var daily_expenses: int = 0
var freight: int = 0
var purchases: int = 0
var import_purchases: int = 0
var export_revenue: int = 0
var depreciation: int = 0
var recorded_profit: int = 0
var retail_revenue: int = 0
var production_cash: int = 0
var cash_expenses: int = 0
var capex: int = 0
var land_capex: int = 0
var property_capex: int = 0
var property_revenue: int = 0
var property_maintenance: int = 0
var research_expense: int = 0
var advertising_expense: int = 0
var payroll_expense: int = 0
var equity_purchase_cash: int = 0
var equity_sale_cash: int = 0
var equity_issue_cash: int = 0
var investment_income: int = 0
var realized_investment_gain: int = 0
var dividend_receipts: int = 0
var dividends_paid: int = 0
var ttm_profit_cached: int = 0
# Knowledge maps technology to acquisition tick (-1 = starting-era baseline).
# Completion is permanent here; partial work is removed on completion.
var known_technologies: Dictionary = {}
var research_progress: Dictionary = {}
# Continuous quality capability belongs to the company/product pair. Progress is
# retained separately from technology work and records the exact next target.
var product_quality_levels: Dictionary = {}
var product_quality_progress: Dictionary = {}
# Process efficiency is a separate company/product capability. It affects only
# conversion cash for future production, never recipes or physical quality.
var process_efficiency_levels: Dictionary = {}
var process_efficiency_progress: Dictionary = {}
# Market presence belongs to the seller, never to goods or individual shops.
var product_brands: Dictionary = {}
var advertising_budgets: Dictionary = {}
var advertising_progress: Dictionary = {}
var advertising_inactive_days: Dictionary = {}
# Aggregate personnel state belongs to the company. Facilities only provide the
# live headquarters capacity and management surface.
var staff_counts: Dictionary = {}
# Result of the most recently processed daily payroll. This is persisted because
# completed-day throughput counters may depend on funded management effects.
var staff_payroll_funded: bool = false

func brand(product: String) -> int:
	return int(product_brands.get(product, 0))

func knows(technology: String) -> bool:
	return known_technologies.has(technology)

func product_quality_level(product: String) -> int:
	return int(product_quality_levels.get(product, 0))

func process_efficiency_level(product: String) -> int:
	return int(process_efficiency_levels.get(product, 0))

func staff_count(role: String) -> int:
	return int(staff_counts.get(role, 0))

func total_staff() -> int:
	var total: int = 0
	for count: Variant in staff_counts.values(): total += int(count)
	return total

var recorded_accounts: Dictionary = {}
var archived_months: Array[Dictionary] = []

func accounts() -> Dictionary:
	return {"revenue": revenue, "retail_revenue": retail_revenue, "property_revenue": property_revenue, "export_revenue": export_revenue, "wholesale_revenue": revenue - retail_revenue - property_revenue - export_revenue,
		"cogs": cogs, "expenses": expenses, "research_expense": research_expense, "advertising_expense": advertising_expense, "payroll_expense": payroll_expense, "freight": freight, "depreciation": depreciation,
		"profit": profit(), "purchases": purchases, "import_purchases": import_purchases, "production_cash": production_cash,
		"cash_expenses": cash_expenses, "capex": capex, "land_capex": land_capex, "property_capex": property_capex, "property_maintenance": property_maintenance, "capital": capital, "cash": cash,
		"equity_purchase_cash": equity_purchase_cash, "equity_sale_cash": equity_sale_cash,
		"equity_issue_cash": equity_issue_cash, "investment_income": investment_income,
		"realized_investment_gain": realized_investment_gain, "dividend_receipts": dividend_receipts,
		"dividends_paid": dividends_paid}
var daily_history: Array[Dictionary] = []
var monthly_history: Array[Dictionary] = []

func record_history(clock: SimClock) -> void:
	var date: String = clock.date_string()
	var month: String = date.substr(0, 7)
	var current: Dictionary = accounts()
	if recorded_accounts.is_empty():
		recorded_accounts = current.duplicate()
		for key: String in current: recorded_accounts[key] = 0
		recorded_accounts.cash = opening_cash
		recorded_accounts.capital = opening_cash
	if daily_history.is_empty() or daily_history.back().date != date:
		daily_history.append({"date": date, "profit": 0, "opening_cash": int(recorded_accounts.cash)})
	if monthly_history.is_empty() or monthly_history.back().month != month:
		monthly_history.append({"month": month, "profit": 0, "opening_cash": int(recorded_accounts.cash)})
	for key: String in current:
		var delta: int = int(current[key]) - int(recorded_accounts[key])
		for record: Dictionary in [daily_history.back(), monthly_history.back()]: record[key] = int(record.get(key, 0)) + delta
	for record: Dictionary in [daily_history.back(), monthly_history.back()]: record["closing_cash"] = cash
	recorded_accounts = current
	recorded_profit = profit()
	while daily_history.size() > 367: daily_history.pop_front()
	while monthly_history.size() > 13: archived_months.append(monthly_history.pop_front())

func ttm_profit(clock: SimClock) -> int:
	# Rolling calendar-year interval (same date last year, current date].
	var cutoff: String = "%04d-%02d-%02d" % [clock.year - 1, clock.month, mini(clock.day, 28) if clock.month == 2 and clock.day == 29 else clock.day]
	var result: int = 0
	for entry: Dictionary in daily_history:
		if str(entry.date) > cutoff: result += int(entry.profit)
	return result

func _init(definition: Dictionary) -> void:
	id = str(definition.id)
	display_name = str(definition.name)
	ai = bool(definition.ai)
	cash = int(definition.cash)
	capital = cash
	opening_cash = cash

func begin_day() -> void:
	daily_revenue = 0
	daily_cogs = 0
	daily_expenses = 0
	staff_payroll_funded = false

func spend(amount: int) -> bool:
	if amount < 0 or amount > cash:
		return false
	cash -= amount
	return true

func pay_expense(amount: int) -> bool:
	if not spend(amount):
		return false
	cash_expenses += amount
	expenses += amount
	daily_expenses += amount
	return true

func record_sale(amount: int, carrying_cost: int) -> void:
	assert(amount >= 0 and carrying_cost >= 0)
	cash += amount
	revenue += amount
	daily_revenue += amount
	cogs += carrying_cost
	daily_cogs += carrying_cost

func profit() -> int:
	return revenue - cogs - expenses + investment_income + realized_investment_gain

func snapshot() -> Dictionary:
	return {"import_purchases": import_purchases, "export_revenue": export_revenue, "staff_counts": staff_counts.duplicate(true), "staff_payroll_funded": staff_payroll_funded, "product_brands": product_brands.duplicate(true), "advertising_budgets": advertising_budgets.duplicate(true), "advertising_progress": advertising_progress.duplicate(true), "advertising_inactive_days": advertising_inactive_days.duplicate(true), "known_technologies": known_technologies.duplicate(true), "research_progress": research_progress.duplicate(true), "product_quality_levels": product_quality_levels.duplicate(true), "product_quality_progress": product_quality_progress.duplicate(true), "process_efficiency_levels": process_efficiency_levels.duplicate(true), "process_efficiency_progress": process_efficiency_progress.duplicate(true), "opening_cash": opening_cash, "retail_revenue": retail_revenue, "property_revenue": property_revenue, "property_maintenance": property_maintenance, "production_cash": production_cash, "cash_expenses": cash_expenses, "capex": capex, "land_capex": land_capex, "property_capex": property_capex, "recorded_accounts": recorded_accounts.duplicate(true), "archived_months": archived_months.duplicate(true), "id": id, "name": display_name, "ai": ai, "cash": cash,
		"freight": freight, "purchases": purchases, "depreciation": depreciation,
		"recorded_profit": recorded_profit, "daily_history": daily_history.duplicate(true), "monthly_history": monthly_history.duplicate(true),
		"capital": capital, "revenue": revenue, "cogs": cogs, "expenses": expenses, "research_expense": research_expense, "advertising_expense": advertising_expense, "payroll_expense": payroll_expense,
		"equity_purchase_cash": equity_purchase_cash, "equity_sale_cash": equity_sale_cash, "equity_issue_cash": equity_issue_cash,
		"investment_income": investment_income, "realized_investment_gain": realized_investment_gain,
		"dividend_receipts": dividend_receipts, "dividends_paid": dividends_paid, "ttm_profit_cached": ttm_profit_cached,
		"profit": profit(), "daily_revenue": daily_revenue,
		"daily_cogs": daily_cogs, "daily_expenses": daily_expenses,
		"daily_profit": daily_revenue - daily_cogs - daily_expenses}
