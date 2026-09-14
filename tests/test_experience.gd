extends SceneTree
var failures: int = 0
var app
var key: String

class BrokenStore:
	extends RefCounted
	var error_message: String = "Simulated storage failure"
	func save_model(_model) -> bool:
		return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	for frame in range(6): await process_frame
	app.ui.sheet.scroll.ensure_control_visible(control)
	for frame in range(6): await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/"+name+".png")
	if is_instance_valid(app.ui.sheet):
		check(app.ui.get_global_rect().encloses(app.ui.sheet.get_global_rect()),"The "+name+" screen fits the viewport")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	key = "res://tmp/experience-"+str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	app.start_game()
	app.ui.open_cat(0)
	await process_frame
	check(app.ui.pet_view.cat != null,"Cat profiles contain a live 3D cat")
	var stage = app.ui.pet_view
	await click(stage)
	check(app.ui.pet_view == stage,"Real petting input preserves the live care stage")
	check(not app.ui.pet_view.held,"Releasing a petting gesture stops repeated interactions")
	await process_frame
	check(app.model.life.state.cats[0].bond==6,"Petting through the UI changes the saved relationship")
	check(app.soundscape.recent_events.has("purr"),"Petting produces the purr audio")
	check(app.world.get_cat(0).reaction=="purr","Petting also animates the real hotel cat")
	await capture("20-petting")
	for pose in ["purr","brush","pounce","chase","groom","yawn","stretch","settle","loaf","box","blanket","sniff","friendship","arrival","departure","checkin","cook","towels","construction","celebrate","inspect","zoomies","missed_jump"]:
		app.ui.pet_view.cat.react(pose)
		for frame in range(250):
			app.ui.pet_view.cat._process(1.0/60.0)
		check(app.ui.pet_view.cat.body.transform.is_finite(),"Animation "+pose+" keeps valid transforms")
	app.model.coins = 20000
	app.model.hotels[0].purchases = 6
	app.model.hotels[0].zones = [3,2,2,2]
	app._rebuild_world()
	app._update_ui()
	app.ui._navigate("Decorate")
	check(preload("res://tests/fixtures/build_actions.gd").replace_trio(app.model,0,["sun_cushion","perch","plant"]).ok,"Apply furnishings through instance ownership")
	app.world.apply_life(app.model)
	check(app.model.life.state.combos.has("sunbeam"),"Decorating discovers a real combination")
	check(app.world.room_builder.room_nodes[0].get_child_count()>0,"Room choices create visible furnishings in the room module")
	await capture("21-decorate")
	app.ui._navigate("Life")
	await capture("22-hotel-life")
	app.perform_action("train",{"staff":1})
	app.perform_action("skill",{"staff":1,"skill":1})
	app.world.staff_selected.emit(1)
	check(app.ui.get("selected_staff") == 1,"World worker index selects the matching staff card")
	await capture("23-staff")
	app.ui._navigate("Events")
	app.perform_action("event",{"id":"nap"})
	check(app.world.event_active,"An active event decorates the hotel")
	await capture("24-events")
	app.model.advance(46)
	app._update_ui()
	app.world.apply_life(app.model)
	check(not app.world.event_active and app.model.life.state.hotels[0].trophies.has("nap"),"Event completion clears the gathering and awards a trophy")
	var rewarded: float = app.model.coins
	app.ui._navigate("Events")
	app.ui._navigate("Life")
	app.ui._navigate("Events")
	check(app.model.coins == rewarded,"Reopening event results does not reward twice")
	app.ui._navigate("Discoveries")
	app.perform_action("inspect")
	app.model.advance(13)
	app._update_ui()
	await capture("25-discoveries")
	app.ui._navigate("Journal")
	await capture("26-scrapbook")
	app.ui._navigate("Shop")
	await capture("27-expansions")
	check(not app.commerce.store_ready and app.ui.purchase_buttons[0].disabled,"A desktop build cannot pretend to take a real payment")
	var real_store = app.store
	app.store = BrokenStore.new()
	app._fulfill_purchase("purrington.forest_lodge","test:forest")
	check(not app.model.hotels[2].owned and not app.commerce.ads_removed,"Failed storage never marks an expansion fulfilled")
	app.store = real_store
	app._save()
	app._fulfill_purchase("purrington.forest_lodge","test:forest")
	check(app.model.hotels[2].owned and app.commerce.ads_removed,"A saved purchase unlocks a hotel and removes all ads")
	app.visit_hotel(2)
	check(app.world.hotel_index==2,"Forest Lodge is a playable destination")
	app.ui.toast_label.hide()
	await capture("28-forest")
	app._fulfill_purchase("purrington.snowcap_spa","test:snowcap")
	app.visit_hotel(3)
	check(app.world.hotel_index==3 and app.model.life.known(17),"Snowcap unlocks its scenery and expansion cats")
	app.ui.toast_label.hide()
	await capture("29-snowcap")
	app.change_setting("watch",true)
	check(not app.ui.header.visible and app.ui.watch_exit.visible,"Watch mode clears the HUD and retains an exit")
	app.world._process(2)
	await capture("30-watch")
	check(not app.ui.toast_label.visible,"Watch mode remains quiet across frames")
	app.change_setting("watch",false)
	if DisplayServer.get_name() != "headless":
		app.ui._navigate("Journal")
		await click(app.ui.sheet.find_child("TakeHotelPhoto",true,false))
		for frame in range(8): await process_frame
		var photo: String = app.model.life.state.memories[-1].get("photo","")
		check(photo != "" and FileAccess.file_exists(photo),"Photo mode saves an actual image and album entry")
		check(app.ui.visible,"Photo mode restores the controls")
		app.ui._navigate("Journal")
		check(app.ui.snapshot.life.memories[-1].get("photo","")==photo,"The photo is immediately available to the scrapbook")
		await capture("31-photo-album")
	app.model.life.state.cats[0].bond = 12
	app.model.life.state.cats[2].bond = 12
	app.model.hotels[3].zones[2] = 1
	app.perform_action("playdate",{"cat":0,"other":2})
	check(app.world.transient_pairs.size()==1,"Playdates bring two real cats together")
	app.world._process(8)
	check(app.world.transient_pairs.is_empty(),"Cats resume their positions after a playdate")
	var restored = app.Model.new()
	check(app.store.load_model(restored,int(Time.get_unix_time_from_system())),"Expanded gameplay can be loaded from disk")
	check(restored.hotels[2].owned and restored.hotels[3].owned and restored.life.owns("purrington.snowcap_spa"),"Expansion access survives reopening")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(key+suffix):
			DirAccess.remove_absolute(key+suffix)
	print("EXPERIENCE TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
