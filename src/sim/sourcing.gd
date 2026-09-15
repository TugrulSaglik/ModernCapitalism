class_name SupplierMarket
extends RefCounted

# Lower price per quality point wins. Eligibility precedes ranking; IDs break ties.
# Future landed cost / reliability terms belong here, not in individual products.
static func offers(sim: Economy, buyer: SimFacility, product: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seller: SimFacility in sim.facilities:
		if seller == buyer or seller.city_id != buyer.city_id or seller.product_id != product or str(sim.catalog.facility_types[seller.type_id].behavior) != "production":
			continue
		var stock: int = seller.inventory.quantity(product)
		var eligible: bool = seller.active and seller.operating and sim.available(product) and stock > 0
		result.append({"id": seller.id, "company": seller.company_id, "price": seller.price,
			"quality": seller.quality, "stock": stock, "eligible": eligible,
			"score": float(seller.price) / seller.quality})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.eligible != b.eligible:
			return a.eligible
		# Integer cross multiplication avoids floating-point ranking ties.
		var left: int = int(a.price) * int(b.quality)
		var right: int = int(b.price) * int(a.quality)
		return str(a.id) < str(b.id) if left == right else left < right)
	return result
