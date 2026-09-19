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
var depreciation: int = 0
var recorded_profit: int = 0
var retail_revenue: int = 0
var production_cash: int = 0
var cash_expenses: int = 0
var capex: int = 0
var recorded_accounts: Dictionary = {}
var archived_months: Array[Dictionary] = []

func accounts() -> Dictionary:
	return {"revenue": revenue, "retail_revenue": retail_revenue, "wholesale_revenue": revenue - retail_revenue,
		"cogs": cogs, "expenses": expenses, "freight": freight, "depreciation": depreciation,
		"profit": profit(), "purchases": purchases, "production_cash": production_cash,
		"cash_expenses": cash_expenses, "capex": capex, "capital": capital, "cash": cash}
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
	return revenue - cogs - expenses

func snapshot() -> Dictionary:
	return {"opening_cash": opening_cash, "retail_revenue": retail_revenue, "production_cash": production_cash, "cash_expenses": cash_expenses, "capex": capex, "recorded_accounts": recorded_accounts.duplicate(true), "archived_months": archived_months.duplicate(true), "id": id, "name": display_name, "ai": ai, "cash": cash,
		"freight": freight, "purchases": purchases, "depreciation": depreciation,
		"recorded_profit": recorded_profit, "daily_history": daily_history.duplicate(true), "monthly_history": monthly_history.duplicate(true),
		"capital": capital, "revenue": revenue, "cogs": cogs, "expenses": expenses,
		"profit": profit(), "daily_revenue": daily_revenue,
		"daily_cogs": daily_cogs, "daily_expenses": daily_expenses,
		"daily_profit": daily_revenue - daily_cogs - daily_expenses}
