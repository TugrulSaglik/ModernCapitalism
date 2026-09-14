extends SceneTree

const Simulation = preload("res://src/sim/economy.gd")

func _initialize() -> void:
	var days: int = 365
	var era: int = 2022
	var seed_value: int = 42
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--days="):
			days = int(argument.trim_prefix("--days="))
		elif argument.begins_with("--era="):
			era = int(argument.trim_prefix("--era="))
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	var sim: Economy = Simulation.new()
	if days <= 0 or not sim.initialize(seed_value, era):
		printerr("Invalid configuration. Use --days=N --era=2012|2022 --seed=N")
		quit(1)
		return
	for tick: int in range(days):
		sim.step()
		var errors: Array[String] = sim.invariant_errors()
		if not errors.is_empty():
			printerr("Tick %d: %s" % [tick, errors])
			quit(1)
			return
	print(JSON.stringify(sim.snapshot(), "  "))
	print("Completed %d days; all daily balance/inventory invariants passed." % days)
	quit(0)
