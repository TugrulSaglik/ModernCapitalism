extends Control

const Simulation = preload("res://src/sim/economy.gd")
var sim: Economy
var era_choice: OptionButton
var report: RichTextLabel

func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	margin.add_child(layout)
	var title: Label = Label.new()
	title.text = "ModernCapitalism — Economic simulation debug"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	var controls: HBoxContainer = HBoxContainer.new()
	layout.add_child(controls)
	era_choice = OptionButton.new()
	controls.add_child(era_choice)
	var probe: Economy = Simulation.new()
	if not probe.initialize():
		return
	for year: Variant in probe.catalog.scenario.starting_years:
		era_choice.add_item(str(int(year)), int(year))
	era_choice.select(1)
	_add_button(controls, "Reset (seed 42)", _reset)
	_add_button(controls, "Advance 1 day", func() -> void: _advance(1))
	_add_button(controls, "Advance 30 days", func() -> void: _advance(30))
	_add_button(controls, "Advance 365 days", func() -> void: _advance(365))
	report = RichTextLabel.new()
	report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report.add_theme_font_size_override("normal_font_size", 17)
	layout.add_child(report)
	_reset()

func _add_button(parent: HBoxContainer, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _reset() -> void:
	sim = Simulation.new()
	if sim.initialize(42, era_choice.get_selected_id()):
		_refresh()

func _advance(days: int) -> void:
	for day: int in range(days):
		sim.step()
	_refresh()

func _refresh() -> void:
	var state: Dictionary = sim.snapshot()
	var lines: PackedStringArray = []
	lines.append("Next simulation day: %s   |   Completed days: %d" % [sim.clock.date_string(), sim.clock.tick])
	lines.append("Cumulative consumer sales: %d units / $%.2f\n" % [state.consumer_units, state.consumer_revenue / 100.0])
	for company: Dictionary in state.companies:
		lines.append("%s: cash $%.2f | revenue $%.2f | profit $%.2f | stock assets $%.2f" % [company.name, company.cash / 100.0, company.revenue / 100.0, company.profit / 100.0, company.inventory_assets / 100.0])
	lines.append("\nFacilities — last completed day")
	for f: Dictionary in state.facilities:
		lines.append("%s / %s: price $%.2f | quality %d | inventory %d | made %d | consumer sales %d%s" % [f.id, f.product, f.price / 100.0, f.quality, int(f.inventory.quantities.get(f.product, 0)), f.produced_today, f.sold_today, "" if sim.catalog.product_public(f.product, sim.clock.year) else " [era locked]"])
	lines.append("\nBalance/inventory checks: " + ("OK" if sim.invariant_errors().is_empty() else str(sim.invariant_errors())))
	report.text = "\n".join(lines)
