extends RefCounted
## Simulation owns activities and rewards. The scene only reads these records.
const Content = preload("res://scripts/core/game_content.gd")
const Moments = preload("res://scripts/creative/creative_moments.gd")
const WALK_SPEED: float = 1.35
const ACTOR_SPACING: float = 0.72
var _model_ref: WeakRef
var model:
	get: return _model_ref.get_ref() if _model_ref != null else null
	set(value): _model_ref = weakref(value) if value != null else null
var agents: Dictionary = {}
var reservations: Dictionary = {}
var _revision: int = -1
var _hotel: int = -1
var _venues: Array = []
var _turn: int = 0
var _staff_ids: Dictionary = {}
var _roster_cursor: int = 0
var _roster_clock: float = 0.0
var moments = Moments.new()
var _activity_serial: int = 0

func reset() -> void:
	moments.reset()
	_activity_serial = 0
	agents.clear()
	reservations.clear()
	_venues = []
	_revision = -1
	_hotel = -1
	_turn = 0
	_staff_ids.clear()
	_roster_cursor = 0
	_roster_clock = 0.0

func advance(seconds: float) -> void:
	if model == null or seconds <= 0: return
	var current: int = int(model.state.get("current_hotel",0))
	if current != _hotel:
		reset()
		_hotel = current
	_sync_guests()
	if int(model.revision) != _revision: _replan()
	_sync_staff()
	var remaining: float = seconds
	while remaining > 0.00001:
		var step: float = minf(remaining,0.2)
		_roster_clock += step
		for actor in agents.values():
			actor.velocity = Vector2.ZERO
			if int(actor.cat)>=1000: _advance_staff(actor,step)
			elif not (String(actor.phase) in ["idle","activity","sit"] and moments.holds(int(actor.cat))): _advance_actor(actor,step)
			var activity_key: String=String(actor.phase)+":"+String(actor.action)+":"+String(actor.venue)
			if activity_key!=String(actor.get("life_key","")):
				_activity_serial+=1
				actor.life_key=activity_key
				actor.life_elapsed=0.0
				actor.life_token=str(_hotel)+":"+str(_activity_serial)
			else: actor.life_elapsed=float(actor.get("life_elapsed",0.0))+step
		moments.advance(step,model)
		remaining -= step

func _arrival() -> Vector2:
	var point: Array = model.map_definition().get("arrival",[0,0])
	return Vector2(float(point[0]),float(point[1]))

func _activity_route(from: Vector2, to: Vector2) -> Array:
	return model.activity_route(from,to) if model.has_method("activity_route") else model.route(from,to)

func _position_free(point: Vector2,except: int=-1,reserved: bool=false,spacing: float=ACTOR_SPACING) -> bool:
	for other in agents.values():
		if int(other.cat)==except: continue
		if point.distance_to(Vector2(other.position))<spacing: return false
		if reserved and String(other.get("slot",""))!="" and point.distance_to(Vector2(other.destination))<ACTOR_SPACING: return false
	return true

func _free_arrival(except: int=-1) -> Vector2:
	var origin:=_arrival()
	# Physical arrival places fill outwards. A newly unlocked roster cannot
	# appear inside one cat, even when a frame admits all eighteen guests.
	for ring in range(12):
		for offset in range(1 if ring==0 else ring*8):
			var angle:=TAU*float(offset)/float(maxi(1,ring*8))
			var candidate:=origin+Vector2(cos(angle),sin(angle))*float(ring)*0.8
			var path:=_activity_route(origin,candidate)
			if path.is_empty(): continue
			var point: Vector2=path[-1]
			# Leave a walking lane between arrivals, not just body clearance.
			if not _position_free(point,except,false,ACTOR_SPACING*2.0+0.5): continue
			var staffed:=false
			for venue in _venues:
				if venue.has("staff_slot") and point.distance_to(Vector2(float(venue.staff_slot.x),float(venue.staff_slot.y)))<ACTOR_SPACING: staffed=true; break
			if not staffed: return point
	return Vector2(INF,INF)

