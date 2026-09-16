extends RefCounted
## Fresh-preview simulation and atomic construction; no legacy saves are consumed.
const Content=preload("res://scripts/creative/creative_content.gd")
const Maps=preload("res://scripts/creative/creative_maps.gd")
const Geo=preload("res://scripts/creative/lot_geometry.gd")
const Legacy=preload("res://scripts/core/game_content.gd")
var state: Dictionary={}
var revision:=0
var social
var _undo: Array=[]
var _redo: Array=[]
var _navigation: Dictionary={}
var _venue_cache: Dictionary={}
var _status_cache: Dictionary={}
var _income_fraction:=0.0

func new_game(now: int=0) -> void:
	state={"version":"creative-hotel-1","coins":1000.0,"current_hotel":0,"hotels":[],"storage":[],"cats":[],"settings":{"motion":true,"music":true,"sound":true,"exterior":false,"ui_text_scale":1.0,"evening":false,"god_mode":false},"next_id":1,"time":0.0,"last_seen":now,"pending_coins":0.0,"entitlements":[]}
	for index in range(4):
		var map: Dictionary=Maps.definition(index)
		var paths: Dictionary={}
		for path in map.paths: paths[_key(Vector2i(path.x,path.y))]={"style":str(path.get("style","earth")),"paid":float(path.get("paid",0))}
		var objects: Array=map.objects.duplicate(true)
		# Inventory is shared by every destination, so authored IDs need a map namespace.
		for object in objects: object.id=str(map.id)+"_"+str(object.id)
		state.hotels.append({"owned":index==0,"plots":[],"rooms":map.rooms.duplicate(true),"objects":objects,"paths":paths,"level":1,"upgrades":[1,0,0,1],"staff":[0,0,0],"visits":0,"happy":0,"cleaned":0,"dirty":{},"purchases":0,"maid":false,"dirt_clock":0.0,"dirt_cursor":0})
	for id in range(Legacy.CAT_NAMES.size()):
		state.cats.append({"id":id,"name":Legacy.CAT_NAMES[id],"preference":Legacy.PREFERENCES[id],"bond":0,"known":id<4,"last_care":-100.0})
	_undo.clear(); _redo.clear(); _invalidate()
	_ensure_social()

func _ensure_social() -> void:
	if social==null:
		social=load("res://scripts/creative/social_simulation.gd").new()
		social.model=self
	social.reset()

func hotel(index: int=-1) -> Dictionary:
	return state.hotels[int(state.current_hotel) if index<0 else index]

func map_definition(index: int=-1) -> Dictionary:
	return Maps.definition(int(state.current_hotel) if index<0 else index)

func is_god_mode() -> bool:
	return bool(state.get("settings",{}).get("god_mode",false))

func set_god_mode(enabled: bool, save: Callable=Callable()) -> Dictionary:
	if is_god_mode()==enabled: return _result(true,"God mode is already "+("on" if enabled else "off"))
	var before:=state.duplicate(true)
	state.settings.god_mode=enabled
	if enabled:
		for index in range(4):
			var data:=hotel(index); data.owned=true
			for plot in map_definition(index).plots:
				if not data.plots.has(plot.id): data.plots.append(plot.id)
		for cat in state.cats: cat.known=true
		for product in Legacy.PRODUCTS:
			if not state.entitlements.has(product.id): state.entitlements.append(product.id)
	if save.is_valid() and not bool(save.call(self)):
		state=before; return _result(false,"Could not save God mode. Nothing changed.")
	# History must not replay a paid transaction as a free, refundable purchase.
	_undo.clear(); _redo.clear(); _invalidate()
	if social!=null: social.reset()
	return _result(true,"God mode on · all content unlocked and editing is free" if enabled else "God mode off · normal prices restored")

func _purchase_price(amount: float) -> float:
	return 0.0 if is_god_mode() else amount

func _key(cell: Vector2i) -> String: return "%d,%d" % [cell.x,cell.y]
func _invalidate() -> void:
	revision+=1; _navigation.clear(); _venue_cache.clear(); _status_cache.clear()

func _result(ok: bool, message: String, cost: float=0, displaced: Array=[]) -> Dictionary:
	return {"ok":ok,"message":message,"cost":cost,"displaced":displaced}

func _id(prefix: String) -> String:
	var id:=prefix+str(state.next_id); state.next_id=int(state.next_id)+1; return id

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if str(value.id)==id: return value
	return {}

func _shell_cost(room: Dictionary) -> float:
	var area:=float(room.w)*float(room.h)
	match str(room.kind):
		"regular": return 450+maxf(0,area-12)*25
		"suite": return 1200+maxf(0,area-20)*25
		_: return area*25

func catalog_price(action: String, payload: Dictionary) -> float:
	if is_god_mode(): return 0.0
	if action=="place_object": return float(Content.item(str(payload.get("item",""))).get("cost",0))
	if action=="place_room": return _shell_cost({"kind":payload.get("kind","regular"),"w":payload.get("w",4),"h":payload.get("h",3)})
	if action=="place_template":
		var template: Dictionary=Content.template(str(payload.get("template","")))
		if template.is_empty(): return 0
		var total:=float(template.w)*float(template.h)*25
		for object in template.objects: total+=float(Content.item(str(object.item)).cost)
		return total
	return 0

func _room_shape(room: Dictionary) -> bool:
	if str(room.get("kind","")) not in ["regular","suite","shared","terrace"]: return false
	for key in ["x","y","w","h","rotation"]:
		if not Geo.whole(room.get(key)): return false
	if absf(float(room.x))>256 or absf(float(room.y))>256: return false
	var minimum:=Vector2i(4,5 if room.kind=="suite" else 3) if room.kind in ["regular","suite"] else Vector2i(2,2)
	return int(room.w)>=minimum.x and int(room.h)>=minimum.y and int(room.w)<=80 and int(room.h)<=80 and int(room.rotation)>=0 and int(room.rotation)<4

func _object_shape(object: Dictionary) -> bool:
	if Content.item(str(object.get("item",""))).is_empty(): return false
	for key in ["x","y"]:
		if not Geo.finite_number(object.get(key)) or not Geo.whole(float(object[key])*2): return false
		if absf(float(object[key]))>256: return false
	return Geo.whole(object.get("rotation")) and int(object.rotation)>=0 and int(object.rotation)<4

