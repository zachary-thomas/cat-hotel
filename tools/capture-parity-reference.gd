extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const World=preload("res://scripts/creative/creative_world.gd")
var model
var world
var evidence=[]
var output="res://docs/unity-migration/evidence/godot"
var elapsed=0.0
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute(output)
	for map in range(4):
		model=Model.new();model.new_game(1000);model.state.current_hotel=map
		world=World.new();root.add_child(world);world.setup(model)
		world.process_mode=Node.PROCESS_MODE_DISABLED
		world.set_world_rect(Rect2(0,0,1280,800));world.focus_hotel()
		elapsed=0
		for frame in range(100):advance(0.1)
		await shot("map-%d-opening"%map)
		world.focus_lot();await shot("map-%d-neighborhood"%map)
		if map==0:
			await clip("neighborhood",30)
			for object in model.hotel().objects:
				if object.item=="fountain":
					world.focus_bounds(Rect2(object.x-3,object.y-3,9,9));break
			await shot("fountain");await clip("fountain",30)
			world.focus_hotel()
			for frame in range(500):advance(0.1)
			await shot("cafe-service");await clip("cafe-service",30)
		model.state.settings.evening=true;world.apply_visual_settings();world.focus_hotel()
		await shot("map-%d-evening"%map)
		world.free()
	var stage=load("res://scripts/creative/creative_care_stage.gd").new()
	root.add_child(stage);stage.size=Vector2(1280,800);stage.process_mode=Node.PROCESS_MODE_DISABLED
	stage.set_tool("wand");stage.use_selected_tool()
	for frame in range(30):
		stage._process(0.1)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/care-%03d.png"%frame)
	stage.free()
	var file=FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"sourceRevision":"4be10cc8bd4979b2ccaaad7e2ce6c3708a7ba1ec","resolution":[1280,800],"fixedStep":0.1,"captures":evidence}));file.close()
	print("PARITY_REFERENCE_CAPTURE_OK ",evidence.size());quit()
func advance(dt):
	model.advance(dt);world._process(dt);world.neighborhood.advance(dt)
	animate(world,dt);elapsed+=dt
func animate(node,dt):
	var script=node.get_script()
	if script!=null:
		var path=script.resource_path
		if path.ends_with("creative_object_motion.gd") or path.ends_with("creative_water_motion.gd"):node._process(dt)
	for child in node.get_children():animate(child,dt)
func shot(label):
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
	var camera=world.camera
	evidence.append({"name":label,"map":model.state.current_hotel,"time":elapsed,"cameraPosition":[camera.position.x,camera.position.y,camera.position.z],"cameraSize":camera.size,"cameraRotation":[camera.rotation.x,camera.rotation.y,camera.rotation.z],"state":model.serialize()})
func clip(label,count):
	for frame in range(count):
		advance(0.1)
		await shot(label+"-%03d"%frame)