func _sync_guests() -> void:
	var cats: Array = model.state.get("cats",[])
	var known: Dictionary = {}
	for index in range(cats.size()):
		var cat: Dictionary = cats[index]
		if not bool(cat.get("known",cat.get("unlocked",index<4))): continue
		known[int(cat.get("id",index))] = cat
	var capacity: int = maxi(0,int(model.guest_capacity())) if model.has_method("guest_capacity") else known.size()
	var staying: int = 0
	for id in agents.keys():
		if int(id)>=1000: continue
		if not known.has(id) or staying>=capacity:
			_release(agents[id])
			agents.erase(id)
		else:
			agents[id].friend = int(known[id].get("friend",-1))
			staying += 1
	# Preserve the current roster between completed stays. Capacity changes
	# affect only the excess guests; new beds fill only the newly free places.
	while staying<mini(capacity,known.size()):
		var admitted: bool = false
		for offset in range(cats.size()):
			var index: int = posmod(_roster_cursor+offset,cats.size())
			var cat: Dictionary = cats[index]
			var id: int = int(cat.get("id",index))
			if not known.has(id) or agents.has(id): continue
			var arrival:=_free_arrival(id)
			if not arrival.is_finite(): break
			agents[id] = {"cat":id,"name":cat.get("name",Content.CAT_NAMES[posmod(id,18)]),"position":arrival,"action":"arrival","venue":"","phase":"idle","time":float(id%4)*0.45,"route":[],"waypoint":0,"slot":"","destination":Vector2.ZERO,"tags":[],"recent":[],"preference":cat.get("preference",Content.PREFERENCES[posmod(id,18)]),"drink":false,"completed":false,"face":0.0,"checked_in":false,"friend":int(cat.get("friend",-1)),"velocity":Vector2.ZERO}
			_roster_cursor = (index+1)%cats.size()
			staying += 1
			admitted = true
			break
		if not admitted: break

func _replan() -> void:
	moments.cancel()
	_revision = int(model.revision)
	_venues = model.venues().duplicate(true)
	reservations.clear()
	for actor in agents.values():
		# A moved wall or object may cover a guest's old position. Return that
		# guest to the real entrance if the graph no longer accepts the start.
		var point: Vector2 = actor.position
		var safe: bool=model.movement_segment_clear(point,point,false) if model.has_method("movement_segment_clear") else not _activity_route(point,point).is_empty()
		if not safe or not _position_free(point,int(actor.cat)):
			var replacement:=_free_arrival(int(actor.cat))
			if replacement.is_finite(): actor.position=replacement
		actor.venue = ""
		actor.slot = ""
		actor.phase = "idle"
		actor.action = "rest"
		actor.time = float(int(actor.cat)%4)*0.12
		actor.route = []
		actor.drink = false
		actor.completed = false
		actor.velocity = Vector2.ZERO
		actor.blocked_time = 0.0

func _advance_actor(actor: Dictionary, seconds: float) -> void:
	if actor.phase in ["walk","walk_seat","walk_depart","wander"]:
		_walk(actor,seconds)
		return
	actor.time = maxf(0,float(actor.time)-seconds)
	if float(actor.time)>0: return
	match String(actor.phase):
		"idle": _choose(actor)
		"order":
			actor.phase = "serve"
			actor.action = "wait"
			actor.time = 2.8
		"serve":
			actor.drink = true
			if not _find_seat(actor):
				actor.phase = "activity"
				actor.action = "drink"
				actor.time = 7.5
		"sit", "activity": _finish(actor)

