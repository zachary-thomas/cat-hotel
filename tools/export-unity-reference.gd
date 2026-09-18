extends SceneTree
## Export authored content and native voxel transforms without touching Godot saves.
const Content=preload("res://scripts/creative/creative_content.gd")
const Maps=preload("res://scripts/creative/creative_maps.gd")
const Legacy=preload("res://scripts/core/game_content.gd")
const Model=preload("res://scripts/creative/creative_model.gd")
const Objects=preload("res://scripts/creative/creative_objects.gd")
const Cat=preload("res://scripts/world/voxel_cat.gd")
const World=preload("res://scripts/creative/creative_world.gd")
const Care=preload("res://scripts/creative/creative_care_room.gd")
const Dialogue=preload("res://scripts/creative/creative_dialogue.gd")
var bindings: Dictionary={}
var output="res://unity/PurringtonHotel/Assets/Resources/Content"
var cube_count=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var model=Model.new();model.new_game(0)
	var manifest={"schema":2,"maps":[],"items":Content.items(),"templates":Content.templates(),"cats":[],"services":[],"staff":Legacy.STAFF,"starter":model.serialize(),"combos":Legacy.COMBOS,"products":Legacy.PRODUCTS,"legacyFurniture":Legacy.FURNITURE,"preferenceCopy":Legacy.PREFERENCE_COPY}
	for i in range(4):
		manifest.maps.append(Maps.definition(i))
		manifest.services.append({"id":i,"name":["Rooms & housekeeping","Kitchen & milkshakes","Lounge & play","Reception & arrivals"][i]})
	for i in range(18):manifest.cats.append({"id":i,"name":Legacy.CAT_NAMES[i],"preference":Legacy.PREFERENCES[i],"favoriteAction":Legacy.FAVORITE_ACTIONS[i],"color":Legacy.COATS[i],"traits":Legacy.CAT_TRAITS[i]})
	var source_hashes={}
	for directory in ["res://scripts/creative","res://scripts/world","res://scripts/core","res://scripts/audio"]:
		for name in DirAccess.get_files_at(directory):
			if name.ends_with(".gd"):source_hashes[directory+"/"+name]=FileAccess.get_sha256(directory+"/"+name)
	manifest.sourceHashes=source_hashes
	manifest.dialogue=Dialogue.EXCHANGES
	_write("GodotReference.json",_clean(manifest))
	var recipes={"schema":2,"items":[],"cats":[],"staff":[],"neighbors":[],"careTools":[],"actorExtras":[],"maps":[]}
	var cup=Node3D.new();root.add_child(cup)
	Objects.drink(cup,Vector3(0.39,0.12,0.42),Color("e5adab"));Objects.flush(cup)
	await process_frame
	recipes.actorExtras.append({"id":"drink","root":_node(cup)});cup.free()
	var stand=Node3D.new();root.add_child(stand)
	var height=Objects.STAFF_STEP_HEIGHT/0.83
	Objects.box(stand,Vector3(0,-height*0.5,0),Vector3(0.92,height,0.89),Color("b99268"))
	Objects.box(stand,Vector3(0,-0.045,0),Vector3(0.98,0.09,0.95),Color("d7b68a"))
	Objects.box(stand,Vector3(0,-height*0.75,-0.53),Vector3(0.82,height*0.5,0.22),Color("c5a277"));Objects.flush(stand)
	await process_frame
	recipes.actorExtras.append({"id":"staffPlatform","root":_node(stand)});stand.free()
	for definition in Content.items():
		var item=Objects.make(definition);root.add_child(item);item.process_mode=Node.PROCESS_MODE_DISABLED
		await process_frame
		recipes.items.append({"id":definition.id,"shape":definition.shape,"root":_node(item)})
		item.free()
	for i in range(21):
		var staff=i>=18
		var index=i-18 if staff else i
		var actor=Cat.new();actor.set_meta("cat_index",index);root.add_child(actor)
		actor.build(Color(Legacy.COATS[index]),staff);actor.process_mode=Node.PROCESS_MODE_DISABLED
		bindings.clear()
		for key in ["body","head","tail","mouth"]:bindings[actor.get(key).get_instance_id()]=key
		for key in ["legs","eyes","ears"]:
			var values: Array=actor.get(key)
			for n in range(values.size()):bindings[values[n].get_instance_id()]=key+"."+str(n)
		for key in actor.props:bindings[actor.props[key].get_instance_id()]="props."+str(key)
		await process_frame
		var recipe={"id":str(index),"root":_node(actor)}
		if staff:recipes.staff.append(recipe)
		else:recipes.cats.append(recipe)
		actor.free();bindings.clear()
	var stage=load("res://scripts/creative/creative_care_stage.gd").new()
	root.add_child(stage);stage.process_mode=Node.PROCESS_MODE_DISABLED
	for tool in stage.TOOLS:
		stage.set_tool(tool)
		await process_frame
		var recipe=_node(stage.prop);recipe.visible=true
		recipes.careTools.append({"id":tool,"root":recipe})
	stage.free()
	for i in range(4):
		model.state.current_hotel=i
		var world=World.new();root.add_child(world);world.setup(model);world.process_mode=Node.PROCESS_MODE_DISABLED
		var care=Node3D.new();root.add_child(care);Care.build(care,i);care.process_mode=Node.PROCESS_MODE_DISABLED
		await process_frame
		await process_frame
		if i==0:
			for n in range(world.neighborhood.pedestrians.size()):
				var actor=world.neighborhood.pedestrians[n].node
				bindings.clear()
				for key in ["body","head","tail","mouth"]:bindings[actor.get(key).get_instance_id()]=key
				for key in ["legs","eyes","ears"]:
					var values: Array=actor.get(key)
					for joint in range(values.size()):bindings[values[joint].get_instance_id()]=key+"."+str(joint)
				var recipe=_node(actor)
				recipe.transform=_matrix(Transform3D.IDENTITY)
				recipes.neighbors.append({"id":str(n),"root":recipe})
			bindings.clear()
		var rooms=[]
		for key in world.room_nodes:rooms.append({"id":key,"root":_node(world.room_nodes[key])})
		var map_recipe={"id":str(model.map_definition().id),"ground":_node(world.get("_terrain")),"building":_node(world.get("_building")),"rooms":rooms,"neighborhood":_node(world.neighborhood.get("_scenery")),"routes":_clean(world.neighborhood.routes),"sceneryBounds":_clean(world.neighborhood.scenery_bounds),"care":_node(care)}
		# A path-free terrain variant prevents starter paving from persisting beneath edits.
		var saved_paths=model.hotel().paths
		model.hotel().paths={};model.revision+=1;world.sync()
		await process_frame
		map_recipe.groundWithoutPaths=_node(world.get("_terrain"))
		var no_parcels=GDScript.new()
		no_parcels.source_code="extends \"res://scripts/creative/creative_world.gd\"\nfunc _parcel(_rect: Rect2, _color: Color, _accent: Color, _owned: bool, _title: String) -> void:\n\tpass\n"
		assert(no_parcels.reload()==OK)
		var bare=no_parcels.new();root.add_child(bare);bare.setup(model);bare.process_mode=Node.PROCESS_MODE_DISABLED
		await process_frame
		map_recipe.groundWithoutParcels=_node(bare.get("_terrain"));bare.free()
		map_recipe.parcels=[]
		var definition=model.map_definition()
		var parcel_definitions=[{"id":"base","rect":definition.base,"name":""}]+definition.plots
		for parcel in parcel_definitions:
			for owned in [false,true]:
				var previous=world._terrain
				var geometry=Node3D.new();root.add_child(geometry);world._terrain=geometry
				var turf=Color(str(definition.ground))
				world._parcel(Rect2(parcel.rect[0],parcel.rect[1],parcel.rect[2],parcel.rect[3]),turf if owned else turf.darkened(0.055),Color(str(definition.accent)),owned,str(parcel.name))
				Objects.flush(geometry);await process_frame
				map_recipe.parcels.append({"id":parcel.id,"owned":owned,"root":_node(geometry)})
				world._terrain=previous;geometry.free()
		model.hotel().paths=saved_paths;model.revision+=1
		recipes.maps.append(map_recipe)
		world.free();care.free()
	_write("GodotGeometry.json",recipes)
	print("UNITY_REFERENCE_EXPORT_OK items=",recipes.items.size()," cats=",recipes.cats.size()," maps=",recipes.maps.size()," voxel_parts=",cube_count)
	quit(0)

