extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="user://creative-package-smoke"
	root.add_child(app)
	await create_timer(0.3).timeout
	check(app.model.state.version=="creative-hotel-1","Pack opens creative schema")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/creative_hotel.tscn","Pack default entry is creative even without launcher")
	var expected_name := "Purrington Hotel Preview" if OS.get_cmdline_user_args().has("--android-package") else "Purrington Creative Social Preview"
	check(ProjectSettings.get_setting("application/config/name")==expected_name,"Pack uses its own Godot save directory")
	check(app.save_path=="user://creative-package-smoke","Pack keeps explicit isolated save location")
	check(app.world.room_nodes.size()==app.model.hotel().rooms.size(),"Pack renders dynamic rooms")
	check(not FileAccess.file_exists("res://docs/mobile-ui-redesign/01-hotel-build-cat-care.png"),"Pack excludes design boards")
	if OS.get_cmdline_user_args().has("--verify-reopen"):
		check(app.model.hotel(0).plots.has("east"),"Pack restart retains land")
		check(is_equal_approx(float(app.model.state.settings.ui_text_scale),1.5),"Pack restart retains text preference")
		check(app.model.state.entitlements.has("purrington.forest_lodge"),"Pack restart retains test expansion progression")
		check(app.model.is_god_mode(),"Pack restart retains God mode")
	else:
		app.model.state.coins=10000
		if not app.model.hotel().plots.has("east"): check(app.perform("buy_plot",{"id":"east"}).ok,"Pack can purchase land")
		app.model.state.settings.ui_text_scale=1.5
		check(app.test_purchase("purrington.forest_lodge").ok,"Pack test expansion works")
		check(app.travel(2).ok,"Pack opens the forest map")
		check(app.world.room_nodes.size()==app.model.hotel().rooms.size(),"Forest geometry follows travel")
		check(app.travel(0).ok,"Pack returns to Meadow")
		app.ui.open_tab("Settings")
		app.ui._setting("god_mode",true)
		check(app.model.is_god_mode() and app.model.hotel(3).owned,"Pack Settings activates God mode and all destinations")
		check(app.model.catalog_price("place_object",{"item":"fountain"})==0,"Pack catalog reflects free editing")
		check(app.save(),"Pack writes its journal")
	app.soundscape.shutdown()
	await create_timer(0.2).timeout
	app.queue_free(); await process_frame
	print("CREATIVE PACK: %d failures" % failures)
	quit(1 if failures else 0)
