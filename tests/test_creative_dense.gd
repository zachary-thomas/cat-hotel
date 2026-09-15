extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const Geo=preload("res://scripts/creative/lot_geometry.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=Model.new(); model.new_game(1000)
	model.state.coins=100000
	var data: Dictionary=model.hotel()
	data.plots=["west","east","north"]; data.rooms.clear(); data.objects.clear(); data.paths.clear()
	data.level=10; data.maid=true
	for i in range(24):
		var x: int=-20+(i%6)*6; var y: int=-12+floori(i/6.0)*6
		var id: String="dense-room-%d" % i
		data.rooms.append({"id":id,"kind":"regular","name":"Garden cottage %d" % i,"x":x,"y":y,"w":4,"h":3,"rotation":0,"paid":0})
		for piece in [["mat",0.5,0.5],["box",2.5,0.5],["plant",3.5,2.5],["lamp",0.5,2.5]]:
			data.objects.append({"id":id+"-"+str(piece[0]),"item":piece[0],"room":id,"x":x+piece[1],"y":y+piece[2],"rotation":0,"paid":0})
		data.dirty[id]=true
	data.rooms.append({"id":"dense-lobby","kind":"shared","name":"Courtyard lobby","x":-10,"y":-19,"w":6,"h":6,"rotation":0,"paid":0})
	data.objects.append({"id":"dense-reception","item":"reception_counter","room":"dense-lobby","x":-9.5,"y":-18.5,"rotation":0,"paid":0})
	data.objects.append({"id":"dense-sofa","item":"lounge_sofa","room":"dense-lobby","x":-9.5,"y":-15.5,"rotation":0,"paid":0})
	for x in range(-20,20):
		for y in range(-20,12):
			if Geo.owns_rect(Rect2(x,y,1,1),model.map_definition(),data): data.paths["%d,%d" % [x,y]]={"style":"earth","paid":0}
	for cat in model.state.cats: cat.known=true
	model._invalidate()
	var snapshot=model.serialize(); var reopened=Model.new()
	var start:=Time.get_ticks_usec()
	check(reopened.restore(snapshot),"Dense layout with 24 cottages survives schema validation")
	var validation_ms: float=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	var ready:=0
	for room in reopened.hotel().rooms:
		if room.kind=="regular" and reopened.room_status(str(room.id)).ready: ready+=1
	var navigation_ms: float=(Time.get_ticks_usec()-start)/1000.0
	check(ready==24,"Every one of 24 cottages is reachable and operational")
	check(reopened.rate()>=24*12,"All rooms beyond eight earn room income")
	var graph: AStar2D=reopened._graph(true,0).graph
	start=Time.get_ticks_usec()
	for i in range(100): reopened.quote("paint_path",{"style":"gravel","cells":[[18,10],[19,10]]})
	var quote_ms: float=(Time.get_ticks_usec()-start)/100000.0
	check(reopened._graph(true,0).graph==graph,"Quotes reuse navigation until a layout commit")
	start=Time.get_ticks_usec()
	for i in range(3600): reopened.advance(1.0/60.0)
	var tick_ms: float=(Time.get_ticks_usec()-start)/3600000.0
	check(reopened._graph(true,0).graph==graph,"Cached navigation survives 3600 simulation frames")
	check(reopened.hotel().cleaned>0,"Housekeeping reaches the dense property")
	check(tick_ms<16.7,"Dense simulation stays within a 60fps CPU frame budget")
	check(quote_ms<150,"Dense build quotes remain responsive")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,800); root.content_scale_size=Vector2i(1280,800)
		var world=load("res://scripts/creative/creative_world.gd").new()
		root.add_child(world); world.setup(reopened)
		world.set_world_rect(Rect2(0,0,1280,800)); world.focus_lot()
		for frame in range(15): await process_frame
		start=Time.get_ticks_usec()
		for frame in range(90): await process_frame
		var rendered_ms: float=(Time.get_ticks_usec()-start)/90000.0
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/creative-preview/dense-property.png")
		print("CREATIVE DENSE GPU: %.2fms/frame; %d draw calls" % [rendered_ms,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		check(rendered_ms<50,"Dense rendered preview stays interactive")
		world.queue_free(); await process_frame
	print("CREATIVE DENSE: %d rooms / %d objects / %d guests; validate %.1fms, navigation %.1fms, quote %.2fms, simulation %.3fms/frame; %d failures" % [ready,data.objects.size(),18,validation_ms,navigation_ms,quote_ms,tick_ms,failures])
	quit(1 if failures else 0)
