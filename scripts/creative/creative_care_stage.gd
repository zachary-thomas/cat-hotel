extends SubViewportContainer
## Visual input only. The screen commits care through the authoritative app.
signal care_action(kind: String)
signal contact_changed(active: bool)
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Content = preload("res://scripts/core/game_content.gd")
const Room = preload("res://scripts/creative/creative_care_room.gd")
const TOOLS: Array[String] = ["pet","brush","wand","yarn","cushion","box"]
var cat_index: int = 0
var hotel_index: int = 0
var enabled_motion: bool = true
var tool: String = "pet"
var viewport: SubViewport
var camera: Camera3D
var scene: Node3D
var cat
var prop: Node3D
var cushion: Node3D
var held: bool = false
var contact: bool = false
var pointer: int = -2
var last_point := Vector2.ZERO
var velocity := Vector2.ZERO
var target := Vector3.ZERO
var yarn_velocity := Vector3.ZERO
var _reward_clock: float = 0.0
var _play_clock: float = 0.0
var _reaction_clock: float = 0.0
var _automatic: float = 0.0
var _fur_clock: float = 0.0

func _ready() -> void:
	stretch=true; mouse_filter=Control.MOUSE_FILTER_STOP
	viewport=SubViewport.new(); viewport.size=Vector2i(480,400); viewport.own_world_3d=true
	viewport.gui_disable_input=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	scene=Node3D.new(); viewport.add_child(scene)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("F5EBD9")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("FFF2DD"); environment.environment.ambient_light_energy=0.6
	scene.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-25,0); light.light_energy=0.7; scene.add_child(light)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH; camera.size=3.8; camera.position=Vector3(1.65,2.5,5)
	scene.add_child(camera); camera.look_at(Vector3(0,0.85,0)); camera.current=true
	cushion=Room.build(scene,hotel_index)
	cat=Cat.new(); cat.set_meta("cat_index",cat_index); scene.add_child(cat)
	cat.build(Color(Content.COATS[cat_index])); cat.remove_from_group(&"navigating_cats")
	cat.scale=Vector3.ONE*1.3
	cat.set_process(false); cat.motion_enabled=enabled_motion
	prop=Node3D.new(); scene.add_child(prop)
	gui_input.connect(_gesture)
	resized.connect(_resize_camera)
	_resize_camera()

func _resize_camera() -> void:
	if camera==null or size.y<=0: return
	# Keep the cat readable in both the short phone stage and wide desktop stage.
	camera.size=maxf(2.9,2.4*size.x/size.y)

func set_tool(value: String) -> void:
	if value not in TOOLS: return
	cancel_contact(); tool=value; _play_clock=0; _automatic=0; yarn_velocity=Vector3.ZERO
	cat.position=Vector3.ZERO; cat.rotation=Vector3.ZERO; cat.reaction=""; cat.action="rest"
	cat.thought.text=""; cat.stroke_direction=Vector2.ZERO
	cushion.visible=false
	for child in prop.get_children(): child.free()
	prop.position=Vector3.ZERO; prop.visible=false
	match tool:
		"brush":
			Room.box(prop,Vector3.ZERO,Vector3(0.25,0.08,0.16),Color("C28C6D"))
			Room.box(prop,Vector3(0,0,-0.18),Vector3(0.07,0.06,0.25),Color("DCB48B"))
			for i in range(4): Room.box(prop,Vector3(-0.09+i*0.06,-0.07,0),Vector3(0.015,0.10,0.13),Color("EEE4D2"))
		"wand":
			Room.box(prop,Vector3(0.25,0.2,0),Vector3(0.025,0.6,0.025),Color("B18B6E")).rotation.z=-0.65
			for i in range(3): Room.ball(prop,Vector3(i*0.05,0,0),0.11,Color("BBABD4") if i%2 else Color("E7B1B7")).scale=Vector3(0.6,1.8,0.35)
		"yarn":
			Room.ball(prop,Vector3.ZERO,0.15,Color("D995A3"))
			for i in range(3):
				var strand:=Room.box(prop,Vector3(0,0.04*i-0.04,0.14),Vector3(0.20,0.016,0.02),Color("F3C5CA")); strand.rotation.z=0.3
		"box":
			Room.box(prop,Vector3(0,0.06,0),Vector3(1.1,0.1,0.9),Color("C69662"))
			for x in [-0.53,0.53]: Room.box(prop,Vector3(x,0.3,0),Vector3(0.06,0.5,0.9),Color("DAB37B"))
			for z in [-0.43,0.43]: Room.box(prop,Vector3(0,0.3,z),Vector3(1.1,0.5,0.06),Color("CDA16C"))
			Room.box(prop,Vector3(0,0.3,0.47),Vector3(0.25,0.10,0.015),Color("F0D7A7"))

