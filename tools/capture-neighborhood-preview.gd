extends SceneTree
## Render the actual game using a disposable save, including camera extremes.
var app
var failures:=0
const DESTINATION="res://docs/creative-preview/neighborhood-polish"
func _initialize()->void: call_deferred("run")
func capture(filename:String)->void:
	for frame in range(10): await process_frame
	await RenderingServer.frame_post_draw
	for control in app.ui._surface.get_children():
		if control is PanelContainer and not Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(control.get_global_rect()):
			failures+=1; push_error("Panel outside viewport in "+filename)
	var error:int=root.get_texture().get_image().save_png(DESTINATION+"/"+filename+".png")
	if error!=OK: failures+=1; push_error("Could not write "+filename)
func run()->void:
	DirAccess.make_dir_recursive_absolute(DESTINATION)
	DirAccess.make_dir_recursive_absolute("res://tmp/neighborhood-captures")
	app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="res://tmp/neighborhood-captures/save-"+str(Time.get_ticks_usec())
	root.add_child(app); app._active=false
	for step in range(500): app.model.advance(0.1)
	for size in [Vector2i(360,640),Vector2i(360,800),Vector2i(390,844),Vector2i(430,932),Vector2i(1280,800)]:
		root.size=size; root.content_scale_size=size; await process_frame
		for text_scale in [1.0,1.5]:
			app.model.state.settings.ui_text_scale=text_scale
			app.ui.open_tab("Hotel"); app.world.focus_hotel()
			await capture("opening-%dx%d-%d"%[size.x,size.y,roundi(text_scale*100)])
			app.world.focus_lot(); app.world.zoom(100.0)
			await capture("fit-%dx%d-%d"%[size.x,size.y,roundi(text_scale*100)])
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	app.model.state.settings.ui_text_scale=1.0; app.ui.refresh()
	await process_frame
	app.world.focus_bounds(Rect2(-4,-4,7,7))
	await capture("lower-reception")
	for index in range(4):
		app.model.state.current_hotel=index; app.model._invalidate()
		app.model.advance(1.0); app.world.sync(); app.ui.open_tab("Hotel")
		app.world.focus_lot()
		await capture("neighborhood-%d"%index)
		app.world.zoom(100.0)
		app.world.pan(Vector2(100000,-100000))
		await capture("camera-edge-%d"%index)
		if index==1:
			for step in range(900): app.model.advance(0.2)
			app.world.focus_bounds(Rect2(3,0,8,8))
			await capture("lower-milkshake-bar")
	app.model.state.current_hotel=0; app.model._invalidate(); app.world.sync(); app.ui.open_tab("Hotel")
	app.world.focus_bounds(Rect2(-13,11,28,13))
	app.world._limit_manual_camera(); app.world._update_camera()
	await capture("sidewalk-life")
	if OS.get_cmdline_user_args().has("--capture-motion"):
		var frames="res://tmp/neighborhood-captures/motion"
		DirAccess.make_dir_recursive_absolute(frames)
		app.world.neighborhood.set_process(false)
		for frame in range(120):
			app.world.neighborhood.advance(0.1)
			await process_frame; await RenderingServer.frame_post_draw
			var error:int=root.get_texture().get_image().save_png(frames+"/frame-%03d.png"%frame)
			if error!=OK: failures+=1
	app.soundscape.shutdown(); app.queue_free(); await process_frame
	print("NEIGHBORHOOD CAPTURES: %d failures"%failures)
	quit(1 if failures else 0)
