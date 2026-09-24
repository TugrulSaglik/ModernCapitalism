extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var failures: Array[String] = []
	_check(screen.city_selector.item_count == 3, "three city options", failures)
	_check(screen.session.select_city("harbor"), "select Harbor", failures)
	screen._build_city()
	screen.refresh()
	_check(screen.city.map_width == screen.session.sim.cities["harbor"].width, "Harbor map", failures)
	_check(screen.minimap.map == screen.session.sim.cities["harbor"], "Harbor minimap", failures)
	_check(screen.facility_list.item_count == 1, "city local facility selector", failures)
	_check(screen.city_selector.get_item_text(screen.city_selector.selected) == "Harbor City", "city identity", failures)
	_check(screen.session.active_company == "player", "company selector independent", failures)
	screen._select_port()
	_check(screen.property_details.text.contains("REGIONAL PORT"), "port inspector", failures)
	screen.reports.tabs.current_tab = 3
	screen.reports.refresh()
	_check(screen.reports.market_city.item_count == 4, "market locations", failures)
	screen.reports.tabs.current_tab = 8
	var site: Vector2i = screen.session.sim.cities["harbor"].valid_sites(3, 2)[0]
	_check(screen.session.submit({"type": "build_facility", "archetype": "electronics_store", "product": "smartphone", "x": site.x, "y": site.y}), "active city build", failures)
	var harbor_store: SimFacility = screen.session.sim.facility("built_000001")
	if harbor_store != null:
		_check(harbor_store.city_id == "harbor", "build city authority", failures)
		harbor_store.inventory.add("smartphone", 2, 0, 50)
	screen.reports.refresh()
	_check(screen.reports.trade_content.visible, "trade tab", failures)
	_check(screen.reports.trade_market_details.text.contains("EXTERNAL MARKET"), "trade quote", failures)
	_check(screen.reports.import_destination.item_count > 0 and screen.reports.export_source.item_count > 0, "trade facility filters", failures)
	var commands: Array[Dictionary] = []
	screen.reports.command_requested.connect(func(command: Dictionary) -> void: commands.append(command))
	screen.reports.trade_content.find_child("ImportGoodsButton", true, false).pressed.emit()
	_check(not commands.is_empty() and commands.back().type == "import_goods" and commands.back().facility == "built_000001" and commands.back().product == "smartphone", "import UI command", failures)
	screen.reports.trade_content.find_child("ExportGoodsButton", true, false).pressed.emit()
	_check(commands.size() > 1 and commands.back().type == "export_goods" and commands.back().facility == "built_000001" and commands.back().product == "smartphone", "export UI command", failures)
	if failures.is_empty():
		print("Milestone 11 focused UI: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("Milestone 11 focused UI: FAIL (%d)" % failures.size())
		quit(1)

func _check(value: bool, label: String, failures: Array[String]) -> void:
	if not value: failures.append(label)
