extends Control
## Layered voxel portraits share the hotel's warm materials and feline anatomy.
var coat: Color = Color("d59c5d")
var locked: bool = false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("e6e6d6") if locked else Color("e8ead6")
	bg.set_corner_radius_all(16)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var s: float = minf(size.x, size.y) / 100
	draw_set_transform(size * Vector2(0.5, 0.54), 0, Vector2.ONE * s)
	var fur: Color = Color("b8bdad") if locked else coat
	draw_circle(Vector2(0, -2), 39, Color("dce3ca") if not locked else Color("d8ddcd"))
	draw_set_transform(size * Vector2(0.5, 0.54), 0, Vector2(s, s * 0.30))
	draw_circle(Vector2(0, 103), 30, Color(0.27, 0.36, 0.24, 0.12))
	draw_set_transform(size * Vector2(0.5, 0.54), 0, Vector2.ONE * s)
	draw_rect(Rect2(-35, 7, 9, 23), fur.darkened(0.12))
	draw_rect(Rect2(-35, 3, 15, 9), fur)
	draw_rect(Rect2(-22, 9, 45, 23), fur.darkened(0.05))
	for x in [-23, 8]:
		draw_rect(Rect2(x, 26, 15, 9), Color("f7edd4") if not locked else fur)
	# A chamfered, block-like head with a lit top and a darker side.
	draw_colored_polygon(PackedVector2Array([Vector2(-27,-21),Vector2(-20,-27),Vector2(33,-27),Vector2(26,-21)]), fur.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(26,-21),Vector2(33,-27),Vector2(33,15),Vector2(26,21)]), fur.darkened(0.20))
	draw_rect(Rect2(-27, -21, 53, 42), fur)
	for x in [-27, 12]:
		draw_rect(Rect2(x, -36, 14, 23), fur)
		draw_rect(Rect2(x+3, -30, 7, 13), Color("d8a193") if not locked else fur.darkened(0.10))
	for x in [-10, 3]:
		draw_rect(Rect2(x, -21, 6, 10), fur.darkened(0.16))
	if not locked:
		draw_rect(Rect2(-13, 3, 28, 14), Color("f7ecd5"))
		for x in [-17, 11]:
			draw_rect(Rect2(x, -8, 6, 8), Color("263d32"))
			draw_rect(Rect2(x+1, -7, 2, 2), Color("fff9e6"))
			draw_rect(Rect2(x-3, 5, 7, 3), Color("d39a86"))
		draw_rect(Rect2(-3, 5, 7, 4), Color("b77d74"))
		draw_line(Vector2(1,9), Vector2(1,13), Color("7c6650"), 1)
		for x in [-1, 1]:
			draw_line(Vector2(x*19, 10), Vector2(x*30, 8), fur.darkened(0.35), 1)
			draw_line(Vector2(x*19, 13), Vector2(x*29, 14), fur.darkened(0.35), 1)
	else:
		draw_arc(Vector2(0, 0), 6, PI, TAU, 16, Color("87947f"), 3)
		draw_rect(Rect2(-8,0,16,12), Color("87947f"))
		draw_circle(Vector2(0,5), 2, Color("dfe3d7"))
