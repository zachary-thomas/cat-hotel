extends Node3D
## Colorful outdoor spaces plus actors driven by the saved grounds simulation.
signal selected(action: String, payload: Dictionary)
const Grounds = preload("res://scripts/core/grounds_model.gd")
const Cat = preload("res://scripts/world/voxel_cat.gd")
var world
var model
var scenery: Node3D
var details: Node3D
var manager
var maid
var walkers: Array = []
var amenity_cats: Array = []
var targets: Array = []
var selected_target: String = ""
var detail_key: String = ""
var current_hotel: int = -1
var materials: Dictionary = {}
var clock: float = 0
var manager_control: bool = false
var mouse_actor: Node3D
var yarn_nodes: Array = []

func block(parent: Node3D, p: Vector3, dimensions: Vector3, color: String) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.position = p
	mesh.scale = dimensions
	if not materials.has(color):
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/voxel_surface.gdshader")
		mat.set_shader_parameter("tint", Color(color))
		materials[color] = mat
	mesh.material_override = materials[color]
	parent.add_child(mesh)
	return mesh

func round_shape(parent: Node3D, p: Vector3, radius: float, height: float, color: String, sphere: bool = false) -> MeshInstance3D:
	var item = block(parent,p,Vector3.ONE,color)
	if sphere:
		var shape = SphereMesh.new()
		shape.radius = radius
		shape.height = height
		shape.radial_segments = 16
		shape.rings = 8
		item.mesh = shape
	else:
		var shape = CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = height
		shape.radial_segments = 24
		item.mesh = shape
	return item

func at(p: Vector2, y: float = 0.2) -> Vector3:
	return Vector3(p.x,y,p.y)

func actor(parent: Node3D, coat: String, p: Vector3, uniform: String = ""):
	var cat = Cat.new()
	parent.add_child(cat)
	cat.build(Color(coat),false)
	cat.scale = Vector3.ONE * 1.35
	cat.place_at(p)
	if uniform != "":
		cat.part(cat.body,Vector3(0,0.40,0.25),Vector3(0.52,0.3,0.10),Color(uniform))
		cat.part(cat.body,Vector3(0,0.53,0.35),Vector3(0.17,0.10,0.06),Color("ffdb72"))
	return cat

