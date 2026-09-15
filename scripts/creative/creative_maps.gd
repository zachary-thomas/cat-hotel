extends RefCounted
## Authored, editable starter properties. Background scenery stays beyond purchasable land.
## x/y are lot coordinates; the world renderer applies the 1.1 scale exactly once.

const Content = preload("res://scripts/creative/creative_content.gd")

static func definition(index: int) -> Dictionary:
	match index:
		0: return _meadow()
		1: return _coast()
		2: return _forest()
		3: return _snow()
	return {}

static func _property(id: String, name: String, theme: String, ground: String, accent: String, base: Array, arrival: Array, parcel_names: Array) -> Dictionary:
	var x: int = base[0]
	var y: int = base[1]
	var w: int = base[2]
	var h: int = base[3]
	return {"id":id,"name":name,"theme":theme,"ground":ground,"accent":accent,"arrival":arrival,"base":base,
		"plots":[
			{"id":"west","name":parcel_names[0],"cost":750,"rect":[x-8,y,8,h]},
			{"id":"east","name":parcel_names[1],"cost":750,"rect":[x+w,y,8,h]},
			{"id":"north","name":parcel_names[2],"cost":1000,"rect":[x,y-8,w,8]}],
		"rooms":[],"objects":[],"paths":[],"scenery":[]}

static func _room(map: Dictionary, id: String, kind: String, name: String, x: int, y: int, w: int, h: int) -> void:
	map.rooms.append({"id":id,"kind":kind,"name":name,"x":x,"y":y,"w":w,"h":h,"rotation":0,"paid":0})

static func _object(map: Dictionary, id: String, item_id: String, room_id: String, x: float, y: float, rotation: int = 0) -> void:
	map.objects.append({"id":id,"item":item_id,"room":room_id,"x":x,"y":y,"rotation":rotation,"paid":0})

static func _guest(map: Dictionary, id: String, name: String, x: int, y: int, bed: String, toy: String = "box") -> void:
	_room(map,id,"regular",name,x,y,6,6)
	_object(map,id+"_bed",bed,id,x+0.5,y+0.5)
	_object(map,id+"_toy",toy,id,x+3.5,y+0.5)
	_object(map,id+"_plant","plant",id,x+0.5,y+4.5)

static func _venue(map: Dictionary, id: String, name: String, template_id: String, x: int, y: int) -> void:
	var arrangement: Dictionary = Content.template(template_id)
	_room(map,id,arrangement.kind,name,x,y,arrangement.w,arrangement.h)
	for i in range(arrangement.objects.size()):
		var object: Dictionary = arrangement.objects[i]
		_object(map,id+"_piece_%d" % i,object.item,id,x+float(object.x),y+float(object.y),int(object.rotation))

static func _paths(map: Dictionary, strips: Array, style: String) -> void:
	var unique := {}
	for strip in strips:
		for x in range(strip[0],strip[0]+strip[2]):
			for y in range(strip[1],strip[1]+strip[3]):
				var key := "%d,%d" % [x,y]
				if unique.has(key): continue
				unique[key] = true
				map.paths.append({"x":x,"y":y,"style":style,"paid":0})

static func _scenery(map: Dictionary, entries: Array) -> void:
	for entry in entries:
		map.scenery.append({"kind":entry[0],"x":entry[1],"y":entry[2],"size":entry[3],"color":entry[4]})

static func _meadow() -> Dictionary:
	var map := _property("meadow","Meadow House","meadow","9fbe83","e5b48b",[-12,-12,24,24],[10.5,10.5],["Orchard plot","Wildflower plot","Meadow rise"])
	_guest(map,"guest_1","Clover Cottage",-10,-10,"mat")
	_guest(map,"guest_2","Daisy Cottage",-10,-2,"mat")
	_venue(map,"lobby","The Garden Welcome","lobby",-1,3)
	_venue(map,"sunroom","Sunbeam Conservatory","sunroom",2,-10)
	_paths(map,[[-4,-8,2,20],[10,-8,2,20],[-4,-3,16,2],[-4,10,16,2],[5,5,7,2]],"earth")
	_object(map,"garden_fountain","fountain","",0,-0.5)
	_object(map,"garden_bench","bench","",7,-1)
	_object(map,"garden_shade","tree","",-10,7)
	_object(map,"garden_border","flower_bed","",-10,5)
	_object(map,"garden_planter","garden_planter","",-6.5,7)
	_object(map,"garden_light","garden_lamp","",8,8.5)
	_scenery(map,[
		["house",-24,-12,3.5,"e8c2a1"],["house",23,-15,3.0,"d7b9bb"],
		["tree",-24,-4,2.5,"88ac75"],["tree",-23,5,2.8,"789c68"],
		["tree",24,2,3.2,"83ad78"],["tree",18,-24,2.7,"9bbf7b"],
		["pond",-6,-26,4.0,"a4cacf"],["shrub",4,-24,2.0,"92b57b"],
		["flowers",-17,16,2.2,"e3b3ba"],["flowers",20,16,2.0,"edca82"],
		["rock",-22,12,1.3,"b9b7a6"],["flowers",1,-22,2.0,"dba3bd"]])
	return map

