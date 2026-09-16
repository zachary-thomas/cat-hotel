extends Node3D
## All geometry shares the model's lot cells. No rendered node awards income.
const UNIT: float = 1.1
const FLOOR: float = 0.18
const Objects = preload("res://scripts/creative/creative_objects.gd")
const Neighborhood = preload("res://scripts/creative/creative_neighborhood.gd")
const Content = preload("res://scripts/creative/creative_content.gd")
const Geometry = preload("res://scripts/creative/lot_geometry.gd")
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Legacy = preload("res://scripts/core/game_content.gd")
const Life = preload("res://scripts/creative/creative_life.gd")
var life
var model
var camera: Camera3D
var neighborhood: Node3D
var room_nodes: Dictionary = {}
var object_nodes: Dictionary = {}
var actors: Dictionary = {}
var world_rect: Rect2 = Rect2()
var outside: bool = false
var _terrain: Node3D
var _building: Node3D
var _cast: Node3D
var _preview: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _revision: int = -1
var _hotel: int = -1
var _target: Vector3 = Vector3(0,FLOOR,0)
var _size: float = 35.0
var _camera_direction: Vector3 = Vector3(1,1.05,1).normalized()
var _preview_key: String = ""
var _last_viewport: Vector2 = Vector2.ZERO
var _status_overlay: CanvasLayer
var _status_badges: Dictionary = {}
var _world_rect_set: bool = false

func _ready() -> void:
	_ensure_scene()

func _ensure_scene() -> void:
	if camera != null: return
	if is_inside_tree(): get_viewport().msaa_3d = Viewport.MSAA_4X
	_terrain = Node3D.new()
	_terrain.name = "Grounds"
	add_child(_terrain)
	neighborhood = Neighborhood.new()
	neighborhood.name = "Neighborhood"
	add_child(neighborhood)
	_building = Node3D.new()
	_building.name = "Hotel"
	add_child(_building)
	_cast = Node3D.new()
	_cast.name = "Guests"
	add_child(_cast)
	_preview = Node3D.new()
	_preview.name = "Preview"
	add_child(_preview)
	_status_overlay = CanvasLayer.new()
	_status_overlay.name = "RoomStatusOverlay"
	_status_overlay.layer = 0
	add_child(_status_overlay)
	life=Life.new(); life.name="HotelLife"; add_child(life)
	var environment = WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("dce7d2")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("ece9d7")
	_environment.ambient_light_energy = 0.47
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = _environment
	add_child(environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48,-28,0)
	_sun.light_color = Color("fff0cf")
	_sun.light_energy = 0.53
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.045
	# Low normal bias stamps shadow-map stripes onto sunlit voxel faces in
	# Compatibility (including Android). Keep depth bias small so contact
	# shadows stay attached, and offset along the face normal instead.
	_sun.shadow_normal_bias = 1.5
	_sun.directional_shadow_max_distance = 140
	add_child(_sun)
	camera = Camera3D.new()
	camera.name = "HotelCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 500
	add_child(camera)
	camera.current = true
	_update_camera()

func setup(next_model) -> void:
	if model!=next_model:
		# A fresh or restored model may reuse the same revision/hotel numbers.
		# Those counters only describe edits within one model instance.
		_revision = -1
		_hotel = -1
		clear_preview()
	model = next_model
	_ensure_scene()
	outside = bool(model.state.get("settings",{}).get("exterior",false))
	sync()
	focus_hotel()

func sync() -> void:
	if model == null: return
	_ensure_scene()
	var changed_hotel: bool = _hotel != int(model.state.current_hotel)
	if _revision==int(model.revision) and not changed_hotel: return
	_revision = int(model.revision)
	_hotel = int(model.state.current_hotel)
	_clear(_terrain)
	_clear(_building)
	_clear(_status_overlay)
	_status_badges.clear()
	room_nodes.clear()
	object_nodes.clear()
	var definition: Dictionary = model.map_definition()
	var hotel: Dictionary = model.hotel()
	_grounds(definition,hotel)
	if changed_hotel: neighborhood.configure(definition)
	for room in hotel.get("rooms",[]): _room(room,definition)
	for item in hotel.get("objects",[]): _object(item)
	Objects.flush(_terrain)
	Objects.flush(_building)
	apply_visual_settings()
	_apply_outside()
	_update_status_badges()
	if changed_hotel:
		_clear(_cast)
		actors.clear()
		focus_hotel()

func apply_visual_settings() -> void:
	if model==null or _environment==null: return
	neighborhood.set_motion_enabled(bool(model.state.get("settings",{}).get("motion",true)))
	_set_water_motion(_terrain,bool(model.state.get("settings",{}).get("motion",true)))
	_set_water_motion(_building,bool(model.state.get("settings",{}).get("motion",true)))
	var evening: bool = bool(model.state.get("settings",{}).get("evening",false))
	_sun.light_color = Color("ffd9b1") if evening else Color("fff0d8")
	_sun.light_energy = 0.37 if evening else 0.53
	_environment.ambient_light_energy = 0.37 if evening else 0.47

func _clear(root: Node) -> void:
	for child in root.get_children(): child.free()

