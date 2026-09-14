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
	if is_instance_valid(app.ui.sheet): app.ui.sheet.scroll.ensure_control_visible(control)
	elif app.ui.welcome.visible: app.ui.welcome.get_child(0).ensure_control_visible(control)
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

func travel_capture(title: String) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task7-" + title + "-" + str(DisplayServer.window_get_size().x) + "x" + str(DisplayServer.window_get_size().y) + ".png")

func travel_capture_row(title: String, row: Control) -> void:
	app.ui.sheet.scroll.ensure_control_visible(row)
	await settle()
	await travel_capture(title)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var key := "res://tmp/mobile-views-" + str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	if "--matrix-only" in OS.get_cmdline_user_args():
		app.start_game()
		await final_matrix_coverage()
		app.soundscape.shutdown()
		await create_timer(0.15).timeout
		app.queue_free()
		await process_frame
		print("MOBILE MATRIX TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
		quit(1 if failures else 0)
		return
	await home_capture("welcome-100")
	app.change_setting("ui_text_scale",1.25)
	await home_capture("welcome-125")
	app.change_setting("ui_text_scale",1.0)
	check(app.ui.welcome.find_child("WelcomeSettings",true,false) != null,"Welcome exposes Settings before Play")
	app.ui._open_settings()
	await settle()
	var scale_choice = app.ui.sheet.find_child("TextScale_150",true,false)
	check(scale_choice != null,"Settings exposes global text size")
	if scale_choice != null:
		await click(scale_choice)
		await settle()
		check(not app.model.started and app.model.settings.ui_text_scale == 1.5,"Pre-start text preference is accepted without starting")
		var weather = app.ui.sheet.find_child("Setting_weather",true,false)
		await click(weather)
		check(not app.model.settings.weather,"Pre-start preferences work")
		await home_capture("settings-prestart-150")
		app.ui.go_back()
		await settle()
		check(app.ui.welcome.visible and app.ui.welcome.find_child("PlayButton",true,false).is_visible_in_tree(),"Back keeps Play available")
		await home_capture("welcome-150")
	app.ui.close_sheet()
	await click(app.ui.welcome.find_child("PlayButton",true,false))
	check(app.model.started and app.model.settings.ui_text_scale==1.5,"Play starts game and retains pre-start preferences")
	app.change_setting("ui_text_scale",1.0)
	await home_coverage()
	if "--home-only" in OS.get_cmdline_user_args():
		app.soundscape.shutdown()
		await create_timer(0.15).timeout
		app.queue_free()
		await process_frame
		preload("res://scripts/core/save_journal.gd").new(key).clear()
		print("HOME VIEWS TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
		quit(1 if failures else 0)
		return
	await travel_shop_coverage()
	app.ui.action_requested.connect(func(action, payload):
		if action == "interact": care_actions.append(payload.kind)
	)
	app.ui._navigate("Life")
	for route in ["Grounds","Manager","Staff","Journal","Discoveries","Kiosk"]:
		var tile = app.ui.sheet.find_child("Life_"+route,true,false)
		check(tile != null, "Life exposes " + route)
		if tile == null: continue
		await click(tile)
		check(app.ui.tab == route, "Tile opens existing route")
		app.ui.go_back()
		check(app.ui.tab == "Life", "Detail returns to hub")
	app.ui.close_sheet()
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
		await settle()
		check(not app.ui.sheet.find_child("Playdate_2", true, false).disabled, "Lounge and both bonds enable a playdate")
		await click(app.ui.sheet.find_child("Playdate_2", true, false))
		check(app.model.life.state.cats[1].friend == 2 and app.model.life.state.cats[2].friend == 1, "Playdate button creates the selected real friendship pair")
	await passive_life_refresh_coverage()
	await journal_focus_refresh_coverage()
	await featured_life_coverage()
	await life_coverage()
	await album_capacity_coverage()
	await final_matrix_coverage()
	app.soundscape.shutdown()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix): DirAccess.remove_absolute(key + suffix)
	print("MOBILE VIEWS TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)

func passive_life_refresh_coverage() -> void:
	var fresh = preload("res://scripts/core/hotel_model.gd").new()
	fresh.new_game(int(Time.get_unix_time_from_system()))
	var fixture: Dictionary = fresh.serialize()
	check(app.model.restore(fixture.duplicate(true)),"Passive refresh starts from an independent valid fixture")
	var viewport_before: Vector2i = root.size
	root.size = Vector2i(360,640)
	await settle()
	app.ui.close_sheet()
	app.model.current_hotel = 0
	for index in range(app.model.life.state.cats.size()):
		app.model.life.state.cats[index].known = index < 3
		app.model.life.state.cats[index].bond = 0
	app.model.hotels[0].zones = [10,2,1,2]
	app.model.life.state.hotels[0].staff = [3,3,3]
	app.model.life.state.hotels[0].visits = 0
	app.model.life.state.hotels[0].visit_clock = app.model.life.visit_interval(app.model,0)-0.5
	app.model.life.touch()
	app._update_ui()
	app.ui.cat_filter = "Met"
	app.ui._navigate("Cats")
	await settle()
	var cat_focus: Control = app.ui.sheet.find_child("CatCard_2",true,false)
	app.ui.sheet.scroll.ensure_control_visible(cat_focus)
	cat_focus.grab_focus()
	app.ui.sheet.scroll.scroll_vertical = 40
	await settle()
	var cat_scroll: int = app.ui.sheet.scroll.scroll_vertical
	app.model.advance(1.0)
	app._update_ui()
	await settle()
	var summary: Label = app.ui.sheet.find_child("CatCollectionSummary",true,false)
	check(summary != null and summary.text.begins_with("4 travelers met"),"A passive happy visit refreshes the open collection count")
	check(app.ui.sheet.find_child("CatCard_6",true,false) != null,"A passively discovered matching guest joins the open Met collection")
	check(app.ui.cat_filter == "Met" and app.ui.sheet.scroll.scroll_vertical == cat_scroll,"Passive collection membership refresh preserves filter and scroll")
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "CatCard_2","Passive collection membership refresh restores the focused cat card")

	check(app.model.restore(fixture.duplicate(true)),"Invitation refresh fixture restores atomically")
	app.model.current_hotel = 0
	for index in range(12): app.model.life.state.cats[index].known = true
	app.model.life.state.cats[0].bond = 9
	app.model.life.state.cats[1].bond = 9
	app.model.hotels[0].zones = [10,2,1,2]
	app.model.life.state.hotels[0].staff = [3,3,3]
	app.model.life.state.hotels[0].visits = 0
	var interval: float = app.model.life.visit_interval(app.model,0)
	app.model.life.state.hotels[0].visit_clock = interval*2.0-0.5
	app.model.life.touch()
	app._update_ui()
	app.ui.selected_cat = 0
	app.ui.open_route("Invitations","Pet")
	await settle()
	var playdate: Button = app.ui.sheet.find_child("Playdate_1",true,false)
	check(playdate != null and playdate.disabled,"Passive invitation regression begins below both friendship gates")
	app.ui.sheet.scroll.ensure_control_visible(playdate)
	playdate.grab_focus()
	var invitation_scroll: int = app.ui.sheet.scroll.scroll_vertical
	var playdate_id: int = playdate.get_instance_id()
	app.model.advance(1.0)
	app._update_ui()
	await settle()
	var refreshed_playdate: Button = app.ui.sheet.find_child("Playdate_1",true,false)
	check(app.model.life.state.cats[0].bond >= 10 and app.model.life.state.cats[1].bond >= 10,"Actual passive visits cross both playdate friendship gates")
	check(refreshed_playdate != null and not refreshed_playdate.disabled,"Passive friendship gains enable the open invitation action")
	check(refreshed_playdate != null and refreshed_playdate.get_instance_id() == playdate_id,"Invitation gate updates in place without rebuilding the sheet")
	check(root.gui_get_focus_owner() == refreshed_playdate and app.ui.sheet.scroll.scroll_vertical == invitation_scroll,"Passive invitation refresh preserves focus and scroll")
	check(app.model.restore(fixture),"Passive refresh fixture restores the prior model")
	app._update_ui()
	root.size = viewport_before
	await settle()

func journal_focus_refresh_coverage() -> void:
	var fresh = preload("res://scripts/core/hotel_model.gd").new()
	fresh.new_game(int(Time.get_unix_time_from_system()))
	var fixture: Dictionary = fresh.serialize()
	check(app.model.restore(fixture.duplicate(true)),"Scrapbook focus starts from an independent valid fixture")
	app.ui.close_sheet()
	app.model.life.state.memories.clear()
	app.model.life.memory("same-cat-first","Miso's first note","A quiet first memory.",0,0)
	app.model.life.memory("same-cat-second","Miso's second note","Another memory about the same cat.",0,0)
	app._update_ui()
	app.ui._navigate("Journal")
	await settle()
	var first_name: String = "JournalVisit_" + "same-cat-first".md5_text()
	var second_name: String = "JournalVisit_" + "same-cat-second".md5_text()
	var first_action: Button = app.ui.sheet.find_child(first_name,true,false)
	var second_action: Button = app.ui.sheet.find_child(second_name,true,false)
	check(first_action != null and second_action != null and first_name != second_name,"Same-cat scrapbook memories receive deterministic unique Visit identifiers")
	if first_action != null:
		app.ui.sheet.scroll.ensure_control_visible(first_action)
		first_action.grab_focus()
		await settle()
		var scroll_before: int = app.ui.sheet.scroll.scroll_vertical
		app.model.life.touch()
		app._update_ui()
		await settle()
		check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == first_name,"A normal life revision restores the focused later scrapbook entry")
		check(app.ui.sheet.scroll.scroll_vertical == scroll_before,"A normal life revision preserves later scrapbook scroll")
	check(app.model.restore(fixture),"Scrapbook focus fixture restores the prior model")
	app._update_ui()