func _validate_layout(data: Dictionary, map: Dictionary) -> Dictionary:
	if not data.get("rooms") is Array or not data.get("objects") is Array or not data.get("plots") is Array: return _result(false,"Choose a valid hotel layout.")
	var seen: Dictionary={}
	# Validate every record before geometry compares it with any other record.
	for room in data.rooms:
		if not room is Dictionary: return _result(false,"Choose a valid room.")
		if not room.get("kind") is String or not room.get("name") is String or str(room.name).is_empty(): return _result(false,"Choose a valid room.")
		if not _room_shape(room) or not room.get("id") is String or str(room.id).is_empty() or seen.has(str(room.id)): return _result(false,"Choose a valid room size and position.")
		if not Geo.finite_number(room.get("paid")) or float(room.paid)<0 or float(room.paid)>_shell_cost(room): return _result(false,"The room purchase price is invalid.")
		seen[str(room.id)]=true
	var objects_seen: Dictionary={}
	var definitions: Dictionary={}
	for object in data.objects:
		if not object is Dictionary or not object.get("item") is String or not object.get("room") is String: return _result(false,"Choose a valid object.")
		if not _object_shape(object) or not object.get("id") is String or str(object.id).is_empty() or objects_seen.has(str(object.id)): return _result(false,"Choose a valid object position.")
		var definition: Dictionary=Content.item(str(object.item))
		if not Geo.finite_number(object.get("paid")) or float(object.paid)<0 or float(object.paid)>float(definition.cost): return _result(false,"The furniture purchase price is invalid.")
		objects_seen[str(object.id)]=true
		definitions[str(object.item)]=definition
	for room in data.rooms:
		var r:=Geo.room_rect(room)
		if not Geo.owns_rect(r,map,data): return _result(false,"Keep the whole room on owned land. Expand your lot to grow.")
		for other in data.rooms:
			if room.id!=other.id and r.intersects(Geo.room_rect(other)): return _result(false,"Rooms need their own floor space.")
		for scenic in map.get("scenery",[]):
			if scenic.get("protected",false) and r.intersects(Rect2(float(scenic.x),float(scenic.y),float(scenic.get("size",2)),float(scenic.get("size",2)))): return _result(false,"Keep this scenic landmark clear.")
	for object in data.objects:
		var bounds:=Geo.object_rect(object)
		if not Geo.owns_rect(bounds,map,data): return _result(false,"Keep the whole object on owned land.")
		var containing:=Geo.room_for(object,data.rooms)
		for room in data.rooms:
			if Geo.room_rect(room).intersects(bounds) and str(room.id)!=containing: return _result(false,"Keep objects inside one space or outside the walls.")
		var surface:="outdoor"
		var found:=_find(data.rooms,containing)
		if not found.is_empty() and found.kind!="terrace": surface="indoor"
		var definition: Dictionary=definitions[str(object.item)]
		if surface not in definition.get("surfaces",["indoor","outdoor"]): return _result(false,"This item belongs "+("outside." if surface=="indoor" else "on an indoor floor."))
		object.room=containing
		for other in data.objects:
			if str(other.id)<=str(object.id): continue
			var other_definition: Dictionary=definitions[str(other.item)]
			if definition.get("shape","")=="rug" or other_definition.get("shape","")=="rug": continue
			if bounds.grow(-0.01).intersects(Geo.object_rect(other).grow(-0.01)): return _result(false,"Leave space between objects.")
	return _result(true,"Ready to place")

func _build_snapshot() -> Dictionary:
	var hotels: Array=[]
	for data in state.hotels:
		hotels.append({"rooms":data.rooms.duplicate(true),"objects":data.objects.duplicate(true),"paths":data.paths.duplicate(true),"plots":data.plots.duplicate(),"upgrades":data.upgrades.duplicate(),"staff":data.staff.duplicate(),"level":data.level,"purchases":data.get("purchases",0),"maid":data.get("maid",false)})
	return {"hotels":hotels,"storage":state.storage.duplicate(true)}

func _apply_build(snapshot: Dictionary) -> void:
	for index in range(4):
		for key in snapshot.hotels[index]: state.hotels[index][key]=snapshot.hotels[index][key].duplicate(true) if snapshot.hotels[index][key] is Array or snapshot.hotels[index][key] is Dictionary else snapshot.hotels[index][key]
	state.storage=snapshot.storage.duplicate(true)
	_invalidate()

func quote(action: String, payload: Dictionary) -> Dictionary:
	# Keep borrowed hotel/room dictionaries untouched, including rejected previews.
	var before: Dictionary=state
	state=state.duplicate(true)
	var result:=_execute(action,payload)
	state=before
	return result

func commit(action: String, payload: Dictionary, save: Callable=Callable()) -> Dictionary:
	var before:=state.duplicate(true)
	var building_before:=_build_snapshot()
	var result:=_execute(action,payload)
	if not result.ok: state=before; return result
	state.coins=float(state.coins)-float(result.cost)
	if save.is_valid() and not bool(save.call(self)):
		state=before
		return _result(false,"Could not save. Your coins are safe; try again.")
	_undo.append({"before":building_before,"after":_build_snapshot(),"cost":result.cost})
	while _undo.size()>20: _undo.pop_front()
	_redo.clear(); _invalidate()
	return result

func undo(save: Callable=Callable()) -> Dictionary: return _history(false,save)
func redo(save: Callable=Callable()) -> Dictionary: return _history(true,save)

func _history(redoing: bool, save: Callable) -> Dictionary:
	var source: Array=_redo if redoing else _undo
	if source.is_empty(): return _result(false,"Nothing to redo." if redoing else "Nothing to undo.")
	var entry: Dictionary=source.back()
	if _build_snapshot()!=(entry.before if redoing else entry.after): return _result(false,"The building changed since this action.")
	var delta: float=float(entry.cost) if redoing else -float(entry.cost)
	if float(state.coins)<delta: return _result(false,"Not enough Cat Coins to repeat this change.")
	var before:=state.duplicate(true)
	_apply_build(entry.after if redoing else entry.before)
	state.coins=float(state.coins)-delta
	if save.is_valid() and not bool(save.call(self)):
		state=before; _invalidate(); return _result(false,"Could not save. Try again.")
	source.pop_back()
	(_undo if redoing else _redo).append(entry)
	return _result(true,"Redone" if redoing else "Undone",delta)

