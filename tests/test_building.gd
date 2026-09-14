extends SceneTree
const Layout = preload("res://scripts/core/room_layout.gd")
var app
var failures: int = 0
var save_key: String

class FailingStore:
	extends RefCounted
	var error_message: String = "Simulated write failure"
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
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	save_key = "res://tmp/building-test-"+str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = save_key
	root.add_child(app)
	await process_frame
	app.start_game()
	app.active = false
	app.model.coins = 15000
	app.model.hotels[0].wings = 2
	app.model.hotels[0].purchases = 8
	app.model.hotels[0].zones = [3,2,2,2]
	app.model.settings.motion = false
	app._rebuild_world()
	app._update_ui()
	var builder = app.build_panel
	check(app.world.room_builder.room_nodes.size()==2,"Initial rooms have independent detailed visual modules")
	app.ui.build_requested.emit()
	await capture("60-room-catalogue")
	check(builder.visible and app.world.build_mode,"Build button opens the world-visible catalogue")
	var before: Dictionary = app.model.serialize()
	builder.begin_place("suite")
	builder.candidate = {"kind":"suite","x":0,"y":4,"rotation":0}
	builder._update_validity()
	builder.focus_room()
	check(builder.validity.ok,"Suite preview fits the unlocked floor and connects its entrance")
	await capture("61-suite-placement")
	check(app.model.serialize()==before,"Viewing and positioning a room preview never changes saved state")
	builder.cancel()
	check(app.model.serialize()==before,"Cancel room placement is free and leaves no room")
	builder.begin_place("suite")
	builder.candidate = {"kind":"suite","x":0,"y":4,"rotation":0}
	builder.confirm()
	check(app.model.room_count(0)==3 and app.model.coins==13800,"Confirm purchases exactly one suite at the listed price")
	check(Layout.entries(app.model,0)[2].kind=="suite","Room type is saved")
	check(builder.selected_room==2 and not builder.placing,"Purchased suite opens its own furnishing controls")
	await capture("62-furnished-suite")
	before = app.model.serialize()
	builder.preview_item("heated")
	await capture("63-object-preview")
	check(app.model.serialize()==before,"Actual-object preview does not buy or equip the furnishing")
	builder.cancel()
	check(app.model.serialize()==before,"Cancelling restores original furniture")
	builder.preview_item("heated")
	app.model.hotels[0].wings = 3
	app.model.life.sync_discoveries(app.model.discovered_cats())
	app._rebuild_world()
	check(builder.selected_item=="heated" and not builder.ghost.is_empty(),"Completing a wing preserves the active furniture preview")
	builder.cancel()
	# Free enough floor for a second bed while retaining the required starter bed.
	var box_uid: String=app.model.furniture.room_items(0,2).filter(func(value): return value.item=="box")[0].uid
	builder._select_object(box_uid); builder.store_selected()
	check(not app.model.furniture.room_items(0,2).any(func(value): return value.uid==box_uid),"Store saves an owned non-bed before placing larger furniture")
	builder.preview_item("heated"); builder.confirm()
	check(app.model.furniture.room_items(0,2).any(func(value): return value.item=="heated") and app.model.coins==13480,"Place immediately buys and saves the bed once")
	builder.confirm()
	check(app.model.coins==13480,"A cleared Place action cannot charge the furnishing twice")
	before=app.model.serialize()
	builder.copy_room()
	check(builder.blueprint_placing and not builder.clipboard.is_empty(),"Copy room enters the current blueprint placement flow")
	builder.cancel(); builder.paste_room()
	check(builder.blueprint_placing and app.model.serialize()==before,"Paste room previews the copied room without charging or saving")
	builder.cancel(); builder._select_room(2)
	var coins: int = app.model.coins_units
	builder.begin_place("suite",2)
	builder.candidate.y = 3
	builder.confirm()
	check(Layout.entries(app.model,0)[2].y==3 and app.model.coins_units==coins,"Moving owned rooms is free")
	before = app.model.serialize()
	var store = app.store
	app.store = FailingStore.new()
	builder.begin_place("regular")
	builder.candidate = {"kind":"regular","x":6,"y":3,"rotation":2}
	builder.confirm()
	check(app.model.serialize()==before,"Failed saves roll back room placement, coins and housekeeping")
	await process_frame
	check(builder.status.text.contains("write failure"),"Build errors remain visible after the next frame")
	app.store = store
	app.save_error = ""
	builder.cancel()
	builder.close()
	check(not app.world.build_mode and app.ui.tab=="Hotel","Closing builder restores normal play")
	var restored = preload("res://scripts/core/hotel_model.gd").new()
	check(restored.restore(app.model.serialize()) and restored.hotels[0].layout==app.model.hotels[0].layout,"Saved rooms restore at their chosen positions")
	# Populate a representative hotel to inspect the complete composition.
	for candidate in [{"kind":"regular","x":6,"y":3,"rotation":2},{"kind":"regular","x":6,"y":6,"rotation":2},{"kind":"regular","x":0,"y":0,"rotation":0},{"kind":"regular","x":6,"y":0,"rotation":2}]:
		check(app.perform_layout("place_room",candidate).ok,"Additional individually placed rooms remain connected")
	app.world.set_motion_enabled(false)
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	app.world.reset_camera()
	app.world.focus_hotel()
	await capture("64-voxel-tycoon-hotel")
	builder.open(2)
	await process_frame
	var point: Vector2 = app.world.camera.unproject_position(Layout.center(app.model.hotels[0].layout[2]))
	check(app.world.room_builder.room_at(point)==2,"Room hit testing resolves the placed suite")
	check(builder.contains_world(point),"Selected suite remains in the unobstructed world area")
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	root.push_input(press,true)
	var release = press.duplicate()
	release.pressed = false
	root.push_input(release,true)
	await process_frame
	check(builder.selected_room==2 and not app.world.dragging,"Mouse taps reach the world-visible room controls and release the gesture")
	var guest = app.world.ensure_cat(0)
	guest.reaction = ""
	guest.place_at(Vector3(0,0.24,5.8))
	var arrival_position: Vector3 = guest.position
	app.world.guest_visit(app.model,0)
	check(guest.position.is_equal_approx(arrival_position) and guest.routine.size()>8,"Guests enter through a route without teleporting into a bed")
	await capture("65-suite-upgraded")
	builder.preview_item("sun_cushion")
	before = app.model.serialize()
	app.ui._open_settings()
	check(not builder.visible and not app.world.build_mode and app.ui.tab=="Settings","Opening Settings safely exits Build and preserves the requested menu")
	check(app.model.serialize()==before,"Opening another menu cancels an unpurchased preview")
	app.ui.close_sheet()
	builder.open(2)
	builder.close()
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(save_key+suffix): DirAccess.remove_absolute(save_key+suffix)
	print("BUILDING TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(0 if failures==0 else 1)
