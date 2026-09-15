extends Node3D
## The inhabited village is decoration, independent of hotel edits and simulation.
## Authored routes and scenery footprints are lot cells; UNIT is applied once.
const UNIT: float = 1.1
const Objects = preload("res://scripts/creative/creative_objects.gd")
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Navigation = preload("res://scripts/world/cat_navigation.gd")
var pedestrians: Array = []
var routes: Array = []
var scenery_bounds: Array[Rect2] = []
var home_bounds: Array[Rect2] = []
var home_connections: Array[Rect2] = []
var motion_enabled: bool = true
var theme: String = "meadow"
var _scenery: Node3D
var _walkers: Node3D
var _parcels: Array[Rect2] = []

func configure(definition: Dictionary) -> void:
	for child in get_children(): child.free()
	pedestrians.clear()
	routes.clear()
	scenery_bounds.clear()
	home_bounds.clear()
	home_connections.clear()
	_parcels.clear()
	theme = String(definition.get("theme","meadow"))
	_parcels.append(_rect(definition.get("base",[-12,-12,24,24])))
	for parcel in definition.get("plots",[]): _parcels.append(_rect(parcel.rect))
	_scenery = Node3D.new()
	_scenery.name = "VillageScenery"
	_scenery.scale = Vector3.ONE*UNIT
	add_child(_scenery)
	_walkers = Node3D.new()
	_walkers.name = "SidewalkCats"
	add_child(_walkers)
	var data: Dictionary = definition.get("neighborhood",{})
	for values in data.get("streets",[]): _street(_rect(values))
	for values in data.get("walkways",[]):
		var bounds := _rect(values)
		if _reserve(bounds): _pavement(bounds,theme=="coast")
	for index in range(data.get("homes",[]).size()):
		var home: Array = data.homes[index]
		var heading: float = float(home[2])
		var center := Vector2(home[0],home[1])
		var breadth: float = absf(cos(heading))*9.8+absf(sin(heading))*11.0
		var depth: float = absf(sin(heading))*9.8+absf(cos(heading))*11.0
		var size := Vector2(breadth,depth)
		var bounds := Rect2(center-size*0.5,size)
		if not _reserve(bounds): continue
		home_bounds.append(bounds)
		_house(center,heading,index)
		if home.size()>3: _connect_home(center,heading,Vector2(home[3][0],home[3][1]))
	for tree in data.get("trees",[]):
		var size: float = float(tree[2])
		var center := Vector2(tree[0],tree[1])
		if _reserve(Rect2(center-Vector2.ONE*size*0.72,Vector2.ONE*size*1.44)):
			_tree(center,size)
	_merge_scenery_parts()
	Objects.flush(_scenery)
	for lane in range(data.get("lanes",[]).size()):
		for segment in range(data.get("segments",[]).size()):
			var ends: Array = data.segments[segment]
			var start := Vector2(float(ends[0]),float(data.lanes[lane]))
			var finish := Vector2(float(ends[1]),start.y)
			var route: Dictionary = {"start":start,"finish":finish,"length":start.distance_to(finish)}
			routes.append(route)
			_walker(route,lane*3+segment,lane)
	set_motion_enabled(motion_enabled)

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	for pedestrian in pedestrians: pedestrian.node.motion_enabled = enabled

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not motion_enabled or delta<=0.0: return
	for pedestrian in pedestrians:
		var remaining: float = delta
		# Travel and turning consume their own portions of the same clock, even
		# for a large deterministic time step. There is no wrap or teleport.
		while remaining>0.00001:
			var step: float
			var cat = pedestrian.node
			if float(pedestrian.turn_left)>0.00001:
				step = minf(remaining,float(pedestrian.turn_left))
				pedestrian.turn_left = maxf(0.0,float(pedestrian.turn_left)-step)
				var t: float = 1.0-float(pedestrian.turn_left)/1.6
				cat.rotation.y = float(pedestrian.turn_from)+PI*smoothstep(0.0,1.0,t)
				cat.moving = false
				cat.action = "sniff"
			else:
				var distance: float = float(pedestrian.distance)
				var length: float = float(pedestrian.route.length)
				var to_end: float = length-distance if pedestrian.direction>0 else distance
				step = minf(remaining,to_end/float(pedestrian.speed))
				pedestrian.distance = clampf(distance+float(pedestrian.direction)*float(pedestrian.speed)*step,0.0,length)
				cat.position = _point(pedestrian)
				cat.rotation.y = PI*0.5 if pedestrian.direction>0 else -PI*0.5
				cat.moving = true
				cat.action = "walk"
				if step>=to_end/float(pedestrian.speed)-0.00001:
					pedestrian.direction = -int(pedestrian.direction)
					pedestrian.turn_from = cat.rotation.y
					pedestrian.turn_left = 1.6
			cat._process(step)
			remaining -= step