func _execute(action: String, p: Dictionary) -> Dictionary:
	if state.is_empty(): return _result(false,"Open your hotel first.")
	var data:=hotel()
	var cost:=0.0
	var displaced: Array=[]
	var message:="Saved"
	match action:
		"buy_plot":
			var found: Dictionary={}
			for plot in map_definition().plots:
				if str(plot.id)==str(p.get("id","")): found=plot
			if found.is_empty() or data.plots.has(found.id): return _result(false,"Choose land you do not own yet.")
			data.plots.append(found.id); cost=float(found.cost); message=found.name+" is yours"
		"place_room":
			var room: Dictionary={"id":_id("room"),"kind":str(p.get("kind","regular")),"name":str(p.get("name","New room")),"x":p.get("x"),"y":p.get("y"),"w":p.get("w",4),"h":p.get("h",3),"rotation":p.get("rotation",0),"paid":0}
			if not _room_shape(room): return _result(false,"Regular rooms start at 4 × 3; suites at 4 × 5.")
			cost=_purchase_price(_shell_cost(room)); room.paid=cost; data.rooms.append(room)
		"move_room","resize_room","copy_room","remove_room":
			var room:=_find(data.rooms,str(p.get("id","")))
			if room.is_empty(): return _result(false,"Select an existing room or shared space.")
			var old:=room.duplicate(true)
			var old_rect:=Geo.room_rect(old)
			var children: Array=[]
			for object in data.objects:
				if str(object.get("room",""))==str(room.id): children.append(object)
			if action=="remove_room":
				cost=-float(room.paid)
				for object in children: data.objects.erase(object); state.storage.append(object)
				data.rooms.erase(room)
			elif action=="resize_room":
				room.w=p.get("w"); room.h=p.get("h")
				if not _room_shape(room): return _result(false,"Keep the minimum room dimensions.")
				var difference: float=(float(room.w)*float(room.h)-float(old.w)*float(old.h))*25
				cost=_purchase_price(difference) if difference>0 else -minf(float(old.paid),-difference)
				room.paid=float(old.paid)+cost
				for object in children:
					if not Geo.room_rect(room).encloses(Geo.object_rect(object)):
						displaced.append(Content.item(str(object.item)).name); data.objects.erase(object); state.storage.append(object)
			else:
				var turns:=int(p.get("rotation",room.rotation))-int(room.rotation)
				if action=="copy_room":
					room=old.duplicate(true); room.id=_id("room"); room.name="Copy of "+str(old.name); cost=_purchase_price(_shell_cost(room)); room.paid=cost; data.rooms.append(room)
				room.x=p.get("x"); room.y=p.get("y"); room.rotation=p.get("rotation",room.rotation)
				if not _room_shape(room): return _result(false,"Choose a room position on the grid.")
				for source in children:
					var object: Dictionary=source.duplicate(true) if action=="copy_room" else source
					var center:=Geo.transform_point(Geo.object_rect(source).get_center(),old_rect,Geo.room_rect(room),turns)
					object.rotation=posmod(int(object.rotation)+turns,4)
					var size:=Geo.object_rect(object).size
					object.x=snappedf(center.x-size.x/2,0.5); object.y=snappedf(center.y-size.y/2,0.5); object.room=room.id
					if action=="copy_room":
						object.id=_id("object"); object.paid=_purchase_price(float(Content.item(str(object.item)).cost)); cost+=float(object.paid); data.objects.append(object)
		"place_template":
			var template: Dictionary=Content.template(str(p.get("template","")))
			if template.is_empty(): return _result(false,"Choose a shared-space arrangement.")
			var room: Dictionary={"id":_id("space"),"kind":template.kind,"name":template.name,"x":p.get("x"),"y":p.get("y"),"w":template.w,"h":template.h,"rotation":p.get("rotation",0),"paid":_purchase_price(float(template.w)*float(template.h)*25)}
			if not _room_shape(room): return _result(false,"Place this shared space on the grid.")
			cost=room.paid; data.rooms.append(room)
			var unrotated:=Rect2(0,0,float(template.w),float(template.h))
			for raw in template.objects:
				var object: Dictionary={"id":_id("object"),"item":raw.item,"room":room.id,"x":raw.x,"y":raw.y,"rotation":raw.get("rotation",0),"paid":_purchase_price(float(Content.item(str(raw.item)).cost))}
				var center:=Geo.transform_point(Geo.object_rect(object).get_center(),unrotated,Geo.room_rect(room),int(room.rotation))
				object.rotation=posmod(int(object.rotation)+int(room.rotation),4)
				var size:=Geo.object_rect(object).size
				object.x=snappedf(center.x-size.x/2,0.5); object.y=snappedf(center.y-size.y/2,0.5)
				cost+=float(object.paid); data.objects.append(object)
		"place_object","move_object","retrieve_object","store_object":
			var object: Dictionary={}
			if action=="place_object":
				var definition: Dictionary=Content.item(str(p.get("item","")))
				if definition.is_empty(): return _result(false,"Choose an item from the catalogue.")
				if int(definition.get("bond",0))>0 and not is_god_mode():
					var unlocked:=false
					for cat in state.cats:
						if cat.known and int(cat.bond)>=int(definition.bond): unlocked=true
					if not unlocked: return _result(false,"Reach 20 friendship with a cat to unlock this blanket.")
				cost=_purchase_price(float(definition.cost))
				object={"id":_id("object"),"item":definition.id,"room":"","x":0,"y":0,"rotation":0,"paid":cost}; data.objects.append(object)
			else:
				object=_find(state.storage if action=="retrieve_object" else data.objects,str(p.get("id","")))
				if object.is_empty(): return _result(false,"Select an owned object.")
			if action=="store_object":
				data.objects.erase(object); object.room=""; state.storage.append(object)
			else:
				if action=="retrieve_object": state.storage.erase(object); data.objects.append(object)
				object.x=p.get("x"); object.y=p.get("y"); object.rotation=p.get("rotation",0)
		"paint_path","erase_path":
			var style:=str(p.get("style","earth"))
			if style not in ["earth","gravel","brick"]: return _result(false,"Choose earth, gravel or brick paths.")
			if not p.get("cells") is Array or p.cells.size()>10000: return _result(false,"Draw a path on your lot.")
			var visited: Dictionary={}
			for raw in p.cells:
				if not raw is Array or raw.size()!=2 or not Geo.whole(raw[0]) or not Geo.whole(raw[1]): return _result(false,"Draw a path on the grid.")
				var cell:=Vector2i(raw[0],raw[1]); var key:=_key(cell)
				if visited.has(key): continue
				visited[key]=true
				if not Geo.owns_rect(Rect2(Vector2(cell),Vector2.ONE),map_definition(),data): return _result(false,"Paths must stay on owned land.")
				var previous: Dictionary=data.paths.get(key,{})
				if action=="erase_path":
					cost-=float(previous.get("paid",0)); data.paths.erase(key)
				elif previous.get("style","")!=style:
					var price: float=_purchase_price(float({"earth":2,"gravel":4,"brick":6}[style]))
					cost+=price-float(previous.get("paid",0)); data.paths[key]={"style":style,"paid":price}
		"upgrade":
			var index:=int(p.get("service",-1))
			if index<0 or index>=4 or int(data.upgrades[index])>=10: return _result(false,"This service is fully upgraded.")
			cost=round(240*pow(2,float(data.upgrades[index])/3)); data.upgrades[index]=int(data.upgrades[index])+1
			data.purchases=int(data.purchases)+1; data.level=mini(10,1+int(data.purchases)/2)
		"train":
			var index:=int(p.get("staff",-1))
			if index<0 or index>2 or int(data.staff[index])>=3: return _result(false,"This staff member is fully trained.")
			cost=250*(int(data.staff[index])+1); data.staff[index]=int(data.staff[index])+1
		"hire_housekeeper":
			if data.get("maid",false): return _result(false,"Daisy already works at this hotel.")
			if int(data.level)<3 and not is_god_mode(): return _result(false,"Housekeeping opens at hotel level 3.")
			cost=600; data.maid=true; message="Daisy will look after your guest rooms"
		_: return _result(false,"Choose a building action.")
	if is_god_mode(): cost=0.0
	var valid:=_validate_layout(data,map_definition())
	if not valid.ok: valid.cost=cost; valid.displaced=displaced; return valid
	if float(state.coins)+0.0001<cost: return _result(false,"Need %d more Cat Coins" % ceili(cost-float(state.coins)),cost,displaced)
	return _result(true,message,cost,displaced)

