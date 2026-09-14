extends SceneTree
var failures: int = 0
var app
var key: String

class FailingStore:
	extends RefCounted
	var error_message := "Simulated disk write failure. Please try collecting again."
	func save_model(_model) -> bool:
		return false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func click(control: Control) -> void:
	for frame in range(6): await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	root.push_input(press,true)
	await process_frame
	var release = press.duplicate()
	release.pressed = false
	root.push_input(release,true)
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	key = "res://tmp/startup-offline-"+str(Time.get_ticks_usec())
	var model = preload("res://scripts/core/hotel_model.gd").new()
	model.new_game(int(Time.get_unix_time_from_system())-3600)
	var store = preload("res://scripts/core/game_store.gd").new(key)
	check(store.save_model(model),"Offline startup fixture saves")
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	await process_frame
	app.active = false
	check(app.ui.tab=="Offline","Loading an existing save opens the coin screen")
	await capture("reward")
	var close_button: Button
	for button in app.ui.sheet.find_children("*","Button",true,false):
		if button.name=="SheetBack": close_button = button
	check(close_button!=null,"Offline screen has a close control")
	if close_button!=null:
		check(app.ui.get_global_rect().encloses(close_button.get_global_rect()),"Startup close control stays inside the visible game window")
		await click(close_button)
		check(app.ui.tab=="Hotel" and app.ui.sheet==null,"Actual pointer click dismisses startup coins without collecting them")
	check(app.model.pending_coins>0,"Dismissing keeps unclaimed earnings available")
	await capture("reward-dismissed")
	app.ui.show_offline()
	await process_frame
	var later = app.ui.sheet.find_child("LaterEarnings",true,false)
	check(later != null,"Reward has a Later action")
	if later != null:
		var pending: int = app.model.pending_units
		var wallet: int = app.model.coins_units
		await click(later)
		check(app.model.pending_units == pending and app.model.coins_units == wallet,"Later does not claim")
		app.ui.show_offline()
		await capture("reward-reopened")
		var real_store = app.store
		app.store = FailingStore.new()
		var feedback_before: int = app.ui.success_count
		await click(app.ui.sheet.find_child("CollectEarnings",true,false))
		check(app.model.pending_units == pending and app.model.coins_units == wallet,"Failed reward save rolls back wallet and pending")
		check(app.ui.tab == "Offline" and app.ui.sheet.find_child("InlineError",true,false).visible,"Failed claim keeps reward and inline error")
		check(app.ui.success_count == feedback_before,"Failed save has no success reaction")
		check(app.ui.toast_label.text != app.save_error,"Persistent save error is not duplicated over the pinned action")
		await capture("reward-error")
		app.store = real_store
		await click(app.ui.sheet.find_child("CollectEarnings",true,false))
		check(app.model.pending_units == 0 and app.model.coins_units == wallet+pending,"Retry claims pending exactly once")
		check(app.ui.sheet == null,"Confirmed claim closes reward")
		var claimed: int = app.model.coins_units
		app.ui.show_offline()
		check(app.model.coins_units == claimed,"Reopening cannot claim twice")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(key+suffix): DirAccess.remove_absolute(key+suffix)
	print("STARTUP OFFLINE TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(0 if failures==0 else 1)

func capture(title: String) -> void:
	for frame in range(6): await process_frame
	app.ui.toast_label.hide()
	app.ui.toast_timer = 0
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task8-"+title+"-"+str(DisplayServer.window_get_size().x)+"x"+str(DisplayServer.window_get_size().y)+".png")
