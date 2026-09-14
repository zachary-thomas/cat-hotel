extends SceneTree
## Reproducible actual-game motion capture; uses a disposable save only.
var app
var save_key: String
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp/motion-preview")
	app = load("res://scenes/main.tscn").instantiate()
	save_key = "res://tmp/motion-preview/save-" + str(Time.get_ticks_usec())
	app.save_path = save_key
	root.add_child(app)
	app.start_game()
	app.model.coins = 15000
	app.model.hotels[0].zones = [3,2,2,2]
	app.model.hotels[0].purchases = 6
	app.expand_hotel()
	app.model.advance(31)
	app._sync_repairs()
	app._update_ui()
	app.change_setting("evening", true)
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await process_frame
	for i in range(48):
		await create_timer(1.0/12.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/motion-preview/frame-%03d.png" % i)
	print("MOTION CAPTURE: 48 real rendered frames; cats and foliage active")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(save_key + suffix):
			DirAccess.remove_absolute(save_key + suffix)
	quit()