func featured_life_coverage() -> void:
	var fresh = preload("res://scripts/core/hotel_model.gd").new()
	fresh.new_game(int(Time.get_unix_time_from_system()))
	var fixture: Dictionary = fresh.serialize()
	check(app.model.restore(fixture.duplicate(true)),"Featured Life starts from an independent valid fixture")
	app.ui.close_sheet()
	app.model.current_hotel = 0
	app.model.life.state.hotels[0].event = {}
	app.model.life.state.hotels[0].last_event = -1000.0
	app.model.life.state.hotels[0].trophies.erase("cardboard")
	app.model.life.state.memories = app.model.life.state.memories.filter(func(entry): return not str(entry.id).begins_with("event_0_cardboard_"))
	app.model.life.touch()
	app._update_ui()
	app.change_setting("ui_text_scale",1.0)
	app.ui._navigate("Life")
	await settle()
	check_featured_event("nap","Great Nap Championship","Ready for a gathering","Get ready","Idle Life")
	var before_reward_units: int = app.model.coins_units
	app.perform_action("event",{"id":"cardboard"})
	await settle()
	check_featured_event("cardboard","Cardboard Castle Festival","50s left","View gathering","Running Life")
	await life_capture("featured-cardboard-running-100-final")
	app.change_setting("ui_text_scale",1.5)
	await settle()
	check_featured_event("cardboard","Cardboard Castle Festival","50s left","View gathering","Enlarged running Life")
	await life_capture("featured-cardboard-running-150-final")
	var running_status: Label = app.ui.sheet.find_child("FeaturedEventStatus",true,false)
	app.model.advance(10.0)
	app._update_ui()
	check(running_status != null and app.ui.sheet.find_child("FeaturedEventStatus",true,false) == running_status and running_status.text.contains("40s left"),"Life featured countdown updates in place")
	app.model.advance(41.0)
	app._update_ui()
	await settle()
	check_featured_event("cardboard","Cardboard Castle Festival","Gathering complete","See results","Cooldown Life")
	check(app.model.life.state.hotels[0].trophies.has("cardboard") and app.model.coins_units >= before_reward_units + 250*app.model.UNIT,"Life event completion keeps the controller-owned first trophy reward")
	await life_capture("featured-cardboard-cooldown-150-final")
	app.change_setting("ui_text_scale",1.0)
	await settle()
	check_featured_event("cardboard","Cardboard Castle Festival","Gathering complete","See results","Normal cooldown Life")
	await life_capture("featured-cardboard-cooldown-100-final")
	var rewarded_units: int = app.model.coins_units
	app.model.advance(60.0)
	app._update_ui()
	await settle()
	check_featured_event("nap","Great Nap Championship","Available again","Get ready","Available-again Life")
	check(app.model.life.state.hotels[0].trophies.count("cardboard") == 1 and app.model.coins_units-rewarded_units < 250*app.model.UNIT,"Life availability adds no duplicate reward or claim path")
	app.model.advance(1.0)
	app.model.life.state.hotels[0].happy=0
	app.perform_action("event",{"id":"nap"})
	app.model.advance(46.0)
	app._update_ui()
	await settle()
	check_featured_event("nap","Great Nap Championship","Gathering complete","See results","Nap cooldown Life")
	app.model.advance(60.0)
	app.model.life.state.hotels[0].happy=0
	app.perform_action("event",{"id":"cardboard"})
	var repeat_reward_units: int = app.model.coins_units
	app.model.advance(51.0)
	app._update_ui()
	await settle()
	check_featured_event("cardboard","Cardboard Castle Festival","Gathering complete","See results","Repeated Cardboard cooldown Life")
	check(app.model.coins_units-repeat_reward_units < 250*app.model.UNIT and app.model.life.state.hotels[0].trophies.count("cardboard")==1,"Repeated Cardboard completion keeps its one-time trophy reward")
	var persisted = preload("res://scripts/core/hotel_model.gd").new()
	check(persisted.restore(JSON.parse_string(JSON.stringify(app.model.serialize()))) and persisted.life.state.hotels[0].get("last_completed_event","")=="cardboard","Repeated Cardboard cooldown identity survives model serialization")
	await life_capture("featured-cardboard-repeat-cooldown-100-final")
	check(app.model.restore(fixture),"Featured Life fixture restores the prior model")
	app._update_ui()

