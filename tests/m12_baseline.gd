extends SceneTree

func _initialize() -> void:
	var sim: Economy = Economy.new()
	assert(sim.initialize(42, 2022, SaveStore.DATA_PATH, {"preset": "legacy"}))
	assert(sim.catalog.errors.is_empty())
	assert(load("res://scenes/game.tscn") != null)
	print("M12 small startup/catalog baseline PASS: ", sim.catalog.products.size(), " products")
	quit()
