extends SceneTree
## Decorative neighbors never claim editable land or join the hotel simulation.
const Maps = preload("res://scripts/creative/creative_maps.gd")
const Navigation = preload("res://scripts/world/cat_navigation.gd")
const Objects = preload("res://scripts/creative/creative_objects.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var native_geometry: bool = DisplayServer.get_name()!="headless"
	if not native_geometry: print("HEADLESS: authored bounds, trunk/body clearance, and movement checks run; actual MultiMesh route clearance requires the native rendered suite.")
	var script = load("res://scripts/creative/creative_neighborhood.gd")
	check(script != null,"A separate neighborhood module exists")
	if script == null:
		quit(1)
		return
	var neighborhood = script.new()
	root.add_child(neighborhood)
	neighborhood.set_process(false)
	for map_index in range(4):
		var definition: Dictionary = Maps.definition(map_index)
		neighborhood.configure(definition)
		check(neighborhood.pedestrians.size()==6,"Each neighborhood has six decorative walkers")
		var connected_homes: int = 0
		var meadow_front_homes: int = 0
		for home in definition.neighborhood.homes:
			if home.size()<4: continue
			connected_homes += 1
			var direction := Vector2(sin(float(home[2])),cos(float(home[2])))
			var to_street: Vector2 = (Vector2(home[3][0],home[3][1])-Vector2(home[0],home[1])).normalized()
			check(direction.dot(to_street)>0.99,"Connected neighbor front doors face their street")
			if definition.theme=="meadow" and absf(float(home[0]))<15 and float(home[1])>20 and float(home[1])<35: meadow_front_homes += 1
		check(connected_homes>=4,"Nearby homes have garden paths to their street")
		check(neighborhood.home_connections.size()==connected_homes,"Every authored gate-to-sidewalk link renders successfully")
		if definition.theme=="meadow": check(meadow_front_homes==2,"Two welcoming homes complete the opposite side of Meadow's road")
		var parcels: Array[Rect2] = [_rect(definition.base)]
		for parcel in definition.plots: parcels.append(_rect(parcel.rect))
		for bounds in neighborhood.scenery_bounds:
			for parcel in parcels: check(not bounds.intersects(parcel),"Neighborhood scenery leaves all purchasable parcels clear: "+definition.id)
		for route in neighborhood.routes:
			if native_geometry: check(not _route_hits_geometry(route,neighborhood.get_node("VillageScenery")),"New neighborhood scenery clears the entire pedestrian route")
			for sample in range(101):
				var point: Vector2 = route.start.lerp(route.finish,float(sample)/100.0)
				for parcel in parcels: check(not parcel.has_point(point) and not parcel.intersects(Rect2(point-Vector2.ONE*0.36,Vector2.ONE*0.72)),"The full pedestrian body stays off editable land")
		var house_bodies: Array[Rect2] = _house_bodies(definition.neighborhood.homes)
		check(house_bodies.size()==neighborhood.home_bounds.size(),"Every neighborhood home has one solid wall volume")
		for scenery in definition.scenery:
			if scenery.kind in ["sea","pond","stream","frozen_pond"]: continue
			var visual: Node3D = Objects.scenery(scenery.kind,float(scenery.size),Color(scenery.color),definition.theme=="snow")
			root.add_child(visual)
			visual.position = Vector3(float(scenery.x)*1.1,0.06,float(scenery.y)*1.1)
			if native_geometry:
				var route_clear: bool = true
				for route in neighborhood.routes:
					if _route_hits_geometry(route,visual): route_clear = false
				check(route_clear,"Retained "+definition.id+" "+scenery.kind+" at "+str(scenery.x)+","+str(scenery.y)+" clears all sidewalk cats")
			if scenery.kind in ["tree","pine","palm"]:
				var trunks_clear: bool = true
				# Use authored solid cube dimensions: Godot's headless renderer
				# returns identity for MultiMesh transforms. Crowns may frame roofs.
				var trunk: AABB = _trunk_bounds(scenery)
				for body in house_bodies:
					if body.intersects(Rect2(trunk.position.x,trunk.position.z,trunk.size.x,trunk.size.z)): trunks_clear = false
				check(trunks_clear,"Retained "+definition.id+" "+scenery.kind+" trunk at "+str(scenery.x)+","+str(scenery.y)+" stays outside neighboring house walls")
			visual.free()
		var initial: Array = []
		var initial_near_hotel: int = 0
		for pedestrian in neighborhood.pedestrians:
			initial.append(pedestrian.node.position)
			if absf(pedestrian.node.position.x)<12.0*1.1: initial_near_hotel += 1
			check(not pedestrian.node.is_in_group(Navigation.GROUP),"Sidewalk cats are excluded from gameplay navigation and population")
			check(not pedestrian.node.is_processing(),"Only the neighborhood clock drives decorative cats")
		check(initial_near_hotel>=2,"At least two sidewalk cats greet the opening view")
		if definition.theme=="meadow":
			var entrance_walker: bool = false
			for pedestrian in neighborhood.pedestrians:
				if Vector2(pedestrian.node.position.x,pedestrian.node.position.z).distance_to(Vector2(8,12.52)*1.1)<1.6: entrance_walker = true
			check(entrance_walker,"Meadow begins with a sidewalk cat visible beside the entrance on a narrow screen")
		var minimum_spacing: float = INF
		for step in range(1200):
			var before: Array = []
			for pedestrian in neighborhood.pedestrians: before.append(pedestrian.node.position)
			neighborhood.advance(0.25)
			for index in range(neighborhood.pedestrians.size()):
				var pedestrian: Dictionary = neighborhood.pedestrians[index]
				check(pedestrian.node.position.distance_to(before[index])<=pedestrian.speed*1.1*0.25+0.001,"Walking and endpoint turns never teleport")
				for other in range(index):
					minimum_spacing = minf(minimum_spacing,pedestrian.node.position.distance_to(neighborhood.pedestrians[other].node.position))
		check(minimum_spacing>0.9,"Pedestrians never overlap during five minutes of deterministic walking")
		check(neighborhood.pedestrians[1].node.position!=initial[1],"Pedestrians actually travel along sidewalks")
		neighborhood.set_motion_enabled(false)
		var stopped: Transform3D = neighborhood.pedestrians[1].node.transform
		var stopped_body: Transform3D = neighborhood.pedestrians[1].node.body.transform
		var stopped_phase: float = neighborhood.pedestrians[1].node.phase
		neighborhood.advance(50.0)
		check(neighborhood.pedestrians[1].node.transform==stopped and neighborhood.pedestrians[1].node.body.transform==stopped_body and neighborhood.pedestrians[1].node.phase==stopped_phase,"Reduced motion freezes movement and every ambient pose")
		neighborhood.set_motion_enabled(true)
		neighborhood.configure(definition)
		for index in range(initial.size()): check(neighborhood.pedestrians[index].node.position==initial[index],"Theme rebuilds reproduce the same authored starting positions")
		check(neighborhood.get_child_count()==2,"Theme rebuild replaces old scenery and old pedestrians")
		check(neighborhood.get_node("VillageScenery").find_children("*","MultiMeshInstance3D",true,false).size()<40,"All static neighborhood cubes share fewer than forty material batches")
		for batch in neighborhood.find_children("*","MultiMeshInstance3D",true,false): check(batch.multimesh.mesh is BoxMesh,"Neighborhood details use actual voxel cubes")
		for mesh in neighborhood.find_children("*","MeshInstance3D",true,false):
			check(mesh.mesh is BoxMesh or mesh.mesh is PlaneMesh,"Cat details are cubes with a contact shadow plane")
		if definition.theme=="coast":
			for bounds in neighborhood.scenery_bounds: check(bounds.end.x<22.2 and bounds.position.y> -22.2,"Coastal neighbors remain on land and leave the ocean open")
		for scene in definition.scenery:
			if not scene.kind in ["stream","pond","frozen_pond"]: continue
			var water: Rect2
			if scene.kind=="stream": water = Rect2(Vector2(scene.x-scene.size*2.02/1.1,scene.y-scene.size*0.28/1.1),Vector2(scene.size*4.04/1.1,scene.size*0.71/1.1))
			else: water = Rect2(Vector2(scene.x-scene.size*0.57/1.1,scene.y-scene.size*0.4/1.1),Vector2(scene.size*1.14/1.1,scene.size*0.8/1.1))
			for home in neighborhood.home_bounds: check(not home.intersects(water),"Neighbor homes preserve the scenic water")
			for path in neighborhood.home_connections: check(not path.intersects(water),"Garden paths preserve the scenic water")
		var batch_count: int = neighborhood.get_node("VillageScenery").find_children("*","MultiMeshInstance3D",true,false).size()
		var cube_count: int = 0
		for batch in neighborhood.get_node("VillageScenery").find_children("*","MultiMeshInstance3D",true,false): cube_count += batch.multimesh.instance_count
		print("NEIGHBORHOOD ",definition.id,": ",neighborhood.home_bounds.size()," homes; ",connected_homes," garden links; ",neighborhood.pedestrians.size()," walkers; ",batch_count," static batches; ",cube_count," cubes")
	# Endpoint pauses and turns consume elapsed time deterministically.
	neighborhood.configure(Maps.definition(0))
	neighborhood.advance(155.0)
	var large_step: Array = []
	for pedestrian in neighborhood.pedestrians: large_step.append(pedestrian.node.position)
	neighborhood.configure(Maps.definition(0))
	for step in range(620): neighborhood.advance(0.25)
	for index in range(large_step.size()): check(neighborhood.pedestrians[index].node.position.distance_to(large_step[index])<0.001,"One large advance matches many small advances through several turns")
	neighborhood.free()
	print("CREATIVE NEIGHBORHOOD: %d failures" % failures)
	quit(1 if failures else 0)

func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))

