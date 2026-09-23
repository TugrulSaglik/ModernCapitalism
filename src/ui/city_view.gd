class_name CityView
extends Node3D

signal facility_selected(id: String)
signal placement_requested(x: int, y: int)
signal placement_changed(reason: String)
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
	var map: Dictionary = state.city
	map_width = int(map.width)
	map_depth = int(map.depth)
	max_zoom = maxf(65.0, maxf(map_width, map_depth) * CELL * 1.5)
	_box(self, Vector3(0, -0.25, 0), Vector3(map.width * CELL, 0.5, map.depth * CELL), Color("738672"))
	for y: int in range(map.depth):
		for x: int in range(map.width):
			var road: bool = CityMap.key(x, y) in map.roads
			var pos: Vector3 = cell_position(x, y)
			if CityMap.key(x, y) in map.water:
				var shore: bool = x > 0 and CityMap.key(x - 1, y) not in map.water
				_box(self, pos + Vector3(0, 0.02, 0), Vector3(CELL, 0.04, CELL), Color("549caf") if shore else Color("3c819c"))
			elif session.sim.city.touches_water(x, y):
				_box(self, pos + Vector3(0, 0.01, 0), Vector3(CELL, 0.02, CELL), Color("b0ac82"))
			if road:
				_box(self, pos + Vector3(0, 0.015, 0), Vector3(CELL, 0.03, CELL), Color("394953"))
			if road and map.road_classes.get(CityMap.key(x, y), "") == "major" and x % 2 == 0:
				_box(self, pos + Vector3(0, 0.045, 0), Vector3(0.5, 0.025, 0.045), Color("c9c7a7"))
	_build_ambient(map)
	parcel_overlay = Node3D.new()
	add_child(parcel_overlay)
	_refresh_parcel_overlay()
	parcel_overlay.hide()
	structures = Node3D.new()
	add_child(structures)
	sync(state)
	preview = _box(self, Vector3.ZERO, Vector3.ONE, Color("70efbb"))
	preview.hide()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 45.0 if map.generation.preset == "legacy" else maxf(map_width, map_depth) * CELL * 0.94
	add_child(camera)
	_update_camera()
	camera.make_current()

func cell_position(x: float, y: float) -> Vector3:
	return Vector3((x - (map_width - 1) / 2.0) * CELL, 0, (y - (map_depth - 1) / 2.0) * CELL)

func sync(state: Dictionary) -> void:
	for child: Node in structures.get_children():
		structures.remove_child(child)
		child.queue_free()
	buildings.clear()
	for f: Dictionary in state.facilities:
		var p: Dictionary = state.city.plots[f.id]
		var definition: Dictionary = session.sim.catalog.facility_types[f.type] if session != null else {}
		var style: String = str(definition.get("style", "shop"))
		var height: float = 2.6 if style == "factory" else (2.9 if style == "department" else 1.5)
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
		if style in ["shop", "department"]:
			for ix: int in range(int(p.width)):
				_box(body, Vector3(-size_value.x / 2.0 + 0.55 + ix * 1.25, -0.12, size_value.z / 2.0 + 0.04), Vector3(0.85, height * 0.48, 0.06), Color("325c70"))
			_box(body, Vector3(0, height / 2.0 - 0.55, size_value.z / 2.0 + 0.3), Vector3(size_value.x + 0.15, 0.12, 0.75), colors[f.company])
		elif style == "research":
			for ix: int in range(int(p.width)):
				_box(body, Vector3(-size_value.x / 2.0 + 0.65 + ix * 1.2, 0, size_value.z / 2.0 + 0.04), Vector3(0.8, 0.8, 0.06), Color("4f8295"))
			_box(body, Vector3(0, height / 2.0 + 0.25, 0), Vector3(1.4, 0.45, 0.9), Color("b6ccd5"))
		elif style == "factory":
			for ix: int in range(2):
				_box(body, Vector3(-1.2 + ix * 1.6, height / 2.0 + 0.4, 0), Vector3(1.1, 0.7, 1.4), Color("93a4aa"))
			_box(body, Vector3(size_value.x / 2.0 - 0.6, height / 2.0 + 1.1, -0.8), Vector3(0.5, 2.2, 0.5), Color("ac8876"))
			for ix: int in range(3):
				_box(body, Vector3(-1.5 + ix * 1.35, 0, size_value.z / 2.0 + 0.03), Vector3(1, 0.5, 0.08), Color("476b7c"))
		else:
			for ix: int in range(3):
				_box(body, Vector3(-2 + ix * 2, -0.1, size_value.z / 2.0 + 0.04), Vector3(1.4, 1.15, 0.12), Color("485f70"))
				_box(body, Vector3(-2 + ix * 2, -height / 2.0 + 0.05, size_value.z / 2.0 + 0.2), Vector3(1.55, 0.12, 0.45), Color("d4b870"))
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
	_refresh_parcel_overlay()

