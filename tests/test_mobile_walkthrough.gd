extends SceneTree
const Interior = preload("res://scripts/core/furniture_layout.gd")
var app
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in range(6): await process_frame
func tap(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()
func click(control: Control) -> void:
	check(is_instance_valid(control),"Walkthrough action exists")
	if not is_instance_valid(control): return
	if is_instance_valid(app.ui.sheet) and app.ui.sheet.scroll.is_ancestor_of(control): app.ui.sheet.scroll.ensure_control_visible(control)
	elif app.build_panel.visible:
		var scroll = app.build_panel.find_child("BuildScroll",true,false)
		if scroll!=null and scroll.is_ancestor_of(control): scroll.ensure_control_visible(control)
	await settle()
	await tap(control.get_global_rect().get_center())
func capture(state: String) -> void:
	await create_timer(0.6).timeout
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var extent := DisplayServer.window_get_size()
	root.get_texture().get_image().save_png("res://tmp/walkthrough-%dx%d-%d-%s.png" % [extent.x,extent.y,roundi(app.model.settings.ui_text_scale*100),state])
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var key := "user://fresh-walkthrough-"+str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await settle()
	check(not app.model.started,"Fresh walkthrough opens Welcome without a save")
	await capture("01-welcome")
	await click(app.ui.welcome.find_child("PlayButton",true,false))
	check(app.model.started,"Pointer Play starts a normal game")
	# Freeze passive time only, to record the exact actions without changing normal starting progression.
	app.active = false
	var starting: float = app.model.coins
	check(starting>=1000 and starting<1001,"Normal starting wallet is 1000 Cat Coins plus elapsed income")
	await capture("02-hotel")
	await click(app.ui.nav_buttons["Cats"])
	await capture("03-cats")
	await click(app.ui.sheet.find_child("CatCard_0",true,false))
	var before_bond: int = app.model.life.state.cats[0].bond
	await click(app.ui.sheet.find_child("Interact_pet",true,false))
	var after_bond: int = app.model.life.state.cats[0].bond
	check(after_bond>before_bond,"Pointer care grows real friendship")
	app.ui.sheet.scroll.scroll_vertical = 0
	await capture("04-care")
	await click(app.ui.nav_buttons["Build"])
	check(app.build_panel.visible,"Pointer Build opens catalogue")
	await capture("05-build-catalogue")
	await click(app.build_panel.find_child("Category_play",true,false))
	await click(app.build_panel.find_child("FurnitureCard_scratch",true,false))
	check(app.build_panel.selected_item=="scratch","Pointer selects affordable furniture")
	# Locate a valid visible floor cell, then send the same real pointer input as a player.
	var placed := false
	for room in range(app.model.room_count(0)):
		var data: Dictionary = app.model.hotels[0].layout[room]
		var items: Array = app.model.furniture.room_items(0,room)
		var dims := Interior.dimensions(data.kind)
		for y in range(dims.y):
			for x in range(dims.x):
				var candidate := {"uid":"preview","item":"scratch","hotel":0,"room":room,"x":x,"y":y,"rotation":0}
				if not Interior.validate(data,items+[candidate],true).ok: continue
				var world_point: Vector3 = Interior.local_to_world(data,Vector2(x+0.15,y+0.15))
				var point: Vector2 = app.world.camera.unproject_position(world_point)
				if not app.build_panel.metrics.world_rect.has_point(point): continue
				await tap(point)
				if app.build_panel.validity.get("ok",false):
					placed = true
					break
			if placed: break
		if placed: break
	check(placed,"Real floor pointer creates a valid preview")
	await capture("06-build-preview")
	var before_coins: float = app.model.coins
	var price: int = app.build_panel.Catalog.item("scratch").cost
	await click(app.build_panel.confirm_button)
	check(is_equal_approx(app.model.coins,before_coins-price),"Pointer Place spends the displayed price exactly once")
	check(app.model.furniture.state.instances.any(func(item): return item.item=="scratch"),"Placed furniture is saved")
	await capture("07-build-placed")
	print("WALKTHROUGH SETTLED BUILD: camera ",app.world.camera.size," target ",app.world.camera_target," world rect ",app.build_panel.metrics.world_rect)
	await click(app.build_panel.find_child("CloseBuilder",true,false))
	check(app.ui.tab=="Hotel" and not app.build_panel.visible,"Pointer Play returns immediately")
	await click(app.ui.nav_buttons["Life"])
	await capture("08-life")
	await click(app.ui.nav_buttons["Map"])
	await capture("09-map")
	await click(app.ui.nav_buttons["Hotel"])
	await click(app.ui.header.find_child("SettingsButton",true,false))
	await click(app.ui.sheet.find_child("TextScale_150",true,false))
	check(app.model.settings.ui_text_scale==1.5,"Pointer Settings changes global text size")
	app.ui.sheet.scroll.scroll_vertical = 0
	await capture("10-settings")
	await click(app.ui.sheet.back)
	await capture("11-hotel-return")
	print("FRESH WALKTHROUGH: coins ",starting," -> ",app.model.coins,"; furniture cost ",price,"; Miso friendship ",before_bond," -> ",after_bond,"; save ",ProjectSettings.globalize_path(key))
	app.soundscape.shutdown()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print("MOBILE WALKTHROUGH TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(1 if failures else 0)
