extends SceneTree

func _initialize() -> void:
	var days: int = 365
	var era: int = 2022
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--days="): days = int(argument.trim_prefix("--days="))
		elif argument.begins_with("--era="): era = int(argument.trim_prefix("--era="))
	var a: Economy = Economy.new()
	var b: Economy = Economy.new()
	if not a.initialize(42, era) or not b.initialize(42, era):
		quit(1)
		return
	var maximum_pending: int = 0
	for day: int in range(days):
		a.step()
		b.step()
		maximum_pending = maxi(maximum_pending, a.pending_commands.size())
		if not a.invariant_errors().is_empty() or not b.invariant_errors().is_empty():
			printerr("INVARIANT FAILURE day=", day, " ", a.invariant_errors(), " ", b.invariant_errors())
			quit(1)
			return
	var deterministic: bool = JSON.stringify(SaveStore.encode(a.snapshot())) == JSON.stringify(SaveStore.encode(b.snapshot()))
	var ai_summary: Dictionary = {}
	var invalid_products: int = 0
	for company_id: String in ["maker_b", "rival"]:
		var facilities: int = 0
		var behaviors: Dictionary = {}
		for f: SimFacility in a.facilities:
			if f.company_id != company_id: continue
			facilities += 1
			var behavior: String = a._behavior(f)
			behaviors[behavior] = int(behaviors.get(behavior, 0)) + 1
			# Scenario fixtures may intentionally reserve dormant future-era sites.
			# Strategic construction itself must always be valid for the current era.
			if f.id.begins_with("built_") and not a.can_configure(company_id, f.type_id, f.product_id): invalid_products += 1
		ai_summary[company_id] = {"cash": a.companies[company_id].cash, "facilities": facilities, "behaviors": behaviors, "staff": a.total_staff(company_id)}
	print("M8C INTEGRATION era=%d days=%d deterministic=%s pending_max=%d invalid_products=%d invariants=0 ai=%s" % [era, days, deterministic, maximum_pending, invalid_products, JSON.stringify(ai_summary)])
	quit(0 if deterministic and maximum_pending == 0 and invalid_products == 0 else 1)
