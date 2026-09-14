extends Control
## Original isometric menu illustrations, drawn with the game's palette.
var kind: String = "suite"
var seaside: bool = false
const OAK = Color("c09965")
const SAGE = Color("8da970")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
func _draw() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("dce8df") if seaside else Color("e8e8cf")
	bg.set_corner_radius_all(18)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	for i in range(16):
		draw_circle(Vector2(fmod(i * 71.0 + 13, size.x), fmod(i * 43.0 + 19, size.y)), 1.8, Color("cbd7b8"))
	var s: float = minf(size.x / 250.0, size.y / 155.0)
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.66), 0, Vector2.ONE * s)
	match kind:
		"hotel":
			block(Vector3(0,-8,0), Vector3(150,10,95), Color("89a777") if not seaside else Color("d6bd8d"))
			block(Vector3(0,0,0), Vector3(111,10,65), OAK)
			block(Vector3(0,26,-23), Vector3(111,46,8), Color("f1dfba"))
			block(Vector3(-51,20,0), Vector3(8,37,65), Color("dfcba2"))
			block(Vector3(0,53,-22), Vector3(118,8,15), SAGE if not seaside else Color("739da1"))
			for x in [-35,0,35]:
				block(Vector3(x,30,-17), Vector3(20,23,3), Color("537456"))
				block(Vector3(x,30,-14), Vector3(13,16,2), Color("dfdfaa"))
			bed(Vector3(-28,8,2), 0.58)
			bed(Vector3(27,8,2), 0.58)
			block(Vector3(0,17,26), Vector3(72,25,11), OAK)
			plant(Vector3(-66,0,4))
			plant(Vector3(64,0,-23))
		"kitchen":
			block(Vector3(0,0,0), Vector3(130,7,80), OAK)
			block(Vector3(0,25,-22), Vector3(116,47,26), SAGE)
			block(Vector3(0,50,-22), Vector3(123,5,30), Color("fff2d5"))
			for x in [-37,0,37]:
				block(Vector3(x,27,-7), Vector3(30,30,2), Color("b8ca93"))
				block(Vector3(x,8,23), Vector3(22,8,21), Color("537456"))
				block(Vector3(x,13,23), Vector3(16,3,15), Color("c1914b"))
			plant(Vector3(40,53,-22))
		"lounge":
			block(Vector3(0,0,0), Vector3(125,7,86), SAGE)
			for x in [-30,30]:
				block(Vector3(x,28,-15), Vector3(9,54,9), OAK)
				block(Vector3(x,57,-15), Vector3(44,8,34), Color("517455"))
			block(Vector3(0,13,22), Vector3(35,25,26), OAK)
			block(Vector3(0,16,36), Vector3(15,17,2), Color("62634b"))
			cat(Vector3(29,63,-13), Color("f0e4cb"))
		"desk":
			block(Vector3(0,0,0), Vector3(130,7,70), SAGE)
			block(Vector3(0,24,5), Vector3(110,46,32), OAK)
			block(Vector3(0,49,5), Vector3(119,6,37), Color("dab784"))
			for x in [-35,0,35]:
				block(Vector3(x,26,22), Vector3(28,32,2), Color("577959"))
			plant(Vector3(-35,53,5))
			block(Vector3(32,57,9), Vector3(11,9,10), Color("e9bb52"))
			cat(Vector3(4,39,-24), Color("e3b279"))
		_: bed(Vector3.ZERO, 1.2)
func iso(p: Vector3) -> Vector2:
	return Vector2((p.x - p.z) * 0.74, (p.x + p.z) * 0.33 - p.y)
func block(p: Vector3, d: Vector3, color: Color) -> void:
	var a = iso(p + Vector3(-d.x/2, d.y/2, -d.z/2))
	var b = iso(p + Vector3(d.x/2, d.y/2, -d.z/2))
	var c = iso(p + Vector3(d.x/2, d.y/2, d.z/2))
	var e = iso(p + Vector3(-d.x/2, d.y/2, d.z/2))
	var down = Vector2(0,d.y)
	draw_colored_polygon(PackedVector2Array([e,c,c+down,e+down]), color.darkened(0.13))
	draw_colored_polygon(PackedVector2Array([b,c,c+down,b+down]), color.darkened(0.29))
	draw_colored_polygon(PackedVector2Array([a,b,c,e]), color.lightened(0.12))
func bed(p: Vector3, s: float) -> void:
	block(p, Vector3(75,15,79) * s, OAK)
	block(p + Vector3(0,15,0)*s, Vector3(72,14,73)*s, Color("f8ebcf"))
	block(p + Vector3(0,24,13)*s, Vector3(73,7,48)*s, SAGE)
	block(p + Vector3(0,23,-39)*s, Vector3(80,58,6)*s, OAK)
	for x in [-19,19]:
		block(p + Vector3(x,27,-23)*s, Vector3(30,9,17)*s, Color("fff3d8"))
	cat(p + Vector3(1,29,5)*s, Color("d9a061"), s)
func plant(p: Vector3) -> void:
	block(p + Vector3(0,8,0), Vector3(15,16,15), Color("b3815c"))
	block(p + Vector3(0,24,0), Vector3(26,20,24), SAGE)
	block(p + Vector3(5,36,0), Vector3(17,12,16), Color("a5b879"))
func cat(p: Vector3, color: Color, s: float = 1) -> void:
	block(p + Vector3(0,7,0)*s, Vector3(22,14,28)*s, color)
	block(p + Vector3(0,19,10)*s, Vector3(26,22,20)*s, color)
	for x in [-9,9]:
		block(p + Vector3(x,33,9)*s, Vector3(7,10,8)*s, color)
		block(p + Vector3(x*0.65,21,21)*s, Vector3(3,4,2)*s, Color("334736"))
