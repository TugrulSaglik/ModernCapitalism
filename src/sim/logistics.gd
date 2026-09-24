class_name Logistics
extends RefCounted

var config: Dictionary = {"base_cents": 100, "cell_unit_cents": 2, "cells_per_day": 20, "lead_penalty_cents": 25}
var shipments: Array[Dictionary] = []
var next_id: int = 1

func quote(sim: Economy, source: String, destination: String, quantity: int) -> Dictionary:
	var seller: SimFacility = sim.facility(source)
	var buyer: SimFacility = sim.facility(destination)
	if seller == null or buyer == null or not sim.cities.has(seller.city_id) or not sim.cities.has(buyer.city_id): return {"mode": "invalid", "distance": -1, "source_leg": -1, "regional_leg": -1, "destination_leg": -1, "lead_days": 0, "freight": 0}
	var source_leg: int = 0
	var regional_leg: int = 0
	var destination_leg: int = 0
	var mode: String = "local"
	var distance: int = -1
	if seller.city_id == buyer.city_id:
		distance = sim.cities[seller.city_id].road_distance(source, destination)
	else:
		mode = "regional"
		var source_city: CityMap = sim.cities[seller.city_id]
		var destination_city: CityMap = sim.cities[buyer.city_id]
		if not source_city.port.is_empty() and not destination_city.port.is_empty():
			source_leg = source_city.road_distance_to_port(source)
			destination_leg = destination_city.road_distance_to_port(destination)
			regional_leg = sim.regional_distance(seller.city_id, buyer.city_id)
			if source_leg >= 0 and destination_leg >= 0 and regional_leg >= 0: distance = source_leg + regional_leg + destination_leg
	return {"mode": mode, "distance": distance, "source_leg": source_leg, "regional_leg": regional_leg, "destination_leg": destination_leg, "lead_days": maxi(1, ceili(float(distance) / int(config.cells_per_day))),
		"freight": int(config.base_cents) + maxi(0, distance) * maxi(0, quantity) * int(config.cell_unit_cents)}

func incoming(destination: String, product: String = "") -> int:
	var units: int = 0
	for s: Dictionary in shipments:
		if s.status == "in_transit" and s.destination == destination and (product.is_empty() or s.product == product):
			units += int(s.quantity)
	return units

func used(f: SimFacility) -> int:
	var units: int = 0
	for quantity: int in f.inventory.quantities.values(): units += quantity
	return units

func free_capacity(sim: Economy, f: SimFacility) -> int:
	if sim._behavior(f) == "research": return 0
	return maxi(0, f.capacity - used(f) - incoming(f.id)) if sim._behavior(f) == "storage" else 100000000

func assets(company: String) -> int:
	var value: int = 0
	for s: Dictionary in shipments:
		if s.company == company and s.status == "in_transit": value += int(s.value)
	return value

func dispatch(sim: Economy, seller: SimFacility, buyer: SimFacility, product: String, requested: int) -> int:
	if seller == null or buyer == null or seller == buyer or requested <= 0 or not sim.product_public(product): return 0
	var units: int = mini(requested, mini(seller.inventory.quantity(product), free_capacity(sim, buyer)))
	var q: Dictionary = quote(sim, seller.id, buyer.id, units)
	if q.distance < 0: return 0
	var owner: SimCompany = sim.companies[buyer.company_id]
	var supplier: SimCompany = sim.companies[seller.company_id]
	var price: int = seller.price if owner != supplier else 0
	if price < 0: return 0
	var per_unit: int = price + int(q.distance) * int(config.cell_unit_cents)
	if owner.cash < int(config.base_cents): return 0
	if per_unit > 0: units = mini(units, (owner.cash - int(config.base_cents)) / per_unit)
	if units <= 0: return 0
	q = quote(sim, seller.id, buyer.id, units)
	var removed: Dictionary = seller.inventory.remove_pooled(product, units)
	var value: int = int(removed.cost)
	if owner != supplier:
		owner.spend(units * price)
		supplier.record_sale(units * price, value)
		value = units * price
		owner.purchases += value
	owner.pay_expense(q.freight)
	owner.freight += int(q.freight)
	shipments.append({"id": next_id, "company": buyer.company_id, "source": seller.id, "destination": buyer.id,
		"mode": q.mode, "source_city": seller.city_id, "destination_city": buyer.city_id, "source_port": str(sim.cities[seller.city_id].port.get("id", "")) if q.mode == "regional" else "", "destination_port": str(sim.cities[buyer.city_id].port.get("id", "")) if q.mode == "regional" else "", "regional_distance": int(q.regional_leg),
		"product": product, "quality_points": int(removed.quality_points), "quantity": units, "value": value, "departure": sim.clock.tick,
		"arrival": sim.clock.tick + int(q.lead_days), "transport_cost": int(q.freight), "distance": int(q.distance), "status": "in_transit"})
	next_id += 1
	return units

func deliver(sim: Economy) -> void:
	for s: Dictionary in shipments:
		if s.status == "in_transit" and int(s.arrival) <= sim.clock.tick:
			sim.facility(s.destination).inventory.add_pooled(s.product, s.quantity, s.value, s.quality_points)
			s.status = "delivered"
	# Retain a week of delivered activity; active shipments are never discarded.
	shipments = shipments.filter(func(s: Dictionary) -> bool: return s.status == "in_transit" or int(s.arrival) >= sim.clock.tick - 7)

func snapshot() -> Dictionary:
	return {"config": config.duplicate(true), "shipments": shipments.duplicate(true), "next_id": next_id}
