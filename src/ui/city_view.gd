class_name CityView
extends Node3D

signal facility_selected(id: String)
signal property_selected(id: String)
signal parcel_selected(x: int, y: int)
signal port_selected
signal placement_requested(x: int, y: int)
signal placement_changed(reason: String)
signal context_cleared
signal placement_cancelled
const CELL: float = 1.4
var camera: Camera3D
var buildings: Dictionary = {}
var selected: String = ""
var focus: Vector3 = Vector3.ZERO
var colors: Dictionary = {}
var session: GameSession
var structures: Node3D
var preview: MeshInstance3D
var build_type: String = ""
var build_product: String = ""
var preview_cell: Vector2i = Vector2i(-1, -1)
var preview_error: String = ""
var input_blocked: Callable
var dragging: bool = false
var map_width: int = 32
var map_depth: int = 24
var max_zoom: float = 65.0
var parcel_overlay: Node3D
var property_structures: Node3D
var property_buildings: Dictionary = {}
var selected_property: String = ""
var ambient_state: Dictionary = {}
var overlay_state: Dictionary = {}
var property_marker: MeshInstance3D

func build(state: Dictionary) -> void:
	var palette: Array[Color] = [Color("699eaf"), Color("c99563"), Color("927cbb"), Color("51bda0"), Color("dc7b80")]
	var index: int = 0
	for owner: Dictionary in state.companies:
		colors[owner.id] = palette[index % palette.size()]
		index += 1
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("243544")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e7ed")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var map: Dictionary = state.get("city", state.get("cities", {}).get(session.active_city, {}))
	map_width = int(map.width)
	map_depth = int(map.depth)
	max_zoom = maxf(65.0, maxf(map_width, map_depth) * CELL * 1.5)
	_box(self, Vector3(0, -0.25, 0), Vector3(map.width * CELL, 0.5, map.depth * CELL), Color("738672"))
	var water_cells: Array[Vector3] = []
	var shore_cells: Array[Vector3] = []
	var road_cells: Array[Vector3] = []
	var bridge_cells: Array[Vector3] = []
	var bank_cells: Array[Vector3] = []
	var city_map: CityMap = session.sim.cities[session.active_city]
	for y: int in range(map.depth):
		for x: int in range(map.width):
			var pos: Vector3 = cell_position(x, y)
			if city_map.is_water(x, y):
				if city_map.touches_road(x, y) or (x > 0 and not city_map.is_water(x - 1, y)): shore_cells.append(pos)
				else: water_cells.append(pos)
			elif city_map.touches_water(x, y): bank_cells.append(pos)
			if city_map.is_road(x, y):
				if CityMap.key(x, y) in city_map.bridges: bridge_cells.append(pos)
				else: road_cells.append(pos)
	_batch_boxes(self, water_cells, Vector3(CELL, 0.04, CELL), Color("3c819c"), 0.02)
	_batch_boxes(self, shore_cells, Vector3(CELL, 0.04, CELL), Color("549caf"), 0.02)
	_batch_boxes(self, bank_cells, Vector3(CELL, 0.02, CELL), Color("b0ac82"), 0.01)
	_batch_boxes(self, road_cells, Vector3(CELL, 0.03, CELL), Color("394953"), 0.035)
	_batch_boxes(self, bridge_cells, Vector3(CELL, 0.13, CELL), Color("756d63"), 0.13)
	property_structures = Node3D.new()
	add_child(property_structures)
	property_marker = _box(self, Vector3.ZERO, Vector3.ONE, Color("ffe190"))
	property_marker.hide()
	parcel_overlay = Node3D.new()
	add_child(parcel_overlay)
	_refresh_parcel_overlay()
	parcel_overlay.hide()
	structures = Node3D.new()
	add_child(structures)
	sync(state)
	if not map.port.is_empty():
		var marker: StaticBody3D = StaticBody3D.new()
		marker.position = cell_position(int(map.port.x), int(map.port.y)) + Vector3(0, 0.65, 0)
		marker.set_meta("port_id", str(map.port.id))
		add_child(marker)
		_box(marker, Vector3.ZERO, Vector3(CELL * 1.1, 0.45, CELL * 1.1), Color("e8a843"))
		_box(marker, Vector3(0, 1.1, 0), Vector3(0.25, 2.0, 0.25), Color("fff0aa"))
		_box(marker, Vector3(0, 2.1, 0), Vector3(1.0, 0.16, 0.25), Color("fff0aa"))
		var label: Label3D = Label3D.new()
		label.text = "PORT"
		label.font_size = 30
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.65, 0)
		marker.add_child(label)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(CELL * 1.2, 3.0, CELL * 1.2)
		collision.shape = shape
		marker.add_child(collision)
	preview = _box(self, Vector3.ZERO, Vector3.ONE, Color("70efbb"))
	preview.hide()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 45.0 if map.generation.preset == "legacy" else 50.0
	add_child(camera)
	var initial: Vector2i = Vector2i(int(map_width / 2), int(map_depth / 2))
	if map.generation.preset == "procedural" and not map.generation.get("centers", []).is_empty():
		var center: Dictionary = map.generation.centers[0]
		initial = Vector2i(int(center.x), int(center.y))
	for f: Dictionary in state.facilities:
		if str(f.company) == session.active_company and map.plots.has(str(f.id)):
			var plot: Dictionary = map.plots[str(f.id)]
			initial = Vector2i(int(plot.x) + int(plot.width) / 2, int(plot.y) + int(plot.depth) / 2)
			break
	focus = cell_position(initial.x, initial.y)
	_update_camera()
	camera.make_current()