func _graph(constructed: bool, index: int) -> Dictionary:
	var cache_key:=str(index)+":"+str(constructed)
	if _navigation.has(cache_key): return _navigation[cache_key]
	var data:=hotel(index); var map:=map_definition(index)
	var bounds:=Geo.rect(map.base)
	for plot in map.plots:
		if data.plots.has(plot.id): bounds=bounds.merge(Geo.rect(plot.rect))
	var floor: Dictionary={}; var blocked: Dictionary={}; var solids: Array=[]
	for room in data.rooms:
		var r:=Geo.room_rect(room)
		for x in range(int(r.position.x*2),int(r.end.x*2)):
			for y in range(int(r.position.y*2),int(r.end.y*2)): floor[Vector2i(x,y)]=room
		if room.kind!="terrace":
			for side in range(4):
				var vertical:=side%2==0
				var start: Vector2=Vector2(r.end.x,r.position.y) if side==0 else (Vector2(r.position.x,r.end.y) if side==1 else r.position)
				var length: float=r.size.y if vertical else r.size.x
				var axis:=Vector2.DOWN if vertical else Vector2.RIGHT
				if room.kind=="shared" or int(room.get("rotation",0))%4==side:
					solids.append(Rect2(start,axis*(length*0.5-0.8)).grow(0.18))
					solids.append(Rect2(start+axis*(length*0.5+0.8),axis*(length*0.5-0.8)).grow(0.18))
				else: solids.append(Rect2(start,axis*length).grow(0.18))
	for object in data.objects:
		var item: Dictionary=Content.item(str(object.item))
		if item.get("role","") in ["gate"] or item.get("shape","")=="rug": continue
		var r:=Geo.object_rect(object).grow(0.18)
		solids.append(r)
		for x in range(floori(r.position.x*2),ceili(r.end.x*2)):
			for y in range(floori(r.position.y*2),ceili(r.end.y*2)):
				if r.has_point(Vector2(x*0.5+0.25,y*0.5+0.25)): blocked[Vector2i(x,y)]=true
	var solid_cells: Dictionary={}
	for solid in solids:
		for x in range(floori(solid.position.x*2),ceili(solid.end.x*2)):
			for y in range(floori(solid.position.y*2),ceili(solid.end.y*2)):
				var cell:=Vector2i(x,y)
				if not solid_cells.has(cell): solid_cells[cell]=[]
				solid_cells[cell].append(solid)
	var graph:=AStar2D.new(); var points: Dictionary={}; var count:=0
	for x in range(int(bounds.position.x*2),int(bounds.end.x*2)):
		for y in range(int(bounds.position.y*2),int(bounds.end.y*2)):
			var cell:=Vector2i(x,y); var point:=Vector2(x*0.5+0.25,y*0.5+0.25)
			if blocked.has(cell) or not Geo.point_owned(point,map,data): continue
			if constructed and not floor.has(cell) and not data.paths.has(_key(Vector2i(floori(point.x),floori(point.y)))): continue
			var inside_solid:=false
			for solid in solid_cells.get(cell,[]):
				if solid.has_point(point): inside_solid=true; break
			if inside_solid: continue
			points[cell]=count; graph.add_point(count,point); count+=1
	var result: Dictionary={"graph":graph,"points":points,"solids":solid_cells}
	for cell in points:
		for step in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
			var next: Vector2i=cell+step
			if not points.has(next): continue
			if not _segment_open(graph.get_point_position(points[cell]),graph.get_point_position(points[next]),result): continue
			graph.connect_points(points[cell],points[next])
	_navigation[cache_key]=result
	return result

