class_name RealEstate
extends RefCounted

var city_id: String = "metro"

# The city owns geometry; this model owns economic land and building state.
var land: Dictionary = {} # cell -> {owner, basis}
var properties: Dictionary = {} # stable property ID -> economic record
var next_property: int = 1
var baseline_jobs: int = 0

func initialize(sim: Economy) -> void:
	land.clear()
	properties.clear()
	next_property = 1
	baseline_jobs = 0
	if sim.cities[city_id].generation.preset == "legacy": return
	for id: String in sim.cities[city_id].ambient:
		var b: Dictionary = sim.cities[city_id].ambient[id]
		properties[id] = _record(id, str(b.kind), "", int(b.x), int(b.y), sim, 0, int(b.population))
	for id: String in sim.cities[city_id].plots:
		var p: Dictionary = sim.cities[city_id].plots[id]
		for cell: String in cells(int(p.x), int(p.y), int(p.width), int(p.depth)):
			land[cell] = {"owner": str(p.owner), "basis": 0}
	var initial_jobs: int = explicit_jobs(sim)
	baseline_jobs = maxi(0, (int(sim.cities[city_id].population.total) + 1) / 2 - initial_jobs)
	recalculate(sim)

func cells(x: int, y: int, width: int, depth: int) -> Array[String]:
	var result: Array[String] = []
	for cy: int in range(y, y + depth):
		for cx: int in range(x, x + width): result.append(CityMap.key(cx, cy))
	return result

func land_cost(sim: Economy, owner: String, x: int, y: int, width: int, depth: int) -> int:
	var total: int = 0
	for cell: String in cells(x, y, width, depth):
		var holding: Dictionary = land.get(cell, {})
		if not holding.is_empty() and str(holding.owner) != owner: return -1
		if holding.is_empty(): total += int(sim.cities[city_id].parcels.get(cell, {}).get("land_value", 0))
	return total

func land_error(sim: Economy, owner: String, x: int, y: int, width: int, depth: int, vacant: bool = false, except_property: String = "") -> String:
	if sim.cities[city_id].generation.preset == "legacy": return "Real estate is unavailable on the legacy board."
	if width < 1 or depth < 1 or x < 0 or y < 0 or x + width > sim.cities[city_id].width or y + depth > sim.cities[city_id].depth: return "Invalid land footprint."
	var access: bool = false
	for cell: String in cells(x, y, width, depth):
		if cell in sim.cities[city_id].roads or cell in sim.cities[city_id].water: return "Road or water cannot be owned."
		var port: Dictionary = sim.cities[city_id].port
		if not port.is_empty() and cell == CityMap.key(int(port.x), int(port.y)): return "Public port land is unavailable."
		var holding: Dictionary = land.get(cell, {})
		if not holding.is_empty() and str(holding.owner) != owner: return "Another company owns this land."
		var point: PackedStringArray = cell.split(",")
		if sim.cities[city_id].touches_road(int(point[0]), int(point[1])): access = true
	if not access: return "Site must touch a road."
	for id: String in sim.cities[city_id].plots:
		var p: Dictionary = sim.cities[city_id].plots[id]
		if _overlap(x, y, width, depth, p):
			if vacant or str(p.owner) != owner: return "Site overlaps a facility."
	for id: String in sim.cities[city_id].ambient:
		if id == except_property: continue
		var property: Dictionary = sim.cities[city_id].ambient[id]
		if _overlap(x, y, width, depth, property) and (vacant or str(property.owner) != owner): return "Site overlaps a property."
	return ""

func _overlap(x: int, y: int, width: int, depth: int, p: Dictionary) -> bool:
	return x < int(p.x) + int(p.width) and x + width > int(p.x) and y < int(p.y) + int(p.depth) and y + depth > int(p.y)

func buy_land(sim: Economy, owner: String, x: int, y: int, width: int, depth: int) -> void:
	var company: SimCompany = sim.companies[owner]
	for cell: String in cells(x, y, width, depth):
		if land.has(cell): continue
		var basis: int = int(sim.cities[city_id].parcels[cell].land_value)
		company.spend(basis)
		company.land_capex += basis
		land[cell] = {"owner": owner, "basis": basis}

func _record(id: String, type_id: String, owner: String, x: int, y: int, sim: Economy, basis: int, residents: int = 0) -> Dictionary:
	var definition: Dictionary = sim.catalog.property_types[type_id]
	return {"id": id, "type": type_id, "owner": owner, "x": x, "y": y,
		"width": int(definition.width), "depth": int(definition.depth),
		"district": str(sim.cities[city_id].parcels[CityMap.key(x, y)].district),
		"land_cells": cells(x, y, int(definition.width), int(definition.depth)),
		"building_cost": basis, "depreciation": 0, "days": 0,
		"population": residents, "occupied_jobs": 0}

