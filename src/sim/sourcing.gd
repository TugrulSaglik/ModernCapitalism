class_name SupplierMarket
extends RefCounted

# Compare a standard buyer-sized shipment, with a modest lead-time penalty.
static func offers(sim: Economy, buyer: SimFacility, product: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seller: SimFacility in sim.facilities:
		var storage: bool = sim._behavior(seller) == "storage" and seller.company_id == buyer.company_id and sim._behavior(buyer) != "storage"
		if seller == buyer or seller.city_id != buyer.city_id or not (storage or (seller.product_id == product and sim._behavior(seller) == "production")): continue
		var stock: int = seller.inventory.quantity(product)
		var quantity: int = maxi(1, mini(stock, buyer.capacity))
		var quote: Dictionary = sim.logistics.quote(sim, seller.id, buyer.id, quantity)
		var price: int = seller.price
		if seller.company_id == buyer.company_id:
			price = ceili(float(seller.inventory.value(product)) / maxi(1, stock))
		var landed: int = price + ceili(float(quote.freight) / quantity)
		var effective: int = landed + int(quote.lead_days) * int(sim.logistics.config.lead_penalty_cents)
		result.append({"id": seller.id, "company": seller.company_id, "price": price,
			"quality": seller.quality, "stock": stock, "eligible": seller.active and seller.operating and sim.available(product) and stock > 0 and quote.distance >= 0,
			"distance": quote.distance, "lead_days": quote.lead_days, "freight": quote.freight,
			"quote_quantity": quantity, "landed": landed, "effective": effective, "score": float(effective) / seller.quality})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.eligible != b.eligible: return a.eligible
		var left: int = int(a.effective) * int(b.quality)
		var right: int = int(b.effective) * int(a.quality)
		return str(a.id) < str(b.id) if left == right else left < right)
	return result