extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
var model
var cases=[]
func _initialize():
	model=Model.new();model.new_game(1000)
	var result={"schema":1,"source":"4be10cc8bd4979b2ccaaad7e2ce6c3708a7ba1ec","maps":[],"construction":[],"care":[]}
	for i in range(4):
		model.state.current_hotel=i
		result.maps.append(snapshot())
	model.new_game(1000);model.state.coins=100000
	var room=model.hotel().rooms[0].id
	step("buy_plot",{"id":"east"})
	step("copy_room",{"id":room,"x":12,"y":-10,"rotation":0})
	var copied=model.hotel().rooms[-1].id
	step("resize_room",{"id":copied,"w":8,"h":6})
	step("resize_room",{"id":copied,"w":6,"h":6})
	var cells=[]
	for x in range(10,20):
		for y in range(-3,-1):cells.append([x,y])
	for x in range(18,20):
		for y in range(-8,-1):cells.append([x,y])
	step("paint_path",{"cells":cells,"style":"earth"})
	step("erase_path",{"cells":[[18,-5],[19,-5]]})
	var undo=model.undo();cases.append({"action":"undo","payload":{},"result":undo,"after":snapshot()})
	step("remove_room",{"id":copied})
	step("upgrade",{"service":0})
	step("train",{"staff":0})
	result.construction=cases
	model.new_game(1000)
	for action in ["pet","brush","wand","yarn","cushion","box"]:
		var response=model.care(0,action)
		result.care.append({"action":action,"result":response,"cat":model.state.cats[0].duplicate(true)})
		model.advance(12)
	var path="res://unity/PurringtonHotel/Assets/Resources/Content/GodotOracle.json"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("PARITY_ORACLE_OK cases=",cases.size());quit()
func step(action,payload):
	var quote=model.quote(action,payload)
	var response=model.commit(action,payload)
	cases.append({"action":action,"payload":payload,"quote":quote,"result":response,"after":snapshot()})
func snapshot():
	var statuses=[]
	for room in model.hotel().rooms:statuses.append({"id":room.id,"status":model.room_status(room.id)})
	return {"index":model.state.current_hotel,"coins":model.state.coins,"rate":model.rate(),"capacity":model.guest_capacity(),"rooms":model.hotel().rooms.duplicate(true),"objects":model.hotel().objects.duplicate(true),"paths":model.hotel().paths.duplicate(true),"plots":model.hotel().plots.duplicate(true),"storage":model.state.storage.duplicate(true),"statuses":statuses}