func _matrix(t: Transform3D) -> Array:
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]

func _color(material: Material) -> Color:
	if material is StandardMaterial3D:return material.albedo_color
	if material is ShaderMaterial:
		for key in ["tint","water_color","base_color"]:
			var value=material.get_shader_parameter(key)
			if value is Color:return value
	return Color.WHITE

func _part(mesh: Mesh, at: Transform3D, color: Color) -> Dictionary:
	var kind="cube"
	var size=Vector3.ONE
	if mesh is BoxMesh:size=mesh.size
	elif mesh is SphereMesh:kind="sphere";size=Vector3(mesh.radius*2,mesh.height,mesh.radius*2)
	elif mesh is CylinderMesh:kind="cylinder";size=Vector3(maxf(mesh.top_radius,mesh.bottom_radius)*2,mesh.height,maxf(mesh.top_radius,mesh.bottom_radius)*2)
	elif mesh is PlaneMesh:kind="plane";size=Vector3(mesh.size.x,1,mesh.size.y)
	else:return {}
	var scaled=at*Transform3D(Basis.IDENTITY.scaled(size),Vector3.ZERO)
	cube_count+=1
	return {"transform":_matrix(scaled),"color":"#"+color.to_html(),"mesh":kind}

func _node(node: Node) -> Dictionary:
	var result={"name":str(node.name),"type":node.get_class(),"transform":_matrix(node.transform if node is Node3D else Transform3D.IDENTITY),"visible":node.visible if node is Node3D else true,"binding":bindings.get(node.get_instance_id(),str(node.name)),"parts":[],"children":[],"meta":{}}
	for key in node.get_meta_list():
		if str(key)!="voxel_parts":result.meta[str(key)]=_clean(node.get_meta(key))
	if node is Label3D:
		result.text=node.text;result.pixelSize=node.pixel_size;result.color="#"+node.modulate.to_html();result.billboard=node.billboard!=BaseMaterial3D.BILLBOARD_DISABLED
	elif node is MeshInstance3D and node.mesh!=null:
		# Cat blob shadows are replaced by Unity's real soft/contact shadows.
		if not node.mesh is PlaneMesh:
			var material=node.material_override if node.material_override!=null else node.mesh.surface_get_material(0)
			var part=_part(node.mesh,Transform3D.IDENTITY,_color(material))
			_water(part,material)
			if not part.is_empty():result.parts.append(part)
	elif node is MultiMeshInstance3D and node.multimesh!=null:
		var mm=node.multimesh
		var tint=_color(node.material_override)
		for i in range(mm.instance_count):
			var part=_part(mm.mesh,mm.get_instance_transform(i),mm.get_instance_color(i) if mm.use_colors else tint)
			_water(part,node.material_override)
			if not part.is_empty():result.parts.append(part)
	for child in node.get_children():
		if child is Node3D:result.children.append(_node(child))
	return result

func _water(part: Dictionary, material: Material) -> void:
	if material is ShaderMaterial and material.shader!=null and material.shader.resource_path.ends_with("water.gdshader"):
		part.material="water"
		part.water={}
		for key in ["deep_color","motion","shore_z"]:
			part.water[key]=_clean(material.get_shader_parameter(key))

func _clean(value):
	if value is Color:return "#"+value.to_html()
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Rect2:return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var result={}
		for key in value:result[str(key)]=_clean(value[key])
		return result
	if value is Array:
		var result=[]
		for entry in value:result.append(_clean(entry))
		return result
	return value

func _write(name: String,value) -> void:
	var file=FileAccess.open(output+"/"+name,FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()
