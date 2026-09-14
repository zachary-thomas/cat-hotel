extends SceneTree

var failures: int = 0
var app
var key: String

class FailingStore:
	extends RefCounted
	var error_message: String = "Simulated disk write failure"
	func save_model(_model) -> bool:
		return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("res://tmp/" + name + ".png")

func click(control: Control) -> void:
	# Container layout must settle in headless runs too, before reading hit bounds.
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	key = "res://tmp/app-test-" + str(Time.get_ticks_usec())
	var scene = load("res://scenes/main.tscn")
	app = scene.instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	check(not app.model.started, "Fresh project opens title screen")
	await capture("01-title")
	await click(app.ui.welcome.find_child("PlayButton", true, false))
	await process_frame
	check(app.model.started and app.model.rate() == 10, "Play starts automatic income")
	for nav_button in app.ui.nav_buttons.values():
		check(app.ui.get_global_rect().encloses(nav_button.get_global_rect()), "Navigation fits the phone viewport")
		check(nav_button.size.y >= 48, "Navigation preserves touch target size")
	var original_cat = app.world.actors[2]
	app.ui.open_upgrades(0)
	await process_frame
	var buy = app.ui.sheet.find_child("PurchaseUpgrade", true, false)
	check(buy != null and not buy.disabled, "First upgrade is affordable")
	var initial_feedback: int = app.ui.success_count
	await click(buy)
	await process_frame
	check(app.model.hotels[0].zones[0] == 2 and app.model.rate() == 20, "UI purchase changes real model")
	check(app.ui.success_count == initial_feedback+1,"Successful upgrade emits exactly one visual reaction")
	check(app.world.actors[2] == original_cat, "Upgrades preserve existing cat routines")
	app.buy_upgrade(1)
	app.buy_upgrade(2)
	app.ui.close_sheet()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	# Construction reactions complete before the attendant resumes the aisle route.
	original_cat._process(4.1)
	var before_walk: Vector3 = original_cat.position
	for i in range(180):
		original_cat._process(1.0 / 60.0)
	check(original_cat.position.distance_to(before_walk) > 0.5, "Staff follow their aisle routine")
	check(app.world.actors.size() == 8, "Opening services adds a chef, eating and playing guests")
	app.world.reset_camera()
	await capture("02-hotel")
	check(app.ui.metrics.world_rect.end.y <= app.ui.dock_panel.get_global_rect().position.y, "Shared world geometry leaves the dock clear")
	for x in [-5.9, 5.9]:
		for z in [-17.2, 5.0]:
			var point: Vector2 = app.world.camera.unproject_position(Vector3(x,0.2,z))
			check(app.ui.world_input_contains(point) and point.x > 0 and point.x < app.ui.size.x, "The entire hotel fits between the controls")
	# Label budgeting must never remove the actual wing's world selection.
	app.world._select(app.world.camera.unproject_position(Vector3(0,0.2,-15.9)))
	await process_frame
	check(app.ui.tab == "Rooms" and app.ui.selected_wing == 2, "Tapping an unlabeled future wing opens that wing's repair details")
	check(app.ui.sheet.find_child("BuildExpansion",true,false).disabled, "Future wings explain their requirements without allowing an out-of-order purchase")
	app.ui.close_sheet()
	app.ui.open_upgrades(0)
	await capture("03-upgrades")
	app.ui._navigate("Map")
	await process_frame
	check(app.ui.sheet.find_child("Destination_0",true,false) != null, "Meadow is navigable")
	check(app.ui.sheet.find_child("Destination_3",true,false) != null, "Snowcap is discoverable")
	check(app.ui.sheet.find_child("UnlockHotel", true, false).disabled, "Map shows locked second hotel")
	await capture("04-map")
	app.ui._navigate("Shop")
	check(app.ui.purchase_buttons.all(func(b): return b.disabled), "Unavailable store cannot buy")
	app.ui._navigate("Cats")
	await capture("05-cats")
	app.change_setting("motion", false)
	check(not app.world.motion_enabled, "Reduced animation setting reaches world")
	var paused_position: Vector3 = original_cat.position
	var paused_phase: float = original_cat.phase
	original_cat._process(2.0)
	check(original_cat.position == paused_position and original_cat.phase == paused_phase, "Reduced motion freezes cat routines and poses")
	for material in app.world.animated_materials:
		check(material.get_shader_parameter("motion") == 0.0, "Reduced motion stops foliage and water shaders")
	app.ui._open_settings()
	await capture("08-settings")
	app.model.coins = 10000
	app.model.hotels[0].purchases = 18
	app.visit_hotel(1)
	await process_frame
	check(app.model.current_hotel == 1 and app.model.hotels[1].owned, "Second hotel unlock runs through controller")
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("06-seaside")
	app.model.last_seen -= 7200
	app.model.reconcile(int(Time.get_unix_time_from_system()))
	app._update_ui()
	app.ui.show_offline()
	await capture("07-offline")
	var pending: float = app.model.pending_coins
	await click(app.ui.sheet.find_child("CollectEarnings", true, false))
	check(app.model.pending_coins == 0 and app.model.coins >= pending, "Offline sheet collects into wallet")
	var saved = app.Model.new()
	check(app.store.load_model(saved, int(Time.get_unix_time_from_system())), "Playable state saves")
	check(saved.current_hotel == 1 and saved.pending_coins == 0, "Second hotel and claim survive reload")
	app.ui.open_expansions()
	await process_frame
	check(app.ui.sheet.find_child("BuildExpansion", true, false).disabled, "Rooms menu enforces the hotel level gate")
	app.model.coins = 1300
	app.model.hotels[1].purchases = 2
	app._update_ui()
	await capture("09-rooms-menu")
	await click(app.ui.sheet.find_child("BuildExpansion", true, false))
	check(app.model.wing_count(1) == 0 and app.model.repair_remaining(1) > 0, "Rooms button starts a timed repair")
	check(app.world.builders.size() == 2, "Two construction cats work in the purchased wing")
	check(app.store.load_model(saved, int(Time.get_unix_time_from_system())) and saved.repair_remaining(1) > 0, "Active construction is saved immediately")
	await capture("13-repairing-hotel")
	app.model.advance(31)
	app._sync_repairs()
	app._update_ui()
	check(app.model.wing_count(1) == 1 and app.model.room_count(1) == 2, "Repair completion opens empty floor for player-designed rooms")
	check(app.world.builders.is_empty(), "Construction cats leave when their work is complete")
	check(app.world.room_centers.size() == 2 and app.world.room_builder.room_nodes.size() == 2, "Expansion preserves the two placed rooms")
	check(app.soundscape.recent_events.has("build"), "Successful expansion triggers its construction cue")
	check(app.store.load_model(saved, int(Time.get_unix_time_from_system())) and saved.wing_count(1) == 1, "Expansion is persisted immediately")
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("10-expanded-hotel")
	app.ui._open_settings()
	await click(app.ui.sheet.find_child("Setting_evening", true, false))
	check(app.model.settings.evening and app.world.evening, "Evening control updates the actual lighting")
	app.ui.close_sheet()
	await capture("11-evening-hotel")
	app.model.coins = 20000
	app.model.hotels[1].purchases = 10
	var real_store = app.store
	app.store = FailingStore.new()
	var before_failed_feedback: int = app.ui.success_count
	app.expand_hotel()
	check(app.model.wing_count(1) == 1 and app.model.coins >= 20000 and app.world.wings == 1, "Failed save rolls back expansion and leaves scenery unchanged")
	check(app.ui.success_count == before_failed_feedback,"Failed expansion save has no success reaction")
	app.store = real_store
	app._save()
	app.expand_hotel()
	app.model.advance(61)
	app._sync_repairs()
	app.expand_hotel()
	app.model.advance(91)
	app._sync_repairs()
	app._update_ui()
	check(app.model.wing_count(1) == 3 and app.model.room_count(1) == 2 and app.world.room_centers.size() == 2, "All three wings can be constructed without auto-placing rooms")
	check(app.store.load_model(saved, int(Time.get_unix_time_from_system())) and saved.wing_count(1) == 3 and saved.settings.evening, "All wings and lighting preference survive reload")
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await capture("12-full-hotel")
	app.world.dragging = true
	var release_over_ui = InputEventMouseButton.new()
	release_over_ui.button_index = MOUSE_BUTTON_LEFT
	release_over_ui.pressed = false
	release_over_ui.position = Vector2(30, 25)
	root.push_input(release_over_ui, true)
	check(not app.world.dragging, "Releasing on the HUD ends a camera drag")
	app.queue_free()
	await process_frame
	# Let the audio server drain playback commands before tearing down the tree.
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix):
			DirAccess.remove_absolute(key + suffix)
	print("APP TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