# Every route shortcut and physical step uses the same expanded walls and
# furniture. Traversing all crossed cells also preserves owned/path boundaries.
func _segment_hits_rect(from: Vector2,to: Vector2,rect: Rect2) -> bool:
	var delta:=to-from; var enter:=0.0; var leave:=1.0
	for axis in range(2):
		if absf(delta[axis])<0.000001:
			if from[axis]<rect.position[axis] or from[axis]>rect.end[axis]: return false
		else:
			var a: float=(rect.position[axis]-from[axis])/delta[axis]
			var b: float=(rect.end[axis]-from[axis])/delta[axis]
			enter=maxf(enter,minf(a,b)); leave=minf(leave,maxf(a,b))
			if enter>leave: return false
	return true

func _segment_open(from: Vector2,to: Vector2,nav: Dictionary,obstacles: Array=[]) -> bool:
	var delta:=to-from
	var cell:=Vector2i(floori(from.x*2),floori(from.y*2))
	var last:=Vector2i(floori(to.x*2),floori(to.y*2))
	var step:=Vector2i(signi(last.x-cell.x),signi(last.y-cell.y))
	var increment:=Vector2(INF if step.x==0 else 0.5/absf(delta.x),INF if step.y==0 else 0.5/absf(delta.y))
	var crossing:=Vector2(INF,INF)
	if step.x!=0: crossing.x=((cell.x+(1 if step.x>0 else 0))*0.5-from.x)/delta.x
	if step.y!=0: crossing.y=((cell.y+(1 if step.y>0 else 0))*0.5-from.y)/delta.y
	for iteration in range(absi(last.x-cell.x)+absi(last.y-cell.y)+3):
		if not nav.points.has(cell): return false
		for solid in nav.solids.get(cell,[]):
			if _segment_hits_rect(from,to,solid): return false
		if cell==last: break
		if absf(crossing.x-crossing.y)<0.000001:
			if not nav.points.has(cell+Vector2i(step.x,0)) or not nav.points.has(cell+Vector2i(0,step.y)): return false
			cell+=step; crossing+=increment
		elif crossing.x<crossing.y: cell.x+=step.x; crossing.x+=increment.x
		else: cell.y+=step.y; crossing.y+=increment.y
	for obstacle in obstacles:
		var center: Vector2=obstacle.position
		var closest:=Geometry2D.get_closest_point_to_segment(center,from,to)
		if closest.distance_to(center)<float(obstacle.radius): return false
	return true

func movement_segment_clear(from: Vector2,to: Vector2,constructed: bool=true,index: int=-1) -> bool:
	if not from.is_finite() or not to.is_finite(): return false
	if index<0: index=int(state.current_hotel)
	return _segment_open(from,to,_graph(constructed,index))

func _simplify_path(path: Array,nav: Dictionary,obstacles: Array=[]) -> Array:
	if path.size()<3: return path
	var result: Array=[path[0]]; var anchor:=0
	while anchor<path.size()-1:
		var next:=path.size()-1
		while next>anchor+1 and not _segment_open(path[anchor],path[next],nav,obstacles): next-=1
		result.append(path[next]); anchor=next
	return result

func route(from: Vector2, to: Vector2, constructed: bool=true, index: int=-1) -> Array:
	if index<0: index=int(state.current_hotel)
	if not from.is_finite() or not to.is_finite(): return []
	var nav:=_graph(constructed,index)
	var graph: AStar2D=nav.graph
	if graph.get_point_count()==0: return []
	var start:=graph.get_closest_point(from); var finish:=graph.get_closest_point(to)
	if graph.get_point_position(start).distance_to(from)>1.5 or graph.get_point_position(finish).distance_to(to)>0.8: return []
	return _simplify_path(Array(graph.get_point_path(start,finish)),nav)

func avoidance_route(from: Vector2,to: Vector2,obstacles: Array,constructed: bool=true,index: int=-1) -> Array:
	if not from.is_finite() or not to.is_finite(): return []
	if index<0: index=int(state.current_hotel)
	var nav:=_graph(constructed,index); var graph: AStar2D=nav.graph
	if graph.get_point_count()==0: return []
	var disabled: Array=[]
	var edges: Array=[]
	for obstacle in obstacles:
		var center: Vector2=obstacle.position; var radius: float=obstacle.radius
		for x in range(floori((center.x-radius)*2),ceili((center.x+radius)*2)):
			for y in range(floori((center.y-radius)*2),ceili((center.y+radius)*2)):
				var id: int=nav.points.get(Vector2i(x,y),-1)
				if id>=0 and not graph.is_point_disabled(id) and graph.get_point_position(id).distance_to(center)<radius:
					graph.set_point_disabled(id,true); disabled.append(id)
		# Two clear endpoints can still cut across a body's circle, especially
		# on diagonal grid edges. Exclude those exact segments for this search.
		for x in range(floori((center.x-radius-0.5)*2),ceili((center.x+radius+0.5)*2)):
			for y in range(floori((center.y-radius-0.5)*2),ceili((center.y+radius+0.5)*2)):
				var id: int=nav.points.get(Vector2i(x,y),-1)
				if id<0 or graph.is_point_disabled(id): continue
				for next in graph.get_point_connections(id):
					if graph.is_point_disabled(next): continue
					var nearest:=Geometry2D.get_closest_point_to_segment(center,graph.get_point_position(id),graph.get_point_position(next))
					if nearest.distance_to(center)<radius:
						graph.disconnect_points(id,next); edges.append(Vector2i(id,next))
	var start:=graph.get_closest_point(from); var finish:=graph.get_closest_point(to)
	var path: Array=[]
	if graph.get_point_position(start).distance_to(from)<=0.8 and graph.get_point_position(finish).distance_to(to)<0.1:
		path=Array(graph.get_point_path(start,finish))
		if not path.is_empty():
			if _segment_open(from,path[0],nav,obstacles): path.push_front(from)
			else: path=[]
	for id in disabled: graph.set_point_disabled(id,false)
	for edge in edges: graph.connect_points(edge.x,edge.y)
	return _simplify_path(path,nav,obstacles)

