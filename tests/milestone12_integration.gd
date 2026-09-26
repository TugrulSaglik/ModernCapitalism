extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	for year: int in [2022,2012]: run_scenario(year)
	print("M12 integrations: two 60-day scenarios; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func run_scenario(year: int) -> void:
	var s: GameSession = GameSession.new()
	var config: Dictionary = SessionSetup.defaults()
	config.era = year
	config.seed = 1212 if year == 2012 else 1222
	config.company_name = "Regional Ventures %d" % year
	config.starting_capital = 50000000 if year == 2012 else 20000000
	check(s.start_setup(config), "start " + str(year))
	if s.sim == null: return
	var expected: Array[Dictionary] = CityProfiles.select(s.sim.catalog.city_profiles,config.seed)
	check(s.sim.city.profile.id == expected[0].id and s.sim.cities.size() == 3, "seeded identities")
	var sim: Economy = s.sim
	var store_id: String = ""
	for site: Vector2i in sim.city.valid_sites(4,3):
		var request: Dictionary = {"type":"build_facility","company":"player","city":"metro","archetype":"supermarket","product":"bread","x":site.x,"y":site.y}
		if not sim.command_error(request).is_empty(): continue
		store_id = "built_%06d" % sim.next_facility_id
		check(s.submit(request), "build new-sector store")
		break
	check(not store_id.is_empty(), "retailer site")
	if not store_id.is_empty(): check(s.submit({"type":"import_goods","facility":store_id,"product":"bread","quantity":20}), "new product trade")
	for site: Vector2i in sim.city.valid_sites(1,1):
		var request: Dictionary = {"type":"develop_property","company":"player","city":"metro","property_type":"house","x":site.x,"y":site.y}
		if sim.command_error(request).is_empty():
			check(s.submit(request), "property investment")
			break
	check(s.submit({"type":"buy_shares","target":"rival","quantity":100}), "corporate finance " + s.message)
	var initial_facilities: int = sim.facilities.size()
	for day: int in range(59):
		sim.step()
		check(sim.invariant_errors().is_empty(), "%d day %d invariants" % [year,day+1])
	check(sim.facilities.size() > initial_facilities, "AI investment activity")
	check(sim.companies.player.retail_revenue > 0 and sim.companies.player.import_purchases > 0, "retail and trade active")
	check(sim.companies.player.property_capex > 0, "property accounted")
	check(sim.market.has("bread") and sim.market.has("shirt") and sim.market.has("chair") and sim.market.has("compact_car"), "new sector markets")
	var path: String = "res://.godot/m12-integration-%d.json" % year
	check(s.save_game(path), "integration save")
	var loaded: GameSession = GameSession.new()
	check(loaded.load_game(path), "integration load " + loaded.message)
	if loaded.sim != null:
		check(loaded.snapshot() == s.snapshot(), "exact day59 restore")
		loaded.sim.step()
	sim.step()
	if loaded.sim != null: check(loaded.snapshot() == s.snapshot(), "exact day60 continuation")
	check(sim.invariant_errors().is_empty(), "final invariants")
	print("Integration ",year," day ",sim.clock.tick," cities ",sim.city.display_name,"/",sim.cities.harbor.display_name,"/",sim.cities.highland.display_name," facilities ",sim.facilities.size()," retail cents ",sim.companies.player.retail_revenue," cash ",sim.companies.player.cash)