func check_featured_event(kind: String, title: String, status_copy: String, action_copy: String, context: String) -> void:
	var art = app.ui.sheet.find_child("FeaturedEventArt",true,false)
	var heading: Label = app.ui.sheet.find_child("FeaturedEventName",true,false)
	var status: Label = app.ui.sheet.find_child("FeaturedEventStatus",true,false)
	var action_button: Button = app.ui.sheet.find_child("Life_Events",true,false)
	check(art != null and art.kind == kind,context+" uses matching featured art")
	check(heading != null and heading.text == title,context+" uses the current gathering name")
	check(status != null and status.text.contains(status_copy),context+" reports live gathering state")
	check(action_button != null and action_button.text.contains(action_copy),context+" uses a matching Events-route caption")
	if status != null and action_button != null:
		check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(status.get_global_rect()),context+" keeps the full featured status visible")
		check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(action_button.get_global_rect()) and action_button.size.y >= 48*app.ui.metrics.unit,context+" keeps the Events action visible and touchable")
	if app.ui.metrics.font_scale == 1.0:
		var grid: GridContainer = app.ui.sheet.find_child("grid",true,false)
		for index in range(mini(2,grid.get_child_count())):
			check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(grid.get_child(index).get_global_rect()),context+" keeps the first complete activity row visible")

