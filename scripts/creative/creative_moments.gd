extends RefCounted
## Transient, reward-free social windows. One clock drives speech and paired gestures.
const Dialogue = preload("res://scripts/creative/creative_dialogue.gd")
const Geometry = preload("res://scripts/creative/lot_geometry.gd")
var active: Dictionary = {}
var serial: int = 0
var recent: Array = []
var _clock: float = 0.0
var _next: float = 17.0
var _scan: float = 0.0
var _revision: int = -1
var _hotel: int = -1
var _cats: Dictionary = {}
var _pairs: Dictionary = {}

func reset() -> void:
	active.clear(); recent.clear(); _cats.clear(); _pairs.clear()
	_clock=0.0; _next=17.0; _scan=0.0; _revision=-1; _hotel=-1; serial=0

func cancel() -> void:
	active.clear()
	_next=maxf(_next,_clock+8.0)

func holds(id: int) -> bool:
	return not active.is_empty() and active.phases.has(id)

func advance(seconds: float, model) -> void:
	if seconds<=0.0 or model==null or model.get("social")==null: return
	var hotel: int=int(model.state.get("current_hotel",0))
	if _hotel!=hotel:
		reset(); _hotel=hotel
	_clock+=seconds
	if _revision!=int(model.revision):
		if _revision!=-1: cancel()
		_revision=int(model.revision)
	if not active.is_empty():
		active.elapsed=float(active.elapsed)+seconds
		if not _valid(model) or float(active.elapsed)>=float(active.duration): cancel()
		return
	_scan-=seconds
	if _clock<_next or _scan>0.0: return
	_scan=0.5
	var candidates: Array = []
	for actor in model.social.agents.values():
		if _available(actor,true) and _clock>=float(_cats.get(int(actor.cat),0.0)): candidates.append(actor)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return int(a.cat)<int(b.cat))
	for a in candidates:
		for b in candidates:
			if int(a.cat)>=int(b.cat): continue
			var key: String="%d:%d" % [int(a.cat),int(b.cat)]
			if _clock<float(_pairs.get(key,0.0)) or not _near(a,b,model): continue
			var topic: String=_topic(a,b,model)
			var dialogue: Dictionary=Dialogue.choose(topic,recent,serial+int(a.cat)*3+int(b.cat))
			if dialogue.is_empty(): continue
			# A short shared pause preserves each reserved activity and its remaining
			# timer. After the exchange the same visit resumes without a new reward.
			var duration: float=float(dialogue.lines.size())*3.4
			serial+=1
			active={"id":serial,"participants":[int(a.cat),int(b.cat)],"phases":{int(a.cat):String(a.phase),int(b.cat):String(b.phase)},"venues":{int(a.cat):String(a.get("venue","")),int(b.cat):String(b.get("venue",""))},"lines":dialogue.lines,"elapsed":0.0,"duration":duration,"topic":topic}
			recent.append(dialogue.id)
			while recent.size()>8: recent.pop_front()
			_cats[int(a.cat)]=_clock+duration+45.0; _cats[int(b.cat)]=_clock+duration+45.0
			_pairs[key]=_clock+duration+90.0
			_next=_clock+duration+20.0+float(posmod(serial*7,16))
			return

func _available(actor: Dictionary, _starting: bool) -> bool:
	if int(actor.get("cat",1000))>=1000 or not bool(actor.get("checked_in",false)): return false
	if String(actor.get("phase","")) not in ["idle","activity","sit"]: return false
	if String(actor.get("action","")) not in ["rest","sit","loaf","sunbathe","sleep","drink","play","peek","scratch"]: return false
	if Vector2(actor.get("velocity",Vector2.ZERO)).length()>0.025: return false
	return true

func _room(point: Vector2, model) -> String:
	if not model.has_method("hotel"): return ""
	for room in model.hotel().get("rooms",[]):
		if String(room.get("kind",""))!="terrace" and Geometry.room_rect(room).has_point(point): return String(room.id)
	return ""

func _near(a: Dictionary, b: Dictionary, model) -> bool:
	var from: Vector2=a.position; var to: Vector2=b.position
	if from.distance_to(to)>3.2 or from.distance_to(to)<0.72: return false
	var area: String=_room(from,model)
	if area!=_room(to,model) or not model.has_method("movement_segment_clear"): return false
	# A table may sit between two friends. Speech checks walls, rather than the
	# walking graph's furniture obstacles, while still rejecting intervening rooms.
	for room in model.hotel().get("rooms",[]):
		if String(room.id)==area or String(room.kind)=="terrace": continue
		var rect: Rect2=Geometry.room_rect(room)
		var corners: Array[Vector2]=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(from,to,corners[i],corners[(i+1)%4])!=null: return false
	return true

func _valid(model) -> bool:
	var ids: Array=active.participants
	for id in ids:
		if not model.social.agents.has(id): return false
		var actor: Dictionary=model.social.agents[id]
		if not _available(actor,false) or String(actor.phase)!=String(active.phases[id]) or String(actor.get("venue",""))!=String(active.venues[id]): return false
	return _near(model.social.agents[ids[0]],model.social.agents[ids[1]],model)

func _topic(a: Dictionary, b: Dictionary, model) -> String:
	if model.has_method("hotel"):
		for object in model.hotel().get("objects",[]):
			if String(object.item) not in ["fountain","fireplace","milkshake_counter"]: continue
			if Geometry.object_rect(object).get_center().distance_to(Vector2(a.position))<3.5:
				return {"fountain":"fountain","fireplace":"warm","milkshake_counter":"food"}[String(object.item)]
	if int(a.get("friend",-1))==int(b.cat) and serial%3==0: return "social"
	var preference: String=String(a.get("preference","social")) if serial%2==0 else String(b.get("preference","social"))
	return preference if preference in ["sunny","quiet","food","warm","play","explore","social"] else "social"

func speech() -> Dictionary:
	if active.is_empty(): return {}
	var elapsed: float=float(active.elapsed)
	for line in active.lines:
		var duration: float=float(line.duration)
		if elapsed<duration:
			var result: Dictionary=line.duplicate()
			result.speaker=int(active.participants[int(line.role)])
			result.elapsed=elapsed; result.moment=int(active.id)
			return result
		elapsed-=duration+0.3
		if elapsed<0.0: return {}
	return {}

func pose_for(id: int) -> Dictionary:
	if active.is_empty() or not active.participants.has(id): return {}
	var line: Dictionary=speech()
	var index: int=active.participants.find(id)
	var kind: String="listen"
	var elapsed: float=fmod(float(active.elapsed),3.4)
	if not line.is_empty() and int(line.speaker)==id: kind=String(line.gesture)
	if float(active.elapsed)<0.65: kind="wave"
	return {"kind":kind,"elapsed":elapsed,"partner":int(active.participants[1-index])}
