extends Control
## Original isometric menu illustrations, drawn with the game's palette.
var kind: String = "suite"
var seaside: bool = false
const SCENES = {"grounds":"garden", "staff":"staff", "journal":"scrapbook", "kiosk":"paw-mart", "nap":"nap-gathering", "cardboard":"gatherings", "lantern":"lantern-gathering", "beach":"beach-gathering", "trail":"trail-gathering", "spa":"spa-gathering"}
static var textures: Dictionary = {}
static var staff_regions: Dictionary = {}
static func texture(scene: String) -> Texture2D:
	if not textures.has(scene): textures[scene] = load("res://assets/ui/mobile/" + scene + ".png")
	return textures[scene]
static func staff_portrait(index: int) -> AtlasTexture:
	if not staff_regions.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture("staff")
		var extent := atlas.atlas.get_size()
		atlas.region = Rect2(Vector2([0.055,0.355,0.665][index],0.23) * extent, Vector2(0.31,0.59) * extent)
		staff_regions[index] = atlas
	return staff_regions[index]
const OAK = Color("c09965")
const SAGE = Color("8da970")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
func _draw() -> void:
	if kind == "manager":
		_draw_manager()
		return
	if SCENES.has(kind):
		var scene := texture(SCENES[kind])
		var extent := scene.get_size()
		if kind == "nap" and size.x > size.y * 1.7:
			var crop_height := extent.x * size.y / size.x
			draw_texture_rect_region(scene,Rect2(Vector2.ZERO,size),Rect2(0,(extent.y-crop_height)*0.53,extent.x,crop_height))
			return
		var fit := minf(size.x / extent.x, size.y / extent.y)
		var drawn := extent * fit
		draw_texture_rect(scene, Rect2((size-drawn)/2,drawn), false)
		return
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("dce8df") if seaside else Color("e8e8cf")
	bg.set_corner_radius_all(18)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	for i in range(16):
		draw_circle(Vector2(fmod(i * 71.0 + 13, size.x), fmod(i * 43.0 + 19, size.y)), 1.8, Color("cbd7b8"))
	var s: float = minf(size.x / 250.0, size.y / 155.0)
	if kind in ["manager","discoveries","pool","litter","playpen","picnic"]: s = minf(size.x/140.0,size.y/130.0)
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.66), 0, Vector2.ONE * s)
	match kind:
		"discoveries":
			draw_colored_polygon(PackedVector2Array([Vector2(-30,-35),Vector2(-15,15),Vector2(0,3),Vector2(15,15),Vector2(30,-35)]),Color("F5A18F"))
			var points := PackedVector2Array()
			for i in range(10): points.append(Vector2.from_angle(-PI/2+i*PI/5)*(43 if i%2==0 else 23)+Vector2(0,-45))
			draw_colored_polygon(points,Color("FFCC68"))
			cat(Vector3(0,43,0),Color("fff8e9"),0.65)
		"pool":
			block(Vector3.ZERO,Vector3(120,18,80),Color("5CC8A1"))
			block(Vector3(0,10,0),Vector3(100,3,65),Color("9bdce7"))
			cat(Vector3(0,15,0),Color("e3b279"))
		"litter":
			block(Vector3.ZERO,Vector3(90,12,65),Color("DCD2F3"))
			block(Vector3(0,9,0),Vector3(75,5,50),Color("e4c99d"))
			block(Vector3(0,32,-30),Vector3(90,60,5),Color("5CC8A1"))
			plant(Vector3(-55,0,0))
		"playpen":
			block(Vector3.ZERO,Vector3(110,8,75),Color("5CC8A1"))
			for x in [-45,45]: block(Vector3(x,20,0),Vector3(6,45,75),Color("F5A18F"))
			block(Vector3(0,20,-32),Vector3(100,40,5),Color("FFCC68"))
			cat(Vector3(0,10,5),Color("999e93"))
		"picnic":
			block(Vector3(0,25,0),Vector3(100,8,55),Color("F5A18F"))
			for x in [-30,30]: block(Vector3(x,10,0),Vector3(8,30,40),OAK)
			plant(Vector3(0,30,0))
			cat(Vector3(60,0,0),Color("e3b279"))
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


func _draw_manager() -> void:
	var scale := minf(size.x,size.y)/100.0
	draw_set_transform((size-Vector2.ONE*100*scale)/2,0,Vector2.ONE*scale)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("E3F3E9")
	backdrop.set_corner_radius_all(16)
	draw_style_box(backdrop,Rect2(0,0,100,100))
	# A room window and floor place the manager in the hotel.
	draw_style_box(_surface(Color("FFF8E9"),4),Rect2(8,7,35,37))
	draw_style_box(_surface(Color("A9DCE3"),2),Rect2(12,11,27,28))
	draw_line(Vector2(25,11),Vector2(25,39),Color("FFF8E9"),3,true)
	draw_line(Vector2(12,25),Vector2(39,25),Color("FFF8E9"),3,true)
	draw_style_box(_surface(Color("DCC29B"),7),Rect2(4,82,92,14))
	# Warm tabby ears, broad face, coral uniform and visible paws.
	draw_colored_polygon(PackedVector2Array([Vector2(29,37),Vector2(26,12),Vector2(46,26),Vector2(62,26),Vector2(81,13),Vector2(79,40)]),Color("DDA26C"))
	draw_colored_polygon(PackedVector2Array([Vector2(31,29),Vector2(30,20),Vector2(41,29)]),Color("F5A18F"))
	draw_colored_polygon(PackedVector2Array([Vector2(67,29),Vector2(77,21),Vector2(75,33)]),Color("F5A18F"))
	draw_style_box(_surface(Color("E8B780"),15),Rect2(24,27,58,37))
	draw_style_box(_surface(Color("FFF0D7"),10),Rect2(35,44,39,19))
	for x in [41,65]:
		draw_circle(Vector2(x,42),3,Color("24483E"))
		draw_circle(Vector2(x-1,41),0.9,Color("FFF8E9"))
	draw_colored_polygon(PackedVector2Array([Vector2(48,49),Vector2(57,49),Vector2(53,54)]),Color("C7786C"))
	draw_arc(Vector2(49,54),4,0,PI,12,Color("24483E"),1.8,true)
	draw_arc(Vector2(57,54),4,0,PI,12,Color("24483E"),1.8,true)
	for x in [46,54,62]: draw_line(Vector2(x,27),Vector2(x-2,32),Color("B47B4F"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(32,64),Vector2(72,64),Vector2(79,86),Vector2(26,86)]),Color("F5A18F"))
	draw_colored_polygon(PackedVector2Array([Vector2(45,64),Vector2(52,76),Vector2(60,64)]),Color("FFF8E9"))
	draw_circle(Vector2(53,81),2,Color("FFCC68"))
	draw_circle(Vector2(27,74),7,Color("E8B780"))
	draw_circle(Vector2(78,73),7,Color("E8B780"))
	draw_line(Vector2(86,35),Vector2(83,86),Color("A67A51"),4,true)
	draw_style_box(_surface(Color("FFCC68"),3),Rect2(75,81,19,10))

func _surface(fill: Color, radius: int) -> StyleBoxFlat:
	var surface := StyleBoxFlat.new()
	surface.bg_color = fill
	surface.set_corner_radius_all(radius)
	return surface
