extends SceneTree
class RejectingStore extends RefCounted:
	var error_message: String="Saving failed for this test. Retry when space is available."
	func save_model(_model) -> bool: return false
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not FileAccess.file_exists("res://scenes/creative_hotel.tscn"):
		check(false,"The isolated creative preview must have its own runnable scene")
		quit(1); return
	var app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="res://tmp/creative-app-"+str(Time.get_ticks_usec())
	root.add_child(app)
	await process_frame
	check(app.model.state.version=="creative-hotel-1","Creative preview uses the new save schema")
	check(app.ui!=null and app.world!=null,"Creative preview connects live world and UI")
	check(app.perform("buy_plot",{"id":"east"}).ok,"App commits the actual land purchase")
	var saved=app.model.serialize()
	var store=load("res://scripts/core/game_store.gd").new(app.save_path)
	var restored=load("res://scripts/creative/creative_model.gd").new()
	var loaded: bool=store.load_model(restored,int(saved.last_seen))
	check(loaded,"Two-slot store loads a creative save")
	if not loaded:
		app.queue_free(); await process_frame; quit(1); return
	check(restored.hotel().plots.has("east"),"Land survives actual journal persistence")
	check(app.perform("undo",{}).ok,"App exposes build history")
	var real_store=app.store
	app.store=RejectingStore.new()
	app.request_close()
	check(app._close_dialog!=null and app._close_dialog.visible,"A failed final save keeps the game open with retry controls")
	check(not app.save_error.is_empty(),"A failed save has visible feedback for the game interface")
	app._close_dialog.hide(); app.store=real_store
	check(app.save() and app.save_error.is_empty(),"Retry clears the save error after a successful journal write")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/creative_hotel.tscn","Normal project Play starts the redesigned hotel")
	app.ui.open_tab("Settings")
	var god_toggle: CheckButton
	for button in app.ui.find_children("*","CheckButton",true,false):
		if button.text=="God mode": god_toggle=button
	check(god_toggle!=null,"Settings exposes a God mode switch")
	if god_toggle!=null: god_toggle.button_pressed=true
	check(app.model.is_god_mode() and app.model.hotel(3).owned,"Settings switch enables all God-mode unlocks")
	check(app.ui._wallet_text()=="FREE","The live header makes free editing visible")
	check(store.load_model(restored,int(app.model.state.last_seen)) and restored.is_god_mode(),"The settings toggle is persisted by the actual journal")
	if OS.get_cmdline_user_args().has("--capture-god-mode") and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute("res://docs/creative-preview/god-mode")
		for dimensions in [Vector2i(360,640),Vector2i(390,844),Vector2i(1280,800)]:
			root.size=dimensions; root.content_scale_size=dimensions
			await process_frame
			for scale_value in [1.0,1.5]:
				app.model.state.settings.ui_text_scale=scale_value
				for tab in ["Settings","Build"]:
					app.ui.open_tab(tab)
					await process_frame; await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://docs/creative-preview/god-mode/%s-%dx%d-%d.png" % [tab.to_lower(),dimensions.x,dimensions.y,roundi(scale_value*100)])
					for control in app.ui._surface.get_children():
						if control is PanelContainer:
							check(control.get_global_rect().end.x<=dimensions.x+2 and control.get_global_rect().end.y<=dimensions.y+2,"God-mode %s panel fits %s at %d%% text: %s" % [tab,dimensions,roundi(scale_value*100),control.get_global_rect()])
	app.ui._setting("god_mode",false)
	check(not app.model.is_god_mode(),"The Settings switch returns to normal prices")
	app.request_new_game()
	check(app._reset_dialog!=null and app._reset_dialog.visible,"Start fresh presents an explicit progress-reset confirmation")
	app._reset_dialog.hide()
	var previous_model=app.model
	var previous_state: Dictionary=app.model.serialize()
	app.store=RejectingStore.new()
	check(not app.start_new_game().ok,"A fresh start waits for a successful save")
	check(app.model==previous_model and app.model.serialize()==previous_state,"A failed reset keeps the original model and all progress")
	app.store=real_store
	check(app.start_new_game().ok,"The confirmed fresh start is saved")
	check(app.model.hotel().plots.is_empty() and not app.model.is_god_mode(),"A fresh preview restores normal starter progress")
	check(app.world.model==app.model and app.ui.active_tab=="Hotel","The fresh hotel immediately appears in the live world")
	app.soundscape.shutdown()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print("CREATIVE APP: %d failures" % failures)
	quit(1 if failures else 0)
