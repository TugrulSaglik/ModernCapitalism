extends SceneTree

var failures: int = 0

func verify(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: GameSession = GameSession.new()
	verify(session.start(2022, 42, "sandbox", {}, "standard"), "start")
	if session.sim == null:
		quit(1)
		return
	var sim: Economy = session.sim
	var initial_population: int = int(sim.city.population.total)
	var sites: Array[Vector2i] = sim.city.valid_sites(2, 2)
	verify(sites.size() >= 2, "two sites")
	if sites.size() < 2:
		quit(1)
		return
	var housing_site: Vector2i = sites[0]
	verify(session.submit({"type": "buy_land", "x": housing_site.x, "y": housing_site.y, "width": 2, "depth": 2}), "land acquisition")
	verify(session.submit({"type": "develop_property", "property_type": "apartments", "x": housing_site.x, "y": housing_site.y}), "housing development")
	verify(session.submit({"type": "issue_shares", "quantity": 250000}), "first equity issue")
	verify(session.submit({"type": "issue_shares", "quantity": 312500}), "second equity issue")
	var office_site: Vector2i = sim.city.valid_sites(2, 2)[0]
	verify(session.submit({"type": "develop_property", "property_type": "office", "x": office_site.x, "y": office_site.y}), "office development " + session.message)
	var initial_jobs: int = int(sim.city.population.jobs)
	var initial_revenue: int = int(sim.companies.player.property_revenue)
	var month_population: Array[int] = []
	var loaded: Economy = null
	var store: SaveStore = SaveStore.new()
	for day: int in range(180):
		sim.step()
		if loaded != null: loaded.step()
		if sim.clock.day == 2: month_population.append(int(sim.city.population.total))
		if day == 89:
			loaded = store.restore(sim.snapshot())
			verify(loaded != null, "midpoint save restore " + store.error)
			if loaded != null: verify(loaded.snapshot() == sim.snapshot(), "midpoint state exact")
		if day % 30 == 0 or day == 179:
			verify(sim.invariant_errors().is_empty(), "day %d invariants %s" % [day + 1, sim.invariant_errors()])
			verify(sim.pending_commands.is_empty(), "day %d pending command queue" % [day + 1])
			verify(int(FinancialReports.balance(sim, "player").assets) == int(FinancialReports.balance(sim, "player").equity), "day %d player balance" % [day + 1])
	verify(loaded != null and loaded.snapshot() == sim.snapshot(), "deterministic save-load continuation")
	verify(int(sim.city.population.total) >= initial_population, "population response")
	verify(int(sim.city.population.jobs) >= initial_jobs, "job capacity retained")
	verify(sim.companies.player.property_revenue > initial_revenue, "rent settled")
	verify(int(sim.real_estate.properties.property_000001.depreciation) > 0, "building depreciated")
	verify(sim.real_estate.land_assets("player") > 0, "land basis retained")
	verify(sim.cumulative_consumer_units > 0, "retail demand active")
	verify(sim.equity_market.invariant_errors(sim.companies).is_empty(), "equity registry valid")
	verify(month_population.size() >= 5, "monthly migration cadence")
	print("M10 INTEGRATION: 180 days, population %d -> %d, jobs %d, rent %d cents, %d failures" % [initial_population, sim.city.population.total, sim.city.population.jobs, sim.companies.player.property_revenue, failures])
	quit(0 if failures == 0 else 1)