func _grounds(definition: Dictionary, hotel: Dictionary) -> void:
	var ground: Color = Color(String(definition.get("ground","a8bc8d")))
	var accent: Color = Color(String(definition.get("accent","b99369")))
	var theme: String = String(definition.get("theme","meadow"))
	_environment.background_color = {"meadow":Color("dae6cc"),"coast":Color("d5e6df"),"forest":Color("cbd8c1"),"snow":Color("dce5e1")}.get(theme,Color("dae6cc"))
	Objects.box(_terrain,Vector3(0,-0.67,0),Vector3(400,1.3,400),ground.darkened(0.10))
	if theme=="coast":
		# The shoreline lies beyond every purchasable lot and continues to the
		# horizon, so the seaside destination reads as an actual coast.
		Objects.water(_terrain,Vector3(112.25,0.07,0),Vector2(175.5,400),Color("75b4bd"))
		Objects.water(_terrain,Vector3(-87.75,0.072,-112.25),Vector2(224.5,175.5),Color("75b4bd"))
	# The parcel edge and gentle change in turf make owned land readable even
	# when the build tray is closed; purchasable plots remain quiet clearings.
	var base: Array = definition.get("base",[-12,-12,24,24])
	_parcel(_rect(base),ground,accent,true,"")
	for parcel in definition.get("plots",[]):
		var owned: bool = hotel.get("plots",[]).has(parcel.id)
		_parcel(_rect(parcel.rect),ground if owned else ground.darkened(0.055),accent,owned,String(parcel.get("name","Garden plot")))
	if definition.has("road"): _road(definition.road,definition.get("arrival",[0,10]))
	for key in hotel.get("paths",{}):
		var split: PackedStringArray = String(key).split(",")
		if split.size()!=2: continue
		var cell: Vector2 = Vector2(float(split[0]),float(split[1]))
		var data: Dictionary = hotel.paths[key]
		var style: String = String(data.get("style","earth"))
		var color: Color = {"earth":Color("cfb78c"),"gravel":Color("c4c3ab"),"brick":Color("bf9981")}.get(style,Color("cfb78c"))
		Objects.box(_terrain,Vector3((cell.x+0.5)*UNIT,0.105,(cell.y+0.5)*UNIT),Vector3(UNIT-0.028,0.10,UNIT-0.028),color)
		if style=="brick":
			for offset in [-0.24,0.24]: Objects.box(_terrain,Vector3((cell.x+0.5)*UNIT,0.159,(cell.y+0.5+offset)*UNIT),Vector3(UNIT-0.03,0.009,0.025),color.darkened(0.1))
	for scene in definition.get("scenery",[]):
		if theme=="coast" and String(scene.kind)=="sea": continue
		var node: Node3D = Objects.scenery(String(scene.kind),float(scene.get("size",1.0)),Color(String(scene.get("color","789666"))),theme=="snow")
		node.position = Vector3(float(scene.x)*UNIT,0.06,float(scene.y)*UNIT)
		_terrain.add_child(node)
	var arrival: Array = definition.get("arrival",[0,10])
	var sign = Node3D.new()
	_terrain.add_child(sign)
	sign.position = Vector3((float(arrival[0])-2.2)*UNIT,0.16,float(arrival[1])*UNIT)
	for side in [-1,1]: Objects.box(sign,Vector3(side*0.95,0.80,0),Vector3(0.14,1.60,0.14),Color("957650"))
	Objects.box(sign,Vector3(0,1.44,0),Vector3(2.4,0.75,0.16),accent.darkened(0.21))
	Objects.label(sign,String(definition.get("name","Purrington")),Vector3(0,1.47,0.09),0.0036,Color("fff3d5"))
	Objects.box(sign,Vector3(0,1.88,0),Vector3(2.6,0.13,0.31),accent)
	# Low garden edging leaves the entrance and future path crossings open.
	var start: float = float(base[0])*UNIT
	var end: float = float(base[0]+base[2])*UNIT
	var z: float = float(base[1]+base[3])*UNIT
	for i in range(int(base[2])+1):
		var x: float = start+float(i)*UNIT
		if absf(x-float(arrival[0])*UNIT)<2.1: continue
		Objects.box(_terrain,Vector3(x,0.27,z),Vector3(0.11,0.48,0.11),Color("d9c49b"))
		if x<end-0.1: Objects.box(_terrain,Vector3(x+UNIT*0.4,0.27,z),Vector3(UNIT*0.8,0.08,0.07),Color("d9c49b"))

func _road(definition: Dictionary, arrival: Array) -> void:
	var rect: Rect2 = _rect(definition.get("rect",[-32,13,64,4]))
	var center: Vector2 = rect.get_center()*UNIT
	var road = Node3D.new()
	road.name = "VillageRoad"
	_terrain.add_child(road)
	Objects.box(road,Vector3(center.x,0.015,center.y),Vector3(rect.size.x*UNIT,0.12,rect.size.y*UNIT),Color("78857e"))
	for side in [-1,1]:
		var edge: float = center.y+float(side)*(rect.size.y*0.5-0.14)*UNIT
		Objects.box(road,Vector3(center.x,0.083,edge),Vector3(rect.size.x*UNIT,0.018,0.08),Color("ced3ba"))
	for dash in range(int(rect.size.x/2.5)):
		var x: float = (rect.position.x+float(dash)*2.5+0.75)*UNIT
		Objects.box(road,Vector3(x,0.084,center.y),Vector3(1.15,0.018,0.11),Color("ece2b8"))
	if bool(definition.get("sidewalk",true)):
		for side in [-1,1]:
			var z: float = center.y+float(side)*(rect.size.y*0.5+0.48)*UNIT
			for tile in range(int(rect.size.x)):
				var x: float = (rect.position.x+float(tile)+0.5)*UNIT
				Objects.box(road,Vector3(x,0.085,z),Vector3(UNIT-0.035,0.17,UNIT*0.92),Color("d4c9ae") if tile%2 else Color("ddd2b8"))
			var curb: float = center.y+float(side)*(rect.size.y*0.5+0.055)*UNIT
			Objects.box(road,Vector3(center.x,0.13,curb),Vector3(rect.size.x*UNIT,0.23,0.14),Color("eee1c3"))
	var crossing_x: float = float(arrival[0])*UNIT
	for stripe in range(6):
		Objects.box(road,Vector3(crossing_x,0.089,(rect.position.y+0.40+float(stripe)*0.62)*UNIT),Vector3(1.64,0.019,0.29),Color("eee8cf"))
	for offset in [-5.5,5.5]:
		var lamp: Node3D = Objects.make(Content.item("garden_lamp"))
		lamp.position = Vector3(crossing_x+offset,0.17,(rect.end.y+1.35)*UNIT)
		lamp.scale = Vector3.ONE*1.25
		road.add_child(lamp)