func _point(pedestrian: Dictionary) -> Vector3:
	var point: Vector2 = pedestrian.route.start.lerp(pedestrian.route.finish,float(pedestrian.distance)/float(pedestrian.route.length))
	return Vector3(point.x*UNIT,0.175,point.y*UNIT)

func _walker(route: Dictionary,index: int,lane: int) -> void:
	var cat = Cat.new()
	cat.name = "NeighborCat%d" % (index+1)
	cat.set_meta("cat_index",index+30)
	_walkers.add_child(cat)
	cat.build(Color(["d9ad7c","999c9b","eee0c1","b58a79","b8bc9f","d5b2a1"][index]))
	cat.remove_from_group(Navigation.GROUP)
	cat.set_process(false)
	cat.scale = Vector3.ONE*0.80*UNIT
	# Hotel-only props have no role here. Batch static face/body parts while
	# preserving the eyes, ears, mouth and leg joints that animate directly.
	for prop in cat.props.values(): prop.free()
	cat.props.clear()
	var animated: Array = cat.eyes+cat.ears+[cat.mouth]
	_batch_cat(cat,animated)
	Objects.flush(cat)
	var ratio: float = [0.47,0.28,0.36,0.58,0.76,0.65][index]
	if theme=="meadow" and index==1: ratio = 0.80
	if theme=="meadow" and index==4: ratio = 0.24
	var pedestrian: Dictionary = {"node":cat,"route":route,"distance":float(route.length)*ratio,"speed":0.52+float(index%3)*0.025,"direction":1 if lane==0 else -1,"turn_left":0.0,"turn_from":0.0}
	cat.position = _point(pedestrian)
	cat.rotation.y = PI*0.5 if lane==0 else -PI*0.5
	cat.moving = true
	cat.action = "walk"
	cat.motion_enabled = true
	cat._process(0.0)
	pedestrians.append(pedestrian)

func _batch_cat(parent: Node3D,animated: Array) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and not animated.has(child):
			var color: Color = child.material_override.get_shader_parameter("tint")
			Objects.box(parent,child.position,child.scale,color,child.rotation)
			child.free()
		elif child is Node3D: _batch_cat(child,animated)

func _merge_scenery_parts() -> void:
	# Neighbor homes do not move or need individual editing. Their cubes can
	# share one material batch across the entire neighborhood, including roofs.
	var combined: Dictionary = _scenery.get_meta("voxel_parts",{})
	for home in _scenery.get_children():
		var parts: Dictionary = home.get_meta("voxel_parts",{})
		for color in parts:
			if not combined.has(color): combined[color] = []
			for part in parts[color]: combined[color].append(home.transform*part)
		if home.has_meta("voxel_parts"): home.remove_meta("voxel_parts")
	_scenery.set_meta("voxel_parts",combined)

func _reserve(bounds: Rect2) -> bool:
	for parcel in _parcels:
		if bounds.intersects(parcel): return false
	# Continuous ocean surfaces begin at these shoreline coordinates.
	if theme=="coast" and (bounds.end.x>=22.2 or bounds.position.y<=-22.2): return false
	scenery_bounds.append(bounds)
	return true

func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))