func cell_position(x: float, y: float) -> Vector3:
	return Vector3((x - (map_width - 1) / 2.0) * CELL, 0, (y - (map_depth - 1) / 2.0) * CELL)

func sync(state: Dictionary) -> void:
	var map: Dictionary = state.get("city", state.get("cities", {}).get(session.active_city, {}))
	if property_structures != null and map.ambient != ambient_state:
		for child: Node in property_structures.get_children():
			property_structures.remove_child(child)
			child.queue_free()
		property_buildings.clear()
		_build_ambient(map)
		ambient_state = map.ambient.duplicate(true)
	for child: Node in structures.get_children():
		structures.remove_child(child)
		child.queue_free()
	buildings.clear()
	for f: Dictionary in state.facilities:
		if str(f.city) != session.active_city: continue
		var p: Dictionary = map.plots[f.id]
		var definition: Dictionary = session.sim.catalog.facility_types[f.type] if session != null else {}
		var style: String = str(definition.get("style", "shop"))
		var height: float = 6.0 if style == "office" else 3.2 if style == "automobile" else 2.6 if style == "factory" else 2.9 if style == "department" else 2.2 if style == "research" else 1.5
		var size_value: Vector3 = Vector3(p.width * CELL - 0.5, height, p.depth * CELL - 0.5)
		var center: Vector3 = cell_position(p.x + (p.width - 1) / 2.0, p.y + (p.depth - 1) / 2.0)
		var body: StaticBody3D = StaticBody3D.new()
		body.position = center + Vector3(0, height / 2.0 + 0.15, 0)
		body.set_meta("facility_id", str(f.id))
		structures.add_child(body)
		_box(body, Vector3(0, -height / 2.0 - 0.07, 0), Vector3(p.width * CELL - 0.1, 0.15, p.depth * CELL - 0.1), Color("bcc1b6"))
		var mesh: MeshInstance3D = _box(body, Vector3.ZERO, size_value, Color("c4c3ae") if style == "factory" else Color("d5ded8"))
		_box(body, Vector3(0, height / 2.0, 0), Vector3(size_value.x + 0.15, 0.18, size_value.z + 0.15), colors[f.company].darkened(0.35))
		var outline: Node3D = Node3D.new()
		body.add_child(outline)
		for side: float in [-1.0, 1.0]:
			_box(outline, Vector3(side * (size_value.x / 2.0 + 0.2), -height / 2.0 + 0.03, 0), Vector3(0.12, 0.08, size_value.z + 0.5), Color("ffe190"))
			_box(outline, Vector3(0, -height / 2.0 + 0.03, side * (size_value.z / 2.0 + 0.2)), Vector3(size_value.x + 0.5, 0.08, 0.12), Color("ffe190"))
		var band: MeshInstance3D = _box(body, Vector3(0, height / 2.0 - 0.3, size_value.z / 2.0 + 0.025), Vector3(size_value.x, 0.35, 0.08), colors[f.company])
		if style in ["shop", "department", "dealer"]:
			for ix: int in range(int(p.width)):
				_box(body, Vector3(-size_value.x / 2.0 + 0.55 + ix * 1.25, -0.12, size_value.z / 2.0 + 0.04), Vector3(0.85, height * 0.48, 0.06), Color("325c70"))
			_box(body, Vector3(0, height / 2.0 - 0.55, size_value.z / 2.0 + 0.3), Vector3(size_value.x + 0.15, 0.12, 0.75), colors[f.company])
		elif style == "research":
			for ix: int in range(int(p.width)):
				_box(body, Vector3(-size_value.x / 2.0 + 0.65 + ix * 1.2, 0, size_value.z / 2.0 + 0.04), Vector3(0.8, 0.8, 0.06), Color("4f8295"))
			_box(body, Vector3(0, height / 2.0 + 0.25, 0), Vector3(1.4, 0.45, 0.9), Color("b6ccd5"))
		elif style in ["factory", "automobile"]:
			for ix: int in range(2):
				_box(body, Vector3(-1.2 + ix * 1.6, height / 2.0 + 0.4, 0), Vector3(1.1, 0.7, 1.4), Color("93a4aa"))
			_box(body, Vector3(size_value.x / 2.0 - 0.6, height / 2.0 + 1.1, -0.8), Vector3(0.5, 2.2, 0.5), Color("ac8876"))
			for ix: int in range(3):
				_box(body, Vector3(-1.5 + ix * 1.35, 0, size_value.z / 2.0 + 0.03), Vector3(1, 0.5, 0.08), Color("476b7c"))
		else:
			for ix: int in range(3):
				_box(body, Vector3(-2 + ix * 2, -0.1, size_value.z / 2.0 + 0.04), Vector3(1.4, 1.15, 0.12), Color("485f70"))
				_box(body, Vector3(-2 + ix * 2, -height / 2.0 + 0.05, size_value.z / 2.0 + 0.2), Vector3(1.55, 0.12, 0.45), Color("d4b870"))
		if style == "office":
			for level: int in range(5):
				_box(body, Vector3(0,-height/2+0.7+level, size_value.z/2+0.035), Vector3(size_value.x*0.9,0.55,0.08), Color("477689"))
			_box(body, Vector3(0,height/2+0.5,0), Vector3(1.4,1.0,1.4), colors[f.company])
		if style in ["dealer", "automobile"]:
			for i: int in range(3):
				_box(body, Vector3(-2+i*2,-height/2+0.28,size_value.z/2+0.1), Vector3(1.3,0.45,0.65), [Color("506b82"),Color("b7b9ad"),Color("9b695e")][i])
		if style == "department":
			_box(body, Vector3(0,height/2+0.45,0), Vector3(size_value.x*0.65,0.8,size_value.z*0.65), Color("a2b5b9"))
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size_value
		collision.shape = shape
		body.add_child(collision)
		var label: Label3D = Label3D.new()
		label.text = str(definition.get("name", f.type))
		label.font_size = 48
		label.pixel_size = 0.025
		label.outline_size = 10
		label.no_depth_test = true
		label.position.y = height / 2.0 + (2.5 if style == "factory" else 0.65)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = colors[f.company].lightened(0.3)
		body.add_child(label)
		buildings[f.id] = {"body": body, "mesh": band, "color": colors[f.company], "label": label, "outline": outline}
	select(selected)
	select_property(selected_property)
	if map.ambient != overlay_state.get("ambient", {}) or map.plots != overlay_state.get("plots", {}):
		_refresh_parcel_overlay()
		overlay_state = {"ambient": map.ambient.duplicate(true), "plots": map.plots.duplicate(true)}