func _parcel(rect: Rect2, color: Color, accent: Color, owned: bool, title: String) -> void:
	var center: Vector2 = rect.get_center()*UNIT
	Objects.box(_terrain,Vector3(center.x,0.01,center.y),Vector3(rect.size.x*UNIT-0.035,0.13,rect.size.y*UNIT-0.035),color)
	if owned: return
	for x in [rect.position.x,rect.end.x]:
		for y in [rect.position.y,rect.end.y]:
			Objects.box(_terrain,Vector3(x*UNIT,0.27,y*UNIT),Vector3(0.16,0.46,0.16),accent.lightened(0.22))
	var board = Node3D.new()
	board.position = Vector3(center.x,0.13,center.y)
	_terrain.add_child(board)
	Objects.box(board,Vector3(0,0.42,0),Vector3(0.12,0.84,0.12),Color("a68b60"))
	Objects.box(board,Vector3(0,0.83,0),Vector3(1.8,0.49,0.1),Color("efe1bb"))
	Objects.label(board,title,Vector3(0,0.86,0.065),0.0031,Color("786d50"))

func _room(room: Dictionary, definition: Dictionary) -> void:
	var root = Node3D.new()
	root.name = "Room_"+String(room.id)
	root.set_meta("id",String(room.id))
	_building.add_child(root)
	room_nodes[String(room.id)] = root
	var rect: Rect2 = Geometry.room_rect(room)
	root.position = Vector3(rect.position.x*UNIT,0,rect.position.y*UNIT)
	var w: float = rect.size.x*UNIT
	var d: float = rect.size.y*UNIT
	var accent: Color = Color(String(definition.get("accent","b99369")))
	var kind: String = String(room.get("kind","regular"))
	var terrace: bool = kind=="terrace"
	var status: Dictionary = model.room_status(String(room.id))
	var ready: bool = bool(status.get("ready",true))
	var floor_color: Color = Color("cfae87") if kind in ["regular","cottage"] else Color("dfc49d")
	if terrace: floor_color = Color("c6b18c")
	Objects.box(root,Vector3(w*0.5,0.07,d*0.5),Vector3(w+0.10,0.20,d+0.10),Color("a48f70"))
	for x in range(int(rect.size.x)):
		for y in range(int(rect.size.y)):
			var color: Color = floor_color.lightened(0.026) if (x+y)%2 else floor_color
			Objects.box(root,Vector3((float(x)+0.5)*UNIT,0.151,(float(y)+0.5)*UNIT),Vector3(UNIT-0.017,0.048,UNIT-0.015),color)
	if terrace:
		for x in [0.0,w]:
			for z in [0.0,d]: Objects.box(root,Vector3(x,0.55,z),Vector3(0.13,1.0,0.13),accent)
		Objects.box(root,Vector3(w*0.5,0.76,0),Vector3(w,0.11,0.10),accent)
		Objects.box(root,Vector3(0,0.76,d*0.5),Vector3(0.10,0.11,d),accent)
	else:
		var full = Node3D.new()
		full.name = "FullWalls"
		root.add_child(full)
		var cutaway = Node3D.new()
		cutaway.name = "CutawayWalls"
		root.add_child(cutaway)
		var door_side: int = posmod(int(room.get("rotation",0)),4)
		var plaster: Color = Color("efe1c9")
		var panel: Color = [Color("e5b2a5"),Color("acc6ad"),Color("a6c7c3"),Color("e8c58e")][posmod(String(room.id).hash(),4)]
		for side in range(4):
			var open_side: bool = side==door_side or kind=="shared"
			_wall(full,w,d,side,2.46,open_side,plaster,accent,panel)
			_wall(cutaway,w,d,side,2.10 if side in [2,3] else 0.25,open_side,plaster,accent,panel)
		var roof = Node3D.new()
		roof.name = "Roof"
		root.add_child(roof)
		var roof_color: Color = {"meadow":Color("a87868"),"coast":Color("82a9a2"),"forest":Color("7c8e6d"),"snow":Color("d9e1d7")}.get(String(definition.get("theme","meadow")),accent)
		Objects.box(roof,Vector3(w*0.5,2.84,d*0.5),Vector3(w+0.54,0.23,d+0.54),roof_color.darkened(0.14))
		var ridge_steps: int = maxi(3,int(ceil(w*0.48)))
		for step in range(ridge_steps):
			var breadth: float = w+0.48-float(step)*(w/float(ridge_steps))
			Objects.box(roof,Vector3(w*0.5,2.99+float(step)*0.17,d*0.5),Vector3(breadth,0.19,d+0.43),roof_color.lightened(float(step)*0.012))
		# Visible eaves span the complete room rectangle; the shape regenerates
		# after a resize or rotation, including every detached cottage.
		for side in [-1,1]: Objects.box(roof,Vector3(w*0.5,2.86,d*0.5+side*(d*0.5+0.24)),Vector3(w+0.59,0.15,0.13),Color("f0dfbc"))
		if kind=="cottage":
			Objects.box(roof,Vector3(w*0.76,3.54,d*0.23),Vector3(0.57,1.15,0.65),Color("a28c77"))
	var title = Node3D.new()
	title.name = "RoomName"
	root.add_child(title)
	var name_label: Label3D = Objects.label(title,String(room.get("name","Guest room")),Vector3(w*0.50,2.65,d*0.5),0.0043,Color("fff4dc"),true)
	name_label.name = "Name"
	name_label.visible = bool(model.state.get("settings",{}).get("room_labels",false))
	name_label.no_depth_test = true
	name_label.outline_modulate = Color("685a48")
	name_label.outline_size = 8
	name_label.render_priority = 8
	if not ready:
		var anchor = Node3D.new()
		anchor.name = "Status"
		anchor.position = Vector3(w*0.5,maxf(4.5,3.4+ceil(w*0.48)*0.17),d*0.5)
		title.add_child(anchor)
		var badge = PanelContainer.new()
		badge.name = "RoomStatus_"+String(room.id)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = Color("fff0cf")
		style.border_color = Color("bd8150")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.shadow_color = Color(0.20,0.14,0.09,0.16)
		style.shadow_size = 3
		badge.add_theme_stylebox_override("panel",style)
		var message = Label.new()
		message.text = String(status.get("status","Room needs attention"))
		message.mouse_filter = Control.MOUSE_FILTER_IGNORE
		message.add_theme_font_override("font",Objects.FONT)
		message.add_theme_color_override("font_color",Color("86502e"))
		badge.add_child(message)
		_status_overlay.add_child(badge)
		_status_badges[String(room.id)] = {"panel":badge,"label":message,"anchor":anchor}
	Objects.flush(root)

