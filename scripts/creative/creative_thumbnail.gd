extends Control
## Catalogue pictures use the actual item's form, palette and arrangement contents.
const FurnitureArt = preload("res://scripts/ui/furniture_thumbnail.gd")
const LEGACY := ["mat","sun_cushion","cave","heated","blanket","box","perch","tower","tunnel","table","plant","rug","scratch","lamp","flowers","cloud_sofa","suite_sofa","adventure_tree","canopy_bed","room_nightstand","suite_table"]
var item: Dictionary = {}
var arrangement: Dictionary = {}
var room_kind: String = ""
var path_style: String = ""
var _children_built: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if not item.is_empty() and str(item.get("id", "")) in LEGACY:
		var art: Control = FurnitureArt.new()
		art.item_id = str(item.id)
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_children_built = true

func _draw() -> void:
	var scale_value: float = minf(size.x / 150.0, size.y / 115.0)
	if scale_value <= 0 or _children_built: return
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.7), 0, Vector2.ONE * scale_value)
	if not path_style.is_empty():
		var tint: Color = {"earth":Color("b59a72"),"gravel":Color("babcb1"),"brick":Color("c78364"),"erase":Color("e9c4b4")}.get(path_style, Color("babcb1"))
		for y in range(3):
			for x in range(3): _box(Vector3((x-1)*25,0,(y-1)*23), Vector3(23,3,21),tint.lightened((x+y)%2*0.06))
	elif not arrangement.is_empty():
		_box(Vector3.ZERO,Vector3(94,4,72),Color("ddc7a1"))
		if str(arrangement.get("kind","shared")) != "terrace":
			_box(Vector3(0,4,-35),Vector3(94,35,3),Color("f5e2c1"))
			_box(Vector3(-45,4,0),Vector3(3,35,72),Color("e6ceac"))
		var catalog: Script = load("res://scripts/creative/creative_content.gd")
		var width: float = float(arrangement.get("w",8))
		var height: float = float(arrangement.get("h",6))
		for entry: Dictionary in arrangement.get("objects",[]):
			var definition: Dictionary = catalog.item(str(entry.item))
			var p: Vector3 = Vector3((float(entry.x)/width-0.5)*83,5,(float(entry.y)/height-0.5)*64)
			_object(definition,p,0.48)
	elif not room_kind.is_empty():
		_box(Vector3.ZERO,Vector3(80,7,70),Color("d9b483"))
		_box(Vector3(0,7,-34),Vector3(80,50,3),Color("f5e4ca"))
		_box(Vector3(-39,7,0),Vector3(3,50,70),Color("e6d3b4"))
		_box(Vector3(10,25,-31),Vector3(24,24,2),Color("abd8d7"))
		if room_kind == "cottage":
			_poly([_iso(Vector3(-46,61,-39)),_iso(Vector3(0,92,-39)),_iso(Vector3(46,61,-39))],Color("ab7863"))
			_box(Vector3(-30,7,12),Vector3(14,20,15),Color("98b58d"))
		else:
			_box(Vector3(0,8,0),Vector3(44,2,43),Color("e8ceb0"))
	else:
		_box(Vector3.ZERO,Vector3(70,2,58),Color("e9e4ce"))
		_object(item,Vector3(0,3,0),1.0)
	draw_set_transform(Vector2.ZERO)