func _route_hits_geometry(route: Dictionary,geometry: Node3D) -> bool:
	var start: Vector2 = route.start*1.1
	var finish: Vector2 = route.finish*1.1
	var swept_body := Rect2(start,finish-start).abs().grow(0.36*1.1)
	for batch in geometry.find_children("*","MultiMeshInstance3D",true,false):
		for index in range(batch.multimesh.instance_count):
			var transform: Transform3D = batch.global_transform*batch.multimesh.get_instance_transform(index)
			var bounds: AABB = transform*AABB(-Vector3.ONE*0.5,Vector3.ONE)
			# Ground, paving, and high tree crowns do not obstruct a walking cat.
			if bounds.end.y<=0.23 or bounds.position.y>=1.4: continue
			if swept_body.intersects(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)): return true
	return false

func _house_bodies(homes: Array) -> Array[Rect2]:
	var bodies: Array[Rect2] = []
	for home in homes:
		var transform := Transform3D(Basis.from_euler(Vector3(0,float(home[2]),0)).scaled(Vector3.ONE*1.1),Vector3(float(home[0])*1.1,0.077,float(home[1])*1.1))
		var bounds: AABB = transform*AABB(Vector3(-3.2,0.4,-3.5),Vector3(6.4,3.3,5.6))
		bodies.append(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z))
	return bodies

func _trunk_bounds(scenery: Dictionary) -> AABB:
	var size: float = float(scenery.size)
	var palm: bool = scenery.kind=="palm"
	var position := Vector3(float(scenery.x)*1.1,0.06+size*(0.85 if palm else 0.68),float(scenery.y)*1.1)
	var dimensions := Vector3(size*(0.18 if palm else 0.17),size*(1.7 if palm else 1.35),size*(0.18 if palm else 0.17))
	var basis := Basis.from_euler(Vector3(0,0,-0.10 if palm else 0.0))
	return Transform3D(basis,position)*AABB(-dimensions*0.5,dimensions)