func _wall(parent: Node3D, w: float, d: float, side: int, height: float, has_door: bool, plaster: Color, accent: Color, panel: Color) -> void:
	var east_west: bool = side in [0,2]
	var length: float = d if east_west else w
	var center: Vector3 = Vector3(w if side==0 else 0.0,FLOOR+height*0.5,d*0.5) if east_west else Vector3(w*0.5,FLOOR+height*0.5,d if side==1 else 0.0)
	var axis: Vector3 = Vector3(0,0,1) if east_west else Vector3(1,0,0)
	var inward: Vector3 = Vector3(-1 if side==0 else 1,0,0) if east_west else Vector3(0,0,-1 if side==1 else 1)
	var sections: Array = []
	if has_door:
		# The navigation portal describes a cat's centre, so visible door jambs
		# leave extra room for its voxel head when it turns through the opening.
		var opening: float=minf(length-0.44,2.06)
		var segment: float = (length-opening)*0.5
		for sign_value in [-1,1]: sections.append({"at":center+axis*float(sign_value)*(length*0.5-segment*0.5),"length":segment})
		if height>2.20: Objects.box(parent,Vector3(center.x,2.50,center.z),Vector3(0.17,0.29,opening) if east_west else Vector3(opening,0.29,0.17),plaster)
		if height>1.0:
			for sign_value in [-1,1]:
				var post: Vector3 = center+axis*float(sign_value)*(opening*0.5+0.11)
				Objects.box(parent,post,Vector3(0.22,height,0.22),accent)
	else: sections.append({"at":center,"length":length})
	for section in sections:
		var point: Vector3 = section.at
		var span: float = float(section.length)
		Objects.box(parent,point,Vector3(0.14,height,span) if east_west else Vector3(span,height,0.14),plaster)
		var band_height: float = minf(0.73,height)
		point.y = FLOOR+band_height*0.5
		Objects.box(parent,point,Vector3(0.16,band_height,span) if east_west else Vector3(span,band_height,0.16),panel)
		for rail_y in [FLOOR+0.065,FLOOR+band_height]:
			point.y = rail_y
			Objects.box(parent,point,Vector3(0.20,0.085,span) if east_west else Vector3(span,0.085,0.20),Color("f4e6cd"))
		if height<1.0: continue
		point.y = FLOOR+height+0.015
		Objects.box(parent,point,Vector3(0.22,0.12,span+0.05) if east_west else Vector3(span+0.05,0.12,0.22),accent)
		for batten in range(maxi(1,int(span/0.60))):
			var location: Vector3 = Vector3(section.at)+axis*((float(batten)+0.5)/maxi(1,int(span/0.60))*span-span*0.5)
			location.y = FLOOR+0.38
			Objects.box(parent,location,Vector3(0.185,0.62,0.033) if east_west else Vector3(0.033,0.62,0.185),panel.lightened(0.14))
		if span<1.4: continue
		var windows: int = maxi(1,int(span/3.0))
		for window in range(windows):
			var point_window: Vector3 = Vector3(section.at)+axis*((float(window)+0.5)/float(windows)*span-span*0.5)
			point_window.y = 1.52
			Objects.box(parent,point_window,Vector3(0.19,0.97,1.38) if east_west else Vector3(1.38,0.97,0.19),accent)
			Objects.box(parent,point_window,Vector3(0.205,0.80,1.20) if east_west else Vector3(1.20,0.80,0.205),Color("90bfc0"))
			for pane in [-1,1]:
				Objects.box(parent,point_window+axis*pane*0.30+Vector3(0,0.21,0),Vector3(0.219,0.28,0.46) if east_west else Vector3(0.46,0.28,0.219),Color("b5ddcf"))
			Objects.box(parent,point_window,Vector3(0.23,0.95,0.065) if east_west else Vector3(0.065,0.95,0.23),Color("fff0d5"))
			Objects.box(parent,point_window,Vector3(0.23,0.065,1.37) if east_west else Vector3(1.37,0.065,0.23),Color("fff0d5"))
			Objects.box(parent,point_window+Vector3(0,-0.53,0),Vector3(0.43,0.12,1.56) if east_west else Vector3(1.56,0.12,0.43),Color("f1dcbb"))
			# Small planter shelf decorates the wall without blocking a floor cell.
			var pot: Vector3 = point_window+axis*0.49+inward*0.20+Vector3(0,-0.41,0)
			Objects.box(parent,pot,Vector3(0.22,0.22,0.22),Color("b87c62"))
			Objects._foliage(parent,pot+Vector3(0,0.20,0),Vector3(0.32,0.32,0.30),Color("6e9b62"))
			for leaf in range(3):
				var vine: Vector3 = pot+axis*0.18+inward*0.07+Vector3(0,-0.10-float(leaf)*0.17,0)
				Objects.box(parent,vine,Vector3(0.13,0.13,0.13),Color("88ab72"))
			if span/float(windows)>2.3:
				var picture: Vector3 = point_window-axis*0.97+inward*0.12+Vector3(0,-0.12,0)
				Objects.box(parent,picture,Vector3(0.08,0.47,0.38) if east_west else Vector3(0.38,0.47,0.08),accent)
				Objects.box(parent,picture+inward*0.048,Vector3(0.023,0.37,0.28) if east_west else Vector3(0.28,0.37,0.023),Color("fff0d1"))
				var art = Node3D.new()
				parent.add_child(art)
				art.position = picture+inward*0.066
				art.rotation = Vector3(0,0,-PI*0.5*inward.x) if east_west else Vector3(PI*0.5*inward.z,0,0)
				Objects.paw(art,Vector3.ZERO,0.22,Color("e3b366"))
	if height>1.0:
		for edge in [-1,1]:
			var pillar: Vector3 = center+axis*float(edge)*(length*0.5-0.025)
			Objects.box(parent,pillar,Vector3(0.22,height+0.06,0.22),Color("f3e3c7"))

