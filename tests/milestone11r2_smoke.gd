extends SceneTree

func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var sim: Economy = Economy.new()
	if not sim.initialize(108):
		printerr("11R2 smoke initialization failed")
		quit(1)
		return
	var ok: bool = sim.cities.size() == 3
	for city_id: String in sim.cities:
		var city: CityMap = sim.cities[city_id]
		ok = ok and city.width >= 192 and city.depth >= 144 and CityProfiles.valid(city.profile) and city.valid_port()
		for f: SimFacility in sim.facilities:
			if f.city_id == city_id: ok = ok and city.road_distance_to_port(f.id) >= 0
	var store_site: Vector2i = sim.cities["harbor"].valid_sites(3, 2)[0]
	var build: Dictionary = {"type": "build_facility", "company": "player", "city": "harbor", "archetype": "electronics_store", "product": "smartphone", "x": store_site.x, "y": store_site.y}
	ok = ok and sim.command_error(build).is_empty()
	sim.queue_command(build)
	sim.process_commands()
	ok = ok and bool(sim.command_results.back().accepted)
	ok = ok and sim.cities["harbor"].road_distance_to_port("built_000001") >= 0
	var quote: Dictionary = sim.logistics.quote(sim, "10_orion", "built_000001", 1)
	ok = ok and quote.mode == "regional" and quote.distance > 0
	var property_site: Vector2i = sim.cities["harbor"].valid_sites(2, 2)[0]
	var development: Dictionary = {"type": "develop_property", "company": "player", "city": "harbor", "property_type": "house", "x": property_site.x, "y": property_site.y}
	ok = ok and sim.command_error(development).is_empty()
	sim.queue_command(development)
	sim.process_commands()
	ok = ok and bool(sim.command_results.back().accepted)
	var import_command: Dictionary = {"type": "import_goods", "company": "player", "facility": "built_000001", "product": "smartphone", "quantity": 1}
	ok = ok and sim.command_error(import_command).is_empty()
	sim.queue_command(import_command)
	sim.process_commands()
	ok = ok and bool(sim.command_results.back().accepted)
	for day: int in range(10): sim.step()
	ok = ok and sim.clock.tick == 10 and sim.invariant_errors().is_empty()
	ok = ok and sim.city.population.total > 0 and sim.regional_trade.export_price(sim, "smartphone") > 0
	var identities: Dictionary = {}
	var sizes: Dictionary = {}
	for id: String in sim.cities:
		var map: CityMap = sim.cities[id]
		identities[map.profile.id] = true
		sizes[Vector2i(map.width, map.depth)] = true
		ok = ok and not sim.market_by_city[id].is_empty()
		var site: Vector2i = sim.strategic_ai._placement_for(sim, "player", "electronics_store", "smartphone", {}, id)
		ok = ok and site.x >= 0
		print("SMOKE CITY ", map.display_name, " ", map.width, "x", map.depth, " population=", map.population.total, " terrain=", map.generation.archetype, " bridges=", map.bridges.size(), " baseline_jobs=", sim.real_estates[id].baseline_jobs)
	ok = ok and identities.size() == 3 and sizes.size() == 3
	var store: SaveStore = SaveStore.new()
	var saved: Dictionary = sim.snapshot()
	ok = ok and store.write_file("res://.godot/11r2-smoke-save.json", {"economy": saved})
	var from_disk: Dictionary = store.read_file("res://.godot/11r2-smoke-save.json")
	ok = ok and not from_disk.is_empty()
	var restored: Economy = store.restore(from_disk.get("economy", {}))
	if restored == null: printerr(store.error)

	ok = ok and restored != null
	if restored != null: ok = ok and restored.snapshot() == sim.snapshot()
	print("Smoke invariants: ", sim.invariant_errors())
	print("11R2 smoke: ", "PASS" if ok else "FAIL", " days=", sim.clock.tick, " population=", sim.city.population.total, " roads=", sim.city.roads.size(), " ambient=", sim.city.ambient.size(), " ms=", Time.get_ticks_msec() - started)
	quit(0 if ok else 1)
