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

# Derived static offer; no company, facility, stock ledger or cash exists for Local.
static func local_offer(sim: Economy, product: String) -> Dictionary:
	return sim.catalog.local_values(product) if sim.product_public(product) else {}

static func empty_report() -> Dictionary:
	return {"potential": 0, "units": 0, "revenue": 0, "quality_total": 0, "brand_total": 0,
		"average_price": 0.0, "average_quality": 0.0, "average_brand": 0.0,
		"average_overall": 0.0, "local_units": 0, "local_share": 0.0,
		"company_units": {}, "market_share": {}}

static func finish_report(m: Dictionary, reference_price: int) -> void:
	var units: int = int(m.units)
	m.average_price = float(m.revenue) / units if units > 0 else 0.0
	m.average_quality = float(m.quality_total) / units if units > 0 else 0.0
	m.average_brand = float(m.brand_total) / units if units > 0 else 0.0
	m.average_overall = ConsumerDemand.overall(m.average_price, reference_price, m.average_quality, m.average_brand)
	m.local_share = float(m.local_units) / units if units > 0 else 0.0
	m.market_share.clear()
	for company: String in m.company_units:
		m.market_share[company] = float(m.company_units[company]) / units if units > 0 else 0.0

static func clear(sim: Economy) -> void:
	var counts: Dictionary = populations(sim)
	var categories: Array = sim.catalog.categories.keys()
	categories.sort()
	var segments: Array = sim.catalog.segments.keys()
	segments.sort()
	var products: Array = sim.catalog.products.keys()
	products.sort()
	sim.market.clear()
	for product: String in products:
		if sim.product_public(product): sim.market[product] = empty_report()
	sim.category_market.clear()
	for category_id: String in categories:
		var category: Dictionary = sim.catalog.categories[category_id]
		var shock: int = sim.rng.randi_range(90, 110)
		var report: Dictionary = {"potential": 0, "units": 0, "revenue": 0, "local_units": 0, "local_revenue": 0, "segments": {}}
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
					if p.category != category_id or not sim.product_public(product) or not sim.catalog.consumer_product(product): continue
					offers.append({"facility": f.id, "product": product, "price": f.line_price(product), "reference_price": int(p.reference_price), "quality": f.inventory.quality(product), "brand": sim.companies[f.company_id].brand(product), "stock": mini(f.capacity - f.sold_today, f.inventory.quantity(product)), "price_sensitivity": float(segment.price_sensitivity), "quality_sensitivity": float(segment.quality_sensitivity)})
			# Stable corporate-ID order followed by sorted Local product IDs.
			for product: String in products:
				if sim.catalog.products[product].category != category_id: continue
				var local: Dictionary = local_offer(sim, product)
				if local.is_empty(): continue
				local.merge({"reference_price": int(sim.catalog.products[product].reference_price), "stock": demand,
					"price_sensitivity": float(segment.price_sensitivity), "quality_sensitivity": float(segment.quality_sensitivity)})
				offers.append(local)
			var allocation: Array[int] = ConsumerDemand.allocate(demand, offers)
			for index: int in range(offers.size()):
				var offer: Dictionary = offers[index]
				var sold: int = allocation[index]
				var m: Dictionary = sim.market[offer.product]
				if offer.has("facility"):
					var f: SimFacility = sim.facility(offer.facility)
					sold = sim.consumer_sale(f, sold, offer.product)
					m.company_units[f.company_id] = int(m.company_units.get(f.company_id, 0)) + sold
				else:
					m.local_units += sold
					report.local_units += sold
					report.local_revenue += sold * int(offer.price)
				var revenue: int = sold * int(offer.price)
				m.units += sold
				m.revenue += revenue
				m.quality_total += sold * int(offer.quality)
				m.brand_total += sold * int(offer.brand)
				report.units += sold
				report.revenue += revenue
		for product: String in products:
			if sim.market.has(product) and sim.catalog.products[product].category == category_id:
				var m: Dictionary = sim.market[product]
				# Potential belongs to the shared category, not each variant separately.
				m.potential = report.potential
				finish_report(m, int(sim.catalog.products[product].reference_price))
		sim.category_market[category_id] = report
		sim.cumulative_consumer_units += int(report.units)
		sim.cumulative_consumer_revenue += int(report.revenue)
	sim.market_history.append({"date": sim.clock.date_string(), "categories": sim.category_market.duplicate(true)})
	if sim.market_history.size() > 90: sim.market_history.pop_front()