func sync(game) -> void:
	model = game
	var h: int = game.current_hotel
	var state: Dictionary = game.grounds.hotels[h]
	if current_hotel != h:
		current_hotel = h
		for child in get_children():
			remove_child(child)
			child.queue_free()
		details = null
		walkers.clear()
		amenity_cats.clear()
		scenery = Node3D.new()
		add_child(scenery)
		_street()
		manager = actor(self,"db9b55",at(Grounds.MANAGER_HOME),"d96765")
		manager.name = "PlayerManager"
		maid = actor(self,"eee3d4",Vector3(0,0.24,3.5),"9b8bc2")
		maid.name = "HousekeeperDaisy"
		maid.part(maid.head,Vector3(0,0.27,0),Vector3(0.45,0.12,0.33),Color("ffffff"))
		for i in range(4):
			var passer = actor(self,["c9a6c5","8e9db1","deaf76","6e7f7c"][i],Vector3(-11+i*6,0.12,10.1+(i%2)*1.2))
			passer.set_meta("passer",i)
			walkers.append(passer)
		detail_key = ""
	var availability: Array = []
	for time in state.yarn_ready + state.bush_ready + [state.mouse_ready]:
		availability.append(game.grounds.seconds >= time)
	var key: String = str(h)+str(state.amenities)+str(availability)+str(state.dirty)+str(game.room_count(h))+str(game.hotels[h].get("layout",[]))
	if key != detail_key:
		detail_key = key
		if is_instance_valid(details):
			remove_child(details)
			details.queue_free()
		details = Node3D.new()
		details.name = "GroundsAmenities"
		add_child(details)
		targets.clear()
		amenity_cats.clear()
		yarn_nodes.clear()
		mouse_actor = null
		for item in Grounds.AMENITIES:
			_amenity(item,state.amenities.has(item.id))
		for i in range(3):
			if game.grounds.seconds >= state.yarn_ready[i]:
				var p: Vector3 = at(Grounds.YARN_SPOTS[i],0.50)
				var yarn = _yarn(details,p,["df7fb1","a797db","eaac50"][i])
				yarn_nodes.append(yarn)
				targets.append({"action":"yarn","payload":{"index":i},"position":p,"radius":0.8,"label":"+5"})
		for i in range(2):
			var p: Vector3 = at(Grounds.BUSH_SPOTS[i])
			var grown: bool = game.grounds.seconds >= state.bush_ready[i]
			for j in range(5 if grown else 2):
				block(details,p+Vector3((j%3-1)*0.55,0.2+j*0.11,0),Vector3(0.85,0.6,0.75),"75a57a" if j%2 else "4d8b79")
			if grown:
				targets.append({"action":"trim","payload":{"index":i},"position":p+Vector3(0,0.8,0),"radius":1.2,"label":"Trim"})
		if game.grounds.seconds >= state.mouse_ready:
			mouse_actor = Node3D.new()
			details.add_child(mouse_actor)
			mouse_actor.position = at(Grounds.MOUSE_SPOT)
			round_shape(mouse_actor,Vector3(0,0.23,0),0.30,0.38,"a7a1b4",true)
			for side in [-1,1]:
				round_shape(mouse_actor,Vector3(side*0.16,0.43,0.15),0.12,0.20,"e3a8bd",true)
				block(mouse_actor,Vector3(side*0.09,0.28,0.28),Vector3(0.04,0.045,0.04),"2e465a")
			block(mouse_actor,Vector3(0,0.12,-0.38),Vector3(0.045,0.05,0.5),"d2a5b3")
			targets.append({"action":"chase","payload":{},"position":at(Grounds.MOUSE_SPOT,0.6),"radius":0.9,"label":"Mouse"})
		for room in game.grounds.dirty_rooms(h,game.room_count(h)):
			var p: Vector3 = at(Grounds.room_spot(room,game,h),0.25)
			for i in range(4):
				block(details,p+Vector3((i%2)*0.36,0.04,(i/2)*0.28),Vector3(0.23,0.05,0.15),"ae927c" if i%2 else "e7d2af")
			targets.append({"action":"clean","payload":{"index":room},"position":p+Vector3(0,0.3,0),"radius":0.9,"label":"Tidy"})
		targets.append({"action":"kiosk","payload":{},"position":at(Grounds.SHOP_SPOT,1.5),"radius":2.0,"label":"Paw Mart"})
	var maid_was_visible: bool = maid.visible
	maid.visible = state.maid
	if maid.visible and not maid_was_visible:
		maid.place_at(maid.position)
	for cat in [manager,maid]+walkers+amenity_cats:
		cat.motion_enabled = game.settings.motion

