extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const Geo=preload("res://scripts/creative/lot_geometry.gd")
var failures:=0

func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)

func empty_property():
	var model=Model.new(); model.new_game(1000)
	var data: Dictionary=model.hotel()
	data.rooms.clear(); data.objects.clear(); data.paths.clear()
	for x in range(-12,12):
		for y in range(-12,12): data.paths["%d,%d"%[x,y]]={"style":"earth","paid":0}
	model._invalidate()
	return model

func actor(id: int,point: Vector2,path: Array=[],phase: String="wander") -> Dictionary:
	return {"cat":id,"name":"Test guest","position":point,"action":"walk","venue":"","phase":phase,"time":1000.0,"route":path,"waypoint":0,"slot":"","destination":path[-1] if not path.is_empty() else point,"tags":[],"recent":[],"preference":"quiet","drink":false,"completed":false,"face":0.0,"checked_in":true,"role":"bed","slot_action":"rest"}

func _initialize() -> void:
	var model=empty_property()
	var from:=Vector2(-4.75,-3.75); var to:=Vector2(4.25,3.25)
	var path: Array=model.route(from,to)
	check(path.size()==2 and path[0]==from and path[-1]==to,"An unobstructed diagonal is one straight walk with unchanged snapped endpoints")
	model.hotel().rooms=[{"id":"wall-room","kind":"regular","x":0,"y":0,"w":4,"h":4,"rotation":0}]
	model.hotel().objects=[{"id":"obstacle","item":"box","room":"","x":-2,"y":0,"rotation":0}]
	model._invalidate()
	path=model.route(Vector2(-3.75,1.25),Vector2(1.25,1.25))
	check(not path.is_empty(),"A walled room remains reachable through its actual door")
	var cut_wall:=false; var cut_object:=false
	for i in range(1,path.size()):
		for sample in range(101):
			var p: Vector2=Vector2(path[i-1]).lerp(Vector2(path[i]),sample/100.0)
			if absf(p.x)<0.15 and p.y>0.15 and p.y<3.85: cut_wall=true
			if Rect2(-2.18,-0.18,1.36,1.36).has_point(p): cut_object=true
	check(not cut_wall and not cut_object,"Simplified routes preserve full walls and furniture clearance")
	model=empty_property()
	model.hotel().paths.clear()
	for x in range(-5,5): model.hotel().paths["%d,0"%x]={"style":"earth","paid":0}
	for y in range(1,5): model.hotel().paths["4,%d"%y]={"style":"earth","paid":0}
	model._invalidate()
	path=model.route(Vector2(-4.75,0.25),Vector2(4.25,4.25))
	var cut_grass:=false
	for i in range(1,path.size()):
		for sample in range(101):
			var p: Vector2=Vector2(path[i-1]).lerp(Vector2(path[i]),sample/100.0)
			if p.y>1 and p.x<4: cut_grass=true
	check(not path.is_empty() and not cut_grass,"Route smoothing stays on constructed access when requested")
	model=empty_property(); model.hotel().plots=["west","north"]; model._invalidate()
	path=model.route(Vector2(-18.75,-10.75),Vector2(-10.75,-18.75),false)
	var crossed_unowned:=false
	for i in range(1,path.size()):
		for sample in range(101):
			var p: Vector2=Vector2(path[i-1]).lerp(Vector2(path[i]),sample/100.0)
			if p.x<-12 and p.y<-12: crossed_unowned=true
	check(not path.is_empty() and not crossed_unowned,"A shortcut between owned plots never crosses their unowned corner")
	model=empty_property()
	var obstacle_center:=Vector2(-0.05,-0.95)
	path=model.avoidance_route(Vector2(-0.75,-0.75),Vector2(-0.25,-0.25),[{"position":obstacle_center,"radius":0.72}])
	var cut_body:=false
	for i in range(1,path.size()):
		if Geometry2D.get_closest_point_to_segment(obstacle_center,path[i-1],path[i]).distance_to(obstacle_center)<0.72: cut_body=true
	check(not path.is_empty() and not cut_body,"Avoidance checks the space between graph nodes, including diagonal tangents")
	model=Model.new(); model.new_game(1000); model.advance(0.001)
	var positions: Array=[]; var arrivals_overlap:=false
	for guest in model.social.agents.values():
		for point in positions:
			if Vector2(guest.position).distance_to(point)<0.70: arrivals_overlap=true
		positions.append(guest.position)
	check(not arrivals_overlap,"New guests and staff arrive at distinct physical positions")
	model=empty_property()
	var sim=model.social
	var walker:=actor(0,Vector2(-3.75,0.25),[Vector2(-3.75,0.25),Vector2(3.25,0.25)])
	var resting:=actor(1,Vector2(0.25,0.25),[],"activity")
	sim.agents={0:walker,1:resting}
	var nearest:=INF
	for step in range(240):
		if walker.phase=="wander": sim._walk(walker,0.05)
		nearest=minf(nearest,Vector2(walker.position).distance_to(resting.position))
	check(nearest>=0.70,"Walking guests never cross a resting guest's body")
	check(Vector2(walker.position).distance_to(Vector2(3.25,0.25))<0.1,"A guest goes around a stationary blocker and reaches its destination")
	var between_cells:=Vector2(-0.60,0.25)
	walker=actor(0,between_cells,model.route(between_cells,Vector2(3.25,0.25)))
	sim.agents={0:walker}; sim._walk(walker,0.05)
	check(Vector2(walker.position).x>between_cells.x,"A new route joins forward from the current position without stepping backwards to the grid")
	var left:=actor(0,Vector2(-3.75,0.25),[Vector2(-3.75,0.25),Vector2(3.25,0.25)])
	var right:=actor(1,Vector2(3.25,0.25),[Vector2(3.25,0.25),Vector2(-3.75,0.25)])
	sim.agents={0:left,1:right}; nearest=INF
	for step in range(300):
		for guest in [left,right]:
			if guest.phase=="wander": sim._walk(guest,0.05)
		nearest=minf(nearest,Vector2(left.position).distance_to(right.position))
	check(nearest>=0.70,"Opposing walkers do not pass through one another")
	check(left.phase=="idle" and right.phase=="idle","Opposing walkers yield and both complete their walk")
	var maid:=actor(1000,Vector2(-3.75,0.25),[Vector2(-3.75,0.25),Vector2(3.25,0.25)],"walk_clean")
	sim.agents={1000:maid,1:resting}; nearest=INF
	for step in range(240):
		if maid.phase=="walk_clean": sim._advance_staff(maid,0.05)
		nearest=minf(nearest,Vector2(maid.position).distance_to(resting.position))
	check(nearest>=0.70 and maid.phase=="clean","Housekeeping obeys the same collision rules and reaches the cleaning station")
	model=empty_property()
	model.hotel().rooms=[{"id":"door-room","kind":"regular","x":0,"y":0,"w":4,"h":4,"rotation":0}]
	model._invalidate(); sim=model.social
	left=actor(0,Vector2(2.25,2.25),model.route(Vector2(2.25,2.25),Vector2(6.25,2.25)))
	right=actor(1,Vector2(6.25,2.25),model.route(Vector2(6.25,2.25),Vector2(2.25,2.25)))
	sim.agents={0:left,1:right}; nearest=INF
	var clipped_wall:=false
	for step in range(500):
		for guest in [left,right]:
			if guest.phase=="wander": sim._walk(guest,0.05)
			var p: Vector2=guest.position
			if absf(p.x-4)<0.18 and (p.y<1.38 or p.y>2.62): clipped_wall=true
		nearest=minf(nearest,Vector2(left.position).distance_to(right.position))
	check(nearest>=0.70 and not clipped_wall,"Doorway yielding respects both the other cat and the solid door jambs")
	check(left.phase=="idle" and right.phase=="idle","Opposing guests both make progress through a single room door")
	walker=actor(0,Vector2(2.25,2.25),model.route(Vector2(2.25,2.25),Vector2(6.25,2.25)))
	maid=actor(1000,Vector2(4.25,2.25),[],"idle")
	sim.agents={0:walker,1000:maid}
	var staff_yielded:=false
	for step in range(400):
		if walker.phase=="wander": sim._walk(walker,0.05)
		sim._advance_staff(maid,0.05)
		if Vector2(maid.position).distance_to(Vector2(4.25,2.25))>0.8: staff_yielded=true
	check(staff_yielded and walker.phase=="idle" and maid.phase=="idle","An idle housekeeper walks aside, clears the guest's doorway, and resumes work")
	# Full 24-cottage fixture: constricted doorways, eighteen simultaneous
	# arrivals, stationary counter staff and a moving housekeeper.
	model=empty_property()
	var data: Dictionary=model.hotel()
	data.plots=["west","east","north"]; data.maid=true
	for i in range(24):
		var x: int=-20+(i%6)*6; var y: int=-12+floori(i/6.0)*6
		var id: String="crowd-room-%d"%i
		data.rooms.append({"id":id,"kind":"regular","name":"Cottage","x":x,"y":y,"w":4,"h":3,"rotation":0,"paid":0})
		for piece in [["mat",0.5,0.5],["box",2.5,0.5],["plant",3.5,2.5],["lamp",0.5,2.5]]:
			data.objects.append({"id":id+"-"+str(piece[0]),"item":piece[0],"room":id,"x":x+piece[1],"y":y+piece[2],"rotation":0,"paid":0})
		data.dirty[id]=true
	data.rooms.append({"id":"crowd-lobby","kind":"shared","name":"Lobby","x":-10,"y":-19,"w":6,"h":6,"rotation":0,"paid":0})
	data.objects.append({"id":"crowd-reception","item":"reception_counter","room":"crowd-lobby","x":-9.5,"y":-18.5,"rotation":0,"paid":0})
	data.objects.append({"id":"crowd-sofa","item":"lounge_sofa","room":"crowd-lobby","x":-9.5,"y":-15.5,"rotation":0,"paid":0})
	for x in range(-20,20):
		for y in range(-20,12):
			if Geo.owns_rect(Rect2(x,y,1,1),model.map_definition(),data): data.paths["%d,%d"%[x,y]]={"style":"earth","paid":0}
	for cat in model.state.cats: cat.known=true
	model._invalidate()
	check(model.guest_capacity()==48,"Crowd fixture keeps every constructed cottage operational")
	nearest=INF
	var checked_in: Dictionary={}; var visited: Dictionary={}; var teleported:=false
	var previous_positions: Dictionary={}
	var started:=Time.get_ticks_usec()
	for step in range(6000):
		model.advance(0.1)
		var guests: Array=model.social.agents.values()
		for i in range(guests.size()):
			var guest: Dictionary=guests[i]
			if previous_positions.has(guest.cat) and Vector2(guest.position).distance_to(previous_positions[guest.cat])>0.136: teleported=true
			previous_positions[guest.cat]=guest.position
			if guest.get("checked_in",false): checked_in[guest.cat]=true
			if guest.get("completed",false): visited[guest.cat]=true
			for j in range(i+1,guests.size()): nearest=minf(nearest,Vector2(guest.position).distance_to(guests[j].position))
	check(nearest>=0.70,"Dense guests and stationary/moving staff retain physical separation (minimum %.3f)"%nearest)
	check(not teleported,"Crowd yielding never teleports or exceeds the walking speed")
	check(checked_in.size()==18 and visited.size()==18,"Every guest checks in and completes an activity despite doorway traffic (%d checked in, %d visited)"%[checked_in.size(),visited.size()])
	check(data.cleaned>0,"Crowd traffic lets housekeeping reach dirty rooms")
	print("CROWD MOVEMENT: %.2fms/tick, %d visits, %d rooms cleaned"%[(Time.get_ticks_usec()-started)/6000000.0,data.visits,data.cleaned])
	print("CREATIVE MOVEMENT: %d failures"%failures)
	quit(1 if failures else 0)
