extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new(); model.new_game(1000); model.state.coins=100000
	var original=model.serialize()
	var room=model.hotel().rooms[0]
	check(model.room_status(str(room.id)).ready,"Starter bedroom has reception and a reachable bed")
	var bed_id=""
	for object in model.hotel().objects:
		if object.room==room.id and object.item=="mat": bed_id=object.id; break
	check(model.commit("store_object",{"id":bed_id}).ok,"Can store the last bed while building in stages")
	check(not model.room_status(str(room.id)).ready,"An empty bedroom is inactive")
	check(model.undo().ok and model.room_status(str(room.id)).ready,"Undo restores both bed and readiness")
	var before_coins:float=model.state.coins
	check(model.commit("resize_room",{"id":room.id,"w":8,"h":6}).ok,"Rooms resize across owned land")
	check(is_equal_approx(model.state.coins,before_coins-300),"Extra 12 cells cost300")
	check(model.commit("resize_room",{"id":room.id,"w":6,"h":6}).ok,"Rooms shrink again")
	check(is_equal_approx(model.state.coins,before_coins),"Shrinking refunds only purchased extra floor")
	check(model.commit("buy_plot",{"id":"east"}).ok,"Open land for a cottage copy")
	var object_count:int=model.hotel().objects.size()
	check(model.commit("copy_room",{"id":room.id,"x":12,"y":-10,"rotation":0}).ok,"Copy a fully furnished cottage onto expanded land")
	check(model.hotel().objects.size()>object_count,"Copied room has distinct editable furniture")
	var copy_room=model.hotel().rooms[-1]
	check(not model.room_status(str(copy_room.id)).ready,"Disconnected cottage stays unfinished")
	var cells:Array=[]
	for x in range(10,20):
		for y in range(-3,-1): cells.append([x,y])
	for x in range(18,20):
		for y in range(-8,-1): cells.append([x,y])
	check(model.commit("paint_path",{"cells":cells,"style":"earth"}).ok,"Connect a two-cell-wide cottage path")
	check(model.room_status(str(copy_room.id)).ready,"Connected cottage opens for guests")
	check(model.commit("erase_path",{"cells":[[18,-5],[19,-5]]}).ok,"A player can erase an occupied route")
	check(not model.room_status(str(copy_room.id)).ready,"Removing the access path closes the cottage")
	check(model.undo().ok and model.room_status(str(copy_room.id)).ready,"Restoring the path reopens the cottage")
	var stored:int=model.state.storage.size()
	check(model.commit("remove_room",{"id":copy_room.id}).ok,"Remove a cottage")
	check(model.state.storage.size()>stored,"Room removal preserves furniture in storage")
	model.restore(original)
	model.hotel().rooms.clear(); model.hotel().objects.clear(); model.hotel().paths.clear(); model._invalidate()
	for i in range(12):
		var x: int=-12+(i%4)*6; var y:int=-12+int(i/4)*7
		check(model.commit("place_room",{"kind":"regular","x":x,"y":y,"w":4,"h":3,"rotation":0}).ok,"Construction supports room %d beyond the old cap" % (i+1))
	check(model.hotel().rooms.size()==12,"No eight-room gameplay cap")
	var saved=model.serialize(); var restored=Model.new()
	check(restored.restore(saved) and restored.hotel().rooms.size()==12,"More than eight rooms survive saving")
	model.restore(original); model.hotel().level=3
	check(model.commit("hire_housekeeper",{}).ok,"Daisy can be hired for the new cottage layout")
	check(model.hotel().get("maid",false),"Housekeeping ownership is saved")
	var beds:=0
	for venue in model.venues():
		if venue.role=="bed" and venue.open: beds+=1
	check(beds>=2,"Operational bedrooms expose actual sleep destinations")
	var bad=model.serialize(); bad.hotels[0].rooms[0].paid=-500
	check(not restored.restore(bad),"Corrupted negative purchase prices cannot mint refund coins")
	model.restore(original)
	model.hotel().rooms=[{"id":"sealed","kind":"regular","name":"Sealed cottage","x":-10,"y":-10,"w":4,"h":3,"rotation":0,"paid":0}]
	model.hotel().objects=[{"id":"wall_bed","item":"mat","room":"sealed","x":-10,"y":-9,"rotation":0,"paid":0}]
	model.hotel().paths.clear()
	for x in range(-11,11): model.hotel().paths["%d,10" % x]={"style":"earth","paid":0}
	for y in range(-10,11): model.hotel().paths["-11,%d" % y]={"style":"earth","paid":0}
	model._invalidate()
	check(model._approaches(model.hotel().objects[0],0).is_empty(),"An outside path cannot reach a bed through a closed wall")
	print("CREATIVE BUILDING: %d failures" % failures)
	quit(1 if failures else 0)
