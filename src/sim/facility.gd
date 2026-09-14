class_name SimFacility
extends RefCounted

const Inventory = preload("res://src/sim/inventory.gd")
var id: String
var company_id: String
var city_id: String
var type_id: String
var product_id: String
var capacity: int
var price: int
var quality: int
var active: bool = true
var sold_today: int = 0
var produced_today: int = 0
var inventory: SimInventory = Inventory.new()

func _init(definition: Dictionary) -> void:
	id = str(definition.id)
	company_id = str(definition.company)
	city_id = str(definition.city)
	type_id = str(definition.type)
	product_id = str(definition.product)
	capacity = int(definition.capacity)
	price = int(definition.price)
	quality = int(definition.quality)

func snapshot() -> Dictionary:
	return {"id": id, "company": company_id, "city": city_id, "type": type_id,
		"product": product_id, "capacity": capacity, "price": price, "quality": quality,
		"active": active, "sold_today": sold_today, "produced_today": produced_today,
		"inventory": inventory.snapshot()}
