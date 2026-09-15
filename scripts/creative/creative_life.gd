extends Node
## Connects live simulation records to reusable visual parts and screen-space speech.
const Speech = preload("res://scripts/creative/creative_speech_overlay.gd")
const Geometry = preload("res://scripts/creative/lot_geometry.gd")
var world
var speech
var live: bool = true
var chatter: bool = true
var _ambient: Array = []
var _revision: int = -1
var _model_id: int = -1
var _service: Dictionary = {}
var _service_line: Dictionary = {}
var _service_exchange: Dictionary = {}
var _prior_guests: Dictionary = {}
var _service_next: float = 0.0
var _attention: Dictionary = {}

func _ready() -> void:
	world=get_parent()
	var layer:=CanvasLayer.new(); layer.layer=0; layer.name="CatSpeechLayer"; add_child(layer)
	speech=Speech.new(); speech.name="CatSpeech"; layer.add_child(speech)

func set_context(active: bool, show_chatter: bool) -> void:
	if live and not active and world.model!=null:
		world.model.social.moments.cancel()
		_service_line.clear()
		_service_exchange.clear()
	live=active; chatter=show_chatter
	if not live or not chatter:
		if is_instance_valid(speech): speech.hide()

func facing_for(data: Dictionary, position: Vector3, fallback: float) -> float:
	if not live or String(data.phase) not in ["idle","activity","sit"]: return fallback
	var paired: Dictionary=world.model.social.moments.pose_for(int(data.cat))
	var target: Vector3
	if not paired.is_empty() and world.model.social.agents.has(paired.partner):
		var point: Vector2=world.model.social.agents[paired.partner].position
		target=Vector3(point.x*world.UNIT,position.y,point.y*world.UNIT)
	elif _attention.has(int(data.cat)) and String(_attention[int(data.cat)].token)==String(data.get("life_token","")):
		target=_attention[int(data.cat)].point
	else: return fallback
	var direction: Vector3=target-position
	return atan2(direction.x,direction.z) if direction.length()>0.1 else fallback

func _same_area(point: Vector2, object: Node3D) -> bool:
	var room_id: String=""
	for room in world.model.hotel().get("rooms",[]):
		if String(room.kind)!="terrace" and Geometry.room_rect(room).has_point(point): room_id=String(room.id); break
	return room_id==String(object.get_meta("room",""))

func _roofed(point: Vector2) -> bool:
	if not world.outside: return false
	for room in world.model.hotel().get("rooms",[]):
		if String(room.kind)!="terrace" and Geometry.room_rect(room).has_point(point): return true
	return false

func _visible(at: Vector3, margin: float=0.0) -> bool:
	return world.is_visible_in_tree() and world._visible_rect().grow(margin).has_point(world.camera.unproject_position(at)) and not world.camera.is_position_behind(at)

