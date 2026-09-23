extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var sim: Economy = screen.session.sim
	var site: Vector2i = sim.city.valid_sites(2, 2)[0]
	for candidate: Vector2i in sim.city.valid_sites(2, 2):
		if sim.city.touches_road(candidate.x, candidate.y):
			site = candidate
			break
	screen.select_parcel(site.x, site.y)
	check(screen.property_panel.visible and not screen.inspector.visible, "parcel inspector")
	check(screen.property_details.text.contains("Land value") and screen.property_details.text.contains("Land owner"), "parcel land read model")
	check(screen.property_buy_land.visible and not screen.property_buy_land.disabled, "buy land action")
	screen.property_buy_land.pressed.emit()
	check(sim.real_estate.land.has(CityMap.key(site.x, site.y)), "buy land button submits command")
	check(screen.property_action.visible and not screen.property_action.disabled, "development action")
	check(screen.property_details.text.contains("Total") and screen.property_details.text.contains("Full occupancy"), "development quote")
	check(screen.session.submit({"type": "develop_property", "property_type": "house", "x": site.x, "y": site.y}), "develop for UI")
	screen.city.sync(sim.snapshot())
	screen.select_property("property_000001")
	check(screen.property_panel.visible and screen.city.selected_property == "property_000001", "property selection")
	check(screen.property_details.text.contains("Building basis") and screen.property_details.text.contains("Monthly rent"), "property financial read model")
	check(screen.property_demolish.visible and screen.property_action.text == "Redevelop property", "owned management actions")
	screen._property_develop()
	check(screen.property_confirm.visible and screen.property_pending.type == "redevelop_property", "redevelopment confirmation")
	screen.property_confirm.hide()
	screen._property_demolish()
	check(screen.property_confirm.visible and screen.property_pending.type == "demolish_property", "demolition confirmation")
	screen.property_confirm.hide()
	var outside: String = ""
	for id: String in sim.real_estate.properties:
		if sim.real_estate.properties[id].owner == "":
			outside = id
			break
	screen.select_property(outside)
	check(screen.property_acquire.visible and not screen.property_demolish.visible, "outside acquisition action")
	screen._property_acquire()
	check(screen.property_confirm.visible and screen.property_pending.type == "acquire_property", "acquisition confirmation")
	screen.property_confirm.hide()
	var rival: String = ""
	for f: SimFacility in sim.facilities:
		if f.company_id == "rival":
			rival = f.id
			break
	screen.select_facility(rival)
	check(screen.inspector.visible and not screen.property_panel.visible, "facility selection retained")
	check(screen.facility_list.get_item_text(0) == "Select a facility, property or parcel", "context bar wording")
	screen._show_construction()
	check(screen.build_details.text.contains("Land acquisition") and screen.build_details.text.contains("Total"), "facility construction land quote")
	screen.reports.tabs.current_tab = 7
	screen.reports.refresh()
	check(screen.reports.report_title.text == "Properties", "properties report tab")
	print("M10 UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
