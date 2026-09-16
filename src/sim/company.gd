class_name SimCompany
extends RefCounted

var id: String
var display_name: String
var ai: bool
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
var daily_history: Array[Dictionary] = []
var monthly_history: Array[Dictionary] = []

func record_history(clock: SimClock) -> void:
	var date: String = clock.date_string()
	var month: String = date.substr(0, 7)
	var delta: int = profit() - recorded_profit
	if daily_history.is_empty() or daily_history.back().date != date:
		daily_history.append({"date": date, "profit": 0})
	if monthly_history.is_empty() or monthly_history.back().month != month:
		monthly_history.append({"month": month, "profit": 0})
	daily_history.back().profit += delta
	monthly_history.back().profit += delta
	recorded_profit = profit()
	while daily_history.size() > 367: daily_history.pop_front()
	while monthly_history.size() > 13: monthly_history.pop_front()

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
	return {"id": id, "name": display_name, "ai": ai, "cash": cash,
		"freight": freight, "purchases": purchases, "depreciation": depreciation,
		"recorded_profit": recorded_profit, "daily_history": daily_history.duplicate(true), "monthly_history": monthly_history.duplicate(true),
		"capital": capital, "revenue": revenue, "cogs": cogs, "expenses": expenses,
		"profit": profit(), "daily_revenue": daily_revenue,
		"daily_cogs": daily_cogs, "daily_expenses": daily_expenses,
		"daily_profit": daily_revenue - daily_cogs - daily_expenses}