func travel_shop_coverage() -> void:
	app.set_process(false)
	app.model.current_hotel = 0
	app.model.coins = 1000
	app.model.hotels[0].purchases = 0
	app._update_ui()
	app.ui._navigate("Map")
	await settle()
	check(app.ui.sheet.find_child("Destination_0",true,false) != null, "Meadow is navigable")
	check(app.ui.sheet.find_child("Destination_3",true,false) != null, "Snowcap is discoverable")
	var unlock: Button = app.ui.sheet.find_child("UnlockHotel",true,false)
	check(unlock != null and unlock.disabled, "Seaside keeps its gate")
	check(app.ui.sheet.find_child("MapArt",true,false) != null, "Journey uses the illustrated world map")
	check(app.ui.sheet.find_child("RequirementLevel",true,false) != null and app.ui.sheet.find_child("RequirementCoins",true,false) != null, "Seaside keeps both live requirements visible")
	check(unlock.text == "Reach Meadow level 10", "Seaside names the unmet level requirement")
	await travel_capture("map-normal-100")
	app.model.hotels[0].purchases = 18
	app._update_ui()
	await settle()
	unlock = app.ui.sheet.find_child("UnlockHotel",true,false)
	check(unlock.text == "Save 9,000 more coins" and unlock.disabled, "Seaside names the unmet coin requirement")
	await travel_capture("map-level-only-100")
	var unlock_before := unlock
	app.model.coins = 10000
	app._update_ui()
	await settle()
	unlock = app.ui.sheet.find_child("UnlockHotel",true,false)
	var seaside_pin: Button = app.ui.sheet.find_child("Destination_1",true,false)
	check(unlock == unlock_before and unlock.text == "Open Seaside · 10,000" and not unlock.disabled and seaside_pin.text.contains("Ready"), "Live balance enables Seaside in place when both requirements are met")
	await travel_capture("map-ready-100")
	await click(app.ui.sheet.find_child("Destination_2",true,false))
	var normal_forest_details: Control = app.ui.sheet.find_child("DestinationDetails",true,false)
	app.model.coins = 9999
	app._update_ui()
	await settle()
	seaside_pin = app.ui.sheet.find_child("Destination_1",true,false)
	var normal_pin_before := seaside_pin
	app.model.coins = 10000
	app._update_ui()
	await settle()
	seaside_pin = app.ui.sheet.find_child("Destination_1",true,false)
	check(seaside_pin == normal_pin_before and seaside_pin.text.contains("Ready") and seaside_pin.accessibility_name.contains("Ready"), "Off-selection Seaside pin and accessibility state update in place")
	check(app.ui.sheet.find_child("DestinationDetails",true,false) == normal_forest_details and app.ui.sheet.find_child("SheetPrimary",true,false).text == "View expansion", "Normal off-selection update preserves Forest details")
	app.model.coins = 1000
	app.model.hotels[0].purchases = 0
	app._update_ui()
	app.ui._navigate("Shop")
	await settle()
	check(app.ui.purchase_buttons.all(func(b): return b.disabled), "Unavailable store cannot buy")
	await travel_capture("shop-unavailable-100")

	var ready_partial := {"ready":true,"can_restore":true,"busy":false,"prices":{"purrington.cat_club":"$3.49"},"message":"One-time expansions. Any purchase removes every ad.","preview":false}
	app.ui.update_commerce(ready_partial)
	await settle()
	var club: Button = app.ui.sheet.find_child("Purchase_purrington_cat_club",true,false)
	var forest: Button = app.ui.sheet.find_child("Purchase_purrington_forest_lodge",true,false)
	check(club != null and club.text == "Buy · $3.49" and not club.disabled, "Shop displays the exact localized catalogue price")
	check(forest != null and forest.text == "Store unavailable" and forest.disabled, "A partial catalogue cannot enable an unpriced expansion")
	club.grab_focus()
	var focused_before := club
	app.ui.update_commerce({"ready":true,"can_restore":true,"busy":true,"prices":{"purrington.cat_club":"$3.49"},"message":"Waiting for the store…","preview":false})
	await settle()
	var current_club: Button = app.ui.sheet.find_child("Purchase_purrington_cat_club",true,false)
	check(current_club == focused_before and is_instance_valid(focused_before) and focused_before.has_focus() and focused_before.disabled, "Pending purchase updates in place and preserves focus")
	await travel_capture("shop-pending-100")
	app.ui.update_commerce(ready_partial.merged({"message":"Purchase cancelled."},true))
	await settle()
	var status: Label = app.ui.sheet.find_child("ShopStatus",true,false)
	current_club = app.ui.sheet.find_child("Purchase_purrington_cat_club",true,false)
	check(status != null and status.text == "Purchase cancelled." and current_club != null and not current_club.disabled, "Cancelled purchase restores the available action")
	app.ui.update_commerce(ready_partial.merged({"message":"Purchase failed. Please try again."},true))
	await settle()
	status = app.ui.sheet.find_child("ShopStatus",true,false)
	current_club = app.ui.sheet.find_child("Purchase_purrington_cat_club",true,false)
	check(status != null and status.text == "Purchase failed. Please try again." and current_club != null and not current_club.disabled, "Failed purchase leaves the priced expansion retryable")
	app.ui._navigate("Map")
	await settle()
	var paid_destination: Button = app.ui.sheet.find_child("Destination_2",true,false)
	await click(paid_destination)
	var paid_action: Button = app.ui.sheet.find_child("SheetPrimary",true,false)
	check(paid_action.text == "View expansion" and not paid_action.disabled, "Locked paid hotel offers its expansion")
	paid_action.pressed.emit()
	await settle()
	forest = app.ui.sheet.find_child("Purchase_purrington_forest_lodge",true,false)
	check(app.ui.tab == "Shop" and forest != null and forest.has_focus(), "Paid destination opens Shop focused on its matching product")

	app.model.life.grant_product(app.model,"purrington.forest_lodge")
	app._update_ui()
	app.ui._shop()
	await settle()
	forest = app.ui.sheet.find_child("Purchase_purrington_forest_lodge",true,false)
	check(forest != null and forest.disabled and forest.text == "Owned · Thank you!", "Owned Forest entitlement has a distinct shop state")
	await travel_capture("shop-owned-100")
	app.ui._navigate("Map")
	await settle()
	var destination: Button = app.ui.sheet.find_child("Destination_2",true,false)
	if destination != null:
		await click(destination)
		var primary: Button = app.ui.sheet.find_child("SheetPrimary",true,false)
		check(primary != null and primary.text == "Visit hotel" and not primary.disabled, "Owned Forest can be visited from its details card")
		primary.pressed.emit()
		await settle()
		check(app.model.current_hotel == 2, "Owned Forest action visits the real hotel")
	else:
		check(false,"Forest destination remains selectable")

	app.model.current_hotel = 0
	app.model.hotels[2].owned = false
	app.model.life.state.entitlements.erase("purrington.forest_lodge")
	app._update_ui()
	app.change_setting("ui_text_scale",1.5)
	app.ui._navigate("Map")
	await settle()
	check(app.ui.sheet.find_child("DestinationList",true,false) != null, "Large text reflows destinations into an illustrated list")
	await travel_capture("map-150")
	app.model.hotels[0].purchases = 18
	app.model.coins = 9999
	app._update_ui()
	await settle()
	var forest_details: Control = app.ui.sheet.find_child("DestinationDetails",true,false)
	var forest_action: Button = app.ui.sheet.find_child("SheetPrimary",true,false)
	var seaside_row: Button = app.ui.sheet.find_child("Destination_1",true,false)
	var seaside_status: Label = app.ui.sheet.find_child("DestinationStatus_1",true,false)
	app.model.coins = 10000
	app._update_ui()
	await settle()
	check(app.ui.sheet.find_child("Destination_1",true,false) == seaside_row and seaside_status.text.contains("Ready") and seaside_status.text.contains("10,000"), "Off-selection Seaside state crosses the live coin gate in place")
	check(app.ui.sheet.find_child("DestinationDetails",true,false) == forest_details and app.ui.sheet.find_child("SheetPrimary",true,false) == forest_action and forest_action.text == "View expansion", "Off-selection Seaside updates do not disturb Forest details")
	app.model.coins = 9999999
	app._update_ui()
	await settle()
	var rows: Array[Control] = []
	for index in range(4):
		var choice: Control = app.ui.sheet.find_child("Destination_"+str(index),true,false)
		rows.append(choice)
		for text_node in choice.find_children("*","Label",true,false):
			check(choice.get_global_rect().grow(1).encloses(text_node.get_global_rect()), "Large-text destination contains wrapped label: "+str(index))
		if index > 0:
			check(not rows[index-1].get_global_rect().intersects(choice.get_global_rect()), "Large-text destination rows do not overlap: "+str(index-1)+"/"+str(index))
		app.ui.sheet.scroll.ensure_control_visible(choice)
		await settle()
		choice.grab_focus()
		check(choice.has_focus() and app.ui.sheet.scroll.get_global_rect().intersects(choice.get_global_rect()), "Large-text destination remains reachable: "+str(index))
	await travel_capture_row("map-forest-row-150",rows[2])
	await travel_capture_row("map-seaside-row-150",rows[1])
	app.ui.selected_destination = 1
	app.ui._map()
	await settle()
	check(app.ui.sheet.find_child("RequirementLevel",true,false) != null and app.ui.sheet.find_child("RequirementCoins",true,false) != null and app.ui.sheet.find_child("UnlockHotel",true,false) != null, "Large-text Seaside keeps both requirements and its pinned action")
	await travel_capture("map-seaside-150")
	app.ui._navigate("Shop")
	await settle()
	await travel_capture("shop-150")
	app.change_setting("ui_text_scale",1.0)
	app.ui.update_commerce({})
	app.set_process(true)