func _street() -> void:
	# Slate-blue lane, wide sandstone pavement, crossing and striped supply kiosk.
	block(scenery,Vector3(0,-0.08,10.7),Vector3(27,0.22,4.1),"72849b")
	block(scenery,Vector3(0,0.01,7.5),Vector3(27,0.20,2.4),"e7cda5")
	for x in range(-12,13):
		block(scenery,Vector3(x,0.05,8.65),Vector3(0.88,0.17,0.22),"f1e4ca")
		if x%3 == 0:
			block(scenery,Vector3(x,0.045,10.8),Vector3(1.3,0.02,0.10),"f7dfa0")
	for z in range(6):
		block(scenery,Vector3(0,0.055,9.1+z*0.55),Vector3(2.1,0.025,0.30),"f6ebd9")
	for x in [-11.4,7.6]:
		block(scenery,Vector3(x,1.2,7.9),Vector3(0.13,2.5,0.13),"47647a")
		round_shape(scenery,Vector3(x,2.5,7.9),0.28,0.40,"ffe0a0",true)
	var p: Vector3 = at(Grounds.SHOP_SPOT,0.15)
	block(scenery,p+Vector3(0,0.55,0),Vector3(3.3,1.0,1.45),"dc8e84")
	block(scenery,p+Vector3(0,1.15,0.25),Vector3(3.7,0.16,1.8),"f5d7ad")
	for x in [-1.5,1.5]:
		block(scenery,p+Vector3(x,1.6,-0.45),Vector3(0.12,2.1,0.12),"487b7f")
	for stripe in range(8):
		block(scenery,p+Vector3(-1.58+stripe*0.45,2.55,0),Vector3(0.44,0.16,2.2),"f3e5c8" if stripe%2 else "dc777d")
	for i in range(4):
		block(scenery,p+Vector3(-1.1+i*0.7,1.4,0.1),Vector3(0.4,0.5,0.5),["e7b25f","9ac2a5","b3a1d8","e3a9b9"][i])
	actor(scenery,"959d94",p+Vector3(0,0.35,-0.7),"62a9ad")
	# A small orchard balances the hotel and breaks up the long side terrace.
	for i in range(6):
		var tree_pos = Vector3(-9.2+(i%2)*1.7,0,-6.0-int(i/2)*2.7)
		block(scenery,tree_pos+Vector3(0,0.8,0),Vector3(0.20,1.6,0.20),"b69572")
		round_shape(scenery,tree_pos+Vector3(0,1.7,0),0.9,1.6,"8eafa0",true)
		for side in [-1,1]:
			round_shape(scenery,tree_pos+Vector3(side*0.5,1.8,0.5),0.18,0.25,"eeae77",true)
	for side in [-1,1]:
		# Bright garden paving gives the grounds a distinct silhouette.
		block(scenery,Vector3(side*9.3,-0.04,-2.4),Vector3(5.4,0.18,15.5),"e5cda8")
		for z in range(-10,7):
			block(scenery,Vector3(side*6.6,0.025,z),Vector3(0.8,0.10,0.83),"d3dbe0")
		for z in [-9.0,-4.8,4.5]:
			block(scenery,Vector3(side*11.8,0.28,z),Vector3(0.6,0.55,1.1),"a38dbc")
			for flower in range(3):
				round_shape(scenery,Vector3(side*11.8,0.78,z-0.3+flower*0.3),0.22,0.24,["e8889f","f4c366","b59cd8"][flower],true)

func _preview_amenity(area: Node3D, id: String) -> void:
	# Planned sites have recognizable silhouettes, rather than identical boxes.
	match id:
		"pool":
			round_shape(area,Vector3(0,0.27,0),1.50,0.25,"7aafbe")
			round_shape(area,Vector3(0,0.41,0),1.25,0.03,"d5e3dd")
		"litter":
			for x in [-0.8,0.8]:
				block(area,Vector3(x,0.35,0),Vector3(1.25,0.35,1.4),"cbb5cb")
		"playpen":
			for x in range(5):
				block(area,Vector3(-1.6+x*0.8,0.45,-1.3),Vector3(0.16,0.85,0.16),"c497bd")
		"picnic":
			block(area,Vector3(0,0.80,0),Vector3(2.5,0.15,1.1),"c6b698")
			block(area,Vector3(0,0.42,0),Vector3(0.18,0.75,1.1),"b5987e")

func _yarn(parent: Node3D, p: Vector3, color: String) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = p
	round_shape(root,Vector3.ZERO,0.42,0.8,color,true)
	for i in range(5):
		var ring = MeshInstance3D.new()
		var shape = TorusMesh.new()
		shape.inner_radius = 0.38
		shape.outer_radius = 0.425
		shape.rings = 16
		shape.ring_segments = 6
		ring.mesh = shape
		ring.rotation_degrees = Vector3(20+i*32,10+i*20,0)
		ring.material_override = materials[color]
		root.add_child(ring)
	block(root,Vector3(0.45,-0.28,0.1),Vector3(0.6,0.055,0.06),color)
	return root