func _refresh_parcel_overlay() -> void:
	if parcel_overlay == null: return
	for child: Node in parcel_overlay.get_children():
		parcel_overlay.remove_child(child)
		child.queue_free()
	var positions: Array[Vector3] = []
	for k: String in session.sim.cities[session.active_city].parcels:
		var p: Dictionary = session.sim.cities[session.active_city].parcels[k]
		if p.terrain == "land" and p.road_access:
			var coordinates: PackedStringArray = k.split(",")
			var x: int = int(coordinates[0])
			var y: int = int(coordinates[1])
			if session.sim.cities[session.active_city].placement_error(x, y, 1, 1).is_empty():
				positions.append(cell_position(x, y))
	_batch_boxes(parcel_overlay, positions, Vector3(CELL * 0.88, 0.04, CELL * 0.88), Color("82bca0"), 0.07)

func _build_ambient(map: Dictionary) -> void:
	for record: Dictionary in map.ambient.values(): property_buildings[str(record.id)] = record
	AmbientDetails.build(property_structures, map.ambient, cell_position, _material)

func _batch_boxes(parent: Node3D, positions: Array[Vector3], size_value: Vector3, color: Color, height: float) -> void:
	if positions.is_empty(): return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = positions.size()
	for i: int in range(positions.size()):
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i] + Vector3(0, height, 0)))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = _material(color)
	parent.add_child(node)