func life_capture(title: String, target: Control = null) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if target != null:
		app.ui.sheet.scroll.ensure_control_visible(target)
		if str(target.name).begins_with("EventArt_"):
			app.ui.sheet.scroll.scroll_vertical += roundi(target.global_position.y-app.ui.sheet.scroll.global_position.y)
	else: app.ui.sheet.scroll.scroll_vertical = 0
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task6-"+title+"-"+str(DisplayServer.window_get_size().x)+"x"+str(DisplayServer.window_get_size().y)+".png")

func life_coverage() -> void:
	app.set_process(false)
	app.ui.close_sheet()
	app.model.current_hotel = 0
	app.model.coins = 20000
	app.model.hotels[0].purchases = 6
	app.model.hotels[0].zones = [3,2,2,2]
	app.model.life.state.hotels[0].staff = [0,0,0]
	app.model.life.state.memories.clear()
	app._rebuild_world()
	app._update_ui()
	var life_fixture: Dictionary = {"coins":app.model.coins,"hotel":app.model.hotels[0].duplicate(true),"life":app.model.life.state.duplicate(true),"grounds":app.model.grounds.hotels.duplicate(true)}
	for scale in [1.0,1.25,1.5]:
		app.model.coins = life_fixture.coins
		app.model.hotels[0] = life_fixture.hotel.duplicate(true)
		app.model.life.state = life_fixture.life.duplicate(true)
		app.model.grounds.hotels = life_fixture.grounds.duplicate(true)
		app.change_setting("ui_text_scale",scale)
		var tag: String = str(roundi(scale*100))
		app.ui._navigate("Life")
		await life_capture("life-"+tag)
		check(app.ui.sheet.find_child("grid",true,false).columns == (1 if scale == 1.5 else 2),"Life grid follows text size")
		check(app.ui.sheet.find_children("Specialty_*","Button",true,false).size()==4,"All four specialties are available")
		for route in ["Grounds","Manager","Staff","Journal","Discoveries","Kiosk"]:
			await click(app.ui.sheet.find_child("Life_"+route,true,false))
			check(app.ui.tab==route,"Life tile works at text size "+tag+": "+route)
			app.ui.go_back()
			await settle()
		app.ui._navigate("Journal")
		app.model.life.state.memories.clear()
		app._update_ui()
		app.ui._journal()
		check(app.ui.sheet.find_child("TakeHotelPhoto",true,false)!=null,"Empty Journal keeps photo action")
		await life_capture("journal-empty-"+tag)
		app.model.life.memory("task6-cat","Mochi found a quiet corner","A soft cushion and a very happy cat.",3,0)
		app.model.life.state.cats[3].known = true
		app._update_ui()
		app.ui._journal()
		var badges = app.ui.sheet.find_children("*","Control",true,false).filter(func(node): return node.get_script() == preload("res://scripts/ui/cat_badge.gd"))
		check(badges.size()==1 and badges[0].cat_index==3,"Journal uses the actual indexed guest portrait")
		await life_capture("journal-populated-"+tag)
		app.model.life.state.hotels[0].staff[1] = 0
		app.world.staff_selected.emit(1)
		await settle()
		check(app.ui.selected_staff == 1 and app.ui.tab == "Staff","World staff index opens the selected card")
		await click(app.ui.sheet.find_child("StaffSelect_2",true,false))
		check(app.ui.selected_staff==2,"Staff selector opens Buttons")
		await click(app.ui.sheet.find_child("StaffSelect_1",true,false))
		await life_capture("staff-0-"+tag,app.ui.sheet.find_child("StaffTrain",true,false))
		check(not app.ui.sheet.find_child("StaffTrain",true,false).disabled,"Open service enables training")
		await click(app.ui.sheet.find_child("StaffSkill_0",true,false))
		check(app.model.life.state.hotels[0].skills[1] == -1,"Untrained skill is disabled")
		await click(app.ui.sheet.find_child("StaffTrain",true,false))
		check(app.model.life.state.hotels[0].staff[1]==1,"Training acts on selected worker")
		await settle()
		await click(app.ui.sheet.find_child("StaffSkill_1",true,false))
		check(app.model.life.state.hotels[0].skills[1]==1,"Skill acts on selected worker")
		app.ui.sheet.scroll.scroll_vertical = 9999
		await settle()
		var scroll_before: int = app.ui.sheet.scroll.scroll_vertical
		app.model.life.touch()
		app._update_ui()
		await settle()
		check(app.ui.selected_staff == 1 and app.ui.sheet.scroll.scroll_vertical==scroll_before,"Revision keeps staff selection and scroll")
		app.model.life.state.hotels[0].staff[1] = 3
		app._update_ui()
		app.ui._staff()
		await life_capture("staff-3-"+tag,app.ui.sheet.find_child("StaffTrain",true,false))
		check(app.ui.sheet.find_child("StaffTrain",true,false).disabled,"Maximum training remains disabled")
		app.model.life.state.hotels[0].staff[1] = 0
		app.model.hotels[0].zones[1] = 0
		app._update_ui()
		check(app.ui.sheet.find_child("StaffTrain",true,false).disabled,"Closed service disables training")
		app.model.hotels[0].zones[1] = 2
		app.model.life.state.hotels[0].staff[1] = 0
		app.model.life.state.hotels[0].skills[1] = -1
		app.model.life.state.hotels[0].event = {}
		app.model.life.state.hotels[0].trophies.clear()
		app.model.life.state.hotels[0].last_event = -1000
		app._update_ui()
		app.ui._navigate("Events")
		await life_capture("event-ready-"+tag)
		var event_status = app.ui.event_label
		await click(app.ui.sheet.find_child("Event_nap",true,false))
		await life_capture("event-running-"+tag)
		event_status = app.ui.event_label
		app.model.advance(10)
		app._update_ui()
		check(app.ui.event_label==event_status and app.ui.event_label.text.contains("35s"),"Countdown updates in place")
		app.model.advance(36)
		app._update_ui()
		check(app.ui.event_label==event_status,"Completion updates in place")
		check(app.ui.sheet.find_child("EventReward_nap",true,false).text.contains("earned"),"Completion displays earned trophy")
		await life_capture("event-complete-"+tag,app.ui.sheet.find_child("Event_nap",true,false))
		var rewarded: float = app.model.coins
		app.ui._navigate("Life")
		app.ui._navigate("Events")
		check(app.model.coins==rewarded,"Reopening result cannot award twice")
		app.model.advance(61)
		app._update_ui()
		check(not app.ui.sheet.find_child("Event_nap",true,false).disabled,"Cooldown expires in place")
		app.model.life.state.combos.clear()
		app._update_ui()
		app.ui._navigate("Discoveries")
		await life_capture("combo-unknown-"+tag,app.ui.sheet.find_child("Combo_sunbeam",true,false))
		await click(app.ui.sheet.find_child("Combo_sunbeam",true,false))
		check(app.model.life.state.pinned=="sunbeam","Pin retains actual command")
		app.model.life.state.combos.append("sunbeam")
		app._update_ui()
		app.ui._discoveries()
		await life_capture("combo-found-"+tag,app.ui.sheet.find_child("Combo_sunbeam",true,false))
		app.model.grounds.hotels[0].amenities.clear()
		app.model.hotels[0].purchases = 0
		app._update_ui()
		app.ui.open_amenity("picnic")
		await life_capture("amenity-locked-"+tag)
		check(app.ui.sheet.find_child("Grounds_amenitypicnic",true,false).disabled,"Amenity level gate is preserved")
		app.model.hotels[0].purchases = 6
		app._update_ui()
		await click(app.ui.sheet.find_child("Grounds_amenitypicnic",true,false))
		check(app.model.grounds.hotels[0].amenities.has("picnic"),"Amenity card buys the actual amenity")
		await life_capture("amenity-owned-"+tag)
		app.model.grounds.hotels[0].maid = false
		app._update_ui()
		app.ui._navigate("Manager")
		await life_capture("daisy-before-"+tag,app.ui.sheet.find_child("Grounds_hire_maid",true,false))
		await click(app.ui.sheet.find_child("Grounds_hire_maid",true,false))
		check(app.model.grounds.hotels[0].maid,"Daisy card hires actual housekeeping")
		await life_capture("daisy-after-"+tag,app.ui.maid_status)
		app.ui._navigate("Kiosk")
		await life_capture("paw-mart-"+tag,app.ui.sheet.find_child("Grounds_treats",true,false))
		app.ui._navigate("Life")
		await click(app.ui.sheet.find_child("Life_Watch",true,false))
		check(app.model.settings.watch and not is_instance_valid(app.ui.sheet),"Watch closes the sheet and changes real setting")
		app.change_setting("watch",false)
	app.change_setting("ui_text_scale",1.0)
	for hotel in range(4):
		app.model.hotels[hotel].owned = true
		app.model.current_hotel = hotel
		app._update_ui()
		app.ui._navigate("Events")
		for item in app.ui.Content.EVENTS:
			if item.hotel >= 0 and item.hotel != hotel: continue
			var art = app.ui.sheet.find_child("EventArt_"+item.id,true,false)
			check(art != null and art.kind==item.id,"Gathering uses distinct scene: "+item.id)
			if hotel == 0 or item.hotel == hotel: await life_capture("scene-"+item.id,art)
	app.model.current_hotel = 0
	app._rebuild_world()
	app._update_ui()
	if DisplayServer.get_name() != "headless":
		app.change_setting("ui_text_scale",1.0)
		app.ui._navigate("Journal")
		await click(app.ui.sheet.find_child("TakeHotelPhoto",true,false))
		await settle()
		var photo: String = app.model.life.state.memories[-1].get("photo","")
		check(photo!="" and FileAccess.file_exists(photo),"Real Journal photo signal saves current hotel locally")
		app.ui._navigate("Journal")
		var image = app.ui.sheet.find_child("JournalPhoto",true,false)
		check(image!=null and maxi(image.texture.get_width(),image.texture.get_height())<=640,"Album caches bounded display-size photo thumbnail")
		var previous = image.texture
		app.ui._journal()
		check(app.ui.sheet.find_child("JournalPhoto",true,false).texture==previous,"Album reuses photo thumbnail on refresh")
		await life_capture("real-photo-100")