func activity_route(from: Vector2, to: Vector2) -> Array:
	var path:=route(from,to,true)
	return route(from,to,false) if path.is_empty() else path

func _approaches(object: Dictionary, index: int) -> Array:
	var r:=Geo.object_rect(object); var result: Array=[]
	var room:=_find(hotel(index).rooms,str(object.get("room","")))
	var indoors: bool=not room.is_empty() and room.kind!="terrace"
	var candidates: Array=[Vector2(r.position.x-0.25,r.get_center().y),Vector2(r.end.x+0.25,r.get_center().y),Vector2(r.get_center().x,r.position.y-0.25),Vector2(r.get_center().x,r.end.y+0.25)]
	var map:=map_definition(index); var arrival:=Vector2(map.arrival[0],map.arrival[1])
	for point in candidates:
		if indoors and not Geo.room_rect(room).has_point(point): continue
		var path:=route(arrival,point,indoors,index)
		if path.is_empty() or Vector2(path[-1]).distance_to(point)>=0.45: continue
		if indoors and not Geo.room_rect(room).has_point(path[-1]): continue
		if not result.has(path[-1]): result.append(path[-1])
	return result

func venues(index: int=-1) -> Array:
	if index<0: index=int(state.current_hotel)
	if _venue_cache.has(index): return _venue_cache[index]
	var data:=hotel(index); var result: Array=[]; var staff_positions: Dictionary={}
	for object in data.objects:
		var item: Dictionary=Content.item(str(object.item)); var role:=str(item.get("role","decoration"))
		if role in ["decoration","fence","gate"]: continue
		var approaches:=_approaches(object,index); var slots: Array=[]
		var staff_slot: Dictionary={}
		if role in ["reception","bar"] and approaches.size()>1:
			var behind:=Vector2(0,-1).rotated(int(object.rotation)*PI/2)
			var center:=Geo.object_rect(object).get_center()
			var best:=-1; var alignment:=-INF
			for n in range(approaches.size()):
				var point: Vector2=approaches[n]
				if staff_positions.has("cell:%.2f,%.2f" % [point.x,point.y]): continue
				var score: float=(Vector2(approaches[n])-center).normalized().dot(behind)
				if score>alignment: alignment=score; best=n
			if best>=0:
				var staff_point: Vector2=approaches[best]; approaches.remove_at(best)
				staff_slot={"x":staff_point.x,"y":staff_point.y,"key":"cell:%.2f,%.2f" % [staff_point.x,staff_point.y]}
				staff_positions[staff_slot.key]=true
		var maximum:=maxi(1,int(item.get("capacity",1)))
		for i in range(approaches.size()):
			var point: Vector2=approaches[i]
			var activity: String={"litter":"dig","box":"peek","scratch":"scratch"}.get(str(object.item),"eat" if role=="bar" else ("play" if role=="play" else "loaf"))
			slots.append({"key":"cell:%.2f,%.2f" % [point.x,point.y],"x":point.x,"y":point.y,"action":activity})
		if role=="bar" and staff_slot.is_empty(): slots.clear()
		var status:="Open" if not slots.is_empty() else "Needs access"
		var venue: Dictionary={"id":str(object.id),"item":str(object.item),"name":str(item.name),"x":float(object.x),"y":float(object.y),"tags":item.get("tags",[]),"role":role,"service":int(item.get("service",-1)),"open":not slots.is_empty(),"status":status,"capacity":maximum,"slots":slots,"room":object.get("room","")}
		if not staff_slot.is_empty(): venue.staff_slot=staff_slot
		result.append(venue)
	# Staff and guests share physical positions, including neighboring venues.
	for venue in result:
		var available: Array=[]
		for slot in venue.slots:
			if not staff_positions.has(slot.key) and available.size()<int(venue.capacity): available.append(slot)
		venue.slots=available; venue.capacity=available.size(); venue.open=not available.is_empty()
		venue.status="Open" if venue.open else "Needs access"
	var reception:=false
	for venue in result:
		if venue.role=="reception" and venue.open: reception=true
	for venue in result:
		if venue.role=="bed" and not reception: venue.open=false; venue.status="Needs reception"
		if venue.role=="bar" and venue.open:
			var seats:=false
			for seat in result:
				if seat.role!="seat" or not seat.open or seat.item=="cafe_table" or seat.room!=venue.room: continue
				if venue.room!="" or Vector2(venue.x,venue.y).distance_to(Vector2(seat.x,seat.y))<=6: seats=true; break
			if not seats: venue.status="Add seating"
	_venue_cache[index]=result
	return result

func room_status(id: String, index: int=-1) -> Dictionary:
	if index<0: index=int(state.current_hotel)
	var key:=str(index)+":"+id
	if _status_cache.has(key): return _status_cache[key]
	var room:=_find(hotel(index).rooms,id)
	var result: Dictionary={"ready":false,"status":"Needs a bed","message":"Add a reachable bed to welcome guests."}
	if room.is_empty(): return {"ready":false,"status":"Missing room","message":"This room was removed."}
	if room.kind in ["shared","terrace"]:
		for venue in venues(index):
			if str(venue.room)==id and venue.open: result={"ready":true,"status":"Open","message":"Cats can spend time here."}; break
		if not result.ready: result={"ready":false,"status":"Add activities","message":"Place a reachable counter, seat or activity."}
	else:
		var reception:=false
		for venue in venues(index):
			if venue.role=="reception" and venue.open: reception=true; break
		var bed:=false; var reachable:=false
		for object in hotel(index).objects:
			if str(object.get("room",""))==id and Content.item(str(object.item)).get("role","")=="bed":
				bed=true
				if not _approaches(object,index).is_empty(): reachable=true
		if bed:
			if not reception: result={"ready":false,"status":"Needs reception","message":"Connect a reception counter to the entrance."}
			elif not reachable: result={"ready":false,"status":"Needs a path","message":"Connect the door and bed to reception."}
			else:
				var bonus:=_furnishing_bonus(id,index)
				result={"ready":true,"status":"Ready for guests","message":"A bed and a welcoming route are ready."+(" Furnishing combinations add %d/min." % int(bonus) if bonus>0 else ""),"bonus":bonus}
	_status_cache[key]=result
	return result

