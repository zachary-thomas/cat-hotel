extends RefCounted
const Interior = preload("res://scripts/core/furniture_layout.gd")
static func replace_trio(model, room: int, items: Array) -> Dictionary:
	var hotel: int = model.current_hotel
	var record: Dictionary = model.furniture.room_record(hotel,room)
	var edit_id := "fixture-%d" % int(model.furniture.state.next_instance)
	var layout: Dictionary = model.hotels[hotel].layout[room]
	var placed: Array = Interior.template(layout.kind,items)
	var existing: Array = model.furniture.room_items(hotel,room)
	for index in range(placed.size()):
		var value: Dictionary = placed[index]
		value.uid="draft:%s:%d" % [edit_id,index]
		for old in existing:
			if old.item==value.item: value.uid=old.uid; break
		value.hotel=hotel; value.room=room
	var result: Dictionary = model.furniture.apply(model,{"hotel":hotel,"room":room,"edit_id":edit_id,"base_room_revision":record.revision,"base_inventory_revision":model.furniture.state.revision,"instances":placed})
	if result.ok: model.life.discover_combos(hotel,room)
	return result
