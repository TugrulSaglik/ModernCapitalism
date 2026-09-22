extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func fresh(era: int = 2022) -> GameSession:
	var session: GameSession = GameSession.new()
	check(session.start(era, 42, "sandbox", {"preset": "legacy"}), "Session starts in %d" % era)
	session.time.set_speed(0)
	return session

func build_headquarters(session: GameSession, company: String = "player") -> SimFacility:
	var definition: Dictionary = session.sim.catalog.facility_types.corporate_headquarters
	var sites: Array[Vector2i] = session.sim.city.valid_sites(definition.width, definition.depth)
	check(not sites.is_empty(), "Headquarters has a valid construction site")
	if sites.is_empty(): return null
	var command: Dictionary = {"type": "build_facility", "company": company, "archetype": "corporate_headquarters", "product": "", "x": sites[0].x, "y": sites[0].y}
	if company == session.player_company:
		var accepted: bool = session.submit(command)
		check(accepted, "Player headquarters construction accepted: " + session.message)
	else:
		check(session.sim.command_error(command).is_empty(), "Other company headquarters construction accepted")
		session.sim.queue_command(command)
		session.sim.process_commands()
	return session.sim.headquarters(company)

func _initialize() -> void:
	_catalog_and_construction()
	_operating_accounting_and_demolition()
	_isolation_and_persistence()
	await _ui_read_model()
	print("M8B1 TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog_and_construction() -> void:
	var catalog: SimCatalog = SimCatalog.new()
	check(catalog.load_data(), "Catalog loads")
	var definition: Dictionary = catalog.facility_types.get("corporate_headquarters", {})
	check(definition.get("behavior") == "headquarters", "Headquarters has distinct behavior")
	check(definition.get("category") == "Corporate" and definition.get("width") == 4 and definition.get("depth") == 3, "Headquarters category and footprint")
	check(definition.get("cost") == 5000000 and definition.get("overhead") == 2500, "Headquarters costs are catalog data")
	check(catalog.supports_product("corporate_headquarters", ""), "Empty headquarters product is valid")
	check(not catalog.supports_product("corporate_headquarters", "smartphone"), "Nonempty headquarters product is invalid")
	check(catalog.supports_product("research_center", ""), "R&D remains productless and valid")
	check(catalog.supports_product("electronics_store", "smartphone"), "Ordinary product facility remains valid")
	for era: int in [2012, 2022]:
		var session: GameSession = fresh(era)
		var owner: SimCompany = session.sim.companies.player
		var cash: int = owner.cash
		var capex: int = owner.capex
		var facility: SimFacility = build_headquarters(session)
		check(facility != null and facility.company_id == "player" and facility.product_id.is_empty(), "%d headquarters owner/product" % era)
		check(session.sim.city.plots[facility.id].width == 4 and session.sim.city.plots[facility.id].depth == 3, "%d headquarters occupies 4 x 3" % era)
		check(owner.cash == cash - 5000000 and owner.capex == capex + 5000000 and facility.asset_cost == 5000000, "%d exact cash/capex/fixed asset" % era)
		var next_site: Vector2i = session.sim.city.valid_sites(4, 3)[0]
		var duplicate: Dictionary = {"type": "build_facility", "company": "player", "archetype": "corporate_headquarters", "product": "", "x": next_site.x, "y": next_site.y}
		check(session.sim.command_error(duplicate).contains("already owns"), "%d second headquarters rejected clearly" % era)
		check(session.sim.invariant_errors().is_empty(), "%d construction balance reconciles" % era)
	var multiple: GameSession = fresh()
	build_headquarters(multiple, "player")
	var other: SimFacility = build_headquarters(multiple, "rival")
	check(other != null and other.company_id == "rival", "Different company independently owns one headquarters")

func _operating_accounting_and_demolition() -> void:
	var session: GameSession = fresh()
	var control: GameSession = fresh()
	var facility: SimFacility = build_headquarters(session)
	var owner: SimCompany = session.sim.companies.player
	var cash: int = owner.cash
	var control_cash: int = control.sim.companies.player.cash
	session.sim.step()
	control.sim.step()
	check((cash - owner.cash) - (control_cash - control.sim.companies.player.cash) == 2500, "Operating headquarters pays exact daily overhead")
	check(facility.accumulated_depreciation == 5000000 / 3650 and owner.depreciation == facility.accumulated_depreciation, "Headquarters uses ordinary 3,650-day depreciation")
	check(session.sim.invariant_errors().is_empty(), "Operating headquarters balance reconciles")
	session.sim.queue_command({"type": "set_operating", "company": "player", "facility": facility.id, "operating": false})
	cash = owner.cash
	control_cash = control.sim.companies.player.cash
	var depreciation: int = facility.accumulated_depreciation
	session.sim.step()
	control.sim.step()
	check(not facility.operating and not facility.active and cash - owner.cash == control_cash - control.sim.companies.player.cash, "Suspended headquarters pays no overhead")
	check(facility.accumulated_depreciation > depreciation, "Suspended headquarters continues depreciation")
	check(session.sim.invariant_errors().is_empty(), "Suspended headquarters balance reconciles")
	var plot: Dictionary = session.sim.city.plots[facility.id].duplicate(true)
	var book_value: int = facility.asset_cost - facility.accumulated_depreciation
	var expenses: int = owner.expenses
	check(session.submit({"type": "demolish_facility", "facility": facility.id}), "Headquarters demolition accepted")
	check(session.sim.headquarters("player") == null and not session.sim.city.plots.has(facility.id), "Demolition frees headquarters relationship and plot")
	check(owner.expenses == expenses + book_value, "Demolition writes off exact remaining book value with zero inventory loss")
	check(session.sim.invariant_errors().is_empty(), "Demolition write-off reconciles")
	var replacement: SimFacility = build_headquarters(session)
	check(replacement != null and replacement.id != facility.id and session.sim.city.plots.has(replacement.id), "Demolition permits replacement headquarters")
	check(plot.width == 4 and plot.depth == 3, "Demolished footprint was headquarters-sized")

func _isolation_and_persistence() -> void:
	var session: GameSession = fresh()
	var headquarters: SimFacility = build_headquarters(session)
	var store: SimFacility = session.sim.facility("20_player")
	store.inventory.add("smartphone", 2, 0, 50)
	var base: Dictionary = {"company": "player", "facility": headquarters.id}
	check(not session.sim.command_error(base.merged({"type": "set_price", "price": 100})).is_empty(), "Headquarters cannot configure price")
	check(not session.sim.command_error(base.merged({"type": "set_supplier", "product": "smartphone", "supplier": ""})).is_empty(), "Headquarters cannot configure sourcing")
	check(not session.sim.command_error(base.merged({"type": "set_warehouse_target", "product": "smartphone", "quantity": 1})).is_empty(), "Headquarters cannot configure replenishment")
	check(not session.sim.command_error({"type": "transfer", "company": "player", "facility": store.id, "destination": headquarters.id, "product": "smartphone", "quantity": 1}).is_empty(), "Headquarters cannot receive inventory transfer")
	check(not session.sim.command_error(base.merged({"type": "assign_research", "project": session.sim.technology_project("modern_wearables")})).is_empty(), "Headquarters cannot receive a research project")
	var brands: Dictionary = session.sim.companies.player.product_brands.duplicate(true)
	var knowledge: Dictionary = session.sim.companies.player.known_technologies.duplicate(true)
	session.sim.step()
	check(session.sim.companies.player.product_brands == brands and session.sim.companies.player.known_technologies == knowledge, "Headquarters adds no brand or research effect")
	check(headquarters.inventory.quantities.is_empty() and headquarters.assortment.is_empty() and headquarters.suppliers.is_empty() and headquarters.research_project.is_empty(), "Headquarters product/logistics/research state stays empty")
	var state: Dictionary = session.sim.snapshot()
	check(state.schema_version == 16 and state.catalog_version == 9 and SaveStore.FORMAT_VERSION == 2, "Current economy uses schema 16 and catalog 9")
	var restored: Economy = SaveStore.new().restore(state)
	var restored_hq: SimFacility = restored.headquarters("player") if restored != null else null
	check(restored_hq != null and restored_hq.id == headquarters.id and restored_hq.company_id == headquarters.company_id, "Built headquarters restores exact identity and owner")
	check(restored_hq != null and restored_hq.operating == headquarters.operating and restored_hq.asset_cost == headquarters.asset_cost and restored_hq.asset_days == headquarters.asset_days and restored_hq.accumulated_depreciation == headquarters.accumulated_depreciation, "Operating and fixed-asset state restores exactly")
	var invalid_product: Dictionary = state.duplicate(true)
	for item: Dictionary in invalid_product.facilities:
		if item.id == headquarters.id:
			item.product = "smartphone"
	check(SaveStore.new().restore(invalid_product) == null, "Corrupted headquarters product rejected")
	var invalid_inventory: Dictionary = state.duplicate(true)
	for item: Dictionary in invalid_inventory.facilities:
		if item.id == headquarters.id:
			item.inventory.quantities = {"smartphone": 1}
			item.inventory.costs = {"smartphone": 100}
			item.inventory.quality_points = {"smartphone": 50}
	check(SaveStore.new().restore(invalid_inventory) == null, "Corrupted headquarters inventory rejected")
	var duplicate_session: GameSession = fresh()
	var first: SimFacility = build_headquarters(duplicate_session, "player")
	var second: SimFacility = build_headquarters(duplicate_session, "rival")
	var duplicate_state: Dictionary = duplicate_session.sim.snapshot()
	for item: Dictionary in duplicate_state.facilities:
		if item.id == second.id: item.company = first.company_id
	check(SaveStore.new().restore(duplicate_state) == null, "Corrupted duplicate company headquarters rejected")

func _ui_read_model() -> void:
	var screen: Control = preload("res://src/ui/game_screen.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var headquarters: SimFacility = build_headquarters(screen.session)
	screen.city.sync(screen.session.sim.snapshot())
	screen.select_facility(headquarters.id)
	await process_frame
	var panel: FacilityPanel = screen.inspector
	check(panel.selected_id == headquarters.id and panel.visible, "Constructed headquarters can be selected")
	check(panel.info.text.contains("Corporate headquarters") and panel.staff_info.text.contains("STAFFING"), "Headquarters-specific inspector information shown")
	check(panel.info.text.contains("Daily overhead") and panel.info.text.contains("Net book value"), "Headquarters inspector shows overhead and fixed asset")
	check(not panel.configure.visible and not panel.price.get_parent().visible and not panel.stock.get_parent().visible and panel.tabs.is_tab_hidden(1) and panel.tabs.is_tab_hidden(2), "Product, price, stock, sourcing and logistics controls hidden")
	check(panel.operating.visible and not panel.operating.disabled and panel.demolish.visible and not panel.demolish.disabled, "Suspend/resume and demolish remain available")
	screen._show_construction()
	for index: int in range(screen.build_choices.item_count):
		if screen.build_choices.get_item_metadata(index) == "corporate_headquarters": screen.build_choices.select(index)
	screen._choose_build()
	check(not screen.build_products.visible and screen.city.build_type == "corporate_headquarters" and screen.city.build_product.is_empty(), "Build UI exposes headquarters without product selection")
	screen.queue_free()