func _furnishing_bonus(id: String, index: int) -> float:
	var items: Dictionary={}; var bonus:=0.0
	for object in hotel(index).objects:
		if object.get("room","")==id: items[str(object.item)]=true
	for combo in Legacy.COMBOS:
		var complete:=true
		for item in combo.items:
			if not items.has(item): complete=false; break
		if complete: bonus+=float(combo.bonus)
	return bonus

func guest_capacity(index: int=-1) -> int:
	if index<0: index=int(state.current_hotel)
	var capacity:=0
	for room in hotel(index).rooms:
		if room.kind in ["regular","suite"] and room_status(str(room.id),index).ready:
			capacity+=4 if room.kind=="suite" else 2
	return capacity

func rate(index: int=-1) -> float:
	var total:=0.0
	for h in range(4):
		if (index>=0 and h!=index) or not hotel(h).owned: continue
		var data:=hotel(h); var families: Dictionary={}
		for room in data.rooms:
			if room.kind in ["regular","suite"] and room_status(str(room.id),h).ready:
				total+=(28 if room.kind=="suite" else 12)+float(room_status(str(room.id),h).get("bonus",0))
				families[0]=true
		for venue in venues(h):
			if venue.open and int(venue.service)>0: families[int(venue.service)]=true
		for family in families: total+=maxi(1,int(data.upgrades[family]))*10
		for staff in data.staff: total+=int(staff)*2
	return total

func advance(seconds: float) -> void:
	if state.is_empty() or not is_finite(seconds) or seconds<=0: return
	state.time=float(state.time)+seconds
	state.coins=float(state.coins)+rate()*seconds/60.0
	for h in range(4):
		var data:=hotel(h)
		if not data.owned: continue
		data.dirt_clock=float(data.get("dirt_clock",0))+seconds
		if float(data.dirt_clock)>=120:
			data.dirt_clock=fmod(float(data.dirt_clock),120)
			var rooms: Array=[]
			for room in data.rooms:
				if room.kind in ["regular","suite"] and room_status(str(room.id),h).ready: rooms.append(room)
			if not rooms.is_empty():
				var cursor:=int(data.get("dirt_cursor",0))%rooms.size()
				data.dirty[str(rooms[cursor].id)]=true; data.dirt_cursor=cursor+1
	if social!=null: social.advance(seconds)

func housekeeping_targets() -> Array:
	var result: Array=[]
	if not hotel().get("maid",false): return result
	for room in hotel().rooms:
		if not hotel().dirty.get(str(room.id),false) or not room_status(str(room.id)).ready: continue
		for object in hotel().objects:
			if object.get("room","")==room.id and Content.item(str(object.item)).get("role","")=="bed":
				var points:=_approaches(object,int(state.current_hotel))
				if not points.is_empty(): result.append({"id":str(room.id),"x":points[0].x,"y":points[0].y,"key":"cell:%.2f,%.2f" % [points[0].x,points[0].y]})
	return result

func clean_room(id: String) -> void:
	if hotel().dirty.get(id,false): hotel().dirty[id]=false; hotel().cleaned=int(hotel().cleaned)+1

func finish_visit(cat: int, tags: Array) -> void:
	if cat<0 or cat>=state.cats.size(): return
	var data:=hotel(); var guest: Dictionary=state.cats[cat]
	data.visits=int(data.visits)+1
	if tags.has(guest.preference):
		data.happy=int(data.happy)+1; guest.bond=mini(100,int(guest.bond)+1)
		for other in state.cats:
			if not other.known and other.preference==guest.preference and int(other.id)<12: other.known=true; break

func care(cat: int, action: String) -> Dictionary:
	if cat<0 or cat>=state.cats.size() or not state.cats[cat].known: return {"ok":false,"message":"Meet this cat first.","progress_changed":false}
	if action not in ["pet","brush","wand","yarn","cushion","box"]: return {"ok":false,"message":"Choose a toy.","progress_changed":false}
	var guest: Dictionary=state.cats[cat]
	var progress_changed:=int(guest.bond)<100 and float(state.time)-float(guest.last_care)>=12
	if progress_changed:
		guest.bond=mini(100,int(guest.bond)+(6 if str(Legacy.FAVORITE_ACTIONS[cat])==action else 3)); guest.last_care=state.time
	var result:=_result(true,str(guest.name)+" is enjoying your company")
	result.progress_changed=progress_changed
	return result

func can_travel(index: int) -> Dictionary:
	if index<0 or index>=4: return _result(false,"Choose a destination.")
	if is_god_mode(): return _result(true,"God mode · visit "+str(Maps.definition(index).name))
	if hotel(index).owned: return _result(true,"Visit "+str(Maps.definition(index).name))
	if index==1:
		if int(hotel(0).level)<10: return _result(false,"Reach Meadow level 10 and save 10,000 Cat Coins",10000)
		return _result(float(state.coins)>=10000,"Open Seaside Suites · 10,000",10000)
	var product: String="purrington.forest_lodge" if index==2 else "purrington.snowcap_spa"
	return _result(state.entitlements.has(product),"Included with "+str(Maps.definition(index).name)+" expansion")

func travel(index: int, save: Callable=Callable()) -> Dictionary:
	var quote:=can_travel(index)
	if not quote.ok: return quote
	var before:=state.duplicate(true)
	state.coins=float(state.coins)-float(quote.cost); hotel(index).owned=true; state.current_hotel=index
	if save.is_valid() and not bool(save.call(self)): state=before; return _result(false,"Could not save this journey. Try again.")
	_invalidate()
	if social!=null: social.reset()
	return _result(true,"Welcome to "+str(Maps.definition(index).name))

func serialize() -> Dictionary: return state.duplicate(true)

