extends Node3D
## All geometry shares the model's lot cells. No rendered node awards income.
const UNIT: float = 1.1
const FLOOR: float = 0.18
const Objects = preload("res://scripts/creative/creative_objects.gd")
const Content = preload("res://scripts/creative/creative_content.gd")
const Geometry = preload("res://scripts/creative/lot_geometry.gd")
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Legacy = preload("res://scripts/core/game_content.gd")
var model
var camera: Camera3D
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
var _camera_direction: Vector3 = Vector3(1,1.10,1).normalized()
var _preview_key: String = ""
var _last_viewport: Vector2 = Vector2.ZERO

func _ready() -> void:
	_ensure_scene()

func _ensure_scene() -> void:
	if camera != null: return
	if is_inside_tree(): get_viewport().msaa_3d = Viewport.MSAA_4X
	_terrain = Node3D.new()
	_terrain.name = "Grounds"
	add_child(_terrain)
	_building = Node3D.new()
	_building.name = "Hotel"
	add_child(_building)
	_cast = Node3D.new()
	_cast.name = "Guests"
	add_child(_cast)
	_preview = Node3D.new()
	_preview.name = "Preview"
	add_child(_preview)
	var environment = WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("dce7d2")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("ece9d7")
	_environment.ambient_light_energy = 0.34
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = _environment
	add_child(environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48,-28,0)
	_sun.light_color = Color("fff0cf")
	_sun.light_energy = 0.43
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.045
	_sun.shadow_normal_bias = 0.8
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
	room_nodes.clear()
	object_nodes.clear()
	var definition: Dictionary = model.map_definition()
	var hotel: Dictionary = model.hotel()
	_grounds(definition,hotel)
	for room in hotel.get("rooms",[]): _room(room,definition)
	for item in hotel.get("objects",[]): _object(item)
	Objects.flush(_terrain)
	Objects.flush(_building)
	apply_visual_settings()
	_apply_outside()
	if changed_hotel:
		_clear(_cast)
		actors.clear()
		focus_hotel()

func apply_visual_settings() -> void:
	if model==null or _environment==null: return
	_set_water_motion(_terrain,bool(model.state.get("settings",{}).get("motion",true)))
	_set_water_motion(_building,bool(model.state.get("settings",{}).get("motion",true)))
	var evening: bool = bool(model.state.get("settings",{}).get("evening",false))
	_sun.light_color = Color("ffd9b1") if evening else Color("fff0d8")
	_sun.light_energy = 0.31 if evening else 0.43
	_environment.ambient_light_energy = 0.30 if evening else 0.34

func _clear(root: Node) -> void:
	for child in root.get_children(): child.free()

func _grounds(definition: Dictionary, hotel: Dictionary) -> void:
	var ground: Color = Color(String(definition.get("ground","a8bc8d")))
	var accent: Color = Color(String(definition.get("accent","b99369")))
	var theme: String = String(definition.get("theme","meadow"))
	_environment.background_color = {"meadow":Color("dae6cc"),"coast":Color("d5e6df"),"forest":Color("cbd8c1"),"snow":Color("dce5e1")}.get(theme,Color("dae6cc"))
	Objects.box(_terrain,Vector3(0,-0.67,0),Vector3(150,1.3,150),ground.darkened(0.10))
	if theme=="coast":
		# The shoreline lies beyond every purchasable lot and continues to the
		# horizon, so the seaside destination reads as an actual coast.
		Objects.water(_terrain,Vector3(62,0.07,0),Vector2(75,150),Color("75b4bd"))
		Objects.water(_terrain,Vector3(-13,0.072,-62),Vector2(150,75),Color("75b4bd"))
	# The parcel edge and gentle change in turf make owned land readable even
	# when the build tray is closed; purchasable plots remain quiet clearings.
	var base: Array = definition.get("base",[-12,-12,24,24])
	_parcel(_rect(base),ground,accent,true,"")
	for parcel in definition.get("plots",[]):
		var owned: bool = hotel.get("plots",[]).has(parcel.id)
		_parcel(_rect(parcel.rect),ground if owned else ground.darkened(0.055),accent,owned,String(parcel.get("name","Garden plot")))
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
	var floor_color: Color = Color("d4bd97") if kind in ["regular","cottage"] else Color("dec8a3")
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
		for side in range(4):
			_wall(full,w,d,side,2.46,side==door_side,Color("e5d7b9"),accent)
			_wall(cutaway,w,d,side,1.62 if side in [2,3] else 0.30,side==door_side,Color("e5d7b9"),accent)
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
	Objects.label(title,String(room.get("name","Guest room")),Vector3(w*0.5,0.28,d+0.26),0.0041,Color("766b53"),true)
	if not ready:
		Objects.label(title,String(status.get("status","Unfinished")),Vector3(w*0.5,0.29,d+0.75),0.0030,Color("a07851"),true)
	Objects.flush(root)

