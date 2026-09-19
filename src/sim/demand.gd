class_name ConsumerDemand
extends RefCounted

# Catalog daily demand is calibrated to 5,000 residents at purchasing power 100.
static func market_size(base: int, population: int, purchasing_power: int = 100, shock: int = 100) -> int:
	return maxi(0, base) * maxi(0, population) * clampi(purchasing_power, 0, 200) * clampi(shock, 0, 200) / 50000000

static func appeal(price: int, reference_price: int, quality: int) -> float:
	if price <= 0 or reference_price <= 0:
		return 0.0
	return clampf(pow(float(reference_price) / price, 1.4) * clampi(quality, 1, 100) / 50.0, 0.001, 100.0)

# Offers arrive in stable ID order. The outside option limits total purchases.
static func allocate(potential: int, offers: Array[Dictionary]) -> Array[int]:
	var allocations: Array[int] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for offer: Dictionary in offers:
		allocations.append(0)
		var weight: float = appeal(int(offer.price), int(offer.reference_price), int(offer.quality)) if int(offer.stock) > 0 else 0.0
		if offer.has("price_sensitivity") and int(offer.stock) > 0 and int(offer.price) > 0:
			weight = clampf(pow(float(offer.reference_price) / int(offer.price), float(offer.price_sensitivity)) * pow(clampi(offer.quality, 1, 100) / 50.0, float(offer.quality_sensitivity)), 0.001, 100.0)
		weights.append(weight)
		total += weight
	var desired: int = int(maxi(0, potential) * total / (1.0 + total))
	for unit: int in range(desired):
		var best: int = -1
		var best_gap: float = -INF
		for index: int in range(offers.size()):
			if allocations[index] >= int(offers[index].stock) or weights[index] <= 0.0:
				continue
			var gap: float = (unit + 1) * weights[index] / total - allocations[index]
			if gap > best_gap:
				best = index
				best_gap = gap
		if best < 0:
			break
		allocations[best] += 1
	return allocations
