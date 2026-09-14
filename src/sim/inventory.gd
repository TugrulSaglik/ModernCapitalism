class_name SimInventory
extends RefCounted

var quantities: Dictionary = {}
var costs: Dictionary = {}

func quantity(product: String) -> int:
	return int(quantities.get(product, 0))

func value(product: String) -> int:
	return int(costs.get(product, 0))

func add(product: String, units: int, cost: int) -> bool:
	if units <= 0 or cost < 0:
		return false
	quantities[product] = quantity(product) + units
	costs[product] = value(product) + cost
	return true

# Returns carrying cost, or -1 without mutation if the request is invalid.
func remove(product: String, units: int) -> int:
	var available: int = quantity(product)
	if units <= 0 or units > available:
		return -1
	@warning_ignore("integer_division")
	var removed_cost: int = value(product) if units == available else value(product) * units / available
	quantities[product] = available - units
	costs[product] = value(product) - removed_cost
	return removed_cost

func total_value() -> int:
	var result: int = 0
	for cost: Variant in costs.values():
		result += int(cost)
	return result

func snapshot() -> Dictionary:
	return {"quantities": quantities.duplicate(true), "costs": costs.duplicate(true)}
