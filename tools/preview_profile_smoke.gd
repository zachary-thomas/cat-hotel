extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if app.save_path!="user://playful-mobile-preview-save" or not OS.get_environment("APPDATA").contains("Purrington Playful Preview 2026-09"):
		push_error("Preview launcher did not isolate its profile")
		quit(1)
		return
	if app.model.started:
		if app.model.settings.ui_text_scale!=1.25:
			push_error("Preview restart did not retain preference")
			quit(1)
			return
		print("PREVIEW PROFILE: second launch retained preview progress")
	else:
		app.start_game()
		app.change_setting("ui_text_scale",1.25)
		print("PREVIEW PROFILE: first launch started fresh and saved independently")
	app.soundscape.shutdown()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	quit(0)