func _view_point(point: Vector2) -> Vector2:
	return point * Vector2(viewport.size) / size.max(Vector2.ONE)

func cat_hit(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO,size).has_point(point): return false
	var at:=_view_point(point)
	return _mesh_hit(cat.body,camera.project_ray_origin(at),camera.project_ray_normal(at))

func _mesh_hit(node: Node, origin: Vector3, direction: Vector3) -> bool:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh!=null:
		var local_origin: Vector3=node.global_transform.affine_inverse()*origin
		var local_direction: Vector3=node.global_basis.inverse()*direction
		if node.get_aabb().intersects_ray(local_origin,local_direction)!=null: return true
	for child in node.get_children():
		if _mesh_hit(child,origin,direction): return true
	return false

func _plane_point(point: Vector2, height: float) -> Vector3:
	var at:=_view_point(point)
	var origin:=camera.project_ray_origin(at); var direction:=camera.project_ray_normal(at)
	var hit: Vector3=origin+direction*((height-origin.y)/direction.y)
	return Vector3(clampf(hit.x,-1.05,1.05),height,clampf(hit.z,-0.55,0.9))

func _gesture(event: InputEvent) -> void:
	if event is InputEventMouse and (event.device==InputEvent.DEVICE_ID_EMULATION or OS.has_feature("mobile")): return
	if event is InputEventScreenTouch:
		if event.pressed and pointer==-2: _begin(event.position,event.index)
		elif not event.pressed and pointer==event.index: _end(event.position,event.canceled)
	elif event is InputEventScreenDrag and pointer==event.index: _move(event.position,event.relative,event.velocity)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and pointer==-2: _begin(event.position,-1)
		elif not event.pressed and pointer==-1: _end(event.position,false)
	elif event is InputEventMouseMotion and pointer==-1: _move(event.position,event.relative,event.velocity)
	accept_event()

func _begin(point: Vector2, id: int) -> void:
	pointer=id; held=true; last_point=point; velocity=Vector2.ZERO; _automatic=0
	_reward_clock=0; _play_clock=0
	if tool in ["pet","brush"]: _set_contact(cat_hit(point)); _update_prop(point)
	elif tool in ["wand","yarn"]:
		prop.visible=true; target=_plane_point(point,0.8 if tool=="wand" else 0.16)
		prop.position=target; yarn_velocity=Vector3.ZERO; _engage()
	else: use_selected_tool()

func _move(point: Vector2, relative: Vector2, speed: Vector2) -> void:
	if not held: return
	last_point=point; velocity=speed
	if not Rect2(Vector2.ZERO,size).has_point(point): cancel_contact(); return
	if tool in ["pet","brush"]:
		_set_contact(cat_hit(point)); _update_prop(point)
		if contact: cat.stroke(relative/20.0)
	else:
		target=_plane_point(point,0.8 if tool=="wand" else 0.16); prop.position=target

func _update_prop(point: Vector2) -> void:
	if tool=="brush":
		var at:=_view_point(point)
		var origin:=camera.project_ray_origin(at); var direction:=camera.project_ray_normal(at)
		prop.visible=contact
		# Keep the brush at the finger's projected height, just in front of the coat.
		prop.position=origin+direction*((0.9-origin.z)/direction.z)+Vector3(0.15,0,0)

func _end(point: Vector2, canceled: bool) -> void:
	if tool=="yarn" and held and not canceled and Rect2(Vector2.ZERO,size).has_point(point):
		var next:=_plane_point(point+velocity.limit_length(1500)*0.15,0.16)
		yarn_velocity=(next-prop.position)*4.0
		if yarn_velocity.length()<0.1: yarn_velocity=Vector3(0.85,0,0.25)
		_play_clock=3.5
	elif tool=="wand" and held and not canceled: _play_clock=1.2
	cancel_contact()

func _set_contact(value: bool) -> void:
	if value==contact: return
	contact=value; contact_changed.emit(contact)
	if contact: _engage()

func _engage() -> void:
	care_action.emit(tool)
	_reaction_clock=0
	if tool in ["pet","brush"]: cat.react("brush" if tool=="brush" else "purr",2.0)

func cancel_contact() -> void:
	held=false; pointer=-2; _set_contact(false)
	if tool=="brush" and is_instance_valid(prop): prop.visible=false