func _refresh_parcel_overlay() -> void:
	if parcel_overlay == null: return
	for child: Node in parcel_overlay.get_children():
		parcel_overlay.remove_child(child)
		child.queue_free()
	for k: String in session.sim.city.parcels:
		var p: Dictionary = session.sim.city.parcels[k]
		if p.terrain == "land" and p.road_access:
			var coordinates: PackedStringArray = k.split(",")
			var x: int = int(coordinates[0])
			var y: int = int(coordinates[1])
			if session.sim.city.placement_error(x, y, 1, 1).is_empty():
				_box(parcel_overlay, cell_position(x, y) + Vector3(0, 0.07, 0), Vector3(CELL * 0.88, 0.04, CELL * 0.88), Color("82bca0"))

func _build_ambient(map: Dictionary) -> void:
	var tones: Array[Color] = [Color("c4b49b"), Color("bec0b4"), Color("b2b7bc"), Color("d2c5af"), Color("a8b6ac")]
	for b: Dictionary in map.ambient.values():
		var center: Vector3 = cell_position(b.x + (b.width - 1) / 2.0, b.y + (b.depth - 1) / 2.0)
		var h: float = 0.65 + int(b.height) * 0.65
		var sx: float = b.width * CELL - 0.65
		var sz: float = b.depth * CELL - 0.65
		var color: Color = tones[b.tone]
		if b.kind == "office": color = Color("839ba5")
		_box(self, center + Vector3(0, h / 2, 0), Vector3(sx, h, sz), color)
		_box(self, center + Vector3(0, h, 0), Vector3(sx + 0.1, 0.15, sz + 0.1), Color("707a7b") if b.kind != "house" else Color("946d59"))
		if b.roof == 1 and b.kind == "house":
			var roof: MeshInstance3D = MeshInstance3D.new()
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(sx + 0.12, 0.65, sz + 0.12)
			roof.mesh = prism
			roof.material_override = _material(Color("946d59").darkened(b.tone * 0.035))
			roof.position = center + Vector3(0, h + 0.32, 0)
			add_child(roof)
		if b.kind == "house":
			_box(self, center + Vector3(sx * 0.28, 0.35, sz / 2 + 0.04), Vector3(0.32, 0.7, 0.06), Color("756653"))
			# Saved tone/orientation choose deterministic garden details.
			if b.tone % 2 == 0:
				var tree: Vector3 = center + Vector3(-sx / 2 - 0.13, 0, sz / 2 + 0.08)
				_box(self, tree + Vector3(0, 0.3, 0), Vector3(0.12, 0.6, 0.12), Color("756653"))
				_box(self, tree + Vector3(0, 0.85, 0), Vector3(0.58, 0.8, 0.58), Color("5c8468"))
		for floor_index: int in range(int(b.height)):
			var window_y: float = 0.55 + floor_index * 0.65
			if b.kind in ["apartments", "block"]:
				for window: int in range(3):
					_box(self, center + Vector3((window - 1) * sx * 0.27, window_y, sz / 2 + 0.025), Vector3(sx * 0.16, 0.27, 0.04), Color("526975"))
			else:
				_box(self, center + Vector3(0, window_y, sz / 2 + 0.025), Vector3(sx * 0.65, 0.22, 0.04), Color("526975"))
			if b.orientation == 1:
				_box(self, center + Vector3(sx / 2 + 0.025, window_y, 0), Vector3(0.04, 0.22, sz * 0.65), Color("526975"))

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
	preview_error = session.sim.command_error({"type": "build_facility", "company": session.active_company, "archetype": build_type, "product": build_product, "x": x, "y": y})
	preview.mesh.size = Vector3(definition.width * CELL - 0.08, 0.16, definition.depth * CELL - 0.08)
	preview.position = cell_position(x + (definition.width - 1) / 2.0, y + (definition.depth - 1) / 2.0) + Vector3(0, 0.25, 0)
	preview.material_override.albedo_color = Color("67ffb8") if preview_error.is_empty() else Color("ff6170")
	preview.material_override.no_depth_test = true
	preview.show()
	var info: Dictionary = session.sim.city.parcel_info(x, y)
	var detail: String = ""
	if info.has("land_value"):
		detail = "\n%s • Land $%.0f/cell%s" % [info.district, info.land_value / 100.0, " • Waterfront" if info.waterfront else ""]
	placement_changed.emit(("Valid site — click to build" if preview_error.is_empty() else preview_error) + detail)

func _update_camera() -> void:
	camera.position = focus + Vector3(35, 35, 35)
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
			camera.size = maxf(18.0, camera.size - 2.0)
			if not build_type.is_empty(): _pointer_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(max_zoom, camera.size + 2.0)
			if not build_type.is_empty(): _pointer_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not build_type.is_empty():
				_pointer_preview(event.position)
				placement_requested.emit(preview_cell.x, preview_cell.y)
				return
			var origin: Vector3 = camera.project_ray_origin(event.position)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 200.0)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider.has_meta("facility_id"):
				facility_selected.emit(str(hit.collider.get_meta("facility_id")))
			else:
				facility_selected.emit("")
