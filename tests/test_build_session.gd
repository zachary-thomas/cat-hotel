extends SceneTree

const Session = preload("res://scripts/core/build_session.gd")
const Inventory = preload("res://scripts/core/furniture_inventory.gd")

class FakeModel:
	const UNIT := 1000000
	var coins_units := 1000 * UNIT
	var hotels := [{"owned":true,"zones":[1,0,0,0],"purchases":0,"wings":0,"layout":[
		{"kind":"regular","x":0,"y":9,"rotation":0}]}]
	var furniture := Inventory.new()
	func _init() -> void: furniture.ensure_rooms(self,0)
	func room_count(hotel: int) -> int: return hotels[hotel].layout.size() if hotel == 0 else 0
	func hotel_level(_hotel: int) -> int: return 1
	func advance(_seconds: float) -> void: coins_units += 7 * UNIT

var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	test_draft_isolation_and_history()
	test_commands_validate_and_track_ownership()
	test_history_is_bounded_and_branches()
	test_quote_requires_complete_current_room()
	test_patch_and_recovery_contract()
	test_corrupt_recovery_is_atomic()
	quit(1 if failures else 0)

func find_item(values: Array, item: String) -> Dictionary:
	for value in values:
		if value.item == item: return value
	return {}

func test_corrupt_recovery_is_atomic() -> void:
	var model := FakeModel.new(); var session := Session.new(); session.begin(model,0,0,"corrupt")
	check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok,"Recovery fixture stages purchase")
	var raw := session.serialize(); var before := session.serialize()
	for key in ["original","storage"]:
		var bad := raw.duplicate(true); bad[key]=[1]
		check(not session.restore(bad,model).ok and session.serialize()==before,"Invalid %s does not mutate session" % key)
	for field in ["uid","item"]:
		var bad := raw.duplicate(true); bad.instances[0][field]="f999" if field=="uid" else "heated"
		check(not session.restore(bad,model).ok and session.serialize()==before,"Recovered permanent identity is validated")
	var bad := raw.duplicate(true); bad.next_draft=0
	check(not session.restore(bad,model).ok and session.serialize()==before,"Counter cannot reuse a draft ID")
	bad=raw.duplicate(true); bad.undo[0][0].uid="f999"
	check(not session.restore(bad,model).ok,"Undo ownership is validated")
	var plant := find_item(session.instances,"plant")
	var steps := session.undo_steps
	check(session.edit("transform",{"uid":plant.uid,"x":6,"y":0,"rotation":1}).ok and session.undo_steps==steps+1,"A combined move and rotation is one undo step")

func test_draft_isolation_and_history() -> void:
	var model := FakeModel.new(); var session := Session.new()
	session.begin(model,0,0,"edit-test-1")
	var inventory_before := model.furniture.serialize(); var coins_before := model.coins_units
	check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok, "A purchase can be staged")
	check(session.quote(model).cost_coins == 140, "A staged copy uses the catalogue price")
	model.advance(5.0); var earned := model.coins_units
	check(earned > coins_before, "Income continues while a draft is open")
	check(session.undo() and session.quote(model).cost_coins == 0, "Undo removes the pending purchase")
	check(session.redo() and session.quote(model).cost_coins == 140, "Redo restores the pending purchase")
	check(model.furniture.serialize() == inventory_before and model.coins_units == earned, "Draft history never rewinds authoritative state")