func _object(item: Dictionary) -> void:
	var definition: Dictionary = Content.item(String(item.item))
	if definition.is_empty(): return
	var node: Node3D = Objects.make(definition)
	node.name = "Item_"+String(item.id)
	node.set_meta("id",String(item.id))
	node.set_meta("item",String(item.item))
	node.set_meta("room",String(item.get("room","")))
	if node.has_node("LifeMotion"): node.get_node("LifeMotion").set_phase_seed(String(item.id).hash())
	var rect: Rect2 = Geometry.object_rect(item)
	var center: Vector2 = rect.get_center()*UNIT
	node.position = Vector3(center.x,FLOOR,center.y)
	node.rotation.y = -float(int(item.get("rotation",0)))*PI*0.5
	_building.add_child(node)
	object_nodes[String(item.id)] = node

func _process(delta: float) -> void:
	if model==null: return
	sync()
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	if viewport!=_last_viewport: _update_camera()
	_sync_actors(delta)
	_update_status_badges()
	life.update(delta)

func set_life_context(active: bool, show_chatter: bool) -> void:
	if life!=null: life.set_context(active,show_chatter)

func _sync_actors(delta: float) -> void:
	if model.social==null: return
	var wanted: Dictionary = {}
	var motion: bool = bool(model.state.get("settings",{}).get("motion",true))
	for id in model.social.agents:
		var data: Dictionary = model.social.agents[id]
		wanted[id] = true
		if not actors.has(id):
			var cat = Cat.new()
			cat.name = "Guest_"+str(id)
			cat.set_meta("cat_index",int(data.get("staff_role",int(id))))
			_cast.add_child(cat)
			cat.build(Color(Legacy.COATS[posmod(int(id),Legacy.COATS.size())]),int(id)>=1000)
			cat.scale = Vector3.ONE*0.83
			if int(id)>=1000 and int(data.get("staff_role",2))!=2:
				var stand = Node3D.new()
				cat.add_child(stand)
				stand.name = "StaffPlatform"
				var height: float = Objects.STAFF_STEP_HEIGHT/0.83
				Objects.box(stand,Vector3(0,-height*0.5,0),Vector3(0.92,height,0.89),Color("b99268"))
				Objects.box(stand,Vector3(0,-0.045,0),Vector3(0.98,0.09,0.95),Color("d7b68a"))
				Objects.box(stand,Vector3(0,-height*0.75,-0.53),Vector3(0.82,height*0.5,0.22),Color("c5a277"))
				Objects.flush(stand)
			var cup = Node3D.new()
			cup.name = "Milkshake"
			cat.add_child(cup)
			Objects.drink(cup,Vector3(0.39,0.12,0.42),Color("e5adab"))
			Objects.flush(cup)
			actors[id] = cat
		var actor = actors[id]
		var position_2d: Vector2 = data.position
		var visual_position: Vector3 = Vector3(position_2d.x*UNIT,FLOOR,position_2d.y*UNIT)
		if int(id)>=1000 and int(data.get("staff_role",2))!=2: visual_position.y += Objects.STAFF_STEP_HEIGHT
		var facing: float = float(data.get("face",0.0))
		if not String(data.phase) in ["walk","walk_seat","walk_clean","walk_depart","wander"] and object_nodes.has(String(data.venue)):
			var toward: Vector3 = object_nodes[String(data.venue)].position-visual_position
			if Vector2(toward.x,toward.z).length()>0.01: facing=atan2(toward.x,toward.z)
		var pose: Dictionary = _furniture_pose(data)
		if not pose.is_empty():
			visual_position = pose.position
			facing = pose.face
		if actor.has_meta("placed"):
			# The simulation already follows clear path segments. Interpolating X/Z
			# here would round doorway corners back into solid walls.
			actor.position = Vector3(visual_position.x,lerpf(actor.position.y,visual_position.y,minf(1.0,delta*9.0)),visual_position.z)
		else:
			actor.position = visual_position
			actor.set_meta("placed",true)
		if life!=null: facing=life.facing_for(data,visual_position,facing)
		actor.rotation.y = lerp_angle(actor.rotation.y,facing,minf(1.0,delta*9.0)) if motion else facing
		actor.motion_enabled = motion
		actor.moving = String(data.phase) in ["walk","walk_seat","walk_clean","walk_depart","wander"] and Vector2(data.get("velocity",Vector2.ZERO)).length()>0.025
		actor.action = {"drink":"eat","sit":"rest","sunbathe":"sleep","order":"greet","wait":"rest","clean":"work","serve":"work"}.get(String(data.action),String(data.action))
		actor.get_node("Milkshake").visible = bool(data.get("drink",false))
		actor.thought.text = {"order":"One shake, please","serve":"Coming right up","drink":"mmm…","sleep":"z z z","play":"!","clean":"Fresh linens"}.get(String(data.action),"")
	for id in actors.keys():
		if not wanted.has(id):
			actors[id].free()
			actors.erase(id)