func home_capture(title: String) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task8-"+title+"-"+str(DisplayServer.window_get_size().x)+"x"+str(DisplayServer.window_get_size().y)+".png")

func home_coverage() -> void:
	app.active = false
	app.ui.close_sheet()
	app.model.coins = 1000
	app._update_ui()
	await home_capture("header-ordinary")
	for scale in [1.0,1.25,1.5]:
		app.change_setting("ui_text_scale",scale)
		app.ui.close_sheet()
		app.model.coins = 9999999
		app._update_ui()
		await settle()
		var bounds: Rect2 = app.ui.metrics.header_rect
		var unit: float = app.ui.metrics.unit
		var gear: Control = app.ui.header.find_child("SettingsButton",true,false)
		for item in [app.ui.title_label,app.ui.level_label,app.ui.coins_label,app.ui.rate_label,gear]:
			check(bounds.grow(1).encloses(item.get_global_rect()),"Header contains essential label/gear at "+str(scale))
		check(gear.size.x>=48*unit and gear.size.y>=48*unit,"Header gear retains physical target")
		check(app.ui.level_label.get_theme_font_size("font_size")/unit>=14*scale,"Header essential text respects scale")
		check(not app.ui.coins_label.get_global_rect().intersects(gear.get_global_rect()),"Wallet does not overlap settings")
		await home_capture("header-"+str(int(scale*100)))
		app.ui._open_settings()
		await settle()
		app.ui.sheet.scroll.scroll_vertical = 0
		await home_capture("settings-"+str(int(scale*100)))
		for key in ["music","sound","motion","haptics","evening","weather"]:
			var control: Control = app.ui.sheet.find_child("Setting_"+key,true,false)
			app.ui.sheet.scroll.ensure_control_visible(control)
			await settle()
			check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Preference reachable at "+str(scale)+": "+key)
			check(control.size.x>=48*unit and control.size.y>=48*unit,"Preference is touch-sized")
		var choice: Control = app.ui.sheet.find_child("TextScale_150",true,false)
		app.ui.sheet.scroll.ensure_control_visible(choice)
		await settle()
		check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(choice.get_global_rect()),"Last text size is reachable")
		choice.grab_focus()
		app.ui.relayout()
		await settle()
		check(choice.has_focus(),"Resizing preserves settings focus")
		await home_capture("settings-scale-"+str(int(scale*100)))
	await settings_bottom_coverage()
	app.change_setting("ui_text_scale",1.0)
	app.model.hotels[0].zones[2] = 2
	app.model.coins = 1000
	app._update_ui()
	app.ui.open_upgrades(2)
	await home_capture("upgrade-affordable")
	check(not app.ui.sheet.find_child("PurchaseUpgrade",true,false).disabled,"Affordable service is enabled")
	app.model.coins = 0
	app._update_ui()
	check(app.ui.sheet.find_child("PurchaseUpgrade",true,false).disabled,"Poor service is disabled")
	await home_capture("upgrade-poor")
	app.model.hotels[0].zones[2] = 10
	app._update_ui()
	check(app.ui.sheet.find_child("PurchaseUpgrade",true,false).disabled,"Maximum service is disabled")
	await home_capture("upgrade-max")
	app.change_setting("ui_text_scale",1.5)
	await home_capture("upgrade-150")
	app.change_setting("motion",false)
	app.ui.success_feedback("collect")
	check(app.ui.feedback_tween == null and app.ui.feedback_icon == null,"Reduced motion has zero transition")
	await home_capture("reduced-motion")
	app.change_setting("ui_text_scale",1.0)
	app.change_setting("motion",true)
	app.model.hotels[0].zones[2] = 0
	app.model.coins = 1000
	app._update_ui()
	app.ui.close_sheet()
	app.active = true