func focus_cell(x: float, y: float) -> void:
	focus = cell_position(clampf(x, 0, map_width - 1), clampf(y, 0, map_depth - 1))
	_update_camera()

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	mesh.position = position_value
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func select(id: String) -> void:
	selected = id
	for key: String in buildings:
		var record: Dictionary = buildings[key]
		record.mesh.material_override.albedo_color = Color("ffe190") if key == selected else record.color
		record.label.visible = key == selected
		record.outline.visible = key == selected

func select_property(id: String) -> void:
	selected_property = id
	if property_marker == null: return
	if not property_buildings.has(id):
		property_marker.hide()
		return
	var b: Dictionary = property_buildings[id]
	property_marker.mesh.size = Vector3(int(b.width) * CELL + 0.15, 0.12, int(b.depth) * CELL + 0.15)
	property_marker.position = cell_position(b.x + (b.width - 1) / 2.0, b.y + (b.depth - 1) / 2.0) + Vector3(0, 0.13, 0)
	property_marker.show()

func begin_placement(type_id: String, product: String) -> void:
	build_type = type_id
	build_product = product
	update_preview(preview_cell.x, preview_cell.y)

func cancel_placement() -> void:
	build_type = ""
	preview.hide()
	placement_cancelled.emit()

func update_preview(x: int, y: int) -> void:
	if build_type.is_empty(): return
	preview_cell = Vector2i(x, y)
	var definition: Dictionary = session.sim.catalog.facility_types[build_type]
	preview_error = session.sim.command_error({"type": "build_facility", "company": session.active_company, "city": session.active_city, "archetype": build_type, "product": build_product, "x": x, "y": y})
	preview.mesh.size = Vector3(definition.width * CELL - 0.08, 0.16, definition.depth * CELL - 0.08)
	preview.position = cell_position(x + (definition.width - 1) / 2.0, y + (definition.depth - 1) / 2.0) + Vector3(0, 0.25, 0)
	preview.material_override.albedo_color = Color("67ffb8") if preview_error.is_empty() else Color("ff6170")
	if get_node("/root/UIService").preferences.high_contrast:
		preview.material_override.albedo_color = Color("eaff8a") if preview_error.is_empty() else Color("ff75ba")
	preview.material_override.no_depth_test = true
	preview.show()
	var info: Dictionary = session.sim.cities[session.active_city].parcel_info(x, y)
	var detail: String = ""
	if info.has("land_value"):
		detail = "\n%s • Land $%.0f/cell%s" % [DisplayLabels.district(session.sim.cities[session.active_city], str(info.district)), info.land_value / 100.0, " • Waterfront" if info.waterfront else ""]
	placement_changed.emit(("Valid site — click to build" if preview_error.is_empty() else preview_error) + detail)