func _choose(actor: Dictionary) -> void:
	var candidates: Array = []
	for venue in _venues:
		if not bool(venue.get("open",false)): continue
		var reception: bool = String(venue.get("role",""))=="reception"
		if not bool(actor.get("checked_in",false)) and not reception: continue
		if bool(actor.get("checked_in",false)) and reception: continue
		var score: float = 1.0
		var tags: Array = venue.get("tags",[])
		if tags.has(actor.preference): score += 5.0
		if actor.recent.has(venue.id): score -= 6.0
		# The shared counter is a natural meeting place, including for guests
		# whose first choice was a nap or a game. Preferences still win first.
		if String(venue.get("role",""))=="bar": score += 1.2
		if String(venue.get("role",""))=="reception": score -= 0.8
		if String(venue.get("role","")) in ["seat","bar","play","warm","sun"]:
			var friend_id: int = int(actor.get("friend",-1))
			if agents.has(friend_id):
				var friend: Dictionary = agents[friend_id]
				for place in _venues:
					if place.id==friend.venue and String(place.get("room",""))==String(venue.get("room","")):
						var proximity: float = Vector2(float(venue.x),float(venue.y)).distance_to(Vector2(friend.position))
						if proximity<5.0: score += 4.0
						break
		# Each named cat has a different, repeatable tie break. Recent choices
		# then open up other reachable activities on subsequent visits.
		score += float(posmod(String(venue.id).hash()+int(actor.cat)*17+_turn*7,97))/97.0
		candidates.append({"venue":venue,"score":score})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.score)>float(b.score))
	for candidate in candidates:
		var venue: Dictionary = candidate.venue
		for slot in venue.get("slots",[]):
			var key: String = String(slot.key)
			if reservations.has(key): continue
			var destination: Vector2 = Vector2(float(slot.x),float(slot.y))
			if not _position_free(destination,int(actor.cat),true): continue
			var path: Array = _activity_route(actor.position,destination)
			if path.is_empty(): continue
			_reserve(actor,venue,slot,path,false)
			actor.tags = venue.get("tags",[]).duplicate()
			actor.completed = false
			_turn += 1
			return
	if bool(actor.get("checked_in",false)) and _wander(actor): return
	actor.time = 1.2 + float(int(actor.cat)%3)*0.3
	actor.action = "rest"

func _wander(actor: Dictionary) -> bool:
	var from: Vector2 = actor.position
	for index in range(8):
		var angle: float = float(posmod(int(actor.cat)+_turn+index,8))*PI*0.25
		var target: Vector2 = from+Vector2(cos(angle),sin(angle))*2.5
		if not _outdoors(target): continue
		var path: Array = model.route(from,target,false)
		if path.is_empty() or Vector2(path[-1]).distance_to(from)<0.8 or not _outdoors(Vector2(path[-1])): continue
		actor.route = path
		actor.waypoint = 0
		actor.phase = "wander"
		actor.action = "walk"
		actor.venue = ""
		actor.slot = ""
		actor.destination = path[-1]
		_turn += 1
		return true
	return false

func _outdoors(point: Vector2) -> bool:
	if not model.has_method("hotel"): return true
	for room in model.hotel().get("rooms",[]):
		var w: float = float(room.w)
		var h: float = float(room.h)
		if int(room.get("rotation",0))%2:
			var old_w: float = w
			w = h
			h = old_w
		if Rect2(float(room.x),float(room.y),w,h).grow(0.20).has_point(point): return false
	return true

func _reserve(actor: Dictionary, venue: Dictionary, slot: Dictionary, path: Array, seating: bool) -> void:
	_release(actor)
	var key: String = String(slot.key)
	reservations[key] = int(actor.cat)
	actor.slot = key
	actor.venue = String(venue.id)
	actor.destination = Vector2(float(slot.x),float(slot.y))
	actor.route = path
	actor.waypoint = 0
	actor.phase = "walk_seat" if seating else "walk"
	actor.action = "walk"
	actor.role = String(venue.get("role","seat"))
	actor.slot_action = String(slot.get("action","rest"))
	actor.blocked_time = 0.0
	if not seating:
		actor.activity_venue = String(venue.id)
		actor.source_room = String(venue.get("room",""))
		actor.source_position = Vector2(actor.position)

func _step_clear(actor: Dictionary,from: Vector2,to: Vector2) -> bool:
	if model.has_method("movement_segment_clear") and not model.movement_segment_clear(from,to,false): return false
	for other in agents.values():
		if int(other.cat)==int(actor.cat): continue
		var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(other.position),from,to)
		if nearest.distance_to(Vector2(other.position))<ACTOR_SPACING-0.0001: return false
	return true