func develop(sim: Economy, owner: String, type_id: String, x: int, y: int) -> String:
	var definition: Dictionary = sim.catalog.property_types[type_id]
	buy_land(sim, owner, x, y, int(definition.width), int(definition.depth))
	var company: SimCompany = sim.companies[owner]
	company.spend(int(definition.cost))
	company.property_capex += int(definition.cost)
	var id: String = "property_%06d" % next_property
	next_property += 1
	var b: Dictionary = _record(id, type_id, owner, x, y, sim, int(definition.cost))
	properties[id] = b
	_visual(sim, b)
	recalculate(sim)
	return id

func acquire(sim: Economy, owner: String, id: String) -> void:
	var b: Dictionary = properties[id]
	var definition: Dictionary = sim.catalog.property_types[str(b.type)]
	buy_land(sim, owner, int(b.x), int(b.y), int(b.width), int(b.depth))
	var company: SimCompany = sim.companies[owner]
	company.spend(int(definition.cost))
	company.property_capex += int(definition.cost)
	b.owner = owner
	b.building_cost = int(definition.cost)
	properties[id] = b
	_visual(sim, b)

func demolish(sim: Economy, id: String) -> void:
	var b: Dictionary = properties[id]
	var loss: int = int(b.building_cost) - int(b.depreciation)
	var company: SimCompany = sim.companies[str(b.owner)]
	company.expenses += loss
	company.daily_expenses += loss
	properties.erase(id)
	sim.cities[city_id].ambient.erase(id)
	sim.cities[city_id].unregister_footprint(id)
	recalculate(sim, true)

func redevelop(sim: Economy, id: String, type_id: String) -> String:
	var old: Dictionary = properties[id]
	var owner: String = str(old.owner)
	var x: int = int(old.x)
	var y: int = int(old.y)
	demolish(sim, id)
	return develop(sim, owner, type_id, x, y)

func _visual(sim: Economy, b: Dictionary) -> void:
	var definition: Dictionary = sim.catalog.property_types[str(b.type)]
	var previous: Dictionary = sim.cities[city_id].ambient.get(str(b.id), {})
	sim.cities[city_id].ambient[str(b.id)] = {"id": str(b.id), "kind": str(b.type), "x": int(b.x), "y": int(b.y),
		"width": int(b.width), "depth": int(b.depth), "district": str(b.district),
		"capacity": int(definition.residential_capacity), "population": int(b.population),
		"height": int(definition.height), "tone": int(previous.get("tone", 1)),
		"roof": int(previous.get("roof", 0)), "orientation": int(previous.get("orientation", 0)), "owner": str(b.owner)}
	sim.cities[city_id].register_footprint(str(b.id), int(b.x), int(b.y), int(b.width), int(b.depth))

func land_assets(owner: String) -> int:
	var amount: int = 0
	for item: Dictionary in land.values():
		if item.owner == owner: amount += int(item.basis)
	return amount

func building_assets(owner: String) -> int:
	var amount: int = 0
	for b: Dictionary in properties.values():
		if b.owner == owner: amount += int(b.building_cost) - int(b.depreciation)
	return amount

func explicit_jobs(sim: Economy) -> int:
	var jobs: int = 0
	for b: Dictionary in properties.values(): jobs += int(sim.catalog.property_types[str(b.type)].job_capacity)
	for f: SimFacility in sim.facilities:
		if f.city_id == city_id and f.operating: jobs += int(sim.catalog.facility_types[f.type_id].jobs)
	return jobs

