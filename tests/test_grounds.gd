extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
const Grounds = preload("res://scripts/core/grounds_model.gd")
var failures: int = 0
var app
var save_key: String
class BrokenStore:
	extends RefCounted
	var error_message: String = "Simulated storage failure"
	func save_model(_model) -> bool: return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/"+name+".png")
	if is_instance_valid(app.ui.sheet):
		check(app.ui.get_global_rect().encloses(app.ui.sheet.get_global_rect()),"Neighborhood menus fit the phone")

func click(control: Control) -> void:
	for frame in range(6): await process_frame
	app.ui.sheet.scroll.ensure_control_visible(control)
	for frame in range(6): await process_frame
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event,true)
		await process_frame

func tap_world(point: Vector2) -> void:
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	var m = Model.new()
	m.new_game(1000)
	check(m.grounds.perform(m,"yarn",{"index":0}).ok and m.coins == 1005,"Yarn awards five real coins")
	check(not m.grounds.perform(m,"yarn",{"index":0}).ok and m.coins == 1005,"Repeated taps cannot collect the same yarn twice")
	m.advance(35)
	check(m.grounds.perform(m,"yarn",{"index":0}).ok,"Yarn respawns after its saved cooldown")
	check(not m.grounds.perform(m,"amenity",{"id":"playpen"}).ok,"Amenities enforce level requirements")
	m.coins = 249
	check(not m.grounds.perform(m,"amenity",{"id":"pool"}).ok,"Amenities enforce affordability")
	m.coins = 1000
	check(m.grounds.perform(m,"amenity",{"id":"pool"}).ok and m.hotel_rate(0) == 15,"The pool adds its advertised income")
	var balance: float = m.coins
	check(not m.grounds.perform(m,"amenity",{"id":"pool"}).ok and m.coins == balance,"Owned amenities cannot charge twice")
	check(m.grounds.perform(m,"trim",{"index":0}).ok,"Tapping an overgrown bush starts a manager job")
	var data: Dictionary = m.grounds.hotels[0]
	var duration: float = data.job.duration
	m.advance(1)
	check(Vector2(data.manager[0],data.manager[1]).distance_to(Grounds.MANAGER_HOME)>0.5,"The manager actually walks toward the job")
	check(not m.grounds.perform(m,"chase",{}).ok,"Busy managers cannot accept overlapping jobs")
	var restored = Model.new()
	check(restored.restore(m.serialize()) and not restored.grounds.hotels[0].job.is_empty(),"An in-progress manager job survives saving")
	var before: float = m.coins
	m.advance(duration-1)
	check(data.job.is_empty() and data.chores == 1 and is_equal_approx(m.coins-before,15+(duration-1)*m.rate()/60.0),"Only completed trimming awards fifteen coins")
	check(not m.grounds.perform(m,"trim",{"index":0}).ok,"Trimmed bushes cannot immediately pay again")
	m.grounds.seconds = data.bush_ready[0]
	check(m.grounds.perform(m,"trim",{"index":0}).ok,"Bushes grow back into playable jobs")
	m.advance(30)
	check(m.grounds.perform(m,"chase",{}).ok,"The mouse can be chased after finishing a job")
	m.advance(30)
	check(data.mouse_ready > m.grounds.seconds and data.chores == 3,"Chasing makes the mouse disappear and grants one reward")
	check(not m.grounds.perform(m,"walk",{"x":3,"z":-3}).ok,"Walking cannot target furniture through a wall")
	check(m.grounds.perform(m,"walk",{"x":6.6,"z":3}).ok,"Tapping an open path directs the manager")
	m.advance(30)
	check(Vector2(data.manager[0],data.manager[1]).is_equal_approx(Vector2(6.6,3)),"Tap-to-walk reaches the selected path")
	m.grounds.hotels[0].dirty[0] = true
	check(m.grounds.perform(m,"clean",{"index":0}).ok,"Managers can clean real dirty rooms")
	m.advance(30)
	check(not data.dirty[0] and data.cleaned > 0,"Manual cleaning removes the room mess")
	m.coins = 5000
	check(not m.grounds.perform(m,"hire_maid",{}).ok,"Housekeeping stays locked before level three")
	m.hotels[0].purchases = 4
	data.dirty[0] = true
	check(m.grounds.perform(m,"hire_maid",{}).ok and not data.maid_job.is_empty(),"Hiring a maid assigns a dirty room automatically")
	check(not m.grounds.perform(m,"clean",{"index":int(data.maid_job.room)}).ok,"Manager and maid cannot reserve the same room")
	m.advance(25)
	check(not data.dirty[0],"The maid finishes actual room cleaning")
	var friendship: int = m.life.state.cats[m.life.state.favorite].bond
	check(m.grounds.perform(m,"treats",{}).ok and m.life.state.cats[m.life.state.favorite].bond == mini(100,friendship+3),"The street shop sells a real treat picnic and friendship")
	check(not m.grounds.perform(m,"treats",{}).ok,"Shop treats respect a cooldown")
	check(restored.restore(m.serialize()) and restored.grounds.hotels[0].maid and restored.grounds.hotels[0].amenities.has("pool"),"Amenities and housekeeping survive reopening")
	var legacy: Dictionary = m.serialize()
	legacy.erase("grounds")
	check(restored.restore(legacy) and restored.grounds.hotels[0].amenities.is_empty(),"Older saves migrate into the neighborhood without losing hotel progress")
	for bad in [-1,INF,"soon"]:
		var corrupt: Dictionary = m.serialize()
		corrupt.grounds.hotels[0].yarn_ready[0] = bad
		check(not restored.restore(corrupt),"Malformed neighborhood cooldowns are rejected")
	var corrupt: Dictionary = m.serialize()
	corrupt.grounds.hotels[0].amenities.append("pool")
	check(not restored.restore(corrupt),"Duplicate amenities cannot inflate income")
	m.new_game(1000)
	m.grounds.perform(m,"trim",{"index":0})
	m.reconcile(1060)
	check(m.grounds.hotels[0].job.is_empty() and is_equal_approx(m.pending_coins,25),"Offline manager work finishes once and its reward waits to be claimed")
	var pending: float = m.pending_coins
	m.reconcile(1060)
	check(m.pending_coins == pending,"Repeated reopening cannot duplicate job rewards")

	m.pending_seconds = m.OFFLINE_CAP
	m.away_seconds = m.OFFLINE_CAP
	m.grounds.hotels[0].mouse_ready = 0
	m.grounds.perform(m,"chase",{})
	m.reconcile(1180)
	check(m.grounds.hotels[0].job.is_empty() and is_equal_approx(m.pending_coins,pending+12),"Assigned work finishes beyond the passive-income cap without adding idle income")
	m.grounds.hotels[0].maid = true
	m.grounds.hotels[0].dirty[0] = true
	m.grounds.advance(180,m)
	check(m.grounds.dirty_rooms(0,m.room_count(0)).is_empty(),"Hired housekeeping leaves rooms clean after a long absence")

	DirAccess.make_dir_recursive_absolute("res://tmp")
	save_key = "res://tmp/grounds-"+str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = save_key
	root.add_child(app)
	await process_frame
	app.start_game()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("40-neighborhood-new")
	app.model.coins = 5000
	app.model.hotels[0].purchases = 4
	app._update_ui()
	app.world.neighborhood.select_at(app.world.camera.unproject_position(Vector3(9.3,0.62,-1.0)))
	check(app.ui.tab == "Amenity" and app.ui.selected_amenity == "pool","Tapping the pool site opens its purchase details")
	await click(app.ui.sheet.find_child("Grounds_amenitypool",true,false))
	check(app.model.grounds.hotels[0].amenities.has("pool"),"The amenity purchase button updates the real hotel")
	for id in ["litter","playpen","picnic"]:
		app.perform_grounds("amenity",{"id":id})
	check(app.world.neighborhood.amenity_cats.size() == 4,"All four amenities have cats using their facilities")
	check(app.world.neighborhood.walkers.size() == 4,"Four neighboring cats walk along the road")
	app.ui.close_sheet()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("41-neighborhood-open")
	var real_store = app.store
	app.store = BrokenStore.new()
	# Exclude wall-clock income from the isolated rollback assertion.
	app.ticks = 0
	var prior: float = app.model.coins
	app.perform_grounds("yarn",{"index":1})
	check(is_equal_approx(app.model.coins,prior) and app.model.grounds.hotels[0].yarn_ready[1] == 0,"A failed save rolls back both yarn reward and cooldown")
	app.store = real_store
	app._save()
	var yarn_point = app.world.camera.unproject_position(Vector3(5.4,0.5,6.2))
	app.world.neighborhood.select_at(yarn_point)
	check(app.model.grounds.hotels[0].yarn_ready[1] > 0,"Tapping a world yarn ball collects its real reward")
	app.ui._navigate("Manager")
	await capture("42-manager-tasks")
	await click(app.ui.sheet.find_child("Grounds_trim0",true,false))
	check(not app.model.grounds.hotels[0].job.is_empty(),"The manager task button starts the selected chore")
	app.model.advance(7.5)
	app.world.apply_life(app.model)
	app.world.focus_grounds()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("43-manager-working")
	app.model.advance(15)
	app.model.grounds.hotels[0].dirty[0] = true
	app.perform_grounds("hire_maid")
	app.model.advance(3)
	app.world.apply_life(app.model)
	check(app.world.neighborhood.maid.visible,"Hiring housekeeping adds a visible uniformed maid")
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("44-housekeeping")
	app.model.advance(30)
	app._update_ui()
	app.world.apply_life(app.model)
	check(not app.model.grounds.hotels[0].dirty[0],"A visible maid actually cleans the assigned room")
	app.ui._navigate("Kiosk")
	await capture("45-paw-mart")
	await click(app.ui.sheet.find_child("Grounds_treats",true,false))
	check(app.model.grounds.hotels[0].treat_until > app.model.grounds.seconds,"Kiosk purchases invite the passing cats to a picnic")
	app.ui.close_sheet()
	app.world.neighborhood._process(3)
	app.ui.manager_mode_requested.emit(true)
	await process_frame
	await tap_world(app.world.camera.unproject_position(Vector3(0,0.2,1.2)))
	check(app.model.grounds.hotels[0].job.get("kind","") == "walk","Actual pointer taps direct the manager to a hotel aisle")
	app.model.advance(30)
	app.world.apply_life(app.model)
	check(Vector2(app.model.grounds.hotels[0].manager[0],app.model.grounds.hotels[0].manager[1]).distance_to(Vector2(0,1.2)) < 0.05,"Manager controls reach the tapped world position")
	app.ui.manager_mode_requested.emit(false)
	app.change_setting("motion",false)
	var passer_position: Vector3 = app.world.neighborhood.walkers[0].position
	app.world.neighborhood._process(2)
	check(app.world.neighborhood.walkers[0].position == passer_position,"Reduced motion pauses ambient street traffic")
	app.visit_hotel(0)
	check(app.world.neighborhood.manager != null,"Changing hotel keeps neighborhood actors connected")
	app.model.hotels[0].wings = 3
	app.model.hotels[0].purchases = 10
	app._rebuild_world()
	app._update_ui()
	app.ui.close_sheet()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("46-full-neighborhood")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(save_key+suffix): DirAccess.remove_absolute(save_key+suffix)
	print("GROUNDS TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