func restore(value: Dictionary) -> bool:
	if value.get("version","")!="creative-hotel-1" or not value.get("hotels") is Array or value.hotels.size()!=4: return false
	for key in ["coins","time","last_seen","pending_coins"]:
		if not Geo.finite_number(value.get(key)) or float(value[key])<0: return false
	if not Geo.whole(value.last_seen): return false
	if not Geo.whole(value.get("current_hotel")) or int(value.current_hotel)<0 or int(value.current_hotel)>3: return false
	# JSON must preserve the integer sequence exactly, including after another allocation.
	if not Geo.whole(value.get("next_id")) or float(value.next_id)<1 or float(value.next_id)>=9007199254740991: return false
	if not value.get("storage") is Array or not value.get("cats") is Array or value.cats.size()!=18 or not value.get("settings") is Dictionary or not value.get("entitlements") is Array: return false
	var candidate: Dictionary=value.duplicate(true)
	var settings_defaults: Dictionary={"motion":true,"music":true,"sound":true,"exterior":false,"evening":false,"ui_text_scale":1.0,"god_mode":false}
	for key in candidate.settings:
		if key not in settings_defaults: return false
	for key in settings_defaults:
		if not candidate.settings.has(key): candidate.settings[key]=settings_defaults[key]
		if key=="ui_text_scale":
			if not Geo.finite_number(candidate.settings[key]) or float(candidate.settings[key])<1.0 or float(candidate.settings[key])>1.5: return false
		elif not candidate.settings[key] is bool: return false
	var entitlements_seen: Dictionary={}
	for product in candidate.entitlements:
		if not product is String or Legacy.product(product).is_empty() or entitlements_seen.has(product): return false
		entitlements_seen[product]=true
	var object_ids: Dictionary={}
	var instance_ids: Array=[]
	for index in range(4):
		var data: Variant=candidate.hotels[index]
		if not data is Dictionary or not data.get("owned") is bool: return false
		for key in ["plots","rooms","objects","upgrades","staff"]:
			if not data.get(key) is Array: return false
		if data.upgrades.size()!=4 or data.staff.size()!=3 or not data.get("paths") is Dictionary: return false
		for level in data.upgrades:
			if not Geo.whole(level) or int(level)<0 or int(level)>10: return false
		for level in data.staff:
			if not Geo.whole(level) or int(level)<0 or int(level)>3: return false
		for key in ["level","visits","happy","cleaned","purchases"]:
			if not Geo.whole(data.get(key)) or float(data[key])<0 or float(data[key])>9007199254740991: return false
		if int(data.level)<1 or int(data.level)>10: return false
		var housekeeping_defaults: Dictionary={"dirty":{},"maid":false,"dirt_clock":0.0,"dirt_cursor":0}
		for key in housekeeping_defaults:
			if not data.has(key): data[key]=housekeeping_defaults[key]
		if not data.dirty is Dictionary or not data.maid is bool: return false
		for room_id in data.dirty:
			# Removed rooms can remain here while their construction is undoable.
			if not room_id is String or room_id.is_empty() or not data.dirty[room_id] is bool: return false
		if not Geo.finite_number(data.dirt_clock) or float(data.dirt_clock)<0: return false
		if not Geo.whole(data.dirt_cursor) or float(data.dirt_cursor)<0 or float(data.dirt_cursor)>9007199254740991: return false
		var plot_ids: Array=[]
		for plot in Maps.definition(index).plots: plot_ids.append(plot.id)
		var seen: Dictionary={}
		for plot in data.plots:
			if not plot is String or plot not in plot_ids or seen.has(plot): return false
			seen[plot]=true
		for key in data.paths:
			if not key is String: return false
			var parts: PackedStringArray=key.split(",")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var cell:=Vector2i(int(parts[0]),int(parts[1]))
			if key!=_key(cell) or absi(cell.x)>256 or absi(cell.y)>256: return false
			var path: Variant=data.paths[key]
			if not path is Dictionary or path.get("style","") not in ["earth","gravel","brick"] or not Geo.finite_number(path.get("paid")) or float(path.paid)<0: return false
			if float(path.paid)>float({"earth":2,"gravel":4,"brick":6}[path.style]): return false
			if not Geo.owns_rect(Rect2(Vector2(cell),Vector2.ONE),Maps.definition(index),data): return false
		if not _validate_layout(data,Maps.definition(index)).ok: return false
		for room in data.rooms: instance_ids.append(str(room.id))
		for object_index in range(data.objects.size()):
			var object: Dictionary=data.objects[object_index]
			if object.room!=value.hotels[index].objects[object_index].room or object_ids.has(object.id): return false
			object_ids[object.id]=true; instance_ids.append(str(object.id))
	if not candidate.hotels[int(candidate.current_hotel)].owned: return false
	for object in candidate.storage:
		if not object is Dictionary or not object.get("item") is String or not object.get("room") is String: return false
		if not _object_shape(object) or not object.get("id") is String or str(object.id).is_empty() or object_ids.has(object.id): return false
		if not Geo.finite_number(object.get("paid")) or float(object.paid)<0 or float(object.paid)>float(Content.item(str(object.item)).cost): return false
		object_ids[object.id]=true; instance_ids.append(str(object.id))
	for id in instance_ids:
		for prefix in ["room","space","object"]:
			if not id.begins_with(prefix): continue
			var suffix: String=id.trim_prefix(prefix)
			if suffix.is_valid_int() and str(int(suffix))==suffix and int(suffix)>=int(candidate.next_id): return false
	for index in range(18):
		var cat: Variant=candidate.cats[index]
		if not cat is Dictionary or not Geo.whole(cat.get("id")) or int(cat.id)!=index or not cat.get("known") is bool or not Geo.whole(cat.get("bond")) or int(cat.bond)<0 or int(cat.bond)>100 or not Geo.finite_number(cat.get("last_care")): return false
		if not cat.get("name") is String or str(cat.name).is_empty() or not cat.get("preference") is String or cat.preference not in Legacy.PREFERENCES: return false
		if cat.has("friend") and (not Geo.whole(cat.friend) or int(cat.friend)<0 or int(cat.friend)>=18 or int(cat.friend)==index): return false
	# No live state, cached routes, social activity or history changes before this point.
	state=candidate; _undo.clear(); _redo.clear(); _invalidate(); _ensure_social()
	return true

func reconcile(now: int) -> void:
	var elapsed:=maxi(0,now-int(state.last_seen))
	state.pending_coins=float(state.pending_coins)+rate()*minf(28800,elapsed)/60
	state.last_seen=now