func _furniture_pose(actor: Dictionary) -> Dictionary:
	if int(actor.cat)>=1000 or not String(actor.phase) in ["activity","sit"]: return {}
	var id: String = String(actor.venue)
	if not object_nodes.has(id): return {}
	var node: Node3D = object_nodes[id]
	var shape: String = String(node.get_meta("shape",""))
	var dimensions: Vector2 = node.get_meta("footprint",Vector2.ONE)
	# Only active occupants take a physical surface position; approaching cats
	# retain their distinct reserved destinations until they arrive.
	var occupants: Array[int] = []
	for data in model.social.agents.values():
		if int(data.cat)<1000 and String(data.venue)==id and String(data.phase) in ["activity","sit"]: occupants.append(int(data.cat))
	occupants.sort()
	var slot_index: int = maxi(0,occupants.find(int(actor.cat)))
	var local: Vector3 = Vector3.ZERO
	var face: float = node.rotation.y
	match shape:
		"cafe_stool":
			if slot_index>0: return {}
			local = Vector3(0,0.78,0.04)
		"cloud_sofa", "lounge_sofa", "bench":
			var count: int = maxi(1,int(floor((dimensions.x-0.70)/0.80))+1)
			if slot_index>=count: return {}
			local = Vector3((float(slot_index)-float(mini(count,occupants.size())-1)*0.5)*0.80,0.59,dimensions.y*0.12)
		"mat", "sun_cushion", "heated", "blanket", "cave", "canopy_bed":
			if slot_index>0: return {}
			local = Vector3(0,0.55,dimensions.y*0.11)
		"perch":
			if slot_index>0: return {}
			local = Vector3(0,1.05,0.06)
		"picnic":
			if slot_index>=4: return {}
			local = Vector3(dimensions.x*0.32*(-1.0 if slot_index<2 else 1.0),0.26,dimensions.y*0.32*(-1.0 if slot_index%2==0 else 1.0))
			face += PI if slot_index%2 else 0.0
		"table":
			var per_side: int = maxi(1,int(floor((dimensions.x-0.70)/0.80))+1)
			if slot_index>=per_side*2: return {}
			var side: float = 1.0 if slot_index%2 else -1.0
			var row_count: int = mini(per_side,ceili(float(occupants.size())/2.0))
			local = Vector3((float(slot_index/2)-float(row_count-1)*0.5)*0.80,0.50,dimensions.y*0.40*side)
			face += PI if side>0 else 0.0
		_: return {}
	return {"position":node.transform*local,"face":face}

func _set_water_motion(root: Node, enabled: bool) -> void:
	for child in root.get_children():
		if child.has_method("set_motion_enabled"): child.set_motion_enabled(enabled)
		if child is MeshInstance3D:
			var material = child.material_override
			if material is ShaderMaterial and material.shader==Objects.WATER: material.set_shader_parameter("motion",1.0 if enabled else 0.0)
		if child.get_child_count()>0: _set_water_motion(child,enabled)

func set_outside(value: bool) -> void:
	outside = value
	_apply_outside()

func _apply_outside() -> void:
	for room in room_nodes.values():
		if room.has_node("Roof"): room.get_node("Roof").visible = outside
		if room.has_node("FullWalls"): room.get_node("FullWalls").visible = outside
		if room.has_node("CutawayWalls"): room.get_node("CutawayWalls").visible = not outside
		if room.has_node("RoomName"):
			var title: Node3D = room.get_node("RoomName")
			if title.has_node("Name"): title.get_node("Name").visible = not outside and bool(model.state.get("settings",{}).get("room_labels",false))

func set_world_rect(rect: Rect2) -> void:
	_world_rect_set = true
	world_rect = rect
	_update_camera()

func _visible_rect() -> Rect2:
	var whole: Rect2 = get_viewport().get_visible_rect()
	if world_rect.size.x<1 or world_rect.size.y<1: return whole
	return world_rect

func _update_camera() -> void:
	if camera==null or not is_inside_tree(): return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_last_viewport = viewport
	if viewport.y<1: return
	camera.size = _size
	camera.position = _target+_camera_direction*85.0
	camera.look_at(_target,Vector3.UP)
	var center: Vector2 = _visible_rect().get_center()-viewport*0.5
	var shift: Vector3 = -camera.basis.x*center.x*_size/viewport.y+camera.basis.y*center.y*_size/viewport.y
	camera.position += shift
	_update_status_badges()

