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

func travel_capture(title: String) -> void:
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task7-" + title + "-" + str(DisplayServer.window_get_size().x) + "x" + str(DisplayServer.window_get_size().y) + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var key := "res://tmp/mobile-views-" + str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = key
	root.add_child(app)
	await process_frame
	app.start_game()
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
		app.ui._invitations()
		await settle()
		check(not app.ui.sheet.find_child("Playdate_2", true, false).disabled, "Lounge and both bonds enable a playdate")
		await click(app.ui.sheet.find_child("Playdate_2", true, false))
		check(app.model.life.state.cats[1].friend == 2 and app.model.life.state.cats[2].friend == 1, "Playdate button creates the selected real friendship pair")
	await life_coverage()
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix): DirAccess.remove_absolute(key + suffix)
	print("MOBILE VIEWS TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)

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
	for scale in [1.0,1.5]:
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
