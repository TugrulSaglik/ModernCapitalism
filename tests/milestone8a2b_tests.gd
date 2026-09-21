extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(SaveStore.encode(a)) == JSON.stringify(SaveStore.encode(b))

func retail(sim: Economy, company: String, product: String = "smartphone") -> SimFacility:
	for f: SimFacility in sim.facilities:
		if f.company_id == company and sim._behavior(f) == "retail" and f.assortment.has(product):
			return f
	return null

func activate_line(sim: Economy, company: String, product: String, units: int = 1) -> SimFacility:
	var store: SimFacility = retail(sim, company, product)
	if store != null and units > 0:
		store.inventory.add(product, units, 0, 50)
	return store

func decide_ads(sim: Economy) -> void:
	sim._ai_advertising_decisions()
	sim._apply_commands()

func _initialize() -> void:
	_eligibility_target_and_cadence()
	_budget_and_allocation()
	_funding_accounting_and_separation()
	_determinism_and_persistence()
	print("M8A2B TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _eligibility_target_and_cadence() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize AI advertising economy")
	var player: SimCompany = sim.companies.player
	var rival: SimCompany = sim.companies.rival
	var product: String = "smartphone"
	var player_budget: int = 777
	player.advertising_budgets[product] = player_budget
	check(not sim._ai_advertising_eligible("player", product), "Player company is never AI-advertising eligible")
	check(not sim._ai_advertising_eligible("rival", product), "Configured line without commercial activity is ineligible")
	activate_line(sim, "rival", product)
	check(sim._ai_advertising_eligible("rival", product), "Stocked configured AI retail line is eligible")
	check(not sim._ai_advertising_eligible("rival", "washing_machine"), "Product without AI retail presence is ineligible")
	var local_brand: int = int(sim.catalog.local_values(product).brand)
	rival.product_brands[product] = local_brand - 1
	sim._ai_decisions()
	sim._apply_commands()
	check(player.advertising_budgets[product] == player_budget, "Weekly AI decision does not touch player budget")
	check(rival.advertising_budgets[product] > 0, "Below-Local eligible brand receives a budget")
	var weekly_budget: int = int(rival.advertising_budgets[product])
	sim.clock.tick = 1
	rival.cash = 0
	sim._ai_decisions()
	sim._apply_commands()
	check(rival.advertising_budgets[product] == weekly_budget, "Advertising budget remains unchanged off weekly cadence")
	sim.clock.tick = 7
	sim._ai_decisions()
	sim._apply_commands()
	check(rival.advertising_budgets[product] == 0, "Weekly zero-cash decision clears active budget")
	rival.cash = 20000000
	rival.product_brands[product] = local_brand
	decide_ads(sim)
	check(rival.advertising_budgets[product] == 0, "Brand equal to Local receives zero budget")
	rival.product_brands[product] = local_brand + 1
	decide_ads(sim)
	check(rival.advertising_budgets[product] == 0, "Brand above Local receives zero budget")
	rival.product_brands[product] = local_brand
	rival.advertising_inactive_days[product] = 59
	sim._advertise()
	check(rival.brand(product) == local_brand - 1, "Existing inactivity path decays AI brand below Local")
	decide_ads(sim)
	check(rival.advertising_budgets[product] > 0, "Later weekly decision resumes advertising after decay")
	var store: SimFacility = retail(sim, "rival", product)
	store.inventory.quantities.erase(product)
	store.inventory.costs.erase(product)
	store.inventory.quality_points.erase(product)
	store.product_history.clear()
	decide_ads(sim)
	check(rival.advertising_budgets[product] == 0, "Stale budget clears when commercial activity ends")
	var early: Economy = Economy.new()
	check(early.initialize(42, 2012, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize locked-product economy")
	check(not early._ai_advertising_eligible("rival", "advanced_phone"), "Locked product is not advertised")

func _budget_and_allocation() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize budget economy")
	var owner: SimCompany = sim.companies.rival
	var smartphone: String = "smartphone"
	activate_line(sim, owner.id, smartphone)
	var threshold: int = sim.advertising_threshold(smartphone, owner.brand(smartphone))
	var expected: int = (threshold + 29) / 30
	decide_ads(sim)
	check(owner.advertising_budgets[smartphone] == expected, "Desired budget is ceil(next-point threshold / 30)")
	var store: SimFacility = retail(sim, owner.id, smartphone)
	var second: String = "laptop"
	store.assortment[second] = int(sim.catalog.products[second].reference_price)
	store.inventory.add(second, 1, 100, 50)
	owner.product_brands[smartphone] = 50
	owner.product_brands[second] = 10
	owner.cash = 100000
	owner.capital = owner.cash - owner.profit() - sim.inventory_assets(owner.id) - sim.fixed_assets(owner.id)
	decide_ads(sim)
	check(owner.advertising_budgets[second] == 100 and owner.advertising_budgets[smartphone] == 0, "Largest brand deficit receives limited cap first")
	var total: int = 0
	for budget: int in owner.advertising_budgets.values(): total += budget
	check(total <= owner.cash / 1000, "Total configured AI spend respects company cash cap")
	owner.product_brands[smartphone] = 10
	owner.product_brands[second] = 10
	owner.cash = 1000
	owner.capital = owner.cash - owner.profit() - sim.inventory_assets(owner.id) - sim.fixed_assets(owner.id)
	decide_ads(sim)
	check(owner.advertising_budgets[second] == 1 and owner.advertising_budgets[smartphone] == 0, "Product-ID tie break is deterministic")
	owner.cash = 999
	owner.capital = owner.cash - owner.profit() - sim.inventory_assets(owner.id) - sim.fixed_assets(owner.id)
	decide_ads(sim)
	check(owner.advertising_budgets[second] == 0 and owner.advertising_budgets[smartphone] == 0, "Tiny cash produces zero bounded advertising")

func _funding_accounting_and_separation() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize funding economy")
	sim.record_history()
	var owner: SimCompany = sim.companies.rival
	var product: String = "smartphone"
	activate_line(sim, owner.id, product)
	var qualities: Dictionary = owner.product_quality_levels.duplicate(true)
	var processes: Dictionary = owner.process_efficiency_levels.duplicate(true)
	var local: Dictionary = sim.catalog.local_values(product).duplicate(true)
	var projects: Array = []
	for f: SimFacility in sim.facilities: projects.append(f.research_project.duplicate(true))
	decide_ads(sim)
	var budget: int = int(owner.advertising_budgets[product])
	var start_cash: int = owner.cash
	sim._advertise()
	check(budget > 0 and start_cash - owner.cash == budget, "Configured AI budget uses shared funded advertising path")
	check(owner.advertising_expense == budget and owner.cash_expenses == budget and owner.expenses == budget, "AI advertising is paid and recorded as operating expense")
	sim.record_history()
	var period: Dictionary = FinancialReports.period(owner, sim.clock)
	check(period.advertising_expense == budget and period.operating_cash == period.revenue - period.purchases - period.production_cash - period.cash_expenses, "AI advertising reconciles in operating cash flow")
	var balance: Dictionary = FinancialReports.balance(sim, owner.id)
	check(period.profit == period.revenue - period.cogs - period.expenses and balance.assets == balance.equity, "AI advertising reconciles profit and equity")
	check(sim.invariant_errors().is_empty(), "AI advertising preserves exact balance identity")
	owner.cash = budget - 1
	owner.capital = owner.cash + sim.inventory_assets(owner.id) + sim.fixed_assets(owner.id) - owner.profit()
	var spent: int = owner.advertising_expense
	owner.advertising_inactive_days[product] = 0
	sim._advertise()
	check(owner.cash == budget - 1 and owner.advertising_expense == spent and owner.advertising_inactive_days[product] == 1, "Unaffordable AI budget spends nothing and advances inactivity")
	owner.cash = 100000000
	owner.capital = owner.cash + sim.inventory_assets(owner.id) + sim.fixed_assets(owner.id) - owner.profit()
	owner.product_brands[product] = 20
	owner.advertising_progress[product] = 0
	owner.advertising_budgets[product] = (sim.advertising_threshold(product, 20) + 29) / 30
	for day: int in range(30): sim._advertise()
	check(owner.brand(product) >= 21, "Funded AI advertising grows brand through existing formula")
	check(same(qualities, owner.product_quality_levels) and same(processes, owner.process_efficiency_levels), "Ad policy leaves product quality and process levels unchanged")
	check(same(local, sim.catalog.local_values(product)), "Ad policy leaves Local unchanged")
	var after_projects: Array = []
	for f: SimFacility in sim.facilities: after_projects.append(f.research_project.duplicate(true))
	check(same(projects, after_projects), "Ad policy leaves research AI assignments unchanged")

func _determinism_and_persistence() -> void:
	var a: Economy = Economy.new()
	var b: Economy = Economy.new()
	check(a.initialize(77, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}) and b.initialize(77, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize deterministic pair")
	activate_line(a, "rival", "smartphone")
	activate_line(b, "rival", "smartphone")
	decide_ads(a)
	decide_ads(b)
	check(same(a.companies.rival.advertising_budgets, b.companies.rival.advertising_budgets), "Same-seed simulations choose identical AI budgets")
	var restored: Economy = SaveStore.new().restore(a.snapshot())
	check(restored != null and same(a.snapshot(), restored.snapshot()), "Existing schema restores chosen AI budgets exactly")
	if restored != null:
		for day: int in range(8):
			a.step()
			restored.step()
		check(same(a.snapshot(), restored.snapshot()), "Save/load continuation produces identical later weekly AI decisions")
	var price_sim: Economy = Economy.new()
	check(price_sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}), "Initialize price-policy check")
	var store: SimFacility = retail(price_sim, "rival", "smartphone")
	var old_price: int = store.line_price("smartphone")
	price_sim._ai_decisions()
	price_sim._apply_commands()
	check(store.line_price("smartphone") != old_price, "Existing weekly AI pricing still operates")