func recalculate(sim: Economy, clamp_population: bool = false) -> void:
	if sim.cities[city_id].generation.preset == "legacy": return
	var housing: int = 0
	for b: Dictionary in properties.values(): housing += int(sim.catalog.property_types[str(b.type)].residential_capacity)
	var population: int = 0
	for b: Dictionary in properties.values(): population += int(b.population)
	if clamp_population and population > housing: _distribute_residents(sim, housing)
	else:
		for b: Dictionary in properties.values(): _visual(sim, b)
	sim.cities[city_id].recalculate_population()
	var total: int = int(sim.cities[city_id].population.total)
	var workforce: int = total / 2
	var jobs: int = baseline_jobs + explicit_jobs(sim)
	var facility_jobs: int = 0
	for f: SimFacility in sim.facilities:
		if f.city_id == city_id and f.operating: facility_jobs += int(sim.catalog.facility_types[f.type_id].jobs)
	var property_workers: int = mini(maxi(0, workforce - baseline_jobs - facility_jobs), maxi(0, jobs - baseline_jobs - facility_jobs))
	var job_capacity: int = jobs - baseline_jobs - facility_jobs
	var ids: Array = properties.keys()
	ids.sort()
	var assigned: int = 0
	for id: String in ids:
		var b: Dictionary = properties[id]
		var capacity: int = int(sim.catalog.property_types[str(b.type)].job_capacity)
		b.occupied_jobs = mini(capacity, property_workers * capacity / maxi(1, job_capacity))
		assigned += int(b.occupied_jobs)
		properties[id] = b
	for id: String in ids:
		if assigned >= property_workers: break
		var b: Dictionary = properties[id]
		if int(b.occupied_jobs) < int(sim.catalog.property_types[str(b.type)].job_capacity):
			b.occupied_jobs += 1
			assigned += 1
			properties[id] = b
	sim.cities[city_id].population["housing_capacity"] = housing
	sim.cities[city_id].population["workforce"] = workforce
	sim.cities[city_id].population["jobs"] = jobs
	sim.cities[city_id].population["employed"] = mini(workforce, jobs)
	sim.cities[city_id].population["unemployed"] = maxi(0, workforce - jobs)

func migrate(sim: Economy) -> void:
	if sim.cities[city_id].generation.preset == "legacy": return
	recalculate(sim, true)
	var current: int = int(sim.cities[city_id].population.total)
	var target: int = mini(int(sim.cities[city_id].population.housing_capacity) * 95 / 100, int(sim.cities[city_id].population.jobs) * 2)
	var gap: int = target - current
	if gap != 0:
		var movement: int = mini(maxi(1, absi(gap) / 12), maxi(1, current * 2 / 100))
		_distribute_residents(sim, clampi(current + (movement if gap > 0 else -movement), 0, int(sim.cities[city_id].population.housing_capacity)))
	recalculate(sim)

func _distribute_residents(sim: Economy, total: int) -> void:
	var ids: Array = properties.keys()
	ids.sort()
	var capacity: int = 0
	for id: String in ids: capacity += int(sim.catalog.property_types[str(properties[id].type)].residential_capacity)
	var assigned: int = 0
	for id: String in ids:
		var b: Dictionary = properties[id]
		b.population = total * int(sim.catalog.property_types[str(b.type)].residential_capacity) / maxi(1, capacity)
		assigned += int(b.population)
		properties[id] = b
	for id: String in ids:
		if assigned >= total: break
		var b: Dictionary = properties[id]
		if int(b.population) < int(sim.catalog.property_types[str(b.type)].residential_capacity):
			b.population += 1
			assigned += 1
			properties[id] = b
	for id: String in ids: _visual(sim, properties[id])

func monthly_rent(sim: Economy) -> void:
	if sim.cities[city_id].generation.preset == "legacy": return
	var ids: Array = properties.keys()
	ids.sort()
	for id: String in ids:
		var b: Dictionary = properties[id]
		if str(b.owner).is_empty(): continue
		var gross: int = gross_rent(sim, b)
		var maintenance: int = gross * 25 / 100
		var owner: SimCompany = sim.companies[str(b.owner)]
		owner.cash += gross
		owner.revenue += gross
		owner.daily_revenue += gross
		owner.property_revenue += gross
		owner.pay_expense(maintenance)
		owner.property_maintenance += maintenance

func gross_rent(sim: Economy, b: Dictionary) -> int:
	var definition: Dictionary = sim.catalog.property_types[str(b.type)]
	var value: int = int(definition.cost)
	for cell: String in b.land_cells: value += int(sim.cities[city_id].parcels[cell].land_value)
	var occupied: int = int(b.population) if int(definition.residential_capacity) > 0 else int(b.occupied_jobs)
	var capacity: int = int(definition.residential_capacity) if int(definition.residential_capacity) > 0 else int(definition.job_capacity)
	return (value * 12 / 1200) * occupied / maxi(1, capacity)