func test_commands_validate_and_track_ownership() -> void:
	var model := FakeModel.new(); var session := Session.new(); session.begin(model,0,0,"commands")
	var count := session.instances.size(); var history := session.undo_steps
	check(not session.edit("add",{"item":"scratch","x":99,"y":3,"rotation":0}).ok, "Invalid geometry rejects")
	check(not session.edit("move",{"uid":"missing","x":1,"y":1}).ok, "Unknown objects reject")
	check(session.instances.size() == count and session.undo_steps == history, "Rejected commands do not enter history")
	check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok, "First purchase stages")
	check(session.edit("add",{"item":"scratch","x":5,"y":3,"rotation":0}).ok, "Second purchase stages")
	check(session.quote(model).cost_coins == 280, "Copies are priced independently")
	var pending_uid: String = session.instances[-1].uid
	check(session.edit("store",{"uid":pending_uid}).ok and session.quote(model).cost_coins == 140, "Removing a pending object discards its cost")
	check(session.edit("add",{"item":"plant","x":6,"y":0,"rotation":0}).ok and session.quote(model).cost_coins == 140, "A reusable license adds no cost")
	var free_uid: String = session.instances[-1].uid
	check(session.edit("store",{"uid":free_uid}).ok and session.quote(model).cost_coins == 140, "Adding then removing a licensed copy stays free")
	var plant := find_item(session.instances,"plant")
	check(session.edit("rotate",{"uid":plant.uid,"rotation":1}).ok, "An owned object can rotate")
	check(session.edit("store",{"uid":plant.uid}).ok, "An existing object can be stored in the draft")
	check(not session.quote(model).report.contributions.has(plant.uid), "Stored objects do not contribute room quality")
	check(not session.edit("place_stored",{"uid":plant.uid,"x":6,"y":3,"rotation":0}).ok, "Only source storage objects can be placed")

func test_history_is_bounded_and_branches() -> void:
	var model := FakeModel.new(); var session := Session.new(); session.begin(model,0,0,"history")
	var plant := find_item(session.instances,"plant")
	for index in range(21):
		check(session.edit("move",{"uid":plant.uid,"x":6 + (index % 2),"y":0}).ok, "Move edit %d is accepted" % index)
	check(session.undo_steps == 20, "Only twenty undo states are retained")
	check(session.undo(), "Undo is available")
	check(session.edit("move",{"uid":plant.uid,"x":6,"y":0}).ok and not session.redo(), "A new edit clears redo")

func test_quote_requires_complete_current_room() -> void:
	var model := FakeModel.new(); var session := Session.new(); session.begin(model,0,0,"quote")
	var mat := find_item(session.instances,"mat")
	check(session.edit("store",{"uid":mat.uid}).ok, "Draft editing permits a temporarily missing bed")
	check(not session.quote(model).ok and session.quote(model).code == "missing_bed", "Apply quote requires a reachable bed")
	var stored: Dictionary = model.furniture.state.instances[0].duplicate(true)
	stored.hotel=-1; stored.room=-1; stored.x=0; stored.y=0; stored.rotation=0
	model.furniture.state.instances[0]=stored
	var resumed := Session.new(); resumed.begin(model,0,0,"storage")
	check(resumed.edit("place_stored",{"uid":stored.uid,"x":0,"y":0,"rotation":0}).ok, "Owned storage can be reserved into a draft")
	model.furniture.state.instances.erase(stored)
	check(resumed.quote(model).code == "unknown_uid", "Quote rejects a storage UID removed from current ownership")

func test_patch_and_recovery_contract() -> void:
	var model := FakeModel.new(); var session := Session.new(); session.begin(model,0,0,"recover")
	check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok, "Recovery draft stages")
	var patch := session.patch(); var saved := session.serialize()
	check(patch.hotel == 0 and patch.room == 0 and patch.edit_id == "recover" and patch.instances.size() == session.instances.size(), "Patch exposes the inventory apply receipt")
	check(saved.version == 1 and saved.has("hotel") and saved.has("room") and saved.has("edit_id") and saved.has("base_room_revision") and saved.has("base_inventory_revision"), "Recovery keeps receipt keys at top level")
	check(saved.has("original") and saved.has("storage") and saved.has("undo") and saved.has("redo") and saved.has("next_draft"), "Recovery contains detached state and history")
	var json_roundtrip = JSON.parse_string(JSON.stringify(saved)); var restored := Session.new(); var result := restored.restore(json_roundtrip,model)
	check(result.ok and restored.dirty() and restored.patch() == patch, "Version-one JSON recovery restores the same patch: %s" % result)
	var stale := saved.duplicate(true); model.furniture.state.revision += 1
	check(Session.new().restore(stale,model).code == "stale", "Recovery rejects changed inventory revisions")
	model.furniture.state.revision -= 1
	for record in model.furniture.state.rooms: record.last_edit_id = "recover"
	check(Session.new().restore(saved,model).code == "already_applied", "Recovery rejects an already applied receipt")