func _pavement(bounds: Rect2,wooden: bool = false) -> void:
	var center: Vector2 = bounds.get_center()
	var color := Color("c7b79a") if wooden else Color("d6cdb5")
	Objects.box(_scenery,Vector3(center.x,0.075,center.y),Vector3(bounds.size.x,0.15,bounds.size.y),color)
	# Long runs share a material batch, including the very small joint lines.
	if bounds.size.x>bounds.size.y:
		for x in range(int(bounds.position.x),int(bounds.end.x)):
			Objects.box(_scenery,Vector3(x,0.155,center.y),Vector3(0.022,0.008,bounds.size.y-0.04),color.darkened(0.12))
	else:
		for y in range(int(bounds.position.y),int(bounds.end.y)):
			Objects.box(_scenery,Vector3(center.x,0.155,y),Vector3(bounds.size.x-0.04,0.008,0.022),color.darkened(0.12))

func _street(bounds: Rect2) -> void:
	if not _reserve(bounds.grow(1.0)): return
	var center: Vector2 = bounds.get_center()
	Objects.box(_scenery,Vector3(center.x,0.015,center.y),Vector3(bounds.size.x,0.10,bounds.size.y),Color("8e9987") if theme=="forest" else Color("8b9491"))
	for side in [-1,1]:
		_pavement(Rect2(center.x+side*(bounds.size.x*0.5+0.50)-0.44,bounds.position.y,0.88,bounds.size.y))
		Objects.box(_scenery,Vector3(center.x+side*(bounds.size.x*0.5+0.035),0.11,center.y),Vector3(0.10,0.19,bounds.size.y),Color("e7dbc5"))
	for y in range(int(bounds.position.y)+1,int(bounds.end.y),3):
		Objects.box(_scenery,Vector3(center.x,0.069,y),Vector3(0.07,0.012,1.1),Color("ddd5b9"))

func _connect_home(center: Vector2,heading: float,sidewalk: Vector2) -> void:
	var gate: Vector2 = center+Vector2(sin(heading),cos(heading))*4.77
	var bounds: Rect2
	if absf(gate.x-sidewalk.x)>absf(gate.y-sidewalk.y):
		bounds = Rect2(minf(gate.x,sidewalk.x),gate.y-0.76,absf(gate.x-sidewalk.x),1.52)
	else:
		bounds = Rect2(gate.x-0.76,minf(gate.y,sidewalk.y),1.52,absf(gate.y-sidewalk.y))
	if not _reserve(bounds): return
	home_connections.append(bounds)
	_pavement(bounds,theme=="coast")

