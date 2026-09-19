extends SceneTree
var checks: int = 0
var failures: int = 0
var screen: Control
var session: GameSession

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func capture(name_value: String) -> void:
	screen.refresh()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory: String = "res://.godot/m4-screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "Capture " + name_value)

func choose(option: OptionButton, text_value: String, metadata: bool = false) -> void:
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index) if metadata else option.get_item_text(index)) == text_value:
			option.select(index)
			return
	check(false, "Option available: " + text_value)

func _run() -> void:
	screen = load("res://scenes/game.tscn").instantiate()
	screen.city_settings = {"preset": "legacy"}
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	session = screen.session
	session.time.set_speed(0)
	screen.save_directory = "res://.godot/m4-ui-saves"
	for era: int in [2022, 2012]:
		screen._new_session(era)
		session.time.set_speed(0)
		session.unlock_debug(DebugConfig.PASSWORD)
		session.debug_action("cash", 20000000)
		check(session.submit({"type": "build_facility", "archetype": "assembly_plant", "product": "smartphone", "x": 24, "y": 10}), "Build factory")
		check(session.submit({"type": "build_facility", "archetype": "warehouse", "product": "smartphone", "x": 24, "y": 3}), "Build warehouse")
		var component_index: int = 0
		for product: String in ["processor", "display", "battery"]:
			check(session.submit({"type": "build_facility", "archetype": "component_plant", "product": product, "x": 3 + component_index * 7, "y": 7}), "Expand component supply")
			component_index += 1
		var factory: SimFacility = session.sim.facility("built_000001")
		var warehouse: SimFacility = session.sim.facility("built_000002")
		session.submit({"type": "set_price", "facility": factory.id, "price": 100000000})
		session.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": "10_orion"})
		for day: int in range(12): session.sim.step()
		check(factory.inventory.quantity("smartphone") >= 20, "Real input sourcing and factory production")
		screen.refresh()
		screen.select_facility(factory.id)
		var panel: FacilityPanel = screen.inspector
		choose(panel.transfer_product, "smartphone")
		choose(panel.transfer_destination, warehouse.id, true)
		panel.transfer_quantity.value = 20
		if era == 2022: await capture("01-manual-transfer")
		var freight: int = session.sim.companies.player.freight
		panel.transfer_button.pressed.emit()
		check(session.sim.logistics.incoming(warehouse.id) == 20 and warehouse.inventory.quantity("smartphone") == 0, "UI order remains in transit")
		check(session.sim.companies.player.freight > freight, "Transfer charges transport")
		screen._save()
		for day: int in range(10): session.sim.step()
		var expected: Dictionary = session.sim.snapshot()
		screen._load()
		for day: int in range(10): session.sim.step()
		check(JSON.stringify(SaveStore.encode(expected)) == JSON.stringify(SaveStore.encode(session.sim.snapshot())), "UI save/reload in-transit replay")
		warehouse = session.sim.facility("built_000002")
		factory = session.sim.facility("built_000001")
		check(warehouse.inventory.quantity("smartphone") == 20, "Warehouse arrival")
		# Suspend retail while routing its next batch, then resume after arrival.
		session.submit({"type": "set_operating", "facility": "20_player", "operating": false})
		session.submit({"type": "set_supplier", "facility": "20_player", "product": "smartphone", "supplier": warehouse.id})
		screen.select_facility(warehouse.id)
		choose(panel.transfer_product, "smartphone")
		choose(panel.transfer_destination, "20_player", true)
		panel.transfer_quantity.value = 10
		panel.transfer_button.pressed.emit()
		check(session.sim.logistics.incoming("20_player", "smartphone") >= 10, "Warehouse outbound via UI")
		check(session.submit({"type": "transfer", "facility": factory.id, "destination": warehouse.id, "product": "smartphone", "quantity": 10}), "Second inbound shipment")
		if era == 2022: await capture("02-warehouse-inbound-outbound")
		for day: int in range(6): session.sim.step()
		session.submit({"type": "set_operating", "facility": "20_player", "operating": true})
		session.sim.step()
		check(session.sim.facility("20_player").sold_today > 0, "Retail sales after warehouse delivery")
		while session.sim.clock.month == 1: session.sim.step()
		var history: Array[Dictionary] = session.sim.companies.player.monthly_history
		check(history.size() == 2 and history.back().profit == 0, "Completed January and new February bar")
		session.sim.step()
		check(history.back().profit != 0, "Current monthly bar updates daily")
		check(session.sim.companies.player.ttm_profit(session.sim.clock) == session.sim.companies.player.profit(), "Available-history TTM")
		if era == 2022:
			await capture("03-selected-warehouse")
			screen.inspector.hide()
			await capture("04-city-financial-hud")
			var city: CityView = screen.city
			var focus: Vector3 = city.focus
			var key: InputEventKey = InputEventKey.new()
			key.pressed = true
			key.keycode = KEY_W
			screen._input(key)
			city._unhandled_input(key)
			check(city.focus == focus, "WASD no longer pans")
			var middle: InputEventMouseButton = InputEventMouseButton.new()
			middle.button_index = MOUSE_BUTTON_MIDDLE
			middle.pressed = true
			city._unhandled_input(middle)
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = Vector2(350, 300)
			motion.relative = Vector2(80, 30)
			motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
			city._unhandled_input(motion)
			middle.pressed = false
			city._unhandled_input(middle)
			check(city.focus != focus, "Middle drag pans through input path")
			await capture("05-middle-drag")
			focus = city.focus
			screen._show_construction()
			screen._show_settings()
			screen.debug_entry.grab_focus()
			await process_frame
			key.keycode = KEY_4
			screen._input(key)
			middle.pressed = true
			city._unhandled_input(middle)
			city._unhandled_input(motion)
			var count: int = session.sim.facilities.size()
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(350, 300)
			city._unhandled_input(click)
			check(session.time.speed == 0 and city.focus == focus and session.sim.facilities.size() == count, "Settings focus blocks speed, drag and placement")
			screen.debug_entry.text = "wasd1234"
			await capture("06-settings-text-focus")
			screen.settings.hide()
			screen.city.cancel_placement()
			var entry: TextEdit = TextEdit.new()
			screen.add_child(entry)
			entry.grab_focus()
			await process_frame
			screen._input(key)
			check(session.time.speed == 0 and screen.world_input_blocked(), "Reusable TextEdit focus guard")
			entry.queue_free()
			await process_frame
		check(session.sim.invariant_errors().is_empty(), "E2E daily accounts")
	print("M4 VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