func _avoid_crowd(actor: Dictionary) -> void:
	if actor.route.is_empty(): return
	var obstacles: Array=[]
	for other in agents.values():
		if int(other.cat)!=int(actor.cat): obstacles.append({"position":Vector2(other.position),"radius":ACTOR_SPACING})
	var destination: Vector2=actor.route[-1]
	var path: Array=[]
	if model.has_method("avoidance_route"):
		path=model.avoidance_route(actor.position,destination,obstacles,true)
		if path.is_empty(): path=model.avoidance_route(actor.position,destination,obstacles,false)
	if not path.is_empty(): actor.route=path; actor.waypoint=0; return
	# Guests waiting to check in must not become permanent entrance walls.
	# Ask an idle neighbour to make room using an ordinary collision-checked
	# walk, while its reception/activity reservation remains unclaimed.
	for other in agents.values():
		if int(other.cat)==int(actor.cat) or other.phase!="idle" or String(other.get("slot",""))!="": continue
		var waiting: Vector2=other.position
		if waiting.distance_to(Vector2(actor.position))>1.5: continue
		var away:=Vector2(actor.position).direction_to(waiting)
		for turn in [0.0,PI*0.5,-PI*0.5,PI*0.25,-PI*0.25]:
			var target:=waiting+away.rotated(turn)*1.25
			if not _step_clear(other,waiting,target): continue
			other.route=[target]; other.waypoint=0; other.destination=target
			other.phase="wander"; other.action="walk"
			return
	# Keep the same passing side relative to travel for opposing walkers.
	# A short physical step can free a narrow entrance when no complete
	# alternative route exists yet. It never crosses geometry or another cat.
	var from: Vector2=actor.position
	var forward:=from.direction_to(actor.route[mini(int(actor.waypoint),actor.route.size()-1)])
	for turn in [PI*0.5,-PI*0.5,PI*0.75,-PI*0.75,PI]:
		var point:=from+forward.rotated(turn)*0.8
		if not _step_clear(actor,from,point): continue
		actor.route=actor.route.slice(int(actor.waypoint))
		actor.route.push_front(point)
		actor.waypoint=0
		return

func _follow_route(actor: Dictionary,seconds: float) -> bool:
	var distance: float = seconds*WALK_SPEED
	var path: Array = actor.route
	var previous: Vector2=actor.position
	actor.velocity=Vector2.ZERO
	# Routes retain snapped endpoints for readiness and interaction slots.
	# A walker between cells can join the next clear segment directly instead
	# of briefly walking backwards to the snapped starting point.
	if int(actor.waypoint)==0 and path.size()>1 and _step_clear(actor,previous,path[1]): actor.waypoint=1
	while distance>0 and int(actor.waypoint)<path.size():
		var next: Vector2 = path[int(actor.waypoint)]
		var point: Vector2 = actor.position
		var gap: float = point.distance_to(next)
		if gap<0.001:
			actor.waypoint = int(actor.waypoint)+1
			continue
		var direction: Vector2 = point.direction_to(next)
		var movement: float = minf(gap,distance)
		var candidate:=point+direction*movement
		if not _step_clear(actor,point,candidate):
			actor.blocked_time=float(actor.get("blocked_time",0.0))+seconds
			if float(actor.blocked_time)>=0.35+float(posmod(int(actor.cat),3))*0.08:
				_avoid_crowd(actor)
				actor.blocked_time=0.0
			break
		actor.face = atan2(direction.x,direction.y)
		actor.position = candidate
		actor.blocked_time = 0.0
		distance -= movement
		if movement>=gap-0.001: actor.waypoint = int(actor.waypoint)+1
	actor.velocity=(Vector2(actor.position)-previous)/seconds
	return int(actor.waypoint)>=actor.route.size()

func _walk(actor: Dictionary, seconds: float) -> void:
	if not _follow_route(actor,seconds): return
	if actor.phase=="wander":
		actor.phase = "idle"
		actor.action = "rest"
		actor.time = 2.0
		actor.route = []
		return
	elif actor.phase=="walk_depart":
		_release(actor)
		agents.erase(int(actor.cat))
		_sync_guests()
		return
	elif actor.phase=="walk_seat":
		actor.phase = "sit"
		actor.action = "drink"
		actor.time = 8.0
	elif actor.role=="bar" or actor.slot_action=="order":
		actor.phase = "order"
		actor.action = "order"
		actor.time = 2.0
	else:
		actor.phase = "activity"
		actor.action = {"bed":"sleep","sun":"sunbathe","warm":"rest","seat":"sit","reception":"greet"}.get(String(actor.role),actor.slot_action)
		actor.time = 2.0 if actor.role=="reception" else (11.0 if actor.action=="sleep" else 7.0)
	# Face the activity, rather than freezing in the direction of the path.
	for venue in _venues:
		if venue.id==actor.venue:
			var facing: Vector2 = Vector2(float(venue.x),float(venue.y))-Vector2(actor.position)
			if facing.length()>0.05: actor.face = atan2(facing.x,facing.y)
			break