func _update_status_badges() -> void:
	if camera==null or model==null: return
	var area: Rect2 = _visible_rect().grow(-6)
	var enabled: bool = is_visible_in_tree() and (not _world_rect_set or world_rect.has_area())
	var text_scale: float = clampf(float(model.state.get("settings",{}).get("ui_text_scale",1.0)),1.0,1.5)
	var placed: Array[Rect2] = []
	for data in _status_badges.values():
		var badge: PanelContainer = data.panel
		var anchor: Node3D = data.anchor
		var screen: Vector2 = camera.unproject_position(anchor.global_position)
		badge.visible = enabled and area.grow(120).has_point(screen)
		if not badge.visible: continue
		var message: Label = data.label
		message.add_theme_font_size_override("font_size",roundi(15.0*text_scale))
		badge.reset_size()
		var dimensions: Vector2 = badge.get_combined_minimum_size()
		var at: Vector2 = screen-Vector2(dimensions.x*0.5,dimensions.y)
		at.x = clampf(at.x,area.position.x,maxf(area.position.x,area.end.x-dimensions.x))
		at.y = clampf(at.y,area.position.y,maxf(area.position.y,area.end.y-dimensions.y))
		for previous in placed:
			if previous.grow(3).intersects(Rect2(at,dimensions)):
				at.y = minf(area.end.y-dimensions.y,previous.end.y+6)
		badge.position = at.round()
		placed.append(Rect2(at,dimensions))

func focus_hotel() -> void:
	if model==null: return
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room in model.hotel().get("rooms",[]):
		var rect: Rect2 = Geometry.room_rect(room)
		bounds = rect if first else bounds.merge(rect)
		first = false
	if first: bounds = _rect(model.map_definition().get("base",[-12,-12,24,24]))
	# Include the inhabited courtyard without expanding to every empty parcel.
	for item in model.hotel().get("objects",[]):
		if not String(item.get("room","")).is_empty(): continue
		bounds = bounds.merge(Geometry.object_rect(item))
	focus_bounds(bounds.grow(0.7))
	var visible: Rect2 = _visible_rect()
	if visible.size.x<620:
		# A phone opens on the inhabited welcome area at a readable scale.
		# The separate Fit lot control remains the complete property overview.
		for object in model.hotel().get("objects",[]):
			if Content.item(String(object.item)).get("role","")!="reception": continue
			for room in model.hotel().get("rooms",[]):
				if String(room.id)!=String(object.get("room","")): continue
				var center: Vector2 = Geometry.room_rect(room).get_center()*UNIT
				for garden_item in model.hotel().get("objects",[]):
					if String(garden_item.item)!="fountain": continue
					var fountain: Vector2=Geometry.object_rect(garden_item).get_center()*UNIT
					if center.distance_to(fountain)<14.0: center=center.lerp(fountain,0.16)
					break
				_target = Vector3(center.x,FLOOR+0.4,center.y)
				break
			break
		var viewport: Vector2 = get_viewport().get_visible_rect().size
		_size = minf(_size,16.5*viewport.y/maxf(1.0,visible.size.x))
		_update_camera()

func focus_lot() -> void:
	if model==null: return
	focus_bounds(_lot_bounds().grow(1.2))

func _lot_bounds() -> Rect2:
	var definition: Dictionary = model.map_definition()
	var bounds: Rect2 = _rect(definition.get("base",[-12,-12,24,24]))
	for parcel in definition.get("plots",[]): bounds = bounds.merge(_rect(parcel.rect))
	return bounds

func focus_bounds(bounds: Rect2) -> void:
	_ensure_scene()
	var center: Vector2 = bounds.get_center()*UNIT
	_target = Vector3(center.x,FLOOR+0.4,center.y)
	_update_camera()
	_size = _fit_size(bounds)
	_update_camera()

func _fit_size(bounds: Rect2) -> float:
	var center: Vector2 = bounds.get_center()*UNIT
	var projected: Rect2 = Rect2()
	var first: bool = true
	for x in [bounds.position.x,bounds.end.x]:
		for y in [bounds.position.y,bounds.end.y]:
			for height in [0.0,3.4]:
				var point: Vector3 = Vector3(float(x)*UNIT-center.x,height,float(y)*UNIT-center.y)
				var projection: Vector2 = Vector2(point.dot(camera.basis.x),point.dot(camera.basis.y))
				if first:
					projected = Rect2(projection,Vector2.ZERO)
					first = false
				else: projected = projected.expand(projection)
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var visible: Rect2 = _visible_rect()
	return clampf(maxf(projected.size.y*viewport.y/maxf(1.0,visible.size.y),projected.size.x*viewport.y/maxf(1.0,visible.size.x))*1.06,8.0,200.0)

func _limit_manual_camera() -> void:
	if model==null: return
	var bounds: Rect2 = _lot_bounds()
	var maximum: float = _fit_size(bounds.grow(1.2))*1.08
	_size = clampf(_size,7.0,maximum)
	# At close range the player can inspect any edge of the property. Pulling
	# back keeps the hotel central, giving glimpses down the neighboring streets.
	var freedom: float = 1.0-clampf((_size/maximum-0.35)/0.65,0.0,1.0)
	var center: Vector2 = bounds.get_center()*UNIT
	var reach: Vector2 = (bounds.size*0.5*freedom+Vector2(3,3))*UNIT
	_target.x = clampf(_target.x,center.x-reach.x,center.x+reach.x)
	_target.z = clampf(_target.z,center.y-reach.y,center.y+reach.y)
	# Adjacent parcels make a cross, not a filled rectangle. Keep close views
	# near real building land instead of drifting into its empty diagonal gaps.
	var definition: Dictionary = model.map_definition()
	var parcels: Array = [definition.base]
	for parcel in definition.plots: parcels.append(parcel.rect)
	var ground_shift: Vector2 = Vector2(_camera_direction.x,_camera_direction.z)*((_target.y-FLOOR)/_camera_direction.y)
	var at: Vector2 = (Vector2(_target.x,_target.z)-ground_shift)/UNIT
	var closest: Vector2 = at
	var nearest: float = INF
	for values in parcels:
		var parcel: Rect2 = _rect(values)
		var point: Vector2 = at.clamp(parcel.position,parcel.end)
		var distance: float = at.distance_to(point)
		if distance<nearest:
			nearest = distance
			closest = point
	if nearest>3.0:
		at = closest+(at-closest).normalized()*3.0
		_target.x = at.x*UNIT+ground_shift.x
		_target.z = at.y*UNIT+ground_shift.y