func _house(center: Vector2,heading: float,index: int) -> void:
	var house := Node3D.new()
	house.name = "NeighborHome%d" % index
	house.position = Vector3(center.x,0.07,center.y)
	house.rotation.y = heading
	_scenery.add_child(house)
	var cream := Color("f2e4ca")
	var wall: Color = Color(["e0bfac","c9cfb7","d5bec4","cfceb5"][index%4])
	var roof: Color = Color(["aa897c","879b8e","ae9893","929e9a"][index%4])
	if theme=="forest": wall = Color(["b59c78","bea886","a6a185","c4b491"][index%4]); roof = Color("768774")
	if theme=="coast": wall = Color(["d5d6c1","bed1ce","dbbeb3","d7cfb8"][index%4]); roof = Color("87a5a4")
	if theme=="snow": wall = Color(["b8a5a2","bdc6c5","b7bcb0","c4b3a4"][index%4]); roof = Color("e8eddf")
	var wood := Color("a68869")
	Objects.box(house,Vector3(0,0.11,0),Vector3(9.3,0.18,10.7),Color("dce3d6") if theme=="snow" else Color("a9b68c"))
	Objects.box(house,Vector3(0,0.235,4.44),Vector3(1.58,0.065,1.85),cream)
	Objects.box(house,Vector3(0,0.35,-0.7),Vector3(6.8,0.55,5.9),Color("c9bca3"))
	Objects.box(house,Vector3(0,2.05,-0.7),Vector3(6.4,3.3,5.6),wall)
	for level in range(7):
		Objects.box(house,Vector3(0,3.77+level*0.24,-0.7),Vector3(7.15-level*0.88,0.29,6.25),roof)
	# Twin stepped ears and an inset dormer make the house silhouette feline.
	for side in [-1,1]:
		for level in range(3):
			Objects.box(house,Vector3(side*(2.18+level*0.12),4.35+level*0.29,1.7),Vector3(1.2-level*0.28,0.33,0.75-level*0.08),roof)
		Objects.box(house,Vector3(side*2.3,4.51,2.095),Vector3(0.46,0.37,0.035),wall)
		Objects.box(house,Vector3(side*3.07,2.05,2.14),Vector3(0.18,3.18,0.15),cream)
		_window(house,Vector3(side*1.93,2.30,2.135),cream)
		Objects.box(house,Vector3(side*1.93,1.48,2.37),Vector3(1.51,0.31,0.46),wood)
		for flower in range(5): _flower(house,Vector3(side*1.93-0.55+flower*0.27,1.66,2.4),Color("dba5b0") if index%2==0 else Color("e7c97c"),0.33)
		# Rear gardens and side streets reveal all four walls of each home.
		_window(house,Vector3(side*1.73,2.30,-3.535),cream,PI)
		_window(house,Vector3(side*3.235,2.30,-0.7),cream,side*PI*0.5)
		Objects.box(house,Vector3(side*1.73,1.48,-3.77),Vector3(1.51,0.31,0.46),wood)
		for flower in range(5): _flower(house,Vector3(side*1.73-0.55+flower*0.27,1.66,-3.8),Color("dba5b0") if index%2==0 else Color("e7c97c"),0.33)
	Objects.box(house,Vector3(0,4.13,2.19),Vector3(1.30,0.91,0.36),cream)
	Objects.box(house,Vector3(0,4.13,2.39),Vector3(0.95,0.63,0.035),Color("9cb8b0"))
	Objects.box(house,Vector3(0,4.13,2.42),Vector3(0.09,0.67,0.04),cream)
	Objects.box(house,Vector3(0,4.13,2.43),Vector3(0.98,0.07,0.04),cream)
	Objects.box(house,Vector3(0,1.48,2.18),Vector3(1.25,2.16,0.16),wood)
	Objects.box(house,Vector3(0,1.90,2.28),Vector3(0.65,0.80,0.07),Color("9cafac"))
	Objects.box(house,Vector3(0.38,1.28,2.30),Vector3(0.1,0.1,0.09),Color("ddbd78"))
	# Porch boards, railings, lamp, door awning and front gate.
	for step in range(3): Objects.box(house,Vector3(0,0.14+step*0.13,3.70-step*0.34),Vector3(2.2,0.18,0.62),cream)
	Objects.box(house,Vector3(0,0.50,2.77),Vector3(2.7,0.20,1.35),wood)
	Objects.box(house,Vector3(0,3.08,2.73),Vector3(2.8,0.19,1.5),roof)
	for side in [-1,1]:
		Objects.box(house,Vector3(side*1.22,1.78,3.28),Vector3(0.13,2.60,0.13),cream)
		Objects.box(house,Vector3(side*1.22,0.96,2.79),Vector3(0.09,0.1,0.90),cream)
		Objects.box(house,Vector3(side*1.22,1.38,2.79),Vector3(0.09,0.1,0.90),cream)
	Objects.box(house,Vector3(0.93,2.36,2.42),Vector3(0.25,0.38,0.26),Color("e7cc91"))
	Objects.box(house,Vector3(0.93,2.58,2.42),Vector3(0.32,0.07,0.32),wood)
	Objects.box(house,Vector3(-2.03,4.86,-1.71),Vector3(0.76,1.8,0.84),Color("b69989"))
	Objects.box(house,Vector3(-2.03,5.80,-1.71),Vector3(0.97,0.18,1.0),cream)
	Objects.box(house,Vector3(-2.03,5.91,-1.71),Vector3(0.60,0.03,0.63),Color("817d70"))
	for side in [-1,1]:
		for picket in range(5):
			var x: float = side*(1.68+picket*0.64)
			Objects.box(house,Vector3(x,0.62,4.77),Vector3(0.15,0.93,0.15),cream)
			Objects.box(house,Vector3(x,1.12,4.77),Vector3(0.21,0.13,0.21),cream)
		for y in [0.39,0.84]: Objects.box(house,Vector3(side*2.97,y,4.77),Vector3(2.82,0.10,0.09),cream)
		for flower in range(6): _flower(house,Vector3(side*(2.0+float(flower%3)*0.67),0.2,3.05+float(flower/3)*0.58),Color("d7a4ba") if index%2 else Color("e0c787"),0.42)
	Objects.box(house,Vector3(1.25,0.65,4.35),Vector3(0.12,1.14,0.12),wood)
	Objects.box(house,Vector3(1.25,1.21,4.35),Vector3(0.52,0.39,0.61),roof)
	Objects.box(house,Vector3(1.25,1.23,4.67),Vector3(0.38,0.055,0.025),cream)
	Objects.box(house,Vector3(1.57,1.45,4.31),Vector3(0.07,0.45,0.06),wood)
	Objects.box(house,Vector3(1.70,1.64,4.31),Vector3(0.22,0.11,0.065),Color("d4a692"))