func suspend() -> void:
	cancel_contact(); _automatic=0; _play_clock=0; yarn_velocity=Vector3.ZERO
	if is_instance_valid(cat): cat.reaction=""; cat.moving=false; cat.thought.text=""

func use_selected_tool() -> void:
	_automatic=2.0; _reaction_clock=0
	match tool:
		"pet","brush":
			_set_contact(true)
			if tool=="brush": prop.visible=true; prop.position=Vector3(0.55,0.95,0.9)
		"wand","yarn":
			prop.visible=true; prop.position=Vector3(0.75,0.85 if tool=="wand" else 0.16,0.2)
			target=prop.position; _play_clock=3.5; _engage()
			if tool=="yarn": yarn_velocity=Vector3(-0.9,0,0.2)
		"cushion":
			cushion.visible=true; prop.visible=false; cat.position=Vector3(0,0.14,0)
			cat.react("settle",4); _engage()
		"box":
			prop.visible=true; cat.position=Vector3.ZERO; cat.react("peek",4); _engage()

func _input(event: InputEvent) -> void:
	# Release can arrive outside this control, or after GUI focus has changed.
	if event is InputEventScreenTouch and not event.pressed and event.index==pointer:
		_end(get_global_transform_with_canvas().affine_inverse()*event.position,event.canceled)
	elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and pointer==-1:
		_end(get_global_transform_with_canvas().affine_inverse()*event.position,false)

func _process(delta: float) -> void:
	if cat==null: return
	cat.motion_enabled=enabled_motion
	cat._process(delta)
	_reaction_clock+=delta
	if _automatic>0:
		_automatic=maxf(0,_automatic-delta)
		if _automatic==0 and not held: cancel_contact()
	if contact:
		_reward_clock+=delta
		if _reward_clock>=1.0: _reward_clock=0; care_action.emit(tool)
		if cat.reaction=="": cat.react("brush" if tool=="brush" else "purr",2)
		if tool=="brush" and enabled_motion:
			if _automatic>0 and not held: prop.position.y=0.95+sin(_reaction_clock*6)*0.12
			_fur_clock+=delta
			if _fur_clock>0.25: _fur_clock=0; _fur()
	if tool in ["wand","yarn"] and (held or _play_clock>0):
		_play_clock=maxf(0,_play_clock-delta)
		_reward_clock+=delta
		if _reward_clock>=1.0: _reward_clock=0; care_action.emit(tool)
		if not enabled_motion: cat.thought.text="♥"; return
		if tool=="yarn" and not held:
			prop.position+=yarn_velocity*delta
			if absf(prop.position.x)>1.05: yarn_velocity.x*=-0.7
			if prop.position.z < -0.55 or prop.position.z>0.9: yarn_velocity.z*=-0.7
			prop.position.x=clampf(prop.position.x,-1.05,1.05); prop.position.z=clampf(prop.position.z,-0.55,0.9)
			yarn_velocity=yarn_velocity.move_toward(Vector3.ZERO,delta*0.22)
		var desired:=Vector3(prop.position.x*0.65,0,prop.position.z*0.45)
		cat.position=cat.position.move_toward(desired,delta*0.75)
		cat.head.rotation.y=clampf((prop.position.x-cat.position.x)*0.6,-0.6,0.6)
		cat.head.rotation.x=-0.12 if tool=="wand" else 0.3
		cat.legs[1].rotation.x=-absf(sin(_reaction_clock*6))*0.8
		if tool=="wand":
			cat.body.position.y=maxf(0,sin(_reaction_clock*3))*0.18
		else:
			cat.body.position.y=absf(sin(_reaction_clock*10))*0.035
			for i in range(4): cat.legs[i].rotation.x=sin(_reaction_clock*10+i*2)*0.35
	elif tool=="box" and prop.visible:
		cat.thought.text="♥"
		if enabled_motion:
			cat.body.scale.y=0.65+maxf(0,sin(_reaction_clock*1.8))*0.35
			cat.head.rotation.z=sin(_reaction_clock*2)*0.15
	if not enabled_motion and contact: cat.thought.text="♥ purrr"

func _fur() -> void:
	var fluff:=Room.ball(scene,prop.position+Vector3(-0.1,0,0),0.025,Color(Content.COATS[cat_index]).lightened(0.3))
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(fluff,"position",fluff.position+Vector3(0.15,-0.35,0.05),0.55)
	tween.tween_property(fluff,"scale",Vector3.ZERO,0.55)
	tween.chain().tween_callback(fluff.queue_free)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: suspend()

func _exit_tree() -> void:
	suspend()
