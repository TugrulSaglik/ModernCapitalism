class_name AmbientDetails
extends RefCounted

# One unit-cube MultiMesh per kind/tone/orientation/component. Transforms encode
# per-property size and cosmetic height; there are no per-window scene nodes.
static func build(parent: Node3D, records: Dictionary, position: Callable, material: Callable) -> void:
	var groups: Dictionary = {}
	var palette: Array[Color] = [Color("c4b49b"), Color("bec0b4"), Color("b2b7bc"), Color("d2c5af"), Color("a8b6ac")]
	for b: Dictionary in records.values():
		var h: float = 0.65 + int(b.height) * 0.65 * (1.0 + int(b.tone) * 0.09 if b.kind in ["block", "office"] else 1.0)
		var sx: float = int(b.width) * CityView.CELL - 0.65
		var sz: float = int(b.depth) * CityView.CELL - 0.65
		var center: Vector3 = position.call(b.x + (b.width - 1) / 2.0, b.y + (b.depth - 1) / 2.0)
		var turn: float = int(b.orientation) * PI / 2.0
		# Rotate decorative facade only; body retains authoritative footprint.
		var facade: Basis = Basis(Vector3.UP, turn)
		var wide: float = sx if int(b.orientation) % 2 == 0 else sz
		var deep: float = sz if int(b.orientation) % 2 == 0 else sx
		var key: String = "%s:%s:%s:" % [b.kind, b.tone, b.orientation]
		var body_color: Color = palette[int(b.tone)]
		if b.kind == "office": body_color = Color("718e9a").lightened(int(b.tone) * 0.035)
		_add(groups, key + "body", center + Vector3(0,h/2,0), Vector3(sx,h,sz), body_color)
		var roof_color: Color = Color("946d59").darkened(int(b.tone) * 0.055) if b.kind == "house" else Color("64757b").lightened(int(b.tone)*0.035)
		if b.kind == "house":
			# Two pitched roof planes; metadata alternates the ridge direction.
			var ridge: Basis = Basis(Vector3.UP, (int(b.roof) % 2) * PI / 2.0)
			var rw: float = sx if int(b.roof) % 2 == 0 else sz
			var rd: float = sz if int(b.roof) % 2 == 0 else sx
			for side: int in [-1,1]:
				_add(groups,key+"roof",center+ridge*Vector3(side*rw/4,h+0.27,0),Vector3(rw*0.61,0.14,rd+0.3),roof_color,ridge*Basis(Vector3.FORWARD,side*0.42))
			_add(groups,key+"chimney",center+Vector3(sx*0.24,h+0.5,-sz*0.25),Vector3(0.25,0.7,0.3),Color("7b6658"))
		else:
			_add(groups,key+"roof",center+Vector3(0,h,0),Vector3(sx+0.12,0.16,sz+0.12),roof_color)
			for side: int in [-1,1]:
				_add(groups,key+"parapet",center+Vector3(side*sx/2,h+0.14,0),Vector3(0.12,0.25,sz),body_color.lightened(0.1))
			_add(groups,key+"utility",center+Vector3(sx*0.2,h+0.28,-sz*0.2),Vector3(sx*0.3,0.45,sz*0.27),Color("92a0a0"))
		var door: Vector3 = center + facade * Vector3(0,0.42,deep/2+0.035)
		_add(groups,key+"door",door,Vector3(0.35,0.84,0.065),Color("4c5d61"),facade)
		var rows: int = 1 if b.kind in ["house","commercial"] else maxi(2, int(h/0.75))
		var columns: int = maxi(2, int(wide / 0.7))
		for row: int in range(rows):
			var y: float = minf(h-0.3,1.12) if rows == 1 else 0.7 + row * (h-1.1)/maxi(1,rows-1)
			for col: int in range(columns):
				var x: float = -wide/2 + (col+0.5)*wide/columns
				if rows == 1 and absf(x) < 0.3: continue
				var glass: Color = Color("385b6d") if (col+row) % 3 != 0 else Color("b8c6bc")
				var win: Vector3 = Vector3(wide/columns*0.65,0.35,0.045)
				if b.kind == "commercial": win.y = 0.7
				for side: int in [-1,1]:
					_add(groups,key+"windows"+str((col+row)%3),center+facade*Vector3(x,y,side*(deep/2+0.025)),win,glass,facade)
		# Side-facing glazing makes detail legible from every camera quadrant.
		for row: int in range(rows):
			var y: float = 0.9 if rows == 1 else 0.7 + row*(h-1.1)/maxi(1,rows-1)
			for side: int in [-1,1]:
				_add(groups,key+"side_windows",center+facade*Vector3(side*(wide/2+0.025),y,0),Vector3(0.045,0.32,deep*0.62),Color("416777"),facade)
		if b.kind == "commercial":
			_add(groups,key+"awning",center+facade*Vector3(0,1.65,deep/2+0.16),Vector3(wide+0.12,0.18,0.45),Color("7b9390"),facade)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = group.transforms.size()
		for i: int in range(group.transforms.size()): multi.set_instance_transform(i,group.transforms[i])
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = key.replace(":", "_")
		node.multimesh = multi
		node.material_override = material.call(group.color)
		parent.add_child(node)

static func _add(groups: Dictionary, key: String, pos: Vector3, size: Vector3, color: Color, rotation: Basis = Basis.IDENTITY) -> void:
	if not groups.has(key): groups[key] = {"color":color,"transforms":[]}
	groups[key].transforms.append(Transform3D(rotation.scaled_local(size),pos))