func _update_camera() -> void:
	# Keep the entire map ahead of the near plane, even with focus at a corner.
	var extent: float = Vector2(map_width, map_depth).length() * CELL
	var distance: float = extent + 32.0
	camera.near = 0.1
	camera.far = distance + extent + 64.0
	camera.position = focus + Vector3.ONE.normalized() * distance
	camera.look_at(focus)

func pan(move: Vector3, delta: float) -> void:
	focus += move.normalized() * delta * 12.0
	focus.x = clampf(focus.x, -map_width * CELL / 2, map_width * CELL / 2)
	focus.z = clampf(focus.z, -map_depth * CELL / 2, map_depth * CELL / 2)
	_update_camera()
	if not move.is_zero_approx() and not build_type.is_empty():
		_pointer_preview(get_viewport().get_mouse_position())

func _pointer_preview(point: Vector2) -> void:
	var ground: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if ground != null:
		update_preview(int(floor(ground.x / CELL + map_width / 2.0)), int(floor(ground.z / CELL + map_depth / 2.0)))

func _property_at_ray(origin: Vector3, direction: Vector3) -> String:
	var map: CityMap = session.sim.cities[session.active_city]
	for level: int in range(14):
		var height: float = 6.5 - level * 0.5
		var point: Variant = Plane(Vector3.UP, height).intersects_ray(origin, direction)
		if point == null: continue
		var x: int = int(floor(point.x / CELL + map_width / 2.0))
		var y: int = int(floor(point.z / CELL + map_depth / 2.0))
		var id: String = str(map.parcel_info(x, y).occupant)
		if not property_buildings.has(id): continue
		var b: Dictionary = property_buildings[id]
		var scale: float = 1.0 + int(b.tone) * 0.09 if b.kind in ["block", "office"] else 1.0
		if height <= 0.65 + int(b.height) * 0.65 * scale: return id
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked.is_valid() and input_blocked.call():
		dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = event.pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and dragging:
		if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			dragging = false
			return
		var plane: Plane = Plane(Vector3.UP, 0)
		var before: Variant = plane.intersects_ray(camera.project_ray_origin(event.position - event.relative), camera.project_ray_normal(event.position - event.relative))
		var after: Variant = plane.intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if before != null and after != null:
			focus += before - after
			focus.x = clampf(focus.x, -map_width * CELL / 2, map_width * CELL / 2)
			focus.z = clampf(focus.z, -map_depth * CELL / 2, map_depth * CELL / 2)
			_update_camera()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and not build_type.is_empty():
		_pointer_preview(event.position)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(18.0, camera.size - 2.0 * event.factor)
			if not build_type.is_empty(): _pointer_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(max_zoom, camera.size + 2.0 * event.factor)
			if not build_type.is_empty(): _pointer_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not build_type.is_empty(): cancel_placement()
			else: context_cleared.emit()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not build_type.is_empty():
				_pointer_preview(event.position)
				placement_requested.emit(preview_cell.x, preview_cell.y)
				return
			var origin: Vector3 = camera.project_ray_origin(event.position)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * camera.far)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider.has_meta("facility_id"):
				facility_selected.emit(str(hit.collider.get_meta("facility_id")))
			elif not hit.is_empty() and hit.collider.has_meta("port_id"):
				port_selected.emit()
			else:
				var property_id: String = _property_at_ray(origin, camera.project_ray_normal(event.position))
				if not property_id.is_empty():
					property_selected.emit(property_id)
					return
				var ground: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, camera.project_ray_normal(event.position))
				if ground != null:
					var cx: int = int(floor(ground.x / CELL + map_width / 2.0))
					var cy: int = int(floor(ground.z / CELL + map_depth / 2.0))
					var occupant: String = str(session.sim.cities[session.active_city].parcel_info(cx, cy).occupant)
					if occupant.begins_with("ambient_") or occupant.begins_with("property_"): property_selected.emit(occupant)
					else: parcel_selected.emit(cx, cy)