func depreciate(sim: Economy) -> void:
	for id: String in properties:
		var b: Dictionary = properties[id]
		if str(b.owner).is_empty() or int(b.days) >= 3650: continue
		b.days += 1
		var accumulated: int = int(b.building_cost) * int(b.days) / 3650
		var expense: int = accumulated - int(b.depreciation)
		b.depreciation = accumulated
		properties[id] = b
		var owner: SimCompany = sim.companies[str(b.owner)]
		owner.depreciation += expense
		owner.expenses += expense
		owner.daily_expenses += expense

func snapshot() -> Dictionary:
	return {"city_id": city_id, "land": land.duplicate(true), "properties": properties.duplicate(true), "next_property": next_property, "baseline_jobs": baseline_jobs}

func restore_state(sim: Economy, state: Dictionary) -> bool:
	if state.get("city_id") != city_id or not state.has("land") or not state.land is Dictionary or not state.has("properties") or not state.properties is Dictionary or not state.get("next_property") is int or not state.get("baseline_jobs") is int: return false
	if int(state.next_property) < 1 or int(state.next_property) > 1000000 or int(state.baseline_jobs) < 0: return false
	if sim.cities[city_id].generation.preset == "legacy": return state.land.is_empty() and state.properties.is_empty() and state.next_property == 1 and state.baseline_jobs == 0
	if state.properties.size() != sim.cities[city_id].ambient.size(): return false
	var seen_cells: Dictionary = {}
	for cell: String in state.land:
		var holding: Variant = state.land[cell]
		if not holding is Dictionary or holding.size() != 2 or not holding.get("owner") is String or not holding.get("basis") is int or not sim.companies.has(holding.owner) or holding.basis < 0 or holding.basis > 100000000000000: return false
		if not sim.cities[city_id].parcels.has(cell) or cell in sim.cities[city_id].roads or cell in sim.cities[city_id].water or (not sim.cities[city_id].port.is_empty() and cell == CityMap.key(int(sim.cities[city_id].port.x), int(sim.cities[city_id].port.y))) or holding.basis not in [0, int(sim.cities[city_id].parcels[cell].land_value)]: return false
	for id: String in state.properties:
		var b: Variant = state.properties[id]
		if not b is Dictionary or b.size() != 14 or not sim.cities[city_id].ambient.has(id) or not sim.catalog.property_types.has(str(b.get("type", ""))): return false
		if b.get("id") != id or not b.get("owner") is String or (b.owner != "" and not sim.companies.has(b.owner)): return false
		for field: String in ["x", "y", "width", "depth", "building_cost", "depreciation", "days", "population", "occupied_jobs"]:
			if not b.get(field) is int: return false
		var definition: Dictionary = sim.catalog.property_types[str(b.type)]
		if b.width != definition.width or b.depth != definition.depth or b.x < 0 or b.y < 0 or b.x + b.width > sim.cities[city_id].width or b.y + b.depth > sim.cities[city_id].depth: return false
		if b.get("district") != sim.cities[city_id].parcels[CityMap.key(int(b.x), int(b.y))].district or b.get("land_cells") != cells(int(b.x), int(b.y), int(b.width), int(b.depth)): return false
		if b.building_cost < 0 or b.depreciation < 0 or b.depreciation > b.building_cost or b.days < 0 or b.days > 3650 or b.depreciation != b.building_cost * b.days / 3650: return false
		if b.building_cost != (0 if b.owner == "" else int(definition.cost)): return false
		if b.owner == "" and (b.days != 0 or b.depreciation != 0): return false
		if b.population < 0 or b.population > definition.residential_capacity or b.occupied_jobs < 0 or b.occupied_jobs > definition.job_capacity: return false
		var visual: Dictionary = sim.cities[city_id].ambient[id]
		if visual.kind != b.type or visual.owner != b.owner or visual.x != b.x or visual.y != b.y or visual.population != b.population: return false
		for cell: String in b.land_cells:
			if seen_cells.has(cell): return false
			seen_cells[cell] = true
			if b.owner != "" and state.land.get(cell, {}).get("owner", "") != b.owner: return false
		if id.begins_with("property_"):
			var serial: String = id.trim_prefix("property_")
			if not serial.is_valid_int() or id != "property_%06d" % int(serial) or int(serial) >= state.next_property: return false
		elif id != "ambient_%03d_%03d" % [int(b.x), int(b.y)]: return false
	for id: String in sim.cities[city_id].plots:
		var plot: Dictionary = sim.cities[city_id].plots[id]
		for cell: String in cells(int(plot.x), int(plot.y), int(plot.width), int(plot.depth)):
			if state.land.get(cell, {}).get("owner", "") != plot.owner: return false
	land = state.land.duplicate(true)
	properties = state.properties.duplicate(true)
	next_property = state.next_property
	baseline_jobs = state.baseline_jobs
	var saved_properties: Dictionary = properties.duplicate(true)
	var saved_population: Dictionary = sim.cities[city_id].population.duplicate(true)
	var saved_ambient: Dictionary = sim.cities[city_id].ambient.duplicate(true)
	recalculate(sim)
	return properties == saved_properties and sim.cities[city_id].population == saved_population and sim.cities[city_id].ambient == saved_ambient and invariant_errors(sim).is_empty()

