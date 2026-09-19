class_name SimInventory
extends RefCounted

var quantities: Dictionary = {}
var costs: Dictionary = {}
var quality_points: Dictionary = {}

func quantity(product: String) -> int:
	return int(quantities.get(product, 0))

func value(product: String) -> int:
	return int(costs.get(product, 0))

# Integer points are authoritative; offer quality rounds down, empty stock is zero.
func points(product: String) -> int:
	return int(quality_points.get(product, 0))

func quality(product: String) -> int:
	@warning_ignore("integer_division")
	return points(product) / quantity(product) if quantity(product) > 0 else 0

func quality_text(product: String) -> String:
	return "Q%d" % quality(product) if quantity(product) > 0 else "no stock"

# Compatibility default for synthetic callers; production supplies quality explicitly.
func add(product: String, units: int, cost: int, unit_quality: int = 50) -> bool:
	if units <= 0 or unit_quality < 1 or unit_quality > 100: return false
	return add_pooled(product, units, cost, units * unit_quality)

func add_pooled(product: String, units: int, cost: int, points_value: int) -> bool:
	if units <= 0 or cost < 0 or points_value < units or points_value > units * 100:
		return false
	quantities[product] = quantity(product) + units
	costs[product] = value(product) + cost
	quality_points[product] = points(product) + points_value
	return true

# Empty result means invalid request without mutation. Transfer points without re-rounding.
func remove_pooled(product: String, units: int) -> Dictionary:
	var available: int = quantity(product)
	if units <= 0 or units > available: return {}
	@warning_ignore("integer_division")
	var removed_cost: int = value(product) if units == available else value(product) * units / available
	@warning_ignore("integer_division")
	var removed_points: int = (points(product) / available) * units + (points(product) % available) * units / available
	quantities[product] = available - units
	costs[product] = value(product) - removed_cost
	quality_points[product] = points(product) - removed_points
	return {"cost": removed_cost, "quality_points": removed_points}

# Returns carrying cost, or -1 without mutation if the request is invalid.
func remove(product: String, units: int) -> int:
	var removed: Dictionary = remove_pooled(product, units)
	return int(removed.cost) if not removed.is_empty() else -1

func total_value() -> int:
	var result: int = 0
	for cost: Variant in costs.values():
		result += int(cost)
	return result

func snapshot() -> Dictionary:
	return {"quantities": quantities.duplicate(true), "costs": costs.duplicate(true), "quality_points": quality_points.duplicate(true)}