func settings_bottom_coverage() -> void:
	check(app.model.started and app.ui.metrics.font_scale==1.5,"Bottom settings fixture uses a started game at 150 percent")
	# Expose conditional UI only; replace the real consent callback with a local spy.
	var privacy_connections: Array = app.ui.privacy_requested.get_connections()
	for connection in privacy_connections: app.ui.privacy_requested.disconnect(connection.callable)
	var privacy_calls: Array[int] = [0]
	var privacy_spy := func(): privacy_calls[0] += 1
	app.ui.privacy_requested.connect(privacy_spy)
	var snapshot: Dictionary = app.ui.snapshot.duplicate(true)
	snapshot.privacy_available = true
	app.ui.render(snapshot)
	app.ui._settings()
	await settle()
	var captions := ["Expansions & restore purchases","Advertising privacy choices","Hotel view"]
	for caption in captions:
		var action: Button = settings_action(caption)
		check(action != null,"Large-text bottom settings exposes "+caption)
		if action == null: continue
		action.grab_focus()
		app.ui.sheet.scroll.ensure_control_visible(action)
		await settle()
		check(action.has_focus(),"Bottom settings action accepts keyboard focus: "+caption)
		check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(action.get_global_rect()),"Bottom settings action is fully visible after scrolling: "+caption)
		check(action.size.x>=48*app.ui.metrics.unit and action.size.y>=48*app.ui.metrics.unit,"Bottom settings action retains 48-unit target: "+caption)
		await click(action)
		match caption:
			"Expansions & restore purchases":
				check(app.ui.tab=="Shop","Settings purchase link opens the real Shop route")
				check(app.ui.sheet.find_child("RestorePurchases",true,false)!=null,"Shop route exposes restore purchases without invoking commerce")
				app.ui.go_back()
				check(app.ui.tab=="Settings","Shop Back returns to Settings")
			"Advertising privacy choices":
				check(privacy_calls[0]==1 and app.ui.tab=="Settings","Privacy button emits exactly one local callback and preserves Settings")
			"Hotel view":
				check(app.ui.tab=="View","Settings hotel-view link opens view choices")
				app.ui.go_back()
				check(app.ui.tab=="Settings","View Back returns to Settings")
		await settle()
	app.ui.sheet.scroll.scroll_vertical = 99999
	await settle()
	await home_capture("settings-bottom-privacy-150")
	app.ui.privacy_requested.disconnect(privacy_spy)
	for connection in privacy_connections: app.ui.privacy_requested.connect(connection.callable,connection.flags)
	snapshot.privacy_available = false
	app.ui.render(snapshot)
	app.ui._settings()

func settings_action(caption: String) -> Button:
	for action in app.ui.sheet.find_children("*","Button",true,false):
		if action.text == caption: return action
	return null

