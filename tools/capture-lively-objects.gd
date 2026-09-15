extends SceneTree
## Controlled demonstration of the actual runtime object/actor integration.
const Model=preload("res://scripts/creative/creative_model.gd")
const World=preload("res://scripts/creative/creative_world.gd")
const Objects=preload("res://scripts/creative/creative_objects.gd")
func _initialize() -> void: call_deferred("run")
func actor(id: int, point: Vector2, venue: String, action: String, phase: String="activity") -> Dictionary:
	return {"cat":id,"name":"Guest","position":point,"phase":phase,"action":action,"venue":venue,"time":7.0,"life_elapsed":0.0,"life_token":venue,"drink":false,"velocity":Vector2.ZERO,"staff_role":1,"role":"bar" if id>=1000 else "","checked_in":true}
func run() -> void:
	Engine.max_fps=24
	root.size=Vector2i(900,720); root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute("res://tmp/lively-objects/frames")
	DirAccess.make_dir_recursive_absolute("res://docs/creative-preview/lively-hotel")
	var model=Model.new(); model.new_game(1000)
	model.hotel().rooms.clear(); model.hotel().objects.clear(); model.hotel().paths.clear()
	for item in [["hearth","fireplace",-5,-4],["water","fountain",1,-4],["shake","milkshake_counter",-5,2],["tray","litter",1,2]]:
		model.hotel().objects.append({"id":item[0],"item":item[1],"room":"","x":item[2],"y":item[3],"rotation":0,"paid":0})
	model._invalidate()
	var world=World.new(); root.add_child(world); world.setup(model)
	world.set_world_rect(Rect2(0,30,900,690)); world.set_life_context(true,false)
	world.focus_bounds(Rect2(-7,-6,13,13))
	model.social.agents={0:actor(0,Vector2(-4,-2.5),"hearth","rest"),1:actor(1,Vector2(2,4.3),"tray","dig"),2:actor(2,Vector2(-3.5,3.5),"shake","wait","serve"),2000:actor(2000,Vector2(-3.5,1.4),"shake","serve","service")}
	var layer:=CanvasLayer.new(); root.add_child(layer)
	var title:=Label.new(); title.text="A little more life at Purrington"; title.position=Vector2(22,16)
	title.add_theme_font_override("font",preload("res://assets/fonts/Fredoka.ttf")); title.add_theme_font_size_override("font_size",27); title.add_theme_color_override("font_color",Color("24483e")); layer.add_child(title)
	for frame in range(180):
		var time: float=float(frame)/24.0
		model.state.time=time
		for data in model.social.agents.values(): data.life_elapsed=time
		if time>=2.8:
			model.social.agents[2].phase="sit"; model.social.agents[2].action="drink"; model.social.agents[2].drink=true; model.social.agents[2].activity_venue="shake"
			model.social.agents[2000].action="work"; model.social.agents[2000].life_elapsed=time-2.8
		world._sync_actors(1.0/24.0); world.life.update(1.0/24.0)
		await process_frame; await RenderingServer.frame_post_draw
		var rendered: Image=root.get_texture().get_image()
		rendered.save_png("res://tmp/lively-objects/frames/frame-%03d.png" % frame)
		if frame==32: rendered.save_png("res://docs/creative-preview/lively-hotel/furniture-in-use.png")
	world.free(); layer.free()
	print("LIVELY OBJECT CAPTURE: 180 frames; actual world activity bridge")
	quit()
