class_name CityView
extends Node3D

signal facility_selected(id: String)
var camera: Camera3D
var buildings: Dictionary = {}
var selected: String = ""
var focus: Vector3 = Vector3.ZERO
var colors: Dictionary = {}

func build(state: Dictionary) -> void:
	var palette: Array[Color] = [Color("699eaf"), Color("c99563"), Color("927cbb"), Color("51bda0"), Color("dc7b80")]
	var index: int = 0
	for owner: Dictionary in state.companies:
		colors[owner.id] = palette[index % palette.size()]
		index += 1
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1e303d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	_box(Vector3(0, -0.3, 1), Vector3(32, 0.5, 32), Color("516659"))
	for road: float in [-3.0, 5.0]:
		_box(Vector3(0, 0.01, road), Vector3(30, 0.04, 1.4), Color("34414a"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_layout.json"))
	for f: Dictionary in state.facilities:
		var point: Array = layout.facilities.get(f.id, [0, 0])
		var height: float = 1.5 if str(f.type) == "electronics_store" else 3.0
		var body: StaticBody3D = StaticBody3D.new()
		body.set_meta("facility_id", str(f.id))
		body.position = Vector3(float(point[0]), height / 2.0, float(point[1]))
		add_child(body)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(4, height, 3.5)
		mesh.mesh = box
		mesh.material_override = _material(colors[f.company])
		body.add_child(mesh)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		body.add_child(collision)
		var label: Label3D = Label3D.new()
		label.text = str(f.id).substr(3).replace("_", " ")
		label.font_size = 40
		label.pixel_size = 0.018
		label.position.y = height / 2.0 + 0.6
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)
		buildings[f.id] = {"body": body, "mesh": mesh, "color": colors[f.company]}
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36.0
	add_child(camera)
	_update_camera()
	camera.make_current()

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _box(position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	mesh.position = position_value
	mesh.material_override = _material(color)
	add_child(mesh)

func select(id: String) -> void:
	selected = id
	for key: String in buildings:
		var record: Dictionary = buildings[key]
		var material: StandardMaterial3D = record.mesh.material_override
		material.albedo_color = Color("ffe190") if key == selected else record.color

func _update_camera() -> void:
	camera.position = focus + Vector3(25, 25, 25)
	camera.look_at(focus)

func _process(delta: float) -> void:
	if camera == null:
		return
	# Only move while the pointer is over this viewport; text entry stays unaffected.
	if not get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
		return
	var move: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move += Vector3(-1, 0, -1)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move += Vector3(1, 0, 1)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move += Vector3(-1, 0, 1)
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move += Vector3(1, 0, -1)
	pan(move, delta)

func pan(move: Vector3, delta: float) -> void:
	focus += move.normalized() * delta * 12.0
	focus.x = clampf(focus.x, -25, 25)
	focus.z = clampf(focus.z, -25, 25)
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(15.0, camera.size - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(65.0, camera.size + 2.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var origin: Vector3 = camera.project_ray_origin(event.position)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 200.0)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider.has_meta("facility_id"):
				facility_selected.emit(str(hit.collider.get_meta("facility_id")))