func _find_seat(actor: Dictionary) -> bool:
	var seats: Array = []
	for venue in _venues:
		if not bool(venue.get("open",false)) or String(venue.get("role",""))!="seat": continue
		if String(venue.get("item",""))=="cafe_table": continue
		var source_room: String = String(actor.get("source_room",""))
		if String(venue.get("room",""))!=source_room: continue
		if source_room=="" and Vector2(actor.position).distance_to(Vector2(float(venue.x),float(venue.y)))>6.0: continue
		for slot in venue.get("slots",[]):
			if reservations.has(String(slot.key)): continue
			var target: Vector2 = Vector2(float(slot.x),float(slot.y))
			if not _position_free(target,int(actor.cat),true): continue
			var path: Array = _activity_route(actor.position,target)
			if not path.is_empty(): seats.append({"venue":venue,"slot":slot,"path":path,"distance":Vector2(actor.position).distance_to(target)})
	seats.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	if seats.is_empty(): return false
	var choice: Dictionary = seats[0]
	_reserve(actor,choice.venue,choice.slot,choice.path,true)
	return true

func _release(actor: Dictionary) -> void:
	var slot: String = String(actor.get("slot",""))
	if reservations.get(slot,-1)==int(actor.cat): reservations.erase(slot)
	actor.slot = ""

func _finish(actor: Dictionary) -> void:
	if String(actor.get("role",""))=="reception":
		actor.checked_in = true
		_release(actor)
		actor.venue = ""
		actor.phase = "idle"
		actor.action = "rest"
		actor.time = 0.5
		return
	if not bool(actor.completed):
		actor.completed = true
		model.finish_visit(int(actor.cat),actor.tags)
	var recent: Array = actor.recent
	recent.append(String(actor.get("activity_venue",actor.venue)))
	while recent.size()>3: recent.pop_front()
	_release(actor)
	actor.venue = ""
	actor.phase = "idle"
	actor.action = "rest"
	actor.time = 2.0+float(int(actor.cat)%3)*0.5
	actor.drink = false
	actor.route = []
	_consider_departure(actor)

func _consider_departure(actor: Dictionary) -> void:
	if _roster_clock<90.0 or not model.has_method("guest_capacity"): return
	var current_guests: int = 0
	for id in agents:
		if int(id)<1000: current_guests += 1
	if current_guests<int(model.guest_capacity()): return
	var waiting: bool = false
	var cats: Array = model.state.get("cats",[])
	for index in range(cats.size()):
		var cat: Dictionary = cats[index]
		if bool(cat.get("known",false)) and not agents.has(int(cat.get("id",index))): waiting=true; break
	if not waiting: return
	var departure: Array = _activity_route(actor.position,_arrival())
	if departure.is_empty(): return
	_roster_clock = 0.0
	actor.route = departure
	actor.destination = departure[-1]
	actor.waypoint = 0
	actor.phase = "walk_depart"
	actor.action = "departure"

