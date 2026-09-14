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
		"music":
			draw_line(Vector2(13,24),Vector2(13,6),Color("D96577"),4,true)
			draw_line(Vector2(27,20),Vector2(27,2),Color("D96577"),4,true)
			draw_line(Vector2(13,7),Vector2(27,3),Color("F5A18F"),6,true)
			draw_circle(Vector2(8,25),6,Color("F5A18F"))
			draw_circle(Vector2(22,21),6,Color("F5A18F"))
		"sound":
			draw_circle(Vector2(16,4),3,Color("C58A28"))
			draw_style_box(_round(Color("FFCC68"),10),Rect2(6,5,20,21))
			draw_line(Vector2(3,25),Vector2(29,25),Color("E7AA3E"),5,true)
			draw_circle(Vector2(16,29),3,Color("C58A28"))
		"evening":
			draw_circle(Vector2(16,16),14,Color("8C83C8"))
			draw_circle(Vector2(21,10),12,Color("FFF8E9"))
			draw_circle(Vector2(28,5),2,Color("FFCC68"))
		"weather":
			draw_circle(Vector2(23,9),8,Color("FFCC68"))
			for point in [Vector2(8,22),Vector2(15,18),Vector2(23,24)]: draw_circle(point,8,Color("ACD9E8"))
		"motion":
			draw_circle(Vector2(16,20),11,Color("E8B780"))
			for side in [-1,1]:
				draw_colored_polygon(PackedVector2Array([Vector2(16+side*11,18),Vector2(16+side*12,4),Vector2(16+side*2,12)]),Color("E8B780"))
			for x in [10,22]: draw_arc(Vector2(x,20),3,PI,TAU,10,Color("24483E"),2,true)
			draw_circle(Vector2(16,24),2,Color("F5A18F"))
		"haptics": _paw(Vector2(16,17),1.0,Color("ED8CA4"))
		"heart":
			draw_circle(Vector2(10,10),8,Color("F5A18F"))
			draw_circle(Vector2(22,10),8,Color("F5A18F"))
			draw_colored_polygon(PackedVector2Array([Vector2(3,13),Vector2(29,13),Vector2(16,30)]),Color("F5A18F"))
		"camera":
			draw_style_box(_round(Color("5CC8A1"),5),Rect2(2,8,28,22))
			draw_style_box(_round(Color("5CC8A1"),2),Rect2(9,3,13,8))
			draw_circle(Vector2(16,18),8,Color("FFF8E9"))
			draw_circle(Vector2(16,18),5,Color("24483E"))
			draw_circle(Vector2(25,12),2,Color("FFCC68"))
		"coin":
			draw_circle(Vector2(16, 17), 15, Color("b88530"))
			draw_circle(Vector2(16, 15), 14, Color("edbd52"))
			draw_arc(Vector2(16, 15), 11.3, 0, TAU, 32, Color("ffe59a"), 1.6, true)
			_paw(Vector2(16, 16), 0.68, Color("b17d28"))
			_paw(Vector2(16, 14.5), 0.68, Color("ffe6a0"))
		"Hotel", "Rooms":
			var wall := Color("55b897") if active else Color("d5b18d")
			draw_style_box(_round(wall.darkened(0.2), 3), Rect2(6, 12, 22, 19))
			draw_style_box(_round(wall, 3), Rect2(5, 10, 22, 19))
			draw_polyline(PackedVector2Array([Vector2(2, 15), Vector2(16, 3), Vector2(30, 15)]), wall.darkened(0.28), 6, true)
			draw_polyline(PackedVector2Array([Vector2(2, 12), Vector2(16, 1), Vector2(30, 12)]), wall.lightened(0.18), 4, true)
			draw_style_box(_round(Color("fff6df"), 2), Rect2(13, 19, 7, 10))
		"Build", "Upgrades":
			draw_line(Vector2(8, 28), Vector2(24, 10), Color("986240"), 8, true)
			draw_line(Vector2(7, 26), Vector2(23, 8), Color("e1a577"), 5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 7), Vector2(21, 1), Vector2(32, 11), Vector2(25, 20)]), Color("3c5882"))
			draw_colored_polygon(PackedVector2Array([Vector2(13, 5), Vector2(20, 0), Vector2(31, 10), Vector2(25, 17)]), Color("7f9fd0"))
			draw_line(Vector2(16, 5), Vector2(26, 13), Color("b6cdf0"), 2, true)
		"Life":
			draw_style_box(_round(Color("b97747"), 2), Rect2(12, 23, 10, 8))
			draw_line(Vector2(17, 25), Vector2(16, 13), Color("356e4e"), 3, true)
			draw_colored_polygon(PackedVector2Array([Vector2(16, 21), Vector2(6, 18), Vector2(2, 8), Vector2(9, 7), Vector2(16, 12)]), Color("49966c"))
			draw_colored_polygon(PackedVector2Array([Vector2(17, 17), Vector2(19, 6), Vector2(29, 3), Vector2(29, 12), Vector2(24, 19)]), Color("60c09a"))
			draw_line(Vector2(17, 23), Vector2(25, 9), Color("28795b"), 1.5, true)
			draw_line(Vector2(16, 21), Vector2(7, 11), Color("b3deab"), 1.5, true)
		"Map":
			for i in range(3):
				var x: float = 1 + i * 10
				var y: float = 7 if i != 1 else 11
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x+10, 11 if i != 1 else 7), Vector2(x+10, 31 if i != 1 else 27), Vector2(x, y+20)]), [Color("b2ded0"), Color("70bba6"), Color("a1d9d1")][i])
			draw_polyline(PackedVector2Array([Vector2(4, 25), Vector2(12, 20), Vector2(20, 23), Vector2(26, 17)]), Color("fff3d4"), 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(16, 9), Vector2(21, 20), Vector2(27, 9)]), Color("dc963e"))
			draw_circle(Vector2(21.5, 7), 6, Color("f5bc58"))
			draw_circle(Vector2(21.5, 6.5), 2.7, Color("fff3cf"))
		"Cats":
			var coat := Color("397967") if active else Color("626470")
			draw_circle(Vector2(16, 19), 12, coat.darkened(0.15))
			draw_circle(Vector2(16, 17), 12, coat)
			for side in [-1, 1]:
				var outer_x: float = 16 + side * 11
				var inner_x: float = 16 + side * 2
				draw_colored_polygon(PackedVector2Array([Vector2(outer_x, 16), Vector2(outer_x, 1), Vector2(inner_x, 12)]), coat)
				draw_line(Vector2(outer_x - side * 2, 5), Vector2(outer_x - side * 2, 10), Color("dea99b"), 2, true)
			for x in [11, 21]:
				draw_circle(Vector2(x, 17), 1.6, Color("fff5dc"))
			draw_circle(Vector2(16, 21), 1.5, Color("f2c7ac"))
			draw_arc(Vector2(13.5, 21), 2.5, 0, PI, 12, Color("fff5dc"), 1.5, true)
			draw_arc(Vector2(18.5, 21), 2.5, 0, PI, 12, Color("fff5dc"), 1.5, true)
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
