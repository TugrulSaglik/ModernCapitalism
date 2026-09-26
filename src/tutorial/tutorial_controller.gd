class_name TutorialController
extends RefCounted

# Presentation and predicates live together; UI only supplies observed navigation.
const STEPS: Array[Dictionary] = [
	{"id":"controls", "title":"Your first day", "instruction":"Middle-drag to pan; wheel to zoom. Space pauses time; 1–4 choose speed. Start paused and explore at your own pace.", "hint":"Press Understood when ready.", "condition":"controls"},
	{"id":"overview", "title":"Know your company", "instruction":"Open Company. Income, cash flow and assets describe the same business from different angles.", "hint":"Close the report to return to the city.", "condition":"overview"},
	{"id":"retail", "title":"Meet your store", "instruction":"Select your Electronics store from the facility selector or map. Existing facilities satisfy objectives too.", "hint":"Overview shows performance; Operations controls product lines and prices.", "condition":"retail"},
	{"id":"sourcing", "title":"Choose a supplier", "instruction":"In the store's Sourcing tab, choose Smartphone and a supplier. Apply the policy, then run one day.", "hint":"Automatic is valid. Commands queued while paused take effect next day.", "condition":"sourcing"},
	{"id":"sale", "title":"Make a sale", "instruction":"Run time until your company records retail revenue. Deliveries need travel time before stock can sell.", "hint":"Keep the store operating, review stock and use a competitive price.", "condition":"sale"},
	{"id":"production", "title":"Make something", "instruction":"Build a Materials plant producing Flour (case), or another compatible factory, and let it produce inventory.", "hint":"Build → Industrial. Choose a vacant road-front site; sourcing is automatic by default.", "condition":"production"},
	{"id":"warehouse", "title":"Buffer your supply chain", "instruction":"Build a Warehouse. In Replenishment, set a target for a public product and run one day.", "hint":"Warehouses buffer stock; Logistics shows freight and goods still in transit.", "condition":"warehouse"},
	{"id":"research", "title":"Improve your products", "instruction":"Build an R&D center, assign product-quality research for Flour (or another known product), and run a day.", "hint":"Research consumes a daily budget. You can stop and resume retained progress.", "condition":"research"},
	{"id":"advertising", "title":"Build market presence", "instruction":"Company → Markets: set a positive advertising budget for a consumer product, then run a day.", "hint":"Brand is company/product market presence. Unfunded campaigns do not improve it.", "condition":"advertising"},
	{"id":"staff", "title":"Manage the business", "instruction":"Build Corporate headquarters and hire one staff member from Staffing.", "hint":"Daily payroll funds bounded management effects; retain cash for operations.", "condition":"staff"},
	{"id":"property", "title":"Invest in your city", "instruction":"Select vacant road-front land and develop a House, or acquire an existing property.", "hint":"Land remains an asset; buildings depreciate. Occupancy determines rent.", "condition":"property"},
	{"id":"trade", "title":"A regional company", "instruction":"Company → Trade: import a small quantity into a compatible facility, or export stocked goods. Explore Finance to see shares and company control.", "hint":"Each city has its own market and port; your company's cash is regional. After a trade, the guided course is complete.", "condition":"trade"},
]
var step: int = 0
var skipped: bool = false
var observations: Dictionary = {}

func observe(event: String) -> void:
	if event in ["controls", "overview", "retail"]: observations[event] = true

func complete() -> bool:
	return skipped or step == STEPS.size()

func current() -> Dictionary:
	return {} if complete() else STEPS[step]

func evaluate(sim: Economy) -> bool:
	if complete() or not satisfied(str(current().condition), sim): return false
	step += 1
	return true

func satisfied(condition: String, sim: Economy) -> bool:
	var owner: SimCompany = sim.companies.player
	if condition in ["controls", "overview"]: return observations.get(condition, false)
	if condition == "sale": return owner.retail_revenue > 0
	if condition == "production": return owner.production_cash > 0
	if condition == "advertising": return owner.advertising_expense > 0
	if condition == "staff": return sim.total_staff("player") > 0
	if condition == "property": return owner.property_capex > 0
	if condition == "trade": return owner.import_purchases > 0 or owner.export_revenue > 0
	for f: SimFacility in sim.facilities:
		if f.company_id != "player": continue
		var behavior: String = sim._behavior(f)
		match condition:
			"retail":
				if behavior == "retail" and observations.get("retail", false): return true
			"sourcing":
				if behavior == "retail" and not f.suppliers.is_empty(): return true
			"production":
				if behavior == "production" and f.inventory.quantity(f.product_id) > 0: return true
			"warehouse":
				if behavior == "storage" and not f.replenishment_targets.is_empty(): return true
			"research":
				if behavior == "research" and not f.research_project.is_empty(): return true
	if condition == "research":
		for level: int in owner.product_quality_levels.values():
			if level > 0: return true
	return false

func snapshot() -> Dictionary:
	return {"step":step, "skipped":skipped, "observations":observations.duplicate()}

func restore(state: Dictionary) -> bool:
	if not SaveStore.shape(state, snapshot()) or state.step < 0 or state.step > STEPS.size(): return false
	for event: String in state.observations:
		if event not in ["controls", "overview", "retail"] or state.observations[event] != true: return false
	step = state.step
	skipped = state.skipped
	observations = state.observations.duplicate()
	return true
