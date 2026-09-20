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

func _initialize() -> void:
	_decay_timing_and_separation()
	_funding_and_availability()
	_market_and_accounting()
	_persistence()
	print("M8A2A TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _decay_timing_and_separation() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize decay economy")
	var owner: SimCompany = sim.companies.player
	var product: String = "smartphone"
	owner.product_brands[product] = 3
	owner.advertising_progress[product] = 123
	var quality_levels: Dictionary = owner.product_quality_levels.duplicate(true)
	var process_levels: Dictionary = owner.process_efficiency_levels.duplicate(true)
	var local: Dictionary = sim.catalog.local_values(product).duplicate(true)
	var inventories: Array = []
	for facility: SimFacility in sim.facilities: inventories.append(facility.inventory.snapshot())
	for day: int in range(30): sim._advertise()
	check(owner.advertising_inactive_days[product] == 30 and owner.brand(product) == 3, "First 30 inactive days do not decay")
	for day: int in range(29): sim._advertise()
	check(owner.advertising_inactive_days[product] == 59 and owner.brand(product) == 3, "Brand remains through inactive day 59")
	sim._advertise()
	check(owner.advertising_inactive_days[product] == 60 and owner.brand(product) == 2, "First decay occurs on inactive day 60")
	for day: int in range(60): sim._advertise()
	check(owner.advertising_inactive_days[product] == 120 and owner.brand(product) == 0, "Repeated 30-day intervals decay deterministically to zero")
	for day: int in range(60): sim._advertise()
	check(owner.brand(product) == 0, "Brand never falls below zero")
	check(owner.advertising_progress[product] == 123, "Inactive periods preserve advertising progress")
	check(same(quality_levels, owner.product_quality_levels) and same(process_levels, owner.process_efficiency_levels), "Decay leaves R&D levels unchanged")
	check(same(local, sim.catalog.local_values(product)), "Decay leaves Local brand unchanged")
	var final_inventories: Array = []
	for facility: SimFacility in sim.facilities: final_inventories.append(facility.inventory.snapshot())
	check(same(inventories, final_inventories), "Decay leaves inventory and physical quality unchanged")

func _funding_and_availability() -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize funding economy")
	var owner: SimCompany = sim.companies.player
	var product: String = "smartphone"
	owner.product_brands[product] = 20
	owner.advertising_inactive_days[product] = 59
	owner.advertising_budgets[product] = 1
	var progress: int = int(owner.advertising_progress[product])
	sim._advertise()
	check(owner.advertising_inactive_days[product] == 0 and owner.brand(product) == 20 and owner.advertising_progress[product] == progress + 1, "Funded advertising resets inactivity and prevents same-day decay")
	owner.advertising_inactive_days[product] = 59
	owner.cash = 0
	owner.capital = -owner.profit()
	sim._advertise()
	check(owner.advertising_inactive_days[product] == 60 and owner.brand(product) == 19, "Unfunded positive budget does not reset inactivity")
	var early: Economy = Economy.new()
	check(early.initialize(42, 2012), "Initialize era-gated economy")
	var future: String = "advanced_phone"
	var early_owner: SimCompany = early.companies.player
	for day: int in range(90): early._advertise()
	check(not early.product_public(future) and early_owner.advertising_inactive_days[future] == 0, "Locked future product does not accumulate inactivity")
	early.clock.year = 2022
	early._advertise()
	check(early.product_public(future) and early_owner.advertising_inactive_days[future] == 1, "Inactivity begins when product becomes public")

func _market_and_accounting() -> void:
	var high: Array[int] = ConsumerDemand.allocate(1000, [{"price": 100, "reference_price": 100, "quality": 50, "brand": 20, "stock": 1000}, {"price": 100, "reference_price": 100, "quality": 50, "brand": 50, "stock": 1000}])
	var low: Array[int] = ConsumerDemand.allocate(1000, [{"price": 100, "reference_price": 100, "quality": 50, "brand": 0, "stock": 1000}, {"price": 100, "reference_price": 100, "quality": 50, "brand": 50, "stock": 1000}])
	check(low[0] < high[0] and low[0] > 0, "Lower decayed brand reduces appeal and share while zero brand can sell")
	var sim: Economy = Economy.new()
	check(sim.initialize(), "Initialize accounting economy")
	var owner: SimCompany = sim.companies.player
	owner.advertising_inactive_days.smartphone = 59
	var before: Dictionary = owner.accounts().duplicate(true)
	sim._advertise()
	check(same(before, owner.accounts()) and sim.invariant_errors().is_empty(), "Decay creates no cash or accounting activity")

func _persistence() -> void:
	var a: Economy = Economy.new()
	check(a.initialize(), "Initialize persistence economy")
	var owner: SimCompany = a.companies.player
	owner.product_brands.smartphone = 7
	owner.advertising_inactive_days.smartphone = 59
	owner.advertising_progress.smartphone = 456
	var b: Economy = SaveStore.new().restore(a.snapshot())
	check(b != null and same(a.snapshot(), b.snapshot()), "Inactive days restore exactly before threshold")
	if b != null:
		a.step()
		b.step()
		check(a.companies.player.brand("smartphone") == 6 and same(a.snapshot(), b.snapshot()), "Restored continuation decays on the exact same day")
	for corruption: String in ["negative", "fraction", "unknown"]:
		var bad: Dictionary = a.snapshot()
		if corruption == "negative": bad.companies[0].advertising_inactive_days.smartphone = -1
		elif corruption == "fraction": bad.companies[0].advertising_inactive_days.smartphone = 1.5
		else: bad.companies[0].advertising_inactive_days.missing = 1
		check(SaveStore.new().restore(bad) == null, "Reject " + corruption + " inactivity state")
