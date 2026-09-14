extends SceneTree
var failures: int = 0
var app
var key: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func click(control: Control) -> void:
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
	var close_button: Button
	for button in app.ui.sheet.find_children("*","Button",true,false):
		if button.name=="SheetBack": close_button = button
	check(close_button!=null,"Offline screen has a close control")
	if close_button!=null:
		check(app.ui.get_global_rect().encloses(close_button.get_global_rect()),"Startup close control stays inside the visible game window")
		await click(close_button)
		check(app.ui.tab=="Hotel" and app.ui.sheet==null,"Actual pointer click dismisses startup coins without collecting them")
	check(app.model.pending_coins>0,"Dismissing keeps unclaimed earnings available")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(key+suffix): DirAccess.remove_absolute(key+suffix)
	print("STARTUP OFFLINE TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(0 if failures==0 else 1)
