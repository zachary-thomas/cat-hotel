extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://pack-smoke-" + str(Time.get_ticks_usec())
	root.add_child(app)
	await create_timer(0.2).timeout
	if app.world.building.get_child_count() < 20 or not app.soundscape.music_players[app.soundscape.current_player].playing:
		push_error("Pack failed to create scenery and music")
		quit(1)
		return
	if not FileAccess.file_exists("res://commerce.cfg"):
		push_error("Pack is missing commerce configuration")
		quit(1)
		return
	app.start_game()
	app.model.coins = 1200
	app.model.hotels[0].purchases = 2
	app.expand_hotel()
	if app.model.repair_remaining(0) <= 0 or app.world.builders.size() != 2:
		push_error("Pack failed to start construction")
		quit(1)
		return
	app.model.advance(31)
	app._sync_repairs()
	app._update_ui()
	if app.model.room_count(0) != 2 or not app.world.builders.is_empty():
		push_error("Pack failed to complete construction")
		quit(1)
		return
	app.model.coins = 2000
	app.model.hotels[0].purchases = 4
	app.build_panel.open()
	app.build_panel.begin_place("regular")
	app.build_panel.candidate = {"kind":"regular","x":0,"y":6,"rotation":0}
	app.build_panel.confirm()
	if app.model.room_count(0)!=3 or app.world.room_builder.room_nodes.size()!=3:
		push_error("Pack failed to place a player-designed room")
		quit(1)
		return
	app.build_panel.preview_item("sun_cushion")
	if app.model.life.state.hotels[0].rooms[2][0]!="mat":
		push_error("Pack preview changed saved furniture before confirmation")
		quit(1)
		return
	app.build_panel.confirm()
	app.build_panel.close()
	if app.model.life.state.hotels[0].rooms[2][0]!="sun_cushion":
		push_error("Pack failed to purchase previewed furniture")
		quit(1)
		return
	app.model.coins = 2000
	app.perform_grounds("amenity",{"id":"pool"})
	app.perform_grounds("trim",{"index":0})
	app.model.advance(30)
	app.world.apply_life(app.model)
	app._update_ui()
	if app.world.neighborhood.amenity_cats.size() != 1 or app.model.grounds.hotels[0].chores != 1:
		push_error("Pack failed to create amenities or finish a manager job")
		quit(1)
		return
	app.perform_grounds("hire_maid")
	if not app.world.neighborhood.maid.visible:
		push_error("Pack failed to hire housekeeping")
		quit(1)
		return
	app.change_setting("exterior",true)
	if not app.world.exterior_view or not app.world.shell.exterior.visible or app.world.shell.doors.size() != 6:
		push_error("Pack failed to create the complete hotel and working room doors")
		quit(1)
		return
	app.change_setting("exterior",false)
	app.world.shell.open_door(0)
	app.world.shell._process(0.3)
	if app.world.shell.doors[0].pivot.rotation.y >= 0:
		push_error("Pack failed to open the room door")
		quit(1)
		return
	app.ui.open_cat(0)
	await process_frame
	app.ui.pet_view.play("pet")
	if app.ui.pet_view.cat == null:
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--commerce-preview"):
		if not app.commerce.preview or not app.commerce.store_ready:
			push_error("Pack test-store mode did not activate")
			quit(1)
			return
		app.commerce.purchase("purrington.forest_lodge")
		if not app.model.hotels[2].owned or not app.commerce.ads_removed:
			push_error("Pack test purchase failed")
			quit(1)
			return
		app.visit_hotel(2)
	print("PACK SMOKE: isometric views, doors, scenery, amenities, manager jobs, housekeeping, repairs, audio, petting, commerce config and selected store mode passed")
	app.soundscape.shutdown()
	app.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0)

