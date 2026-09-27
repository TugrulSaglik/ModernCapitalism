class_name DisplayLabels
extends RefCounted

static func district(map: CityMap, id: String) -> String:
	return str(map.districts.get(id, {}).get("name", map.display_name))

static func facility_base(sim: Economy, f: SimFacility) -> String:
	var definition: Dictionary = sim.catalog.facility_types[f.type_id]
	var label: String = "%s • %s" % [str(definition.name).capitalize(), sim.companies[f.company_id].display_name]
	if str(definition.behavior) == "production" and sim.catalog.products.has(f.product_id):
		var product: String = str(sim.catalog.products[f.product_id].name).capitalize()
		if label.length() + product.length() < 90: label += " • " + product
	return label.replace("R&d", "R&D")

static func facility_location(sim: Economy, f: SimFacility) -> String:
	var map: CityMap = sim.cities[f.city_id]
	var plot: Dictionary = map.plots.get(f.id, {})
	var parcel: Dictionary = map.parcels.get(CityMap.key(int(plot.get("x", 0)), int(plot.get("y", 0))), {})
	return district(map, str(parcel.get("district", "")))

static func facility(sim: Economy, f: SimFacility) -> String:
	var label: String = facility_base(sim, f)
	var matches: Array[SimFacility] = []
	for other: SimFacility in sim.facilities:
		if facility_base(sim, other) == label: matches.append(other)
	if matches.size() < 2: return label
	var location: String = facility_location(sim, f)
	label += " — " + location
	var same: Array[SimFacility] = []
	for other: SimFacility in matches:
		if facility_location(sim, other) == location: same.append(other)
	if same.size() < 2: return label
	label += " • " + sim.cities[f.city_id].display_name
	var count: int = 0
	for other: SimFacility in same:
		if other.city_id == f.city_id: count += 1
	if count > 1:
		var plot: Dictionary = sim.cities[f.city_id].plots[f.id]
		label += " (%d, %d)" % [plot.x, plot.y]
	return label

static func property_label(sim: Economy, city_id: String, b: Dictionary) -> String:
	return "%s • %s • %s" % [sim.catalog.property_types[str(b.type)].name, district(sim.cities[city_id], str(b.district)), "Unowned" if str(b.owner).is_empty() else sim.companies[str(b.owner)].display_name]

static func parcel_label(map: CityMap, x: int, y: int) -> String:
	var parcel: Dictionary = map.parcels.get(CityMap.key(x, y), {})
	var kind: String = "Water" if map.is_water(x, y) else "Road" if map.is_road(x, y) else "Vacant Land"
	return "%s • %s" % [kind, district(map, str(parcel.get("district", "")))]
