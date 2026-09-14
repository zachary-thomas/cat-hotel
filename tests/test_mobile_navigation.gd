extends SceneTree
var failures := 0
var app
var primary_calls := [0, 0]
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func click(control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.pressed = false
	root.push_input(release, true)
	await process_frame
func settle() -> void:
	for frame in range(4): await process_frame
func capture(title: String) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/" + title + "-" + str(DisplayServer.window_get_size().x) + "x" + str(DisplayServer.window_get_size().y) + ".png")
func check_shell() -> void:
	var safe: Rect2 = app.ui.metrics.safe_rect
	var unit: float = app.ui.metrics.unit
	for nav_button in app.ui.nav_buttons.values():
		check(safe.encloses(nav_button.get_global_rect()), "Dock stays in the safe area")
		check(nav_button.size.x >= 48 * unit and nav_button.size.y >= 48 * unit, "Dock targets remain at least 48 phone units")
		var caption: Label = nav_button.find_child("DockCaption", true, false)
		check(caption.get_global_rect().end.y <= nav_button.get_global_rect().end.y, "Dock caption stays within its target")
	if is_instance_valid(app.ui.sheet):
		check(safe.encloses(app.ui.sheet.get_global_rect()), "Sheet fits the safe area")
		check(app.ui.sheet.get_global_rect().end.y <= app.ui.dock_panel.get_global_rect().position.y, "Sheet leaves every dock target accessible")
func check_tile_art(tile: Button) -> void:
	var drawing: Control = tile.get_child(0).get_child(0)
	var phone_size: Vector2 = drawing.get_global_rect().size / float(app.ui.metrics.unit)
	# Native containers may round the assigned height to a canvas pixel.
	check(drawing.get_global_rect().size.distance_to(Vector2(80, 80) * float(app.ui.metrics.unit)) <= 1.0, "Tile artwork uses an 80×80 phone-unit slot without horizontal stretching")
	check(phone_size.x >= 64 and phone_size.x <= 88 and phone_size.y >= 64 and phone_size.y <= 88, "Displayed tile art stays within 64–88 phone units in both dimensions")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var key := "res://tmp/mobile-navigation-" + str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	app.start_game()
	await settle()
	app.world.set_motion_enabled(false)
	app.world.focus_hotel()
	var world_region: Rect2 = app.ui.metrics.world_rect
	check(app.world.ui_world_rect == world_region,"Camera and world input share the UI rectangle")
	for room in range(2):
		check(world_region.has_point(app.world.camera.unproject_position(app.world.room_builder.bed_position(room))),"Starter bed projects into the available world rectangle")
	var cat_bounds := Rect2()
	var first_point := true
	for point in app.world.visible_mesh_points(app.world.get_cat(0).body):
		var screen: Vector2 = app.world.camera.unproject_position(point)
		if first_point:
			cat_bounds = Rect2(screen,Vector2.ZERO)
			first_point = false
		else: cat_bounds = cat_bounds.expand(screen)
	check(cat_bounds.size.y / float(app.ui.metrics.unit) >= 28,"Starter cat rendered bounds are at least 28 phone units high")
	print("STARTER CAT PHONE HEIGHT: ",cat_bounds.size.y / float(app.ui.metrics.unit)," CAMERA: ",app.world.camera.size)
	await capture("task3-starter")
	check(app.ui.objective_panel.get_global_rect().end.y <= app.ui.metrics.footer_rect.position.y,"Objective settles above the dock before the first capture")
	check(app.ui.objective_button.get_global_rect().encloses(app.ui.progress_label.get_global_rect()),"Objective copy belongs to the whole-card action target")
	app.world.focus_zone(0)
	var target: Vector3 = app.world.camera_target
	var zoom: float = app.world.camera.size
	await click(app.ui.nav_buttons["Cats"])
	await click(app.ui.nav_buttons["Hotel"])
	check(app.world.camera_target.is_equal_approx(target),"Returning from Cats preserves target")
	check(is_equal_approx(app.world.camera.size,zoom),"Returning from Cats preserves zoom")
	await capture("task3-returned-from-cats")
	app.ui.reset_camera_requested.emit()
	check(app.world.overview,"Explicit Fit all still enters overview")
	app.world.focus_hotel()
	var objective_data: Dictionary = app.ui.snapshot.duplicate(true)
	objective_data.pending = 42
	check(app.ui.next_action(objective_data).route == "Offline","Pending earnings lead the objective priority")
	objective_data.pending = 0
	objective_data.grounds.hotels[0].job = {"kind":"clean","duration":30.0,"elapsed":12.0}
	objective_data.repair_remaining = 20
	check(app.ui.next_action(objective_data).route == "Manager","Running manager work precedes repairs and discoveries")
	objective_data.grounds.hotels[0].job = {}
	check(app.ui.next_action(objective_data).route == "Rooms","Running repairs precede pinned discoveries")
	objective_data.repair_remaining = 0
	objective_data.life.pinned = "sunbeam"
	objective_data.room_furnishings = [["sun_cushion"]]
	check(app.ui.next_action(objective_data).title == "Sunbeam Suite" and app.ui.next_action(objective_data).detail.begins_with("1 / 2"),"Pinned discovery names the combination and live room progress")
	objective_data.life.pinned = ""
	objective_data.coins = 0
	var action: Dictionary = app.ui.next_action(objective_data)
	check(action.route == "Upgrades" and action.payload.has("zone") and action.detail.contains(str(objective_data.costs[action.payload.zone])),"Unaffordable upgrade names the real shortfall and preserves its details route")
	app.set_process(false)
	app.ui.render(objective_data)
	await click(app.ui.objective_button)
	check(app.ui.tab == "Upgrades" and app.ui.selected_zone == action.payload.zone,"Objective dispatches to the exact service upgrade")
	app.ui.close_sheet()
	app._update_ui()
	app.set_process(true)
	check(app.ui.nav_buttons.keys() == ["Hotel","Cats","Build","Life","Map"], "Five stable destinations")
	# Stop cleanly on the intentional pre-implementation failure.
	if failures == 0:
		await click(app.ui.nav_buttons["Cats"])
		app.ui.open_cat(0)
		app.ui.go_back()
		check(app.ui.tab == "Cats", "Profile returns to collection")
		await click(app.ui.nav_buttons["Life"])
		app.ui.open_route("Staff", "Life")
		app.ui.go_back()
		check(app.ui.tab == "Life", "Staff returns to Life")
		await click(app.ui.nav_buttons["Build"])
		check(app.build_panel.visible and not app.ui.footer.visible, "Build enters contextual workspace")
	app.build_panel.close()
	await settle()
	await click(app.ui.nav_buttons["Cats"])
	await settle()
	var cat_tile: Button = app.ui.sheet.find_child("Tile_Miso", true, false)
	check(cat_tile != null, "Cat collection uses a whole-card action")
	if cat_tile != null:
		check_tile_art(cat_tile)
		await click(cat_tile)
		check(app.ui.tab == "Pet", "Tapping the whole cat card opens its profile")
		var original_pet = app.ui.pet_view
		for tick in range(3):
			app.model.advance(1)
			app._update_ui()
		check(app.ui.pet_view == original_pet, "Model ticks preserve the live pet viewport")
		await settle()
		await click(app.ui.sheet.back)
		check(app.ui.tab == "Cats", "Visible Back returns to the actual collection parent")
	app.ui.open_route("Staff", "Cats")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.ui.tab == "Cats", "Android Back follows the actual parent, not the dock category")
	app.ui.open_route("Staff", "Life")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(app.ui.tab == "Life", "Escape follows the detail Back route")
	app.ui.open_route("Grounds", "Life")
	app.ui.open_route("Kiosk", "Grounds")
	app.ui.open_route("Grounds", "Kiosk")
	app.ui.go_back()
	check(app.ui.tab == "Kiosk", "Cross-linked detail pages retain their immediate parent")
	app.ui.go_back()
	app.ui.go_back()
	check(app.ui.tab == "Life", "Cross-linked detail history unwinds without a routing loop")
	app.ui._navigate("Cats")
	await settle()
	var remembered: Button = app.ui.sheet.find_child("Tile_Miso", true, false)
	remembered.grab_focus()
	app.ui.sheet.scroll.scroll_vertical = 32
	var scroll_before: int = app.ui.sheet.scroll.scroll_vertical
	app.ui.open_route("Staff", "Cats")
	app.ui.go_back()
	await settle()
	check(app.ui.sheet.scroll.scroll_vertical == scroll_before, "Back restores collection scroll after layout")
	check(root.gui_get_focus_owner().name == "Tile_Miso", "Back restores the named card focus")
	await capture("task2-cats-100")
	# Build a long body to exercise the reusable fixed action contract directly.
	app.ui.open_route("Life")
	app.ui.tab = "TestSheet"
	var body: VBoxContainer = app.ui._base_sheet("A little more lovely", 650)
	for i in range(12): body.add_child(app.ui.paragraph("A cozy corner for every cat. Take your time and make yourself at home."))
	app.ui.set_primary_action("Make it cozy", func(): primary_calls[0] += 1)
	var primary: Button = app.ui.set_primary_action("Make it cozy", func(): primary_calls[1] += 1)
	await settle()
	var position_before: Vector2 = primary.global_position
	app.ui.sheet.scroll.scroll_vertical = 9999
	await settle()
	check(primary.global_position == position_before, "Primary action stays fixed when the body scrolls")
	await click(primary)
	check(primary_calls == [0, 1], "Replacing a primary action disconnects its old callback")
	for scale in [1.0, 1.25, 1.5]:
		app.change_setting("ui_text_scale", scale)
		await settle()
		check_shell()
		check(primary.size.y >= 56 * app.ui.metrics.unit, "Primary action is at least 56 phone units")
		await capture("task2-sheet-" + str(roundi(scale * 100)))
	app.ui.close_sheet()
	await settle()
	check(app.ui.objective_panel.get_global_rect().end.y <= app.ui.metrics.footer_rect.position.y,"Large-text objective leaves every dock target clear")
	await capture("task3-objective-150")
	app.ui._navigate("Life")
	await settle()
	check_shell()
	await capture("task2-life-150")
	app.ui.open_route("View", "Hotel")
	await settle()
	await click(app.ui.view_button)
	check(app.model.settings.exterior and app.ui.tab == "Hotel", "View changes Inside/Outside through the real setting")
	app.ui._navigate("Cats")
	await settle()
	# Shade consumes the initial pointer event before routing Back.
	var shade_press := InputEventMouseButton.new()
	shade_press.button_index = MOUSE_BUTTON_LEFT
	shade_press.pressed = true
	shade_press.position = Vector2(2, 2)
	root.push_input(shade_press, true)
	check(app.ui.tab == "Hotel" and root.is_input_handled(), "Shade dismisses and consumes the pointer event")
	var reset_count := [0]
	app.ui.reset_camera_requested.connect(func(): reset_count[0] += 1)
	app.ui._navigate("Hotel")
	check(reset_count[0] == 0, "Hotel navigation preserves the camera view")
	app.active = false
	app.ui._navigate("Cats")
	await settle()
	var existing_tile: Button = app.ui.sheet.find_child("Tile_Miso", true, false)
	check_tile_art(existing_tile)
	var drawing: Control = existing_tile.get_child(0).get_child(0)
	var previous_size := drawing.size
	app.ui.metrics.unit *= 1.25
	app.ui._apply_control_metrics(app.ui)
	await settle()
	check_tile_art(existing_tile)
	check(drawing.size.distance_to(previous_size * 1.25) <= 1.5, "Existing artwork resizes with phone metrics without rebuilding its tile")
	app.ui.relayout()
	await settle()
	var unit: float = app.ui.metrics.unit
	var viewport: Vector2 = app.ui.size
	var inset_safe := Rect2(Vector2(12, 24) * unit, viewport - Vector2(30, 44) * unit)
	app.ui.metrics = app.ui.PhoneLayout.measure(viewport, inset_safe, 1.0 / unit, 1.5)
	app.ui._apply_shell_geometry()
	app.ui._layout_navigation()
	app.ui.sheet.relayout(app.ui._sheet_bounds())
	await settle()
	check_shell()
	check_tile_art(existing_tile)
	await capture("task2-safe-150")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix): DirAccess.remove_absolute(key + suffix)
	print("MOBILE NAVIGATION TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