func _sync_staff() -> void:
	var wanted: Dictionary = {}
	for role in ["reception","bar"]:
		var number: int = 0
		for venue in _venues:
			if String(venue.get("role",""))!=role or not venue.get("open",false) or not venue.has("staff_slot"): continue
			var key: String = String(venue.id)
			if not _staff_ids.has(key):
				var next: int = 2000+posmod(key.hash(),1000000)
				while _staff_ids.values().has(next): next += 1
				_staff_ids[key] = next
			var id: int = int(_staff_ids[key])
			var slot: Dictionary = venue.staff_slot
			var station: String = String(slot.get("key","staff:"+String(venue.id)))
			if reservations.has(station) and int(reservations[station])!=id: continue
			var staff_point:=Vector2(float(slot.x),float(slot.y))
			var station_taken:=false
			for other_id in wanted:
				if agents.has(other_id) and staff_point.distance_to(Vector2(agents[other_id].position))<ACTOR_SPACING: station_taken=true; break
			if station_taken: continue
			wanted[id] = true
			if not agents.has(id):
				var names: Array = ["Pippin","Poppy","Cedar","Wren","Robin","Willow"] if role=="reception" else ["Saffron","Honey","Nutmeg","Cinnamon","Ginger","Cocoa"]
				var staff_name: String = String(names[number%names.size()])+(" "+str(number/names.size()+1) if number>=names.size() else "")
				agents[id] = _staff_record(id,staff_name,0 if role=="reception" else 1)
			var actor: Dictionary = agents[id]
			actor.venue = String(venue.id)
			actor.slot = station
			reservations[actor.slot] = id
			actor.position = staff_point
			actor.destination = staff_point
			for guest in agents.values():
				if int(guest.cat)==id or Vector2(guest.position).distance_to(staff_point)>=ACTOR_SPACING: continue
				var replacement:=_free_arrival(int(guest.cat))
				if replacement.is_finite(): guest.position=replacement; guest.route=[]; guest.phase="idle"; guest.time=0.1; _release(guest)
			actor.phase = "service"
			actor.role = role
			var facing: Vector2 = Vector2(float(venue.x),float(venue.y))-Vector2(actor.position)
			actor.face = atan2(facing.x,facing.y)
			number += 1
	if model.has_method("housekeeping_targets") and model.has_method("hotel") and bool(model.hotel().get("maid",false)):
		wanted[1000] = true
		if not agents.has(1000):
			var point:=_free_arrival(1000)
			if point.is_finite(): agents[1000]=_staff_record(1000,"Buttons",2); agents[1000].position=point
	for id in agents.keys():
		if int(id)>=1000 and not wanted.has(id):
			_release(agents[id])
			agents.erase(id)

func _staff_record(id: int, name_value: String, role_index: int) -> Dictionary:
	return {"cat":id,"name":name_value,"position":_arrival(),"action":"work","venue":"","phase":"idle","time":0.0,"route":[],"waypoint":0,"slot":"","destination":Vector2.ZERO,"tags":[],"recent":[],"preference":"","drink":false,"completed":false,"face":0.0,"staff_role":role_index}

func _advance_staff(actor: Dictionary, seconds: float) -> void:
	if int(actor.cat)!=1000:
		actor.action = "greet" if actor.role=="reception" else "work"
		for guest in agents.values():
			if int(guest.cat)<1000 and guest.venue==actor.venue and guest.phase=="serve": actor.action = "serve"
		return
	if actor.phase=="wander":
		if _follow_route(actor,seconds):
			actor.phase="idle"
			actor.action="work"
			actor.time=0.5
			actor.route=[]
		return
	if actor.phase=="walk_clean":
		if _follow_route(actor,seconds):
			actor.phase = "clean"
			actor.action = "clean"
			actor.time = 5.0
		return
	actor.time = maxf(0,float(actor.time)-seconds)
	if actor.time>0: return
	if actor.phase=="clean":
		model.clean_room(String(actor.venue))
		_release(actor)
		actor.venue = ""
		actor.phase = "idle"
		actor.action = "work"
		actor.time = 1.0
		return
	for target in model.housekeeping_targets():
		var key: String = String(target.get("key","cell:%.2f,%.2f" % [float(target.x),float(target.y)]))
		if reservations.has(key): continue
		if not _position_free(Vector2(float(target.x),float(target.y)),int(actor.cat),true): continue
		var path: Array = _activity_route(actor.position,Vector2(float(target.x),float(target.y)))
		if path.is_empty(): continue
		actor.venue = String(target.id)
		actor.slot = key
		reservations[key] = int(actor.cat)
		actor.route = path
		actor.destination = path[-1]
		actor.waypoint = 0
		actor.phase = "walk_clean"
		actor.action = "walk"
		return
	actor.time = 2.0
