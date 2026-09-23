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

func _row(tree: Tree, label: String) -> TreeItem:
	for item: TreeItem in tree.get_root().get_children():
		if item.get_text(0) == label:
			return item
	return null

func _select_product(reports: CompanyReports, product: String) -> void:
	for index: int in range(reports.products.item_count):
		if str(reports.products.get_item_metadata(index)) == product:
			reports.products.select(index)
			return

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var screen: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	screen.session.time.set_speed(0)
	for day: int in range(4):
		screen.session.sim.step()
	var reports: CompanyReports = screen.reports
	reports.tabs.current_tab = 3
	reports.refresh()
	await process_frame
	var sim: Economy = screen.session.sim
	var owner: SimCompany = sim.companies.player

	check(reports.market_content.visible and not reports.table.visible and not reports.report_controls.visible, "Markets has a dedicated content surface")
	for index: int in range(reports.products.item_count):
		var id: String = str(reports.products.get_item_metadata(index))
		check(sim.catalog.consumer_product(id), "Selector contains only consumer products: " + id)
		check(reports.products.get_item_text(index) == str(sim.catalog.products[id].name), "Selector uses catalog display name: " + id)
	_select_product(reports, "smartphone")
	reports.refresh()
	var selected: String = str(reports.products.get_item_metadata(reports.products.selected))
	check(selected == "smartphone" and reports.market_metadata.text.contains("Product ID: smartphone"), "Stable selected product metadata is visible")
	reports.tabs.current_tab = 0
	reports.refresh()
	check(reports.table.visible and reports.report_controls.visible and not reports.market_content.visible, "Income Statement retains financial controls without Markets leakage")
	reports.tabs.current_tab = 1
	reports.refresh()
	check(reports.table.visible and not reports.report_controls.visible and not reports.market_content.visible, "Balance Sheet remains intact without period controls")
	reports.tabs.current_tab = 3
	reports.refresh()
	check(str(reports.products.get_item_metadata(reports.products.selected)) == selected, "Product selection survives ordinary tab switching")

	var definition: Dictionary = sim.catalog.products[selected]
	var category: Dictionary = sim.category_market[definition.category]
	var market: Dictionary = sim.market[selected]
	var history_units: int = 0
	for record: Dictionary in sim.market_history:
		history_units += int(record.categories.get(definition.category, {}).get("units", 0))
	check(reports.market_metadata.text.contains(str(definition.name)) and reports.market_metadata.text.contains(str(sim.catalog.categories[definition.category].name)) and reports.market_metadata.text.contains("PUBLIC"), "Product/category/availability metadata is exact")
	check(_row(reports.market_overview, "Category potential").get_metadata(1) == int(category.potential), "Category potential exact")
	check(_row(reports.market_overview, "Purchased").get_metadata(1) == int(category.units), "Purchased exact")
	check(_row(reports.market_overview, "No purchase / unfilled").get_metadata(1) == int(category.potential) - int(category.units), "Unfilled demand exact")
	check(_row(reports.market_overview, "Product units sold").get_metadata(1) == int(market.units), "Selected-product units exact")
	check(is_equal_approx(float(_row(reports.market_overview, "Local share").get_metadata(1)), float(market.local_share)), "Local share exact")
	check(_row(reports.market_overview, "90-day category activity").get_metadata(1) == history_units and _row(reports.market_overview, "90-day category activity").get_text(1).contains("includes Local"), "90-day category activity exact and labeled")

	var brand: int = owner.brand(selected)
	check(_row(reports.advertising_summary, "Current company brand").get_metadata(1) == brand, "Company-product brand exact")
	check(_row(reports.advertising_summary, "Daily advertising budget").get_metadata(1) == int(owner.advertising_budgets[selected]), "Advertising budget exact")
	check(_row(reports.advertising_summary, "Progress toward next brand point").get_metadata(1) == int(owner.advertising_progress[selected]), "Advertising progress exact")
	check(_row(reports.advertising_summary, "Next threshold").get_metadata(1) == sim.advertising_threshold(selected, brand), "Advertising threshold uses simulation helper")
	check(_row(reports.advertising_summary, "Inactive advertising days").get_metadata(1) == int(owner.advertising_inactive_days[selected]), "Advertising inactivity exact")
	owner.product_brands[selected] = 100
	reports.refresh()
	check(_row(reports.advertising_summary, "Next threshold").get_text(1) == "MAX" and _row(reports.advertising_summary, "Progress toward next brand point").get_text(1) == "MAX", "Brand 100 shows MAX")
	owner.product_brands[selected] = brand
	reports.refresh()
	var emitted: Array[Dictionary] = []
	reports.command_requested.connect(func(command: Dictionary) -> void: emitted.append(command))
	reports.advertising_budget.value = 25.75
	reports.apply_advertising.pressed.emit()
	check(not emitted.is_empty() and emitted.back() == {"type": "set_advertising_budget", "product": selected, "budget": 2575}, "Budget command converts dollars to cents exactly")

	var local: Dictionary = ConsumerMarket.local_offer(sim, selected)
	check(_row(reports.market_benchmark, "Price").get_text(1) == CompanyReports.money(int(local.price)) and _row(reports.market_benchmark, "Price").get_text(2) == CompanyReports.money(int(round(market.average_price))), "Local and market price exact")
	check(_row(reports.market_benchmark, "Quality").get_text(1) == str(int(local.quality)) and _row(reports.market_benchmark, "Brand").get_text(1) == str(int(local.brand)), "Local quality and brand exact")
	check(_row(reports.market_benchmark, "Overall / 100").get_text(1) == "%.1f" % ConsumerDemand.overall(local.price, definition.reference_price, local.quality, local.brand), "Local overall exact")
	check(_row(reports.market_benchmark, "Quality").get_text(2) == "%.1f" % float(market.average_quality) and _row(reports.market_benchmark, "Brand").get_text(2) == "%.1f" % float(market.average_brand) and _row(reports.market_benchmark, "Overall / 100").get_text(2) == "%.1f" % float(market.average_overall), "Market averages exact")

	var expected_offers: int = 0
	for facility: SimFacility in sim.facilities:
		if sim._behavior(facility) == "retail" and facility.assortment.has(selected):
			expected_offers += 1
			var item: TreeItem = null
			for candidate: TreeItem in reports.corporate_offers.get_root().get_children():
				if str(candidate.get_metadata(0)) == facility.id: item = candidate
			check(item != null, "Offer row exists for " + facility.id)
			if item != null:
				var sold: int = int(facility.line_today.get(selected, {}).get("units", 0))
				check(item.get_text(0).contains(sim.companies[facility.company_id].display_name) and item.get_text(0).contains(sim.catalog.facility_types[facility.type_id].name), "Offer identity exact for " + facility.id)
				check(item.get_metadata(1) == facility.line_price(selected) and item.get_text(2) == facility.inventory.quality_text(selected), "Offer price and stock quality exact for " + facility.id)
				check(item.get_metadata(3) == sim.companies[facility.company_id].brand(selected) and item.get_metadata(4) == sold, "Offer brand and completed-day units exact for " + facility.id)
				check(is_equal_approx(float(item.get_metadata(5)), float(sold) / int(market.units) if int(market.units) > 0 else 0.0), "Offer realized share exact for " + facility.id)
				if facility.company_id == "player": check(item.get_text(0).contains("YOU"), "Player offer identifiable")
	check(reports.corporate_offers.get_root().get_child_count() == expected_offers, "One offer row per retail facility carrying product")

	check(_row(reports.company_shares, "Local") != null and is_equal_approx(float(_row(reports.company_shares, "Local").get_metadata(2)), float(market.local_share)), "Local is present with exact realized share")
	for company_id: String in market.market_share:
		var share_row: TreeItem = _row(reports.company_shares, sim.companies[company_id].display_name)
		check(share_row != null and is_equal_approx(float(share_row.get_metadata(2)), float(market.market_share[company_id])), "Corporate realized share exact for " + company_id)
	check(_row(reports.company_shares, "No purchase") == null and _row(reports.company_shares, "Unfilled") == null, "Outside option is not inserted as a seller")
	for segment_id: String in category.segments:
		var segment_row: TreeItem = _row(reports.segment_potential, sim.catalog.segments[segment_id].name)
		check(segment_row != null and segment_row.get_metadata(1) == int(category.segments[segment_id]), "Segment potential exact for " + segment_id)

	sim.market[selected] = ConsumerMarket.empty_report()
	reports.refresh()
	check(_row(reports.market_overview, "Product units sold").get_text(1) == "No realized sales today" and _row(reports.company_shares, "No realized sales today.") != null, "No-realized-sales state is explicit")
	screen.session.start(2012, 42, "sandbox")
	reports.products.clear()
	reports.refresh()
	_select_product(reports, "advanced_phone")
	reports.refresh()
	check(reports.market_metadata.text.contains("ERA LOCKED") and reports.apply_advertising.disabled and not reports.advertising_budget.editable, "Era-locked state disables advertising without changing gates")
	check(_row(reports.corporate_offers, "No corporate offers currently carry this product.") != null, "Locked/no-offer state is explicit")

	screen._show_company()
	await process_frame
	await process_frame
	check(screen.overview.size.x <= 800.0 and screen.overview.size.y <= 650.0 and reports.report_scroll.get_v_scroll_bar().visible, "Markets remains vertically reachable in the bounded Company dialog")
	var horizontal_overflow: bool = false
	for market_tree: Tree in [reports.market_overview, reports.advertising_summary, reports.market_benchmark, reports.corporate_offers, reports.company_shares, reports.segment_potential]:
		for scrollbar: Node in market_tree.find_children("*", "HScrollBar", true, false):
			horizontal_overflow = horizontal_overflow or (scrollbar as HScrollBar).visible
	check(not horizontal_overflow, "Markets has no horizontal overflow")
	check(reports.tabs.tab_count == 7 and screen.world_input_blocked(), "Company dialog remains seven-tab and modal")

	print("8UI-B4B TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
