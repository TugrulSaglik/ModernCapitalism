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
		"capital": capital, "revenue": revenue, "cogs": cogs, "expenses": expenses,
		"profit": profit(), "daily_revenue": daily_revenue,
		"daily_cogs": daily_cogs, "daily_expenses": daily_expenses,
		"daily_profit": daily_revenue - daily_cogs - daily_expenses}
