extends SceneTree
var failures := 0
var app
var care_actions: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for frame in range(6): await process_frame
func click(control: Control) -> void:
	await settle()
	app.ui.sheet.scroll.ensure_control_visible(control)
	await settle()
	var point := control.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func capture(title: String) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task5-" + title + "-" + str(DisplayServer.window_get_size().x) + "x" + str(DisplayServer.window_get_size().y) + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var key := "res://tmp/mobile-views-" + str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	app.start_game()
	app.ui.action_requested.connect(func(action, payload):
		if action == "interact": care_actions.append(payload.kind)
	)
	app.ui.open_cat(0)
	await settle()
	var stage = app.ui.pet_view
	var bond: int = app.model.life.state.cats[0].bond
	await click(app.ui.sheet.find_child("Interact_pet", true, false))
	check(app.model.life.state.cats[0].bond > bond, "Pet changes real friendship")
	check(app.ui.pet_view == stage, "Friendship refresh preserves petting stage")
	var progress = app.ui.sheet.find_child("CareFriendship", true, false)
	if progress != null: check(progress.value == app.model.life.state.cats[0].bond, "Care friendship bar reflects the real bond")
	check(absf(stage.size.y - 220 * float(app.ui.metrics.unit)) <= 1.0, "Care stage is 220 phone units within canvas rounding")
	app.ui.sheet.scroll.scroll_vertical = 0
	await settle()
	var touch := InputEventScreenTouch.new()
	touch.position = stage.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	check(stage.held, "Real held touch begins petting")
	touch = InputEventScreenTouch.new()
	touch.position = Vector2(1, 1)
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	check(not stage.held, "Releasing outside the stage stops held touch")
	app.ui.go_back()
	check(app.ui.tab == "Cats", "Care returns to collection even when opened from hotel")
	# Fail cleanly against the previous collection before exercising its new controls.
	var filter = app.ui.sheet.find_child("CatFilter_To_meet", true, false) if is_instance_valid(app.ui.sheet) else null
	check(filter != null, "Collection has a discovery filter")
	if filter != null:
		await capture("collection-100")
		await click(filter)
		await settle()
		var unknown = app.ui.sheet.find_child("CatCard_11", true, false)
		check(unknown != null and unknown.get_child(0).get_child(0).locked, "Unknown portrait remains a silhouette")
		await click(unknown)
		check(app.ui.sheet.find_child("PettingView", true, false) == null, "Unknown cat has no live care actions")
		check(not app.ui.sheet_content.get_child(0).text.contains("Loves"), "Unknown preference stays hidden")
		await click(app.ui.sheet.find_child("InviteTraveler", true, false))
		check(not app.ui.toast_label.text.contains("heated cushions"), "An unsuccessful invitation does not reveal an unknown preference")
		check(not app.model.life.state.cats[11].preference, "Invitation failure does not discover the preference")
		app.ui.go_back()
		await settle()
		check(app.ui.cat_filter == "To meet", "Back preserves collection filter")
		app.ui.sheet.scroll.scroll_vertical = 200
		await settle()
		var scroll_before: int = app.ui.sheet.scroll.scroll_vertical
		app.ui.open_cat(11)
		app.ui.go_back()
		await settle()
		check(app.ui.sheet.scroll.scroll_vertical == scroll_before, "Care Back restores collection scroll")
		await click(app.ui.sheet.find_child("CatCard_17", true, false))
		check(app.ui.sheet.find_child("InviteTraveler", true, false) == null, "Unowned expansion cannot be invited")
		check(app.ui.sheet.find_child("CatExpansion", true, false) != null, "Expansion discovery offers the shop")
		app.ui._navigate("Cats")
		await settle()
		await click(app.ui.sheet.find_child("CatFilter_Met", true, false))
		await settle()
		await click(app.ui.sheet.find_child("CatCard_0", true, false))
		await capture("care-100")
		await click(app.ui.sheet.find_child("CatInvitations", true, false))
		check(app.ui.tab == "Invitations", "Invitation is a child route")
		var playdate = app.ui.sheet.find_child("Playdate_1", true, false)
		check(playdate.disabled, "Playdate requires lounge and both bonds")
		app.ui.go_back()
		check(app.ui.tab == "Pet", "Invitation Back returns to care")
		app.change_setting("ui_text_scale", 1.5)
		await settle()
		var toys: GridContainer = app.ui.sheet.find_child("toys", true, false)
		check(toys.columns == 2, "Large text reflows toys to two columns")
		care_actions.clear()
		for kind in ["pet", "brush", "wand", "yarn", "cushion", "box"]:
			var toy = app.ui.sheet.find_child("Interact_" + kind, true, false)
			await click(toy)
			check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(toy.get_global_rect()), "Every large-text toy is reachable: " + kind)
			check(toy.size.x >= 48 * app.ui.metrics.unit and toy.size.y >= 48 * app.ui.metrics.unit, "Toy has a full touch target")
		check(care_actions == ["pet", "brush", "wand", "yarn", "cushion", "box"], "All six real toy clicks dispatch their distinct gameplay actions")
		await capture("toys-150")
		await click(app.ui.sheet.find_child("CatInvitations", true, false))
		await settle()
		app.ui.sheet.scroll.scroll_vertical = 9999
		await capture("invitations-150")
		check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(app.ui.sheet.find_child("Playdate_2", true, false).get_global_rect()), "Last large-text invitation is reachable by scrolling")
		app.ui.go_back()
		app.ui.go_back()
		await settle()
		check(app.ui.sheet.find_child("CatCollection", true, false).columns == 1, "Large text reflows collection to one column")
		await capture("collection-150")
		# Live invitation and favorite controls still execute the existing model commands.
		app.ui.open_cat(1)
		await settle()
		app.ui.sheet.scroll.ensure_control_visible(app.ui.sheet.find_child("CatFavorite", true, false))
		await capture("favorite-before-150")
		await click(app.ui.sheet.find_child("CatFavorite", true, false))
		check(app.model.life.state.favorite == 1, "Favorite button changes the actual hotel favorite")
		app.ui.open_route("Invitations", "Pet")
		await settle()
		await click(app.ui.sheet.find_child("InviteHotel", true, false))
		check(app.model.life.state.memories.any(func(entry): return entry.id == "invite_0_1"), "Hotel invitation sends the selected cat to this hotel")
		app.model.life.state.cats[1].bond = 10
		app.model.life.state.cats[2].bond = 10
		app.model.hotels[0].zones[2] = 1
		app._update_ui()
		app.ui._invitations()
		await settle()
		check(not app.ui.sheet.find_child("Playdate_2", true, false).disabled, "Lounge and both bonds enable a playdate")
		await click(app.ui.sheet.find_child("Playdate_2", true, false))
		check(app.model.life.state.cats[1].friend == 2 and app.model.life.state.cats[2].friend == 1, "Playdate button creates the selected real friendship pair")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix): DirAccess.remove_absolute(key + suffix)
	print("MOBILE VIEWS TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