func _wall(parent: Node3D, w: float, d: float, side: int, height: float, has_door: bool, plaster: Color, accent: Color) -> void:
	var east_west: bool = side in [0,2]
	var length: float = d if east_west else w
	var center: Vector3 = Vector3(w if side==0 else 0.0,FLOOR+height*0.5,d*0.5) if east_west else Vector3(w*0.5,FLOOR+height*0.5,d if side==1 else 0.0)
	var axis: Vector3 = Vector3(0,0,1) if east_west else Vector3(1,0,0)
	var thickness: float = 0.13
	if has_door:
		var section: float = (length-1.17)*0.5
		for sign_value in [-1,1]:
			var location: Vector3 = center+axis*float(sign_value)*(length*0.5-section*0.5)
			Objects.box(parent,location,Vector3(thickness,height,section) if east_west else Vector3(section,height,thickness),plaster)
		if height>2.0: Objects.box(parent,Vector3(center.x,2.47,center.z),Vector3(thickness,0.37,1.17) if east_west else Vector3(1.17,0.37,thickness),plaster)
		if height>1.0:
			for sign_value in [-1,1]:
				var post: Vector3 = center+axis*float(sign_value)*0.64
				Objects.box(parent,post,Vector3(0.20,height,0.20),accent)
	else:
		Objects.box(parent,center,Vector3(thickness,height,length) if east_west else Vector3(length,height,thickness),plaster)
		if height>1.0:
			var trim: Vector3 = Vector3(center.x,FLOOR+height+0.035,center.z)
			Objects.box(parent,trim,Vector3(0.19,0.11,length+0.08) if east_west else Vector3(length+0.08,0.11,0.19),accent)
			for section in range(maxi(1,int(length/3.5))):
				var offset: float = (float(section)+0.5)*length/float(maxi(1,int(length/3.5)))-length*0.5
				var point: Vector3 = center+axis*offset
				point.y = 1.28
				Objects.box(parent,point,Vector3(0.18,0.65,1.18) if east_west else Vector3(1.18,0.65,0.18),accent.lightened(0.12))
				Objects.box(parent,point+Vector3(0,0.035,0),Vector3(0.196,0.49,0.94) if east_west else Vector3(0.94,0.49,0.196),Color("a9c8bd"))
				Objects.box(parent,point,Vector3(0.21,0.68,0.045) if east_west else Vector3(0.045,0.68,0.21),Color("f1e1c1"))

func _object(item: Dictionary) -> void:
	var definition: Dictionary = Content.item(String(item.item))
	if definition.is_empty(): return
	var node: Node3D = Objects.make(definition)
	node.name = "Item_"+String(item.id)
	node.set_meta("id",String(item.id))
	node.set_meta("item",String(item.item))
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
				Objects.box(stand,Vector3(0,-0.19,0),Vector3(0.78,0.38,0.80),Color("b69a73"))
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
		if int(id)>=1000 and int(data.get("staff_role",2))!=2: visual_position.y += 0.315
		var facing: float = float(data.get("face",0.0))
		if not String(data.phase) in ["walk","walk_seat","walk_clean","walk_depart","wander"] and object_nodes.has(String(data.venue)):
			var toward: Vector3 = object_nodes[String(data.venue)].position-visual_position
			if Vector2(toward.x,toward.z).length()>0.01: facing=atan2(toward.x,toward.z)
		var pose: Dictionary = _furniture_pose(data)
		if not pose.is_empty():
			visual_position = pose.position
			facing = pose.face
		if actor.has_meta("placed"):
			actor.position = actor.position.lerp(visual_position,minf(1.0,delta*9.0))
		else:
			actor.position = visual_position
			actor.set_meta("placed",true)
		actor.rotation.y = lerp_angle(actor.rotation.y,facing,minf(1.0,delta*9.0))
		actor.motion_enabled = motion
		actor.moving = String(data.phase) in ["walk","walk_seat","walk_clean","walk_depart","wander"]
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
	var local: Vector3 = Vector3.ZERO
	var slot_index: int = 0
	var capacity: int = 1
	for venue in model.venues():
		if String(venue.id)!=id: continue
		capacity = maxi(1,int(venue.get("capacity",1)))
		for index in range(venue.slots.size()):
			if String(venue.slots[index].key)==String(actor.slot): slot_index=index
		break
	match shape:
		"cafe_stool": local = Vector3(0,0.71,0.04)
		"cloud_sofa", "lounge_sofa", "bench":
			local = Vector3((float(slot_index)+0.5)/float(capacity)*dimensions.x*0.72-dimensions.x*0.36,0.52,dimensions.y*0.10)
		"mat", "sun_cushion", "heated", "blanket", "cave", "canopy_bed": local = Vector3(0,0.34,dimensions.y*0.11)
		"perch": local = Vector3(0,1.01,0)
		"table", "picnic": local = Vector3(0,0.50,dimensions.y*0.40*(1.0 if slot_index%2 else -1.0))
		_: return {}
	return {"position":node.transform*local,"face":node.rotation.y}

