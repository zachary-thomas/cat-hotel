extends SceneTree
## Render the actual creative scene from a disposable profile, including a natural conversation.
var app
var destination: String="res://docs/creative-preview/lively-hotel"
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+"/"+name_value+".png")
	print("CAPTURE ",name_value," speech=",app.world.life.speech.visible," live=",app.world.life.live," chatter=",app.world.life.chatter," line=",app.model.social.moments.speech()," rect=",app.world.life.speech.bubble_rect)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	DirAccess.make_dir_recursive_absolute("res://tmp/lively-capture")
	root.size=Vector2i(390,844); root.content_scale_size=root.size
	app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="res://tmp/lively-capture/save-"+str(Time.get_ticks_usec())
	root.add_child(app); app.set_process(false)
	app.model.state.settings.music=false; app.model.state.settings.sound=false; app.apply_settings()
	for step in range(2400):
		app.model.advance(0.1)
		if not app.model.social.moments.active.is_empty(): break
	if app.model.social.moments.active.is_empty(): push_error("No natural conversation found"); quit(1); return
	print("NATURAL CONVERSATION: ",app.model.social.moments.active)
	for step in range(10): app.model.advance(0.1)
	app.ui.refresh(); app.world.focus_hotel()
	await capture("phone-conversation")
	var ids: Array=app.model.social.moments.active.participants
	var at: Vector2=app.model.social.agents[ids[0]].position
	app.world.focus_bounds(Rect2(at-Vector2(4,4),Vector2(8,8)))
	await capture("phone-conversation-close")
	for step in range(34): app.model.advance(0.1)
	await capture("phone-reply")
	app.model.state.settings.ui_text_scale=1.5; app.ui.refresh()
	await capture("phone-large-text")
	app.model.state.settings.ui_text_scale=1.0; app.ui.refresh()
	root.size=Vector2i(960,720); root.content_scale_size=root.size
	await process_frame; app.ui.refresh(); app.world.focus_bounds(Rect2(at-Vector2(4,4),Vector2(8,8)))
	await capture("desktop-conversation")
	if OS.get_cmdline_user_args().has("--stills-only"):
		app.soundscape.shutdown(); app.queue_free(); await process_frame; quit(); return
	# A second natural exchange gives the clip its full beginning and reply.
	app.model.social.moments.cancel()
	var serial: int=app.model.social.moments.serial
	for step in range(3000):
		app.model.advance(0.1)
		if app.model.social.moments.serial>serial and not app.model.social.moments.active.is_empty(): break
	if not app.model.social.moments.active.is_empty():
		at=app.model.social.agents[app.model.social.moments.active.participants[0]].position
		app.world.focus_bounds(Rect2(at-Vector2(4,4),Vector2(8,8)))
		DirAccess.make_dir_recursive_absolute("res://tmp/lively-capture/frames")
		for frame in range(150):
			app.model.advance(1.0/15.0); app.world._sync_actors(1.0/15.0); app.world.life.update(1.0/15.0)
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/lively-capture/frames/frame-%03d.png" % frame)
	app.soundscape.shutdown(); app.queue_free(); await process_frame
	print("LIVELY CAPTURES complete")
	quit()