func pan(relative: Vector2) -> void:
	var center: Vector2 = _visible_rect().get_center()
	var first: Vector2 = world_point(center)
	var second: Vector2 = world_point(center-relative)
	var difference: Vector2 = (second-first)*UNIT
	_target += Vector3(difference.x,0,difference.y)
	_limit_manual_camera()
	_update_camera()

func zoom(factor: float) -> void:
	_size = clampf(_size*factor,7.0,200.0)
	_limit_manual_camera()
	_update_camera()

func world_point(screen: Vector2) -> Vector2:
	if camera==null: return Vector2.ZERO
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if absf(direction.y)<0.0001: return Vector2.ZERO
	var point: Vector3 = origin+direction*((FLOOR-origin.y)/direction.y)
	return Vector2(point.x/UNIT,point.z/UNIT)

func pick_guest(screen_position: Vector2) -> int:
	if camera==null or not _visible_rect().has_point(screen_position): return -1
	var closest: int=-1
	var depth: float=INF
	for id in actors:
		if int(id)<0 or int(id)>=model.state.cats.size() or not model.state.cats[int(id)].known: continue
		var actor: Node3D=actors[id]
		if not actor.is_visible_in_tree() or camera.is_position_behind(actor.global_position): continue
		if outside and life!=null and life._roofed(Vector2(actor.position.x,actor.position.z)/UNIT): continue
		var bounds:=Rect2()
		var first: bool=true
		for x in [-0.5,0.5]:
			for y in [0.05,1.35]:
				for z in [-0.5,0.6]:
					var point: Vector2=camera.unproject_position(actor.global_transform*Vector3(x,y,z))
					if first: bounds=Rect2(point,Vector2.ZERO); first=false
					else: bounds=bounds.expand(point)
		var dimensions: Vector2=bounds.size.max(Vector2(44,44))
		bounds=Rect2(bounds.get_center()-dimensions*0.5,dimensions)
		var distance: float=camera.global_position.distance_squared_to(actor.global_position)
		if bounds.has_point(screen_position) and distance<depth: closest=int(id); depth=distance
	return closest

func set_preview(action: String, payload: Dictionary, valid: bool) -> void:
	_ensure_scene()
	var key: String = action+JSON.stringify(payload)+str(valid)
	if key==_preview_key: return
	clear_preview()
	_preview_key = key
	var color: Color = Color("92c39f") if valid else Color("d89487")
	var rect: Rect2 = Rect2()
	if action in ["paint_path","erase_path"]:
		for cell in payload.get("cells",[]): _outline(Rect2(float(cell[0]),float(cell[1]),1,1),color)
	elif action in ["place_object","move_object","retrieve_object"]:
		var item: Dictionary = payload.duplicate()
		if not item.has("item"):
			for instance in model.hotel().get("objects",[]):
				if instance.id==payload.get("id",""): item.item = instance.item
			for instance in model.state.get("storage",[]):
				if instance.id==payload.get("id",""): item.item = instance.item
		if item.has("item"):
			rect = Geometry.object_rect(item)
			_outline(rect,color)
	elif action=="place_template":
		var template: Dictionary = Content.template(String(payload.get("template","")))
		if not template.is_empty():
			var room: Dictionary = payload.duplicate()
			room.w = template.w
			room.h = template.h
			rect = Geometry.room_rect(room)
			_outline(rect,color)
	elif action in ["place_room","move_room","copy_room","resize_room"]:
		var room: Dictionary = payload.duplicate()
		if action!="place_room":
			for source in model.hotel().get("rooms",[]):
				if source.id==payload.get("id",""):
					room = source.duplicate()
					room.merge(payload,true)
		if room.has("w") and room.has("h"):
			rect = Geometry.room_rect(room)
			_outline(rect,color)
			var door: Vector2 = Geometry.door(room)
			Objects.box(_preview,Vector3(door.x*UNIT,0.30,door.y*UNIT),Vector3(0.40,0.18,0.40),Color("f5e2a9"))
	elif action=="buy_plot":
		for parcel in model.map_definition().get("plots",[]):
			if parcel.id==payload.get("id",""): _outline(_rect(parcel.rect),color)
	Objects.flush(_preview)

func _outline(rect: Rect2, color: Color) -> void:
	var center: Vector2 = rect.get_center()*UNIT
	var dimensions: Vector2 = rect.size*UNIT
	for side in [-1,1]:
		Objects.box(_preview,Vector3(center.x+float(side)*dimensions.x*0.5,0.23,center.y),Vector3(0.095,0.07,dimensions.y+0.08),color)
		Objects.box(_preview,Vector3(center.x,0.23,center.y+float(side)*dimensions.y*0.5),Vector3(dimensions.x+0.08,0.07,0.095),color)
	for x in range(int(ceil(rect.size.x))):
		for y in range(int(ceil(rect.size.y))):
			Objects.box(_preview,Vector3((rect.position.x+float(x)+0.5)*UNIT,0.214,(rect.position.y+float(y)+0.5)*UNIT),Vector3(0.16,0.012,0.16),color)

func clear_preview() -> void:
	_preview_key = ""
	if _preview!=null: _clear(_preview)

func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
