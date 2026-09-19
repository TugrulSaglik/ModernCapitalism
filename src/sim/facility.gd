class_name SimFacility
extends RefCounted

const Inventory = preload("res://src/sim/inventory.gd")
var id: String
var company_id: String
var city_id: String
var type_id: String
var research_project: String = ""
var product_id: String
var capacity: int
var price: int
var quality: int
var active: bool = true
var sold_today: int = 0
var produced_today: int = 0
var operating: bool = true
var stock_days: int = 2
var suppliers: Dictionary = {}
var last_sources: Dictionary = {}
var recent_sales: Array[Dictionary] = []
var asset_cost: int = 0
var accumulated_depreciation: int = 0
var asset_days: int = 0
var replenishment_targets: Dictionary = {}
var inventory: SimInventory = Inventory.new()
var assortment: Dictionary = {}
var line_sales: Dictionary = {}
var line_today: Dictionary = {}
var product_history: Array[Dictionary] = []

func line_ids() -> Array:
	var ids: Array = assortment.keys()
	ids.sort()
	return ids

func line_price(product: String) -> int:
	return price if product == product_id else int(assortment.get(product, price))

func _init(definition: Dictionary) -> void:
	id = str(definition.id)
	company_id = str(definition.company)
	city_id = str(definition.city)
	type_id = str(definition.type)
	product_id = str(definition.get("product", ""))
	capacity = int(definition.capacity)
	price = int(definition.get("price", 0))
	quality = int(definition.quality)
	if not product_id.is_empty(): assortment[product_id] = price

func snapshot() -> Dictionary:
	return {"research_project": research_project, "id": id, "company": company_id, "city": city_id, "type": type_id,
		"assortment": assortment.duplicate(true), "line_sales": line_sales.duplicate(true),
		"line_today": line_today.duplicate(true), "product_history": product_history.duplicate(true),
		"asset_cost": asset_cost, "accumulated_depreciation": accumulated_depreciation, "asset_days": asset_days,
		"replenishment_targets": replenishment_targets.duplicate(true),
		"product": product_id, "capacity": capacity, "price": price, "quality": quality,
		"active": active, "sold_today": sold_today, "produced_today": produced_today,
		"operating": operating, "stock_days": stock_days,
		"suppliers": suppliers.duplicate(true), "last_sources": last_sources.duplicate(true),
		"recent_sales": recent_sales.duplicate(true),
		"inventory": inventory.snapshot()}
