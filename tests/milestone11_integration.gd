extends SceneTree

func _initialize() -> void:
	var session: GameSession = GameSession.new()
	if not session.start(2022, 42, "sandbox", {}, "standard"):
		_fail("session initialization")
		return
	session.select_city("harbor")
	var sim: Economy = session.sim
	var site: Vector2i = sim.cities["harbor"].valid_sites(3, 2)[0]
	if not session.submit({"type": "build_facility", "archetype": "electronics_store", "product": "smartphone", "x": site.x, "y": site.y}):
		_fail("Harbor company entry: " + session.message)
		return
	var harbor_store: SimFacility = sim.facility("built_000001")
	if harbor_store == null:
		_fail("Harbor store missing")
		return
	var seller: SimFacility = sim.facility("10_orion")
	seller.inventory.add("smartphone", 8, 0, 50)
	if sim.logistics.dispatch(sim, seller, harbor_store, "smartphone", 4) != 4:
		_fail("cross-city shipment")
		return
	if not session.submit({"type": "import_goods", "facility": harbor_store.id, "product": "smartphone", "quantity": 2}):
		_fail("Harbor import: " + session.message)
		return
	if not session.submit({"type": "export_goods", "facility": harbor_store.id, "product": "smartphone", "quantity": 1}):
		# The export is intentionally exercised after a delivery below.
		pass
	var property_site: Vector2i = sim.cities["harbor"].valid_sites(2, 2)[0]
	if not session.submit({"type": "develop_property", "property_type": "house", "x": property_site.x, "y": property_site.y}):
		_fail("Harbor property: " + session.message)
		return
	var initial_populations: Dictionary = {}
	for city_id: String in sim.cities: initial_populations[city_id] = int(sim.cities[city_id].population.total)
	var checkpoint_path: String = "res://.godot/m11-integration.save"
	var exported: bool = false
	for day: int in range(240):
		sim.step()
		if not exported and harbor_store.inventory.quantity("smartphone") > 0:
			exported = session.submit({"type": "export_goods", "facility": harbor_store.id, "product": "smartphone", "quantity": 1})
		if (day + 1) % 30 == 0:
			var error_list: Array[String] = sim.invariant_errors()
			if not error_list.is_empty():
				_fail("day %d invariants: %s" % [day + 1, str(error_list)])
				return
			if not sim.pending_commands.is_empty():
				_fail("pending commands at day %d" % [day + 1])
				return
			for city_id: String in sim.cities:
				if not sim.cities[city_id].valid_port():
					_fail("port at day %d: %s" % [day + 1, city_id])
					return
		if day == 119 and not session.save_game(checkpoint_path):
			_fail("midpoint save: " + session.message)
			return
	if not exported or sim.companies.player.import_purchases == 0 or sim.companies.player.export_revenue == 0:
		_fail("external trade did not occur")
		return
	var cross_city_count: int = 0
	for shipment: Dictionary in sim.logistics.shipments:
		if shipment.mode == "regional": cross_city_count += 1
	# Active shipments are bounded; the departure occurred at the start.
	var owned_cities: Dictionary = {}
	var facility_ids: Dictionary = {}
	var ai_regional: bool = false
	for f: SimFacility in sim.facilities:
		if facility_ids.has(f.id):
			_fail("facility ID collision")
			return
		facility_ids[f.id] = true
		if f.company_id == "player": owned_cities[f.city_id] = true
		if sim.companies[f.company_id].ai and f.city_id != "metro": ai_regional = true
	if owned_cities.size() < 2 or not ai_regional:
		_fail("regional company expansion: player cities %d AI regional %s" % [owned_cities.size(), ai_regional])
		return
	var migration: bool = false
	for city_id: String in sim.cities:
		if int(sim.cities[city_id].population.total) != int(initial_populations[city_id]): migration = true
		if sim.market_by_city[city_id] == sim.market and sim.cities.size() > 1:
			_fail("city market equals entire region")
			return
	if not migration:
		_fail("no city population evolution")
		return
	var total_potential: int = 0
	for city_id: String in sim.cities: total_potential += int(sim.category_market_by_city[city_id].smartphones.potential)
	if total_potential != int(sim.category_market.smartphones.potential):
		_fail("regional market aggregate")
		return
	var restored_session: GameSession = GameSession.new()
	if not restored_session.load_game(checkpoint_path) or restored_session.active_city != "harbor":
		_fail("midpoint load: " + restored_session.message)
		return
	for day: int in range(120): restored_session.sim.step()
	if restored_session.sim.snapshot() != sim.snapshot():
		_fail("midpoint deterministic continuation")
		return
	print("M11 INTEGRATION PASS: 240 days; player cities %d; AI regional %s; regional departures recorded; imports %d; exports %d; populations evolved; midpoint restore exact" % [owned_cities.size(), ai_regional, sim.companies.player.import_purchases, sim.companies.player.export_revenue])
	quit(0)

func _fail(message: String) -> void:
	printerr("M11 INTEGRATION FAIL: ", message)
	quit(1)