func _window(parent: Node3D,point: Vector3,trim: Color,heading: float = 0.0) -> void:
	var frame := Node3D.new()
	Objects.box(frame,Vector3.ZERO,Vector3(1.45,1.48,0.14),trim)
	Objects.box(frame,Vector3(0,0,0.09),Vector3(1.14,1.17,0.065),Color("9eb9b1"))
	Objects.box(frame,Vector3(0,0,0.14),Vector3(0.09,1.21,0.05),trim)
	Objects.box(frame,Vector3(0,0,0.15),Vector3(1.19,0.09,0.05),trim)
	for side in [-1,1]: Objects.box(frame,Vector3(side*0.93,0,0.025),Vector3(0.31,1.50,0.10),Color("a6b19a"))
	# Rotate a complete local frame, then retain the shared house batches.
	var transform := Transform3D(Basis.from_euler(Vector3(0,heading,0)),point)
	var combined: Dictionary = parent.get_meta("voxel_parts",{})
	var parts: Dictionary = frame.get_meta("voxel_parts",{})
	for color in parts:
		if not combined.has(color): combined[color] = []
		for part in parts[color]: combined[color].append(transform*part)
	parent.set_meta("voxel_parts",combined)
	frame.free()

func _flower(parent: Node3D,point: Vector3,color: Color,size: float) -> void:
	Objects.box(parent,point+Vector3(0,size*0.4,0),Vector3(0.045,size*0.8,0.045),Color("718e69"))
	Objects.box(parent,point+Vector3(0,size*0.87,0),Vector3(size*0.62,size*0.28,size*0.61),color)
	Objects.box(parent,point+Vector3(0,size*1.04,0),Vector3(size*0.22,size*0.13,size*0.21),Color("e8d19a"))

func _tree(point: Vector2,size: float) -> void:
	var color := Color("8b9f78") if theme=="meadow" else Color("6f8a75")
	if theme=="coast": color = Color("8aaa8c")
	if theme=="snow": color = Color("95aea0")
	Objects.box(_scenery,Vector3(point.x,size*0.69,point.y),Vector3(size*0.17,size*1.39,size*0.17),Color("a28b6c"))
	if theme in ["snow","forest"]:
		for level in range(4):
			var width: float = size*(1.35-level*0.28)
			Objects.box(_scenery,Vector3(point.x,size*(0.88+level*0.37),point.y),Vector3(width,size*0.39,width),color)
			if theme=="snow": Objects.box(_scenery,Vector3(point.x,size*(1.085+level*0.37),point.y),Vector3(width*0.91,size*0.055,width*0.91),Color("e7ecde"))
	else:
		Objects.box(_scenery,Vector3(point.x,size*1.26,point.y),Vector3(size*1.38,size*0.66,size*1.32),color)
		Objects.box(_scenery,Vector3(point.x-size*0.12,size*1.82,point.y),Vector3(size*0.99,size*0.62,size*0.99),color.lightened(0.05))
		Objects.box(_scenery,Vector3(point.x+size*0.30,size*1.53,point.y-size*0.15),Vector3(size*0.72,size*0.55,size*0.80),color.lightened(0.08))