func update(delta: float) -> void:
	if world==null or world.model==null or world.model.social==null or not is_instance_valid(speech): return
	var model=world.model
	var motion: bool=live and bool(model.state.get("settings",{}).get("motion",true))
	var changed: bool=_revision!=int(model.revision) or _model_id!=model.get_instance_id()
	if changed:
		_revision=int(model.revision); _model_id=model.get_instance_id()
		_ambient.clear(); _service.clear(); _service_line.clear(); _service_exchange.clear(); _prior_guests.clear(); _attention.clear()
		for node in world.object_nodes.values():
			if String(node.get_meta("shape","")) in ["fountain","plant","flowers","garden_planter"]: _ambient.append(node)
	var activities: Dictionary={}
	var serving: Dictionary={}
	for data in model.social.agents.values():
		if int(data.cat)>=1000: continue
		var id: String=String(data.get("venue",""))
		if not world.object_nodes.has(id): continue
		var action: String=_object_action(data)
		if action=="": continue
		if not activities.has(id) or (action=="serve" and _object_action(activities[id])!="serve") or (action==_object_action(activities[id]) and int(data.cat)<int(activities[id].cat)): activities[id]=data
		if action=="serve": serving[id]=true
	_update_service_history(model,serving)
	var bursts: int=0
	for id in world.object_nodes:
		var node: Node3D=world.object_nodes[id]
		var controller=node.get_node_or_null("LifeMotion")
		if controller==null: continue
		var visible_effects: bool=live and _visible(node.global_position+Vector3(0,0.9,0),90) and not _roofed(Vector2(node.position.x,node.position.z)/world.UNIT)
		var data: Dictionary=activities.get(id,{})
		var action: String=_object_action(data) if not data.is_empty() else ""
		if action in ["dig","scratch"] and visible_effects:
			bursts+=1
			if bursts>4: visible_effects=false
		controller.set_motion_enabled(motion)
		controller.set_effects_visible(visible_effects)
		controller.set_activity(action,float(data.get("life_elapsed",0.0)),String(data.get("life_token","")))
	_attention.clear()
	for id in model.social.agents:
		if not world.actors.has(id): continue
		var data: Dictionary=model.social.agents[id]
		var actor=world.actors[id]
		actor.motion_enabled=motion
		actor.thought.hide()
		actor.set_social_pose("",0.0)
		if not live or bool(actor.moving): continue
		var elapsed: float=float(data.get("life_elapsed",0.0))
		var paired: Dictionary=model.social.moments.pose_for(int(id))
		if not paired.is_empty() and world.actors.has(paired.partner):
			actor.set_social_pose(String(paired.kind),float(paired.elapsed))
			continue
		var shape: String=""
		if world.object_nodes.has(String(data.get("venue",""))): shape=String(world.object_nodes[String(data.venue)].get_meta("shape",""))
		if int(id)>=1000:
			if String(data.get("role",""))=="bar":
				if serving.has(String(data.venue)): actor.set_social_pose("serve",elapsed)
				elif _service.has(String(data.venue)) and elapsed<0.8: actor.set_social_pose("handoff",elapsed)
			continue
		if String(data.phase) in ["activity","sit"]:
			var kind: String={"dig":"dig","scratch":"scratch","peek":"peek","play":"play_object"}.get(String(data.action),"")
			if String(data.action)=="sleep" and elapsed<2.6: kind="knead"
			if shape=="fireplace": kind="warm"
			if kind!="": actor.set_social_pose(kind,elapsed); continue
		if String(data.phase)=="idle" and int(id)%3!=2:
			for object in _ambient:
				if not is_instance_valid(object): continue
				var difference: Vector3=object.position-actor.position
				if Vector2(difference.x,difference.z).length()<3.0 and _same_area(Vector2(data.position),object):
					actor.set_social_pose("curious",elapsed)
					_attention[int(id)]={"token":String(data.get("life_token","")),"point":object.position}
					break
	for id in _service.keys():
		if float(model.state.time)-float(_service[id])>0.8: _service.erase(id)
	_present_speech(model,motion)

func _object_action(data: Dictionary) -> String:
	if String(data.get("phase",""))=="serve": return "serve"
	if String(data.get("phase","")) not in ["activity","sit","order"]: return ""
	var action: String=String(data.get("action",""))
	if action=="sleep" and float(data.get("life_elapsed",0.0))<2.6: return "knead"
	return {"loaf":"rest","sit":"rest","sunbathe":"rest","order":""}.get(action,action)

func _present_speech(model, motion: bool) -> void:
	if not live or not chatter or not world._visible_rect().has_area(): speech.hide(); return
	var line: Dictionary=model.social.moments.speech()
	if line.is_empty() and model.social.moments.active.is_empty(): line=_service_speech(model)
	if line.is_empty() or not world.actors.has(int(line.speaker)): speech.hide(); return
	var id: int=int(line.speaker)
	if not model.social.agents.has(id): speech.hide(); return
	var actor: Node3D=world.actors[id]
	if _roofed(Vector2(model.social.agents[id].position)): speech.hide(); return
	var anchor: Vector3=actor.global_position+Vector3(0,1.3,0)
	if world.camera.is_position_behind(anchor): speech.hide(); return
	var blocked: Array=[]
	for badge in world._status_badges.values():
		if badge.panel.visible: blocked.append(Rect2(badge.panel.position,badge.panel.size))
	# Keep other cats' faces clear of the bubble, including the reply's listener.
	for other in world.actors.values():
		var screen: Vector2=world.camera.unproject_position(other.global_position+Vector3(0,0.7,0))
		blocked.append(Rect2(screen-Vector2(10,9),Vector2(20,18)))
	speech.present(line,String(model.social.agents[id].name),world.camera.unproject_position(anchor),world._visible_rect().grow(-5),blocked,float(model.state.settings.get("ui_text_scale",1.0)),motion)