static func _coast() -> Dictionary:
	var map := _property("seaside","Seaside Suites","coast","e6d0a0","82c4cc",[-14,-10,28,20],[2.5,9.5],["Dune garden","Beachfront plot","Harbor overlook"])
	_guest(map,"guest_1","Shell Cottage",-12,-8,"sun_cushion","perch")
	_guest(map,"guest_2","Sea Glass Cottage",-4,-8,"mat","box")
	_venue(map,"lobby","Harbor Welcome","lobby",-12,1)
	_venue(map,"terrace","Sea Breeze Milkshake Deck","terrace",4,1)
	_paths(map,[[-6,-6,2,16],[2,-6,2,16],[12,-1,2,11],[-6,-1,20,2],[-6,8,20,2]],"brick")
	_object(map,"coast_pool","pool","",4,-7)
	_object(map,"coast_bench","bench","",9,-2)
	_object(map,"coast_flowers","flower_bed","",8,-3)
	_object(map,"coast_planter","garden_planter","",-3,2)
	_object(map,"coast_courtyard_seat","bench","",0,4)
	_object(map,"coast_light","garden_lamp","",0,6.5)
	_scenery(map,[
		["sea",29,0,13.0,"79b6c9"],["sea",7,-28,10.0,"8ec2cd"],
		["palm",-25,-7,3.0,"78a891"],["palm",-24,4,2.6,"87b28b"],
		["palm",-15,-22,2.7,"81ab8b"],["dune",-26,11,3.0,"e6c797"],
		["dune",-5,15,3.3,"ecd6ab"],["rock",23,-15,1.8,"bbbcae"],
		["boat",28,5,2.4,"db9b89"],["buoy",25,-6,1.0,"e6a58e"],
		["rock",21,14,1.4,"c9c6b4"],["flowers",-19,-21,1.5,"e8c9b1"]])
	return map

static func _forest() -> Dictionary:
	var map := _property("forest","Forest Lodge","forest","829b6f","bd936f",[-12,-14,24,28],[-3.5,12.5],["Fern hollow","Pine grove","Woodland ridge"])
	_guest(map,"guest_1","Fern Cabin",-10,-12,"cave","tower")
	_guest(map,"guest_2","Acorn Cabin",2,-12,"mat","perch")
	_venue(map,"lobby","Trailhead Welcome","lobby",-10,4)
	_venue(map,"playroom","Treetop Adventure Club","play",0,-2)
	_paths(map,[[-4,-10,2,24],[8,-10,2,24],[-4,-5,14,2],[-4,11,14,2]],"gravel")
	_object(map,"forest_picnic","picnic","",0,8)
	_object(map,"forest_tree","tree","",-10,-3)
	_object(map,"forest_playpen","playpen","",-7,0)
	_object(map,"forest_shrub","shrub","",5,7)
	_object(map,"forest_lantern","garden_lamp","",6,10)
	_object(map,"forest_statue","cat_statue","",-1,-9)
	_scenery(map,[
		["pine",-24,-10,3.7,"496d55"],["pine",-23,1,3.4,"668461"],
		["pine",23,-11,3.8,"52775b"],["pine",23,5,3.1,"5b7a58"],
		["pine",-8,-27,3.3,"72906c"],["pine",6,-27,4.0,"547553"],
		["stream",-2,19,7.0,"86adad"],["log",-18,18,2.8,"876952"],
		["mushroom",-23,9,1.4,"c39583"],["mushroom",18,18,1.8,"d0b286"],
		["rock",16,-26,2.7,"a0a48e"],["rock",-19,-25,2.1,"a8aa96"]])
	return map

static func _snow() -> Dictionary:
	var map := _property("snowcap","Snowcap Spa","snow","d7e4e2","a9bccd",[-14,-12,28,24],[10.5,11.5],["Snowdrop garden","Sunlit slope","Alpine lookout"])
	_guest(map,"guest_1","Snowdrop Chalet",-12,-10,"heated","perch")
	_guest(map,"guest_2","Juniper Chalet",-12,-2,"cave","box")
	_venue(map,"lobby","Alpine Welcome","lobby",0,4)
	_venue(map,"lounge","The Hearth Room","lounge",2,-10)
	_paths(map,[[-6,-8,2,20],[10,-8,2,20],[-6,-3,18,2],[-6,10,18,2],[6,6,6,2]],"brick")
	_object(map,"snow_hearth","fireplace","",-1,-1)
	_object(map,"snow_bench","bench","",3,-1)
	_object(map,"snow_sculpture","cat_statue","",-10,6)
	_object(map,"snow_planter","garden_planter","",-7.5,8)
	_object(map,"snow_lantern","garden_lamp","",8,9)
	_object(map,"snow_shrub","shrub","",7,3)
	_scenery(map,[
		["mountain",-5,-30,9.0,"b8c8d0"],["mountain",19,-28,7.0,"c2d1d5"],
		["mountain",-24,-25,7.0,"aebbcb"],["pine",-26,-8,3.7,"849f95"],
		["pine",-25,4,3.5,"75978e"],["pine",26,-7,4.0,"90aaa0"],
		["pine",25,6,3.0,"76948e"],["frozen_pond",-4,18,5.0,"b7d3dc"],
		["snowdrift",-19,17,3.0,"e4eeeb"],["snowdrift",20,17,3.5,"e7efed"],
		["rock",-25,12,1.8,"afbfc7"],["rock",25,12,1.5,"bdcbd0"]])
	return map