func _amenity(item: Dictionary, owned: bool) -> void:
	var area = Node3D.new()
	details.add_child(area)
	area.name = item.id.capitalize()
	area.position = at(item.position,0.12)
	block(area,Vector3(0,0.05,0),Vector3(4.4,0.18,3.5),{"pool":"b6e0dc","litter":"b7c6db","playpen":"d6b3ce","picnic":"c3d496"}[item.id])
	targets.append({"action":"amenity","payload":{"id":item.id},"position":area.position+Vector3(0,0.5,0),"radius":2.1,"label":item.name})
	if not owned:
		# Potential amenities are visible as colorful planned spaces.
		for x in [-1.8,1.8]:
			block(area,Vector3(x,0.35,0),Vector3(0.12,0.6,2.7),"f5ead3")
		block(area,Vector3(0,0.35,0),Vector3(1.4,0.4,1.2),"eee1cf")
		block(area,Vector3(0,0.58,0),Vector3(0.6,0.10,0.12),"608890")
		block(area,Vector3(0,0.58,0),Vector3(0.12,0.10,0.6),"608890")
		_preview_amenity(area,item.id)
		return
	match item.id:
		"pool":
			round_shape(area,Vector3(0,0.24,0),1.65,0.40,"64b7c6")
			round_shape(area,Vector3(0,0.46,0),1.4,0.08,"83d4e2")
			for p in [Vector3(-0.8,0.60,0.7),Vector3(0.7,0.60,-0.5)]:
				round_shape(area,p,0.19,0.2,"f6d262",true)
			block(area,Vector3(1.9,0.23,0.6),Vector3(0.6,0.12,1.4),"e69ea4")
			var cat = actor(area,"e3d5b9",Vector3(-0.6,0.52,0))
			cat.set_routine([{"position":Vector3(-0.6,0.52,0),"action":"play","wait":4},{"position":Vector3(0.6,0.52,0.3),"action":"rest","wait":5}])
			amenity_cats.append(cat)
		"litter":
			block(area,Vector3(0,0.8,-1.4),Vector3(4.1,1.5,0.16),"8fa9ba")
			block(area,Vector3(-1.95,0.6,0),Vector3(0.12,1.1,2.8),"a9c2c5")
			for x in [-0.85,0.85]:
				block(area,Vector3(x,0.24,0),Vector3(1.3,0.3,1.5),"d9b3c7")
				block(area,Vector3(x,0.40,0),Vector3(1.12,0.07,1.32),"f0dec1")
			block(area,Vector3(0,0.16,1.25),Vector3(2.0,0.10,0.45),"7ea9b2")
			var cat = actor(area,"9babb0",Vector3(0.85,0.48,0))
			cat.set_routine([{"position":Vector3(0.85,0.48,0),"action":"rest","wait":5},{"position":Vector3(0,0.2,1.3),"action":"rest","wait":6}])
			amenity_cats.append(cat)
		"playpen":
			for x in range(7):
				for z in [-1.45,1.45]:
					block(area,Vector3(-1.9+x*0.62,0.45,z),Vector3(0.18,0.85,0.16),["e4a1b5","b6a1d3","e6c078"][x%3])
			for x in [-1.9,1.9]:
				block(area,Vector3(x,0.52,0),Vector3(0.15,0.14,2.9),"a694c4")
			for x in [-0.4,0.4]:
				block(area,Vector3(x,0.48,-0.4),Vector3(0.16,0.8,1.1),"dc9eae")
			block(area,Vector3(0,0.94,-0.4),Vector3(1.0,0.15,1.1),"c58abd")
			_yarn(area,Vector3(1.1,0.50,0.6),"e9b455")
			var cat = actor(area,"c98759",Vector3(-0.9,0.2,0.6))
			cat.set_routine([{"position":Vector3(-0.9,0.2,0.6),"action":"play","wait":3},{"position":Vector3(0.7,0.2,0.6),"action":"play","wait":3}])
			amenity_cats.append(cat)
		"picnic":
			block(area,Vector3(0,0.8,0),Vector3(2.8,0.18,1.2),"deac77")
			for x in [-0.9,0.9]:
				block(area,Vector3(x,0.4,0),Vector3(0.16,0.8,1.2),"b38972")
			for z in [-1.0,1.0]:
				block(area,Vector3(0,0.45,z),Vector3(2.8,0.2,0.45),"a9b984")
			block(area,Vector3(0,1.6,0),Vector3(0.1,2.7,0.1),"bfa38b")
			round_shape(area,Vector3(0,2.8,0),1.7,0.16,"dca1ad")
			for x in [-0.6,0.6]:
				round_shape(area,Vector3(x,0.95,0),0.25,0.10,"eed5a4")
			var cat = actor(area,"d9c3de",Vector3(0,0.57,1.0))
			cat.set_routine([{"position":Vector3(0,0.57,1.0),"action":"eat","wait":20}])
			amenity_cats.append(cat)