func _service_speech(model) -> Dictionary:
	var now: float=float(model.state.time)
	if not _service_line.is_empty():
		var id: int=int(_service_line.speaker)
		if not model.social.agents.has(id) or String(model.social.agents[id].get("life_token",""))!=String(_service_line.token): _service_line.clear()
		else:
			var elapsed: float=now-float(_service_line.started)
			if elapsed<float(_service_line.duration):
				var result: Dictionary=_service_line.duplicate(); result.elapsed=elapsed; return result
			_service_line.clear()
	if not _service_exchange.is_empty():
		var guest_id: int=int(_service_exchange.guest)
		var venue: String=String(_service_exchange.venue)
		if not model.social.agents.has(guest_id) or not world.object_nodes.has(venue):
			_service_exchange.clear()
		else:
			var guest: Dictionary=model.social.agents[guest_id]
			if String(guest.get("venue",""))!=venue or String(guest.get("phase","")) not in ["order","serve"]:
				_service_exchange.clear()
			elif String(guest.get("phase",""))=="serve":
				for attendant in model.social.agents.values():
					if int(attendant.cat)>=1000 and String(attendant.get("role",""))=="bar" and String(attendant.get("venue",""))==venue and String(attendant.get("action",""))=="serve" and world.actors.has(int(attendant.cat)):
						_service_line={"speaker":int(attendant.cat),"text":"Coming right up!","token":String(attendant.get("life_token","")),"started":now,"duration":2.7,"gesture":"talk","elapsed":0.0}
						_service_exchange.clear()
						return _service_line.duplicate()
	if now<_service_next: return {}
	for data in model.social.agents.values():
		var action: String=String(data.get("action",""))
		if action!="order" or float(data.get("life_elapsed",0.0))>0.8: continue
		if not world.actors.has(int(data.cat)): continue
		var actor: Node3D=world.actors[int(data.cat)]
		if not _visible(actor.global_position) or _roofed(Vector2(data.position)): continue
		_service_next=now+9.0
		_service_exchange={"guest":int(data.cat),"venue":String(data.get("venue",""))}
		_service_line={"speaker":int(data.cat),"text":"One shake, please!","token":String(data.get("life_token","")),"started":now,"duration":1.9,"gesture":"talk","elapsed":0.0}
		return _service_line.duplicate()
	return {}

func _update_service_history(model, serving: Dictionary) -> void:
	var current: Dictionary={}
	for data in model.social.agents.values():
		if int(data.cat)>=1000: continue
		var id: int=int(data.cat)
		current[id]={"phase":String(data.get("phase","")),"venue":String(data.get("venue","")),"activity_venue":String(data.get("activity_venue",data.get("venue",""))),"drink":bool(data.get("drink",false))}
		if _prior_guests.has(id):
			var previous: Dictionary=_prior_guests[id]
			var completed_venue: String=String(previous.get("venue",""))
			if String(previous.get("phase",""))=="serve" and not bool(previous.get("drink",false)) and bool(data.get("drink",false)) and String(data.get("phase","")) in ["walk_seat","sit","activity"] and String(data.get("activity_venue",data.get("venue","")))==completed_venue:
				_service[completed_venue]=float(model.state.time)
	_prior_guests=current
	# A successful handoff waits until the final overlapping service has finished.
	for venue in serving: _service.erase(venue)
