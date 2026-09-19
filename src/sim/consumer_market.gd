class_name ConsumerMarket
extends RefCounted

# Shares are positive weights; integer rounding residue goes in stable ID order.
static func district_segments(catalog: SimCatalog, population: int, income: int) -> Dictionary:
	var result: Dictionary = {}
	var weights: Dictionary = {}
	var total: float = 0.0
	var ids: Array = catalog.segments.keys()
	ids.sort()
	for id: String in ids:
		var s: Dictionary = catalog.segments[id]
		weights[id] = maxf(5.0, float(s.share) + (income - 100) * float(s.income_slope))
		total += float(weights[id])
	var assigned: int = 0
	for id: String in ids:
		result[id] = int(maxi(0, population) * float(weights[id]) / total)
		assigned += int(result[id])
	for index: int in range(maxi(0, population) - assigned): result[ids[index % ids.size()]] += 1
	return result

static func populations(sim: Economy) -> Dictionary:
	var result: Dictionary = {}
	for id: String in sim.catalog.segments: result[id] = 0
	if int(sim.city.population.total) == 0: return result
	if sim.city.districts.is_empty():
		return district_segments(sim.catalog, sim.city.population.total, sim.city.population.purchasing_power)
	var ids: Array = sim.city.districts.keys()
	ids.sort()
	for id: String in ids:
		var d: Dictionary = sim.city.districts[id]
		var counts: Dictionary = district_segments(sim.catalog, d.population, d.purchasing_power)
		for segment: String in counts: result[segment] += int(counts[segment])
	return result

static func potential(category: Dictionary, segment: Dictionary, count: int, income: int, shock: int) -> int:
	var power: float = maxf(0.0, income * float(segment.purchasing_power) / 10000.0)
	return int(count * float(category.daily_demand) / 5000.0 * float(category.purchase_frequency) * pow(power, float(category.income_sensitivity)) * float(segment.category_preferences.get(category.id, 1.0)) * shock / 100.0)

static func clear(sim: Economy) -> void:
	var counts: Dictionary = populations(sim)
	var categories: Array = sim.catalog.categories.keys()
	categories.sort()
	var segments: Array = sim.catalog.segments.keys()
	segments.sort()
	var products: Array = sim.catalog.products.keys()
	products.sort()
	for product: String in products:
		if sim.product_public(product): sim.market[product] = {"potential": 0, "units": 0, "revenue": 0, "average_price": 0.0, "company_units": {}, "market_share": {}}
	sim.category_market.clear()
	for category_id: String in categories:
		var category: Dictionary = sim.catalog.categories[category_id]
		var shock: int = sim.rng.randi_range(90, 110)
		var report: Dictionary = {"potential": 0, "units": 0, "revenue": 0, "segments": {}}
		for segment_id: String in segments:
			var segment: Dictionary = sim.catalog.segments[segment_id]
			var demand: int = potential(category, segment, counts[segment_id], sim.city.population.purchasing_power, shock)
			if not sim.technology_public(category.technology): demand = 0
			report.potential += demand
			report.segments[segment_id] = demand
			var offers: Array[Dictionary] = []
			for f: SimFacility in sim.facilities:
				if not f.active or sim._behavior(f) != "retail": continue
				for product: String in f.line_ids():
					var p: Dictionary = sim.catalog.products[product]
					if p.category != category_id or not sim.product_public(product): continue
					offers.append({"facility": f.id, "product": product, "price": f.line_price(product), "reference_price": int(p.reference_price), "quality": f.inventory.quality(product), "stock": mini(f.capacity - f.sold_today, f.inventory.quantity(product)), "price_sensitivity": float(segment.price_sensitivity), "quality_sensitivity": float(segment.quality_sensitivity)})
			var allocation: Array[int] = ConsumerDemand.allocate(demand, offers)
			for index: int in range(offers.size()):
				var offer: Dictionary = offers[index]
				var f: SimFacility = sim.facility(offer.facility)
				var sold: int = sim.consumer_sale(f, allocation[index], offer.product)
				var revenue: int = sold * int(offer.price)
				var m: Dictionary = sim.market[offer.product]
				m.units += sold
				m.revenue += revenue
				m.company_units[f.company_id] = int(m.company_units.get(f.company_id, 0)) + sold
				report.units += sold
				report.revenue += revenue
		for product: String in products:
			if sim.market.has(product) and sim.catalog.products[product].category == category_id:
				var m: Dictionary = sim.market[product]
				# Category potential is shared, not additional demand for each variant.
				m.potential = report.potential
				m.average_price = float(m.revenue) / int(m.units) if int(m.units) > 0 else 0.0
				for company: String in m.company_units: m.market_share[company] = float(m.company_units[company]) / int(m.units) if int(m.units) > 0 else 0.0
		sim.category_market[category_id] = report
		sim.cumulative_consumer_units += int(report.units)
		sim.cumulative_consumer_revenue += int(report.revenue)
	sim.market_history.append({"date": sim.clock.date_string(), "categories": sim.category_market.duplicate(true)})
	if sim.market_history.size() > 90: sim.market_history.pop_front()
