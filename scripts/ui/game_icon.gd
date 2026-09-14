extends Control
## Small original vector icons; crisp at every phone density.
var kind: String = "paw"
var color: Color = Color("31573f")
var active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var s: float = minf(size.x, size.y) / 32.0
	draw_set_transform((size - Vector2.ONE * 32 * s) * 0.5, 0, Vector2.ONE * s)
	match kind:
		"coin":
			draw_circle(Vector2(16, 17), 15, Color("b88530"))
			draw_circle(Vector2(16, 15), 14, Color("edbd52"))
			draw_arc(Vector2(16, 15), 11.3, 0, TAU, 32, Color("ffe59a"), 1.6, true)
			_paw(Vector2(16, 16), 0.68, Color("b17d28"))
			_paw(Vector2(16, 14.5), 0.68, Color("ffe6a0"))
		"Hotel", "Rooms":
			draw_colored_polygon(PackedVector2Array([Vector2(2, 14), Vector2(16, 2), Vector2(30, 14), Vector2(27, 17), Vector2(27, 29), Vector2(5, 29), Vector2(5, 17)]), color)
			if kind == "Rooms":
				draw_line(Vector2(16, 15), Vector2(16, 26), Color("f9f3db"), 3)
				draw_line(Vector2(10, 20), Vector2(22, 20), Color("f9f3db"), 3)
			else:
				_paw(Vector2(16, 20), 0.6, Color("f9f3db"))
		"Upgrades":
			draw_line(Vector2(8, 27), Vector2(24, 9), color, 7, true)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 6), Vector2(19, 0), Vector2(31, 11), Vector2(25, 18)]), color)
		"Map":
			for i in range(3):
				var x: float = 2 + i * 10
				var y: float = 3 if i != 1 else 7
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x+8, 7 if i != 1 else 3), Vector2(x+8, 29 if i != 1 else 25), Vector2(x, y+22)]), color)
		"Cats":
			draw_circle(Vector2(16, 19), 12, color)
			for side in [-1, 1]:
				var outer_x: float = 16 + side * 11
				var inner_x: float = 16 + side * 2
				draw_colored_polygon(PackedVector2Array([Vector2(outer_x, 16), Vector2(outer_x, 2), Vector2(inner_x, 12)]), color)
			for x in [11, 21]:
				draw_circle(Vector2(x, 18), 1.7, Color("fff5dc"))
			draw_line(Vector2(14, 23), Vector2(18, 23), Color("fff5dc"), 2, true)
		"settings":
			for i in range(8):
				var v = Vector2.from_angle(i * TAU / 8)
				draw_line(Vector2(16, 16) + v * 8, Vector2(16, 16) + v * 13, color, 6, true)
			draw_circle(Vector2(16, 16), 10, color)
			draw_circle(Vector2(16, 16), 4, Color("f8f2dd"))
		"chair":
			draw_style_box(_round(color, 6), Rect2(7, 2, 18, 24))
			draw_style_box(_round(color.lightened(0.1), 3), Rect2(2, 14, 28, 14))
			for x in [6, 23]:
				draw_line(Vector2(x, 27), Vector2(x, 31), color.darkened(0.2), 3)
		_: _paw(Vector2(16, 17), 1.0, color)

func _paw(p: Vector2, s: float, c: Color) -> void:
	draw_circle(p + Vector2(0, 3) * s, 6 * s, c)
	for v in [Vector2(-8, -3), Vector2(-3, -8), Vector2(4, -8), Vector2(9, -2)]:
		draw_circle(p + v * s, 3.2 * s, c)

func _round(c: Color, r: int) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(r)
	return b

