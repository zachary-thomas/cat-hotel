extends SceneTree
## Actual game captures from a disposable profile, never a player's journal.
var app
var destination: String="res://docs/creative-preview/garden-polish"
var failures:=0
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	for control in app.ui._surface.get_children():
		if control is PanelContainer and not Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(control.get_global_rect()):
			failures+=1; push_error("Panel outside viewport in "+name_value)
	root.get_texture().get_image().save_png(destination+"/"+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	DirAccess.make_dir_recursive_absolute("res://tmp/garden-captures")
	app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="res://tmp/garden-captures/preview-"+str(Time.get_ticks_usec())
	root.add_child(app); app._active=false
	for step in range(600): app.model.advance(0.1)
	for dimensions in [Vector2i(360,640),Vector2i(360,800),Vector2i(390,844),Vector2i(430,932),Vector2i(1280,800)]:
		root.size=dimensions; root.content_scale_size=dimensions
		await process_frame
		for scale_value in [1.0,1.5]:
			app.model.state.settings.ui_text_scale=scale_value
			app.ui.open_tab("Hotel"); app.world.focus_hotel()
			await capture("hotel-%dx%d-%d" % [dimensions.x,dimensions.y,roundi(scale_value*100)])
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	app.model.state.settings.ui_text_scale=1.0; app.ui.open_tab("Hotel")
	await process_frame
	app.world.focus_bounds(Rect2(-11,-11,23,23))
	await capture("meadow-overview")
	app.world.focus_bounds(Rect2(-4.5,-4.5,7,7))
	await capture("reception-close")
	app.world.focus_bounds(Rect2(3,-8,8,9))
	await capture("fountain-garden")
	app.world.set_outside(true); app.world.focus_bounds(Rect2(-11,-11,23,23))
	await capture("hotel-exterior")
	app.world.set_outside(false)
	app.perform("store_object",{"id":"meadow_guest_1_bed"})
	app.ui.refresh()
	app.world.focus_bounds(Rect2(-11,-11,14,14))
	await capture("room-warning")
	root.size=Vector2i(360,640); root.content_scale_size=root.size
	app.model.state.settings.ui_text_scale=1.5; app.ui.refresh()
	app.world.focus_bounds(Rect2(-11,-11,8,8))
	await capture("room-warning-phone")
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	app.model.state.settings.ui_text_scale=1.0; app.ui.refresh()
	app.perform("undo")
	app.world.set_world_rect(Rect2(0,0,1280,800)); app.ui.hide()
	app.world.focus_bounds(Rect2(-4.5,-4.5,9,9))
	if OS.get_cmdline_user_args().has("--capture-motion"):
		var frames: String="res://tmp/garden-captures/motion"
		DirAccess.make_dir_recursive_absolute(frames)
		for frame in range(120):
			app.model.advance(0.1)
			app.world._sync_actors(0.1)
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(frames+"/frame-%03d.png" % frame)
	app.soundscape.shutdown(); app.queue_free()
	await process_frame
	print("GARDEN CAPTURES: ",failures," failures")
	quit(1 if failures else 0)
