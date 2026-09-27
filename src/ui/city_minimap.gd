class_name CityMinimap
extends Control

var city: CityView
var terrain_texture: ImageTexture
var terrain_map: CityMap
var map: CityMap

func _ready() -> void:
	custom_minimum_size = Vector2(168, 126)
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click to move camera • Teal: player • Gold: selected"

func _draw() -> void:
	if map == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("142b38"))
	var cell: Vector2 = (size - Vector2(8, 8)) / Vector2(map.width, map.depth)
	if terrain_map != map:
		var raster: Image = Image.create(map.width, map.depth, false, Image.FORMAT_RGB8)
		raster.fill(Color("789077"))
		for k: String in map.water:
			var p: PackedStringArray = k.split(",")
			raster.set_pixel(int(p[0]), int(p[1]), Color("3c819c"))
		for k: String in map.roads:
			var p: PackedStringArray = k.split(",")
			raster.set_pixel(int(p[0]), int(p[1]), Color("364651"))
		terrain_texture = ImageTexture.create_from_image(raster)
		terrain_map = map
	draw_texture_rect(terrain_texture, Rect2(Vector2(4, 4), size - Vector2(8, 8)), false)
	for b: Dictionary in map.ambient.values():
		draw_rect(Rect2(Vector2(4, 4) + Vector2(b.x, b.y) * cell, Vector2(b.width, b.depth) * cell), Color("c2b69e"))
	for id: String in map.plots:
		var p: Dictionary = map.plots[id]
		var color: Color = Color("ffe190") if city.selected == id else (Color("45f0be") if p.owner == "player" else Color("e69079"))
		draw_rect(Rect2(Vector2(4, 4) + Vector2(p.x, p.y) * cell, Vector2(p.width, p.depth) * cell), color)
	if not map.port.is_empty():
		draw_rect(Rect2(Vector2(2, 2) + Vector2(int(map.port.x), int(map.port.y)) * cell, Vector2(4, 4)), Color("f4c86a"))
	var focus_point: Vector2 = Vector2(city.focus.x / CityView.CELL + (map.width - 1) / 2.0, city.focus.z / CityView.CELL + (map.depth - 1) / 2.0)
	var viewport_cells: Vector2 = Vector2(city.camera.size * 1.25 / CityView.CELL, city.camera.size * 0.85 / CityView.CELL)
	draw_rect(Rect2(Vector2(4, 4) + (focus_point - viewport_cells / 2.0) * cell, viewport_cells * cell), Color.WHITE, false, 1.0)
	draw_circle(Vector2(4, 4) + focus_point * cell, 3.0, Color.WHITE, false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if city == null or city.input_blocked.call(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (event.position - Vector2(4, 4)) / (size - Vector2(8, 8))
		city.focus_cell(point.x * map.width, point.y * map.depth)
		queue_redraw()
		accept_event()