func album_capacity_coverage() -> void:
	var views = preload("res://scripts/ui/views/life_views.gd")
	views.thumbnails.clear()
	var entries: Array = []
	var previous := {}
	var paths: Array[String] = []
	var tiny := Image.create(8,8,false,Image.FORMAT_RGBA8)
	tiny.fill(Color("5CC8A1"))
	for index in range(81):
		var path := "res://tmp/album-capacity-%d-%d.png" % [Time.get_ticks_usec(),index]
		check(tiny.save_png(path)==OK,"Capacity fixture photo saves")
		paths.append(path)
		if index<80:
			entries.append({"photo":path})
			previous[path] = views.thumbnail(path)
	check(views.thumbnails.size()==80,"Album cache reaches its existing 80-photo cap")
	entries.push_front({"photo":paths[80]})
	entries.resize(80)
	views.prune_thumbnails(entries)
	for entry in entries:
		var texture = views.thumbnail(entry.photo)
		if previous.has(entry.photo): check(texture==previous[entry.photo],"A new full-album photo preserves every other displayed texture")
	check(views.thumbnails.size()==80 and not views.thumbnails.has(paths[79]),"Only the undisplayed oldest photo is pruned")
	views.thumbnails.clear()
	for path in paths: DirAccess.remove_absolute(path)

func final_matrix_coverage() -> void:
	app.ui.close_sheet()
	app.active = false
	app.set_process(false)
	app.ui.set_process(false)
	# Every scale/inset starts from the same ordinary model, independent of prior seeded scenarios.
	var fresh = preload("res://scripts/core/hotel_model.gd").new()
	fresh.new_game(int(Time.get_unix_time_from_system()))
	var fixture: Dictionary = fresh.serialize()
	for scale in [1.0,1.25,1.5]:
		for inset in [false,true]:
			app.ui.route_state.clear()
			app.ui._route_history.clear()
			check(app.model.restore(fixture.duplicate(true)),"Matrix resets its independent starting-state fixture")
			app.change_setting("ui_text_scale",scale)
			app._rebuild_world()
			app._update_ui()
			for route in ["Hotel","Cats","Pet","Life","Events","Journal","Upgrades","Map","Settings","Staff","Grounds","Shop"]:
				app.ui.selected_cat = 0
				app.ui._navigate(route)
				apply_matrix_geometry(scale,inset)
				await settle()
				# The fixture pauses UI processing to preserve injected safe geometry, so drive its normal post-layout restore.
				for frame in range(3): app.ui._advance_sheet_restore()
				await settle()
				var safe: Rect2 = app.ui.metrics.safe_rect
				var unit: float = app.ui.metrics.unit
				if is_instance_valid(app.ui.sheet):
					check(safe.grow(0.1).encloses(app.ui.sheet.get_global_rect()),"Matrix sheet stays safe: "+route)
					check(app.ui.sheet.get_global_rect().end.y<=app.ui.metrics.footer_rect.position.y+0.1,"Matrix dock remains reachable: "+route)
					check(app.ui.sheet.back.size.x>=48*unit-0.01 and app.ui.sheet.back.size.y>=48*unit-0.01,"Matrix Back meets physical target: "+route)
					if app.ui.sheet.primary.visible: check(app.ui.sheet.primary.size.y>=56*unit-0.01,"Matrix pinned action meets physical target: "+route)
					if DisplayServer.window_get_size().x>=1000: check(app.ui.sheet.size.x<=620*unit,"Desktop detail uses a reading column: "+route)
				await final_capture(route.to_lower()+"-"+str(roundi(scale*100))+"-"+("inset" if inset else "plain"))
				if route=="Pet":
					var toys: Control = app.ui.sheet.find_child("toys",true,false)
					for toy in toys.get_children():
						check(toy.get_global_rect().grow(1).encloses(toy._art.get_global_rect()),"Care toy artwork stays inside its actual target")
						for caption in toy.find_children("*","Label",true,false):
							check(toy.get_global_rect().grow(1).encloses(caption.get_global_rect()),"Care toy caption stays inside its actual target")
					app.ui.sheet.scroll.ensure_control_visible(toys.get_child(0))
					await final_capture("care-toys-"+str(roundi(scale*100))+"-"+("inset" if inset else "plain"))
				if route=="Map" and scale>1.0:
					await click(app.ui.sheet.find_child("Destination_1",true,false))
					apply_matrix_geometry(scale,inset)
					await settle()
					for frame in range(3): app.ui._advance_sheet_restore()
					await settle()
					var details: Control = app.ui.sheet.find_child("DestinationDetails",true,false)
					check(details.has_focus(),"Selected destination details receive deliberate visible focus")
					for requirement in ["RequirementLevel","RequirementCoins"]:
						check(app.ui.sheet.scroll.get_global_rect().grow(1).encloses(app.ui.sheet.find_child(requirement,true,false).get_global_rect()),"Selection reveals both live Seaside requirements: "+requirement)
					await final_capture("map-selected-seaside-"+str(roundi(scale*100))+"-"+("inset" if inset else "plain"))
	app.ui.set_process(true)
	app.ui.relayout()
	for index in [11,13]:
		app.ui.open_cat(index)
		await settle()
		check(app.ui.sheet.find_child("PettingView",true,false)==null,"Unknown and paid guests do not expose a live care stage")
		await final_capture("cat-"+("unknown" if index==11 else "paid")+"-150-plain")

func apply_matrix_geometry(scale: float,inset: bool) -> void:
	var unit: float = app.ui.metrics.unit
	var viewport: Vector2 = app.ui.size
	var safe := Rect2(Vector2.ZERO,viewport)
	if inset: safe = Rect2(Vector2(12,24)*unit,viewport-Vector2(30,44)*unit)
	app.ui.metrics = app.ui.PhoneLayout.measure(viewport,safe,1.0/unit,scale)
	app.ui._apply_theme_metrics()
	app.ui._apply_control_metrics(app.ui)
	app.ui._apply_shell_geometry()
	app.ui._layout_navigation()
	app.ui._layout_home()
	if is_instance_valid(app.ui.sheet): app.ui.sheet.relayout(app.ui._sheet_bounds())
	app.ui.CatViews.relayout(app.ui)
	app.ui.LifeViews.relayout(app.ui)

func final_capture(title: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var extent := DisplayServer.window_get_size()
		app.ui.toast_timer = 0
		app.ui.toast_label.hide()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/final-%dx%d-%s.png" % [extent.x,extent.y,title])
