class_name RegionalTrade
extends RefCounted

const IMPORT_CAP: int = 100
var day_tick: int = -1
var import_used: Dictionary = {}
var export_used: Dictionary = {}
var history: Array[Dictionary] = []

func _roll_day(sim: Economy) -> void:
	if day_tick == sim.clock.tick: return
	day_tick = sim.clock.tick
	import_used.clear()
	export_used.clear()

func _key(city_id: String, product: String) -> String:
	return city_id + ":" + product

func import_price(sim: Economy, product: String) -> int:
	return (int(sim.catalog.products[product].reference_price) * 125 + 99) / 100

func export_price(sim: Economy, product: String) -> int:
	return int(sim.catalog.products[product].reference_price) * 110 / 100

func export_cap(sim: Economy, city_id: String, product: String) -> int:
	if not sim.catalog.consumer_product(product): return 50
	var category: String = str(sim.catalog.products[product].category)
	var potential: int = int(sim.category_market_by_city.get(city_id, {}).get(category, {}).get("potential", 0))
	return maxi(10, potential / 2)

func import_remaining(sim: Economy, city_id: String, product: String) -> int:
	return maxi(0, IMPORT_CAP - int(import_used.get(_key(city_id, product), 0)))

func export_remaining(sim: Economy, city_id: String, product: String) -> int:
	return maxi(0, export_cap(sim, city_id, product) - int(export_used.get(_key(city_id, product), 0)))

func quote(sim: Economy, facility_id: String, product: String, quantity: int, mode: String) -> Dictionary:
	var f: SimFacility = sim.facility(facility_id)
	if f == null or not sim.cities.has(f.city_id) or not sim.product_public(product) or quantity < 1 or mode not in ["import", "export"]: return {}
	var city: CityMap = sim.cities[f.city_id]
	if city.port.is_empty(): return {}
	var local_leg: int = city.road_distance_to_port(f.id)
	if local_leg < 0: return {}
	var external_leg: int = int(sim.city_definition(f.city_id).external_trade_distance)
	var distance: int = local_leg + external_leg
	var freight: int = int(sim.logistics.config.base_cents) + distance * quantity * int(sim.logistics.config.cell_unit_cents)
	return {"mode": mode, "city": f.city_id, "port": str(city.port.id), "local_leg": local_leg, "external_leg": external_leg, "distance": distance, "lead_days": maxi(1, ceili(float(distance) / int(sim.logistics.config.cells_per_day))), "freight": freight, "price": import_price(sim, product) if mode == "import" else export_price(sim, product), "quantity": quantity}

func command_error(sim: Economy, command: Dictionary) -> String:
	var mode: String = "import" if command.get("type") == "import_goods" else "export"
	var f: SimFacility = sim.facility(str(command.get("facility", "")))
	if f == null or f.company_id != str(command.get("company", "")): return "Choose an owned facility."
	var product: String = str(command.get("product", ""))
	if not sim.product_public(product): return "Product is not publicly available."
	if not command.get("quantity") is int or int(command.quantity) < 1: return "Quantity must be positive."
	var quantity: int = int(command.quantity)
	if sim.catalog.productless_behavior(sim._behavior(f)): return "Facility cannot hold goods."
	if mode == "import" and not sim.can_receive(f, product): return "Facility cannot receive this product."
	var q: Dictionary = quote(sim, f.id, product, quantity, mode)
	if q.is_empty(): return "No road route to an operating port."
	if mode == "import":
		if quantity > import_remaining(sim, f.city_id, product): return "External supply exhausted today."
		if quantity > sim.logistics.free_capacity(sim, f): return "Destination capacity is full."
		if sim.companies[f.company_id].cash < quantity * int(q.price) + int(q.freight): return "Insufficient cash for import."
	else:
		if quantity > export_remaining(sim, f.city_id, product): return "External demand exhausted today."
		if quantity > f.inventory.quantity(product): return "Insufficient stock."
		if sim.companies[f.company_id].cash + quantity * int(q.price) < int(q.freight): return "Insufficient freight funds."
	return ""

func execute(sim: Economy, command: Dictionary) -> void:
	_roll_day(sim)
	var f: SimFacility = sim.facility(str(command.facility))
	var product: String = str(command.product)
	var quantity: int = int(command.quantity)
	var mode: String = "import" if command.type == "import_goods" else "export"
	var q: Dictionary = quote(sim, f.id, product, quantity, mode)
	var owner: SimCompany = sim.companies[f.company_id]
	var goods_value: int = int(q.price) * quantity
	var shipment: Dictionary = {"id": sim.logistics.next_id, "company": f.company_id, "source": "import:" + f.city_id if mode == "import" else f.id, "destination": f.id if mode == "import" else "export:" + f.city_id,
		"mode": mode, "source_city": f.city_id, "destination_city": f.city_id, "source_port": str(q.port), "destination_port": str(q.port), "regional_distance": int(q.external_leg),
		"product": product, "quantity": quantity, "value": goods_value if mode == "import" else 0, "quality_points": quantity * 50, "departure": sim.clock.tick, "arrival": sim.clock.tick + int(q.lead_days), "transport_cost": int(q.freight), "distance": int(q.distance), "status": "in_transit" if mode == "import" else "exported"}
	if mode == "import":
		owner.spend(goods_value)
		owner.purchases += goods_value
		owner.import_purchases += goods_value
		import_used[_key(f.city_id, product)] = int(import_used.get(_key(f.city_id, product), 0)) + quantity
	else:
		var removed: Dictionary = f.inventory.remove_pooled(product, quantity)
		shipment.quality_points = int(removed.quality_points)
		owner.record_sale(goods_value, int(removed.cost))
		owner.export_revenue += goods_value
		export_used[_key(f.city_id, product)] = int(export_used.get(_key(f.city_id, product), 0)) + quantity
	owner.pay_expense(int(q.freight))
	owner.freight += int(q.freight)
	sim.logistics.shipments.append(shipment)
	sim.logistics.next_id += 1
	_record(sim, f.city_id, product, mode, quantity, goods_value)

func _record(sim: Economy, city_id: String, product: String, mode: String, units: int, value: int) -> void:
	var date: String = sim.clock.date_string()
	if history.is_empty() or history.back().date != date: history.append({"date": date, "cities": {}})
	var cities: Dictionary = history.back().cities
	if not cities.has(city_id): cities[city_id] = {}
	if not cities[city_id].has(product): cities[city_id][product] = {"import_units": 0, "import_value": 0, "export_units": 0, "export_value": 0}
	var record: Dictionary = cities[city_id][product]
	record[mode + "_units"] += units
	record[mode + "_value"] += value
	if history.size() > 90: history.pop_front()

func snapshot() -> Dictionary:
	return {"day_tick": day_tick, "import_used": import_used.duplicate(true), "export_used": export_used.duplicate(true), "history": history.duplicate(true)}
