extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const World=preload("res://scripts/creative/creative_world.gd")
const Objects=preload("res://scripts/creative/creative_objects.gd")
const Content=preload("res://scripts/creative/creative_content.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1; push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for item in ["reception_counter","milkshake_counter"]:
		var counter=Objects.make(Content.item(item))
		check(float(counter.get_meta("counter_height",INF))<=0.8,item+" worktop is below cat eye height")
		counter.free()
	var model=Model.new(); model.new_game(1000)
	var world=World.new(); root.add_child(world); world.setup(model)
	model.advance(1.0); world._sync_actors(1.0)
	for id in world.actors:
		var actor=world.actors[id]
		if not actor.has_node("StaffPlatform"): continue
		check(actor.position.y-World.FLOOR<=0.23,"Counter staff stand on a low step")
		check(actor.eyes[0].global_position.y>World.FLOOR+0.85,"Employee eyes clear the lower worktop")
	for dimensions in [Vector2i(360,640),Vector2i(360,800),Vector2i(390,844),Vector2i(430,932),Vector2i(1280,800)]:
		root.size=dimensions; root.content_scale_size=dimensions
		world.set_world_rect(Rect2(12,100,dimensions.x-24,dimensions.y*0.55))
		await process_frame
		for index in range(4):
			model.state.current_hotel=index; model._invalidate(); world.sync()
			world.focus_lot()
			for parcel in model.map_definition().plots:
				var rect:Rect2=world._rect(parcel.rect)
				for x in [rect.position.x,rect.end.x]:
					for y in [rect.position.y,rect.end.y]:
						var screen:Vector2=world.camera.unproject_position(Vector3(x*World.UNIT,3.4,y*World.UNIT))
						check(world._visible_rect().grow(2).has_point(screen),"Fit lot retains all expansion corners")
			var fit_size:float=world._size
			world.zoom(100.0)
			check(world._size<=fit_size*1.1,"Zoom stops near the whole property at "+str(dimensions))
			for drag in [Vector2(100000,100000),Vector2(-100000,-100000)]:
				world.pan(drag)
				var center:Vector2=world.world_point(world._visible_rect().get_center())
				check(absf(center.x)<28 and absf(center.y)<28,"Manual pan cannot leave the hotel neighborhood")
			world.zoom(0.001)
			for drag in [Vector2(0,100000),Vector2(0,-100000),Vector2(100000,0),Vector2(-100000,0)]:
				world.pan(drag)
				var center:Vector2=world.world_point(world._visible_rect().get_center())
				var definition:Dictionary=model.map_definition()
				var parcels:Array=[definition.base]
				for parcel in definition.plots: parcels.append(parcel.rect)
				var nearest:float=INF
				for values in parcels:
					var rect:Rect2=world._rect(values)
					nearest=minf(nearest,center.distance_to(center.clamp(rect.position,rect.end)))
				check(nearest<3.01,"Close zoom avoids empty gaps between expansion parcels")
			# Every purchasable parcel must remain individually frameable.
			for parcel in model.map_definition().plots:
				var rect:Rect2=world._rect(parcel.rect)
				world.focus_bounds(rect)
				var center:Vector2=world.world_point(world._visible_rect().get_center())
				check(center.distance_to(rect.get_center())<1.0,"Selection frames every expansion parcel")
	world.free()
	print("CREATIVE COUNTER CAMERA: %d failures"%failures)
	quit(1 if failures else 0)