func select_at(screen_pos: Vector2) -> bool:
	if model == null:
		return false
	var nearest: Dictionary = {}
	var distance: float = 29
	var manager_screen: Vector2 = world.camera.unproject_position(manager.global_position+Vector3(0,0.6,0))
	if manager_screen.distance_to(screen_pos) < 22 and not (world.exterior_view and world.contains_hotel(manager.position)):
		selected.emit("manager",{})
		return true
	for target in targets:
		if world.exterior_view and world.contains_hotel(target.position):
			continue
		var p: Vector2 = world.camera.unproject_position(target.position)
		var d: float = p.distance_to(screen_pos)
		if target.get("screen_rect",Rect2()).has_point(screen_pos):
			d = minf(d,20.0)
		if d < distance:
			distance = d
			nearest = target
	if not nearest.is_empty():
		selected_target = str(nearest.action)+str(nearest.payload)
		selected.emit(nearest.action,nearest.payload)
		return true
	if manager_control:
		var point = Plane(Vector3.UP,0.2).intersects_ray(world.camera.project_ray_origin(screen_pos),world.camera.project_ray_normal(screen_pos))
		if point != null and Grounds.walkable(Vector2(point.x,point.z),world.wings,model,model.current_hotel):
			selected.emit("walk",{"x":point.x,"z":point.z})
			return true
	return false

func _process(delta: float) -> void:
	if model == null or not is_instance_valid(manager):
		return
	var data: Dictionary = model.grounds.hotels[model.current_hotel]
	var next: Vector3 = at(Vector2(data.manager[0],data.manager[1]),0.24)
	_animate_worker(manager,next,data.job,"trim" if data.job.get("kind","") == "trim" else "sweep",delta)
	if maid.visible:
		var mp: Vector2 = Grounds.job_position(data.maid_job) if not data.maid_job.is_empty() else Vector2(data.maid_position[0],data.maid_position[1])
		_animate_worker(maid,at(mp,0.24),data.maid_job,"sweep",delta)
	if not model.settings.motion:
		return
	clock += delta
	for i in range(walkers.size()):
		var passer = walkers[i]
		var x: float = fmod(clock*0.85+i*6.4,27)-13.5
		if i%2:
			x = -x
		var desired = Vector3(x,0.12,10.1+(i%2)*1.1)
		if model.grounds.seconds < data.treat_until and i < 2:
			desired = Vector3(-1.5+i*3,0.24,6.9)
			passer.moving = passer.move_safely(desired,delta*2)
			passer.action = "walk" if passer.moving else "eat"
		else:
			# Wrap at the edge of the street, but check the re-entry space too.
			if absf(passer.position.x-desired.x) > 20.0:
				passer.place_at(desired)
			passer.moving = passer.move_safely(desired,delta*2)
			passer.action = "walk"
			passer.rotation.y = PI/2 if i%2 == 0 else -PI/2
	for yarn in yarn_nodes:
		yarn.rotation.y = sin(clock*0.8)*0.12
	if is_instance_valid(mouse_actor):
		mouse_actor.position = at(Grounds.MOUSE_SPOT)+Vector3(sin(clock*2)*0.2,0,cos(clock)*0.15)

func _animate_worker(cat, next: Vector3, job: Dictionary, pose: String, delta: float) -> void:
	var previous: Vector3 = cat.position
	if cat.motion_enabled:
		cat.moving = cat.move_safely(next,Grounds.SPEED*delta)
	else:
		cat.moving = false
	var direction: Vector3 = cat.position-previous
	if cat.moving:
		cat.rotation.y = atan2(direction.x,direction.z)
	var working: bool = not job.is_empty() and float(job.elapsed) >= float(job.travel) and cat.position.distance_to(next) < 0.2
	cat.action = "walk" if cat.moving else "rest"
	if working:
		var kind: String = job.get("kind","clean")
		var actual: String = "pounce" if kind == "chase" else pose
		if cat.reaction != actual:
			cat.react(actual,maxf(0.5,float(job.duration)-float(job.elapsed)))
		cat.thought.text = ""
	elif cat.reaction in ["trim","sweep","pounce"]:
		cat.reaction = ""
