extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func apply(sim: Economy, request: Dictionary) -> bool:
	var error: String = sim.command_error(request)
	check(error.is_empty(), str(request) + " " + error)
	if not error.is_empty(): return false
	sim.queue_command(request)
	sim.process_commands()
	return true

func _initialize() -> void:
	for product: String in ["bread", "shirt", "chair", "compact_car"]: sector(product)
	print("M12 sector fixtures: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func sector(product: String) -> void:
	var sim: Economy = Economy.new()
	check(sim.initialize(42,2022,SaveStore.DATA_PATH,{"preset":"legacy"}), "sector initialize")
	# Isolate an AI portfolio with adequate contributed capital for a car plant,
	# dealer, HQ and lab. These are fixture conditions, not difficulty bonuses.
	var owner: SimCompany = sim.companies.maker_b
	owner.cash += 100000000
	owner.capital += 100000000
	for f: SimFacility in sim.facilities.duplicate():
		if f.company_id == "maker_b": apply(sim,{"type":"demolish_facility","company":"maker_b","facility":f.id})
	for p: String in sim.catalog.products:
		if sim.catalog.consumer_product(p): sim.catalog.products[p].daily_demand = 10000 if p == product else 1
	var store: SimFacility
	var factory: SimFacility
	for decision: int in range(5):
		var request: Dictionary = sim.strategic_ai._capital_command(sim,"maker_b",false,{},sim.strategic_ai.difficulty_profile("standard"),"metro")
		check(not request.is_empty(), "AI decision " + product)
		if request.is_empty(): break
		request.erase("priority")
		request.erase("strategic_score")
		var id: String = "built_%06d" % sim.next_facility_id
		if not apply(sim,request): break
		var f: SimFacility = sim.facility(id)
		if sim._behavior(f) == "retail" and f.product_id == product: store = f
		if sim._behavior(f) == "production" and f.product_id == product:
			factory = f
			break
	check(store != null and factory != null, "AI entered and vertically integrated " + product)
	if store == null or factory == null: return
	for input: String in sim.catalog.products[product].inputs:
		var units: int = int(sim.catalog.products[product].inputs[input]) * 6
		var cost: int = units * int(sim.catalog.products[input].reference_price)
		check(owner.spend(cost), "fixture input funded")
		owner.purchases += cost
		factory.inventory.add(input,units,cost)
	apply(sim,{"type":"set_supplier","company":"maker_b","facility":store.id,"product":product,"supplier":factory.id})
	var initial_retail: int = owner.retail_revenue
	var produced: bool = false
	for day: int in range(12):
		sim.step()
		produced = produced or factory.inventory.quantity(product) > 0 or factory.produced_today > 0
	check(produced, "production " + product)
	check(owner.retail_revenue > initial_retail, "real retail sale " + product)
	check(sim.invariant_errors().is_empty(), "sector invariants " + product)
	check(not sim.strategic_ai.research_choice(sim,"maker_b").is_empty(), "AI research relevant " + product)
	print("Sector ",product,": AI retailer + factory, production, sourcing, sales; retail ",owner.retail_revenue-initial_retail)