func invariant_errors(sim: Economy) -> Array[String]:
	var errors: Array[String] = []
	if sim.cities[city_id].generation.preset == "legacy": return errors
	var housing: int = 0
	var residents: int = 0
	var occupied_cells: Dictionary = {}
	var district_population: Dictionary = {}
	var district_capacity: Dictionary = {}
	for district: String in sim.cities[city_id].districts:
		district_population[district] = 0
		district_capacity[district] = 0
	for cell: String in land:
		var holding: Dictionary = land[cell]
		if not sim.cities[city_id].parcels.has(cell) or cell in sim.cities[city_id].roads or cell in sim.cities[city_id].water or (not sim.cities[city_id].port.is_empty() and cell == CityMap.key(int(sim.cities[city_id].port.x), int(sim.cities[city_id].port.y))) or not sim.companies.has(str(holding.get("owner", ""))) or int(holding.get("basis", -1)) < 0: errors.append("Invalid land: " + cell)
	for id: String in properties:
		var b: Dictionary = properties[id]
		if not sim.catalog.property_types.has(str(b.type)) or not sim.cities[city_id].ambient.has(id): errors.append("Invalid property: " + id)
		else:
			var definition: Dictionary = sim.catalog.property_types[str(b.type)]
			if b.owner != "" and (not sim.companies.has(str(b.owner)) or _unowned_cells(b)): errors.append("Property land: " + id)
			if int(b.population) < 0 or int(b.population) > int(definition.residential_capacity) or int(b.occupied_jobs) < 0 or int(b.occupied_jobs) > int(definition.job_capacity) or int(b.depreciation) < 0 or int(b.depreciation) > int(b.building_cost): errors.append("Property bounds: " + id)
			if b.land_cells != cells(int(b.x), int(b.y), int(b.width), int(b.depth)) or b.district != sim.cities[city_id].parcels[CityMap.key(int(b.x), int(b.y))].district: errors.append("Property footprint: " + id)
			if sim.cities[city_id].ambient[id].population != b.population or sim.cities[city_id].ambient[id].owner != b.owner: errors.append("Property visual mirror: " + id)
			for cell: String in b.land_cells:
				if occupied_cells.has(cell): errors.append("Overlapping properties: " + id)
				occupied_cells[cell] = true
			housing += int(definition.residential_capacity)
			residents += int(b.population)
			district_population[str(b.district)] = int(district_population.get(str(b.district), 0)) + int(b.population)
			district_capacity[str(b.district)] = int(district_capacity.get(str(b.district), 0)) + int(definition.residential_capacity)
	for id: String in sim.cities[city_id].plots:
		var plot: Dictionary = sim.cities[city_id].plots[id]
		for cell: String in cells(int(plot.x), int(plot.y), int(plot.width), int(plot.depth)):
			if occupied_cells.has(cell) or str(land.get(cell, {}).get("owner", "")) != str(plot.owner): errors.append("Facility property/land overlap: " + id)
	for district: String in sim.cities[city_id].districts:
		if int(sim.cities[city_id].districts[district].population) != int(district_population[district]) or int(sim.cities[city_id].districts[district].capacity) != int(district_capacity[district]): errors.append("District population: " + district)
	var workforce: int = residents / 2
	var jobs: int = baseline_jobs + explicit_jobs(sim)
	if residents != int(sim.cities[city_id].population.total) or housing != int(sim.cities[city_id].population.housing_capacity) or housing != int(sim.cities[city_id].population.capacity) or residents > housing or int(sim.cities[city_id].population.workforce) != workforce or int(sim.cities[city_id].population.jobs) != jobs or int(sim.cities[city_id].population.employed) != mini(workforce, jobs) or int(sim.cities[city_id].population.unemployed) != maxi(0, workforce - jobs): errors.append("City employment/population")
	return errors

func _unowned_cells(b: Dictionary) -> bool:
	for cell: String in b.land_cells:
		if str(land.get(cell, {}).get("owner", "")) != str(b.owner): return true
	return false