func _set_water_motion(root: Node, enabled: bool) -> void:
	for child in root.get_children():
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
		if room.has_node("RoomName"): room.get_node("RoomName").visible = not outside

func set_world_rect(rect: Rect2) -> void:
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

func focus_hotel() -> void:
	if model==null: return
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room in model.hotel().get("rooms",[]):
		var rect: Rect2 = Geometry.room_rect(room)
		bounds = rect if first else bounds.merge(rect)
		first = false
	if first: bounds = _rect(model.map_definition().get("base",[-12,-12,24,24]))
	focus_bounds(bounds.grow(1.6))
	var visible: Rect2 = _visible_rect()
	if visible.size.x<620:
		# A phone opens on the inhabited welcome area at a readable scale.
		# The separate Fit lot control remains the complete property overview.
		for object in model.hotel().get("objects",[]):
			if Content.item(String(object.item)).get("role","")!="reception": continue
			for room in model.hotel().get("rooms",[]):
				if String(room.id)!=String(object.get("room","")): continue
				var center: Vector2 = Geometry.room_rect(room).get_center()*UNIT
				_target = Vector3(center.x,FLOOR+0.4,center.y)
				break
			break
		var viewport: Vector2 = get_viewport().get_visible_rect().size
		_size = minf(_size,16.5*viewport.y/maxf(1.0,visible.size.x))
		_update_camera()

func focus_lot() -> void:
	if model==null: return
	var definition: Dictionary = model.map_definition()
	var bounds: Rect2 = _rect(definition.get("base",[-12,-12,24,24]))
	for parcel in definition.get("plots",[]): bounds = bounds.merge(_rect(parcel.rect))
	focus_bounds(bounds.grow(1.2))

func focus_bounds(bounds: Rect2) -> void:
	_ensure_scene()
	var center: Vector2 = bounds.get_center()*UNIT
	_target = Vector3(center.x,FLOOR+0.4,center.y)
	_update_camera()
	var projected: Rect2 = Rect2()
	var first: bool = true
	for x in [bounds.position.x,bounds.end.x]:
		for y in [bounds.position.y,bounds.end.y]:
			for height in [0.0,3.4]:
				var point: Vector3 = Vector3(float(x)*UNIT,height,float(y)*UNIT)-_target
				var projection: Vector2 = Vector2(point.dot(camera.basis.x),point.dot(camera.basis.y))
				if first:
					projected = Rect2(projection,Vector2.ZERO)
					first = false
				else: projected = projected.expand(projection)
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var visible: Rect2 = _visible_rect()
	_size = clampf(maxf(projected.size.y*viewport.y/maxf(1.0,visible.size.y),projected.size.x*viewport.y/maxf(1.0,visible.size.x))*1.06,8.0,200.0)
	_update_camera()

func pan(relative: Vector2) -> void:
	var center: Vector2 = _visible_rect().get_center()
	var first: Vector2 = world_point(center)
	var second: Vector2 = world_point(center-relative)
	var difference: Vector2 = (second-first)*UNIT
	_target += Vector3(difference.x,0,difference.y)
	_update_camera()

func zoom(factor: float) -> void:
	_size = clampf(_size*factor,7.0,200.0)
	_update_camera()

func world_point(screen: Vector2) -> Vector2:
	if camera==null: return Vector2.ZERO
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if absf(direction.y)<0.0001: return Vector2.ZERO
	var point: Vector3 = origin+direction*((FLOOR-origin.y)/direction.y)
	return Vector2(point.x/UNIT,point.z/UNIT)

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