func _object(data: Dictionary, p: Vector3, s: float) -> void:
	var shape: String = str(data.get("shape",data.get("role","seat")))
	var c: Color = Color(str(data.get("color","91b5a0")))
	var role: String = str(data.get("role","decoration"))
	if "plant" in shape or "flower" in shape or "tree" in shape or shape=="shrub":
		_box(p,Vector3(16,15,16)*s,Color("bc845c"))
		_box(p+Vector3(0,15,0)*s,Vector3(3,30,3)*s,Color("6e8753"))
		for v: Vector3 in [Vector3(-8,30,0),Vector3(7,39,1),Vector3(0,47,-2)]:
			_box(p+v*s,Vector3(18,12,17)*s,c)
	elif "fence" in shape or "gate" in shape or role in ["fence","gate"]:
		for x in [-26,-9,9,26]: _box(p+Vector3(x,0,0)*s,Vector3(5,35,5)*s,c)
		for y in [12,27]: _box(p+Vector3(0,y,0)*s,Vector3(61,5,4)*s,c.lightened(0.1))
	elif "pool" in shape or "fountain" in shape or "water" in shape:
		_box(p,Vector3(60,12,45)*s,c)
		_box(p+Vector3(0,12,0)*s,Vector3(49,2,34)*s,Color("8dd3dc"))
		if "fountain" in shape: _box(p+Vector3(0,14,0)*s,Vector3(8,27,8)*s,Color("e1d7bd"))
	elif shape=="fireplace":
		_box(p,Vector3(48,8,24)*s,Color("a49381"))
		for x in [-18,18]: _box(p+Vector3(x,8,0)*s,Vector3(12,34,22)*s,c)
		_box(p+Vector3(0,39,0)*s,Vector3(54,7,28)*s,c.lightened(0.2))
		_box(p+Vector3(0,8,0)*s,Vector3(23,14,11)*s,Color("df9863"))
		_box(p+Vector3(0,10,-1)*s,Vector3(9,19,7)*s,Color("ffd171"))
	elif shape=="cat_statue":
		_box(p,Vector3(28,8,26)*s,Color("ada895"))
		_box(p+Vector3(0,8,0)*s,Vector3(21,25,20)*s,c)
		_box(p+Vector3(0,33,0)*s,Vector3(25,20,21)*s,c)
		for x in [-9,9]: _box(p+Vector3(x,51,-1)*s,Vector3(6,9,7)*s,c)
	elif shape=="litter" or shape=="playpen":
		_box(p,Vector3(58,6,45)*s,c)
		_box(p+Vector3(0,6,0)*s,Vector3(47,2,34)*s,Color("ddc9a4"))
		for z in [-20,20]: _box(p+Vector3(0,6,z)*s,Vector3(58,19 if shape=="playpen" else 8,4)*s,c)
		for x in [-27,27]: _box(p+Vector3(x,6,0)*s,Vector3(4,19 if shape=="playpen" else 8,43)*s,c)
	elif "bed" in shape or "cushion" in shape or role in ["bed","sun","warm"]:
		_box(p,Vector3(45,7,48)*s,Color("bc9269"))
		_box(p+Vector3(0,7,0)*s,Vector3(42,8,45)*s,c)
		_box(p+Vector3(0,15,-14)*s,Vector3(31,6,12)*s,Color("fff8e9"))
	elif "bar" in shape or "counter" in shape or role in ["reception","bar"]:
		_box(p,Vector3(64,14,26)*s,c)
		_box(p+Vector3(0,14,0)*s,Vector3(68,3,31)*s,Color("ead6ad"))
		for x in [-21,21]: _box(p+Vector3(x,17,-1)*s,Vector3(8,9,8)*s,Color("efd29a"))
	elif "table" in shape:
		for x in [-19,19]:
			for z in [-12,12]: _box(p+Vector3(x,0,z)*s,Vector3(4,25,4)*s,Color("ad855f"))
		_box(p+Vector3(0,25,0)*s,Vector3(52,5,36)*s,c)
	elif "tower" in shape or "scratch" in shape or role == "play":
		_box(p,Vector3(41,5,35)*s,c)
		_box(p+Vector3(8,5,0)*s,Vector3(7,47,7)*s,Color("cab694"))
		_box(p+Vector3(8,47,0)*s,Vector3(30,6,28)*s,c)
		_box(p+Vector3(-12,21,8)*s,Vector3(23,6,23)*s,c.lightened(0.12))
	elif "lamp" in shape or "lantern" in shape:
		_box(p,Vector3(17,4,17)*s,c.darkened(0.25))
		_box(p+Vector3(0,4,0)*s,Vector3(4,35,4)*s,c)
		_box(p+Vector3(0,33,0)*s,Vector3(24,19,24)*s,Color("f5d886"))
	elif "rug" in shape:
		_box(p,Vector3(56,2,45)*s,c)
		_box(p+Vector3(0,2,0)*s,Vector3(45,1,34)*s,c.lightened(0.2))
	else:
		_box(p,Vector3(54,10,31)*s,c.darkened(0.13))
		_box(p+Vector3(0,10,11)*s,Vector3(54,24,8)*s,c)
		_box(p+Vector3(0,10,-2)*s,Vector3(48,6,23)*s,c.lightened(0.2))
		for x in [-25,25]: _box(p+Vector3(x,8,0)*s,Vector3(6,17,30)*s,c)

func _iso(p: Vector3) -> Vector2:
	return Vector2((p.x-p.z)*0.73,(p.x+p.z)*0.32-p.y)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func _box(p: Vector3, extent: Vector3, c: Color) -> void:
	var a: Vector3 = p+Vector3(-extent.x/2,0,-extent.z/2)
	var b: Vector3 = a+Vector3(extent.x,0,0)
	var d: Vector3 = a+Vector3(0,0,extent.z)
	var e: Vector3 = b+Vector3(0,0,extent.z)
	var h: Vector3 = Vector3(0,extent.y,0)
	_poly([_iso(d),_iso(e),_iso(e+h),_iso(d+h)],c.darkened(0.14))
	_poly([_iso(b),_iso(e),_iso(e+h),_iso(b+h)],c.darkened(0.26))
	_poly([_iso(a+h),_iso(b+h),_iso(e+h),_iso(d+h)],c.lightened(0.12))
