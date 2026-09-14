extends Node

const Model = preload("res://scripts/core/hotel_model.gd")
const Store = preload("res://scripts/core/game_store.gd")
const World = preload("res://scripts/world/hotel_world.gd")
const UI = preload("res://scripts/ui/hotel_ui.gd")
const Content = preload("res://scripts/core/game_content.gd")
const Commerce = preload("res://scripts/commerce/commerce_service.gd")
const Layout = preload("res://scripts/core/room_layout.gd")

@export var save_path: String = "user://hotel-save"
var model = Model.new()
var store
var world
var ui
var active: bool = true
var ticks: int = 0
var refresh_elapsed: float = 0.0
var save_elapsed: float = 0.0
var save_error: String = ""
var soundscape
var block_start: bool = false
var closing: bool = false
var commerce
var notice_elapsed: float = 0.0
var observed_events: Dictionary = {}
var ad_showing: bool = false
var activity
var build_panel
var build_input = preload("res://scripts/ui/build_input.gd").new()
var draft_store
var draft_session
var draft_elapsed := 0.0
var recovered_draft: Dictionary = {}
var build_history = preload("res://scripts/core/build_history.gd").new()

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
	if OS.get_cmdline_user_args().has("--commerce-preview") and OS.has_feature("debug") and not OS.has_feature("mobile"):
		save_path = "user://commerce-preview-save"
	store = Store.new(save_path)
	var loaded: bool = store.load_model(model, int(Time.get_unix_time_from_system()))
	draft_store = preload("res://scripts/core/build_draft_store.gd").new(save_path)
	if loaded: recovered_draft = draft_store.recover(model)
	if not loaded and store.error_message != "":
		save_error = store.error_message
		block_start = true
	world = World.new()
	add_child(world)
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	activity = preload("res://scripts/ui/world_activity.gd").new()
	activity.world = world
	activity.model = model
	layer.add_child(activity)
	ui = UI.new()
	activity.ui = ui
	layer.add_child(ui)
	ui.world_rect_changed.connect(world.set_ui_world_rect)
	world.set_ui_world_rect(ui.metrics.world_rect)
	build_panel = preload("res://scripts/ui/build_panel.gd").new()
	build_panel.app = self
	build_panel.ui = ui
	layer.add_child(build_panel)
	ui.build_requested.connect(func(): build_panel.open())
	ui.modal_requested.connect(build_panel.dismiss_for_menu)
	world.room_selected.connect(func(index): build_panel.open(index) if model.started else null)
	world.build_tapped.connect(func(point): build_panel.world_tapped(point))
	ui.grounds_requested.connect(perform_grounds)
	ui.manager_mode_requested.connect(func(enabled):
		if enabled and model.settings.exterior:
			change_setting("exterior",false)
		world.neighborhood.manager_control = enabled
		ui.manager_mode = enabled
		ui.close_sheet()
		world.focus_grounds() if enabled else world.reset_camera()
		_update_ui()
	)
	world.grounds_selected.connect(select_grounds)
	ui.play_requested.connect(start_game)
	ui.expansion_requested.connect(expand_hotel)
	ui.ui_sound_requested.connect(func(): soundscape.play_effect("tap") if soundscape != null else null)
	world.expansion_selected.connect(func(wing): ui.open_expansions(wing) if model.started else null)
	ui.upgrade_requested.connect(buy_upgrade)
	ui.hotel_requested.connect(visit_hotel)
	ui.claim_requested.connect(collect_earnings)
	ui.setting_changed.connect(change_setting)
	ui.zone_focus_requested.connect(func(index):
		if model.settings.exterior:
			change_setting("exterior",false)
		world.focus_zone(index)
	)
	ui.reset_camera_requested.connect(world.reset_camera)
	ui.hotel_focus_requested.connect(world.focus_hotel)
	ui.action_requested.connect(perform_action)
	ui.purchase_requested.connect(func(id): commerce.purchase(id))
	ui.restore_requested.connect(func(): commerce.restore_purchases())
	ui.photo_requested.connect(take_photo)
	ui.privacy_requested.connect(func(): commerce.ad_adapter.open_privacy_options())
	world.staff_selected.connect(func(_index): ui._navigate("Staff"))
	world.zone_selected.connect(func(zone):
		if model.started:
			ui.open_upgrades(zone)
	)
	world.cat_selected.connect(func(index):
		if model.started and model.life.known(index):
			soundscape.meow()
			ui.open_cat(index)
	)
	_setup_audio()
	commerce = Commerce.new()
	commerce.changed.connect(ui.update_commerce)
	commerce.purchased.connect(_fulfill_purchase)
	commerce.ad_visibility_changed.connect(func(value):
		ad_showing = value
		soundscape.configure(model.settings,model.current_hotel,active and not value,false)
	)
	commerce.preview_ad_requested.connect(_show_test_ad)
	add_child(commerce)
	if commerce.preview:
		commerce.preview_owned = model.life.state.entitlements.duplicate()
	commerce.set_ads_removed(not model.life.state.entitlements.is_empty())
	if loaded:
		_rebuild_world()
		if not model.settings.watch: world.focus_hotel()
		_save()
		world.react_cat(model.life.state.favorite,"head_bump" if model.life.state.cats[model.life.state.favorite].bond>=100 else "greet")
	_update_ui()
	if model.pending_coins > 0:
		ui.show_offline()
	if save_error != "":
		ui.show_toast(save_error)
	elif not recovered_draft.is_empty():
		ui.show_toast("A saved room makeover is waiting in Build.")
	ticks = Time.get_ticks_usec()

func start_game() -> void:
	if model.started or block_start:
		if block_start:
			ui.show_toast(save_error)
		return
	model.new_game(int(Time.get_unix_time_from_system()))
	if not _save():
		model.started = false
		ui.show_toast(save_error)
		return
	ticks = Time.get_ticks_usec()
	_rebuild_world()
	_update_ui()
	soundscape.play_effect("open")
	ui.show_toast("Welcome home. Your suites are already earning!")
	world.focus_hotel()

func _settle() -> void:
	var now: int = Time.get_ticks_usec()
	if active and model.started and ticks > 0:
		model.advance(float(now - ticks) / 1000000.0)
	ticks = now

func _process(delta: float) -> void:
	if closing or not active or not model.started:
		return
	if draft_session != null:
		draft_elapsed += delta
		if draft_elapsed >= 1.0: flush_draft()
	var previous_coins: int = model.coins_units
	_settle()
	soundscape.note_income(float(model.coins_units - previous_coins) / Model.UNIT)
	refresh_elapsed += delta
	save_elapsed += delta
	if refresh_elapsed >= 0.25:
		refresh_elapsed = 0
		_sync_repairs()
		_update_ui()
		world.apply_life(model)
		while not model.grounds.notices.is_empty():
			var notice: Dictionary = model.grounds.notices.pop_front()
			if notice.hotel == model.current_hotel:
				ui.show_toast(notice.message)
				_feedback("collect")
			_save()
		for h in range(model.hotels.size()):
			var running: bool = not model.life.state.hotels[h].event.is_empty()
			if observed_events.get(h,false) and not running and ui.tab == "Hotel":
				commerce.natural_break("event_finished")
			observed_events[h] = running
	notice_elapsed += delta
	if notice_elapsed > 6 and not model.life.notices.is_empty() and ui.tab=="Hotel" and not model.settings.watch:
		notice_elapsed = 0
		var note: Dictionary = model.life.notices.pop_front()
		ui.show_toast(note.message)
		if note.get("cat",-1)>=0:
			if note.get("hotel",model.current_hotel)==model.current_hotel:
				if note.get("animation","")=="visit":
					world.guest_visit(model,note.cat)
				else:
					world.react_cat(note.cat,note.get("animation",""),note.get("buddy",-1))
	if save_elapsed >= 5.0:
		save_elapsed = 0
		_save()

func buy_upgrade(zone: int) -> void:
	_settle()
	if not _prepare_transaction():
		return
	var before: Dictionary = model.serialize()
	if not model.upgrade(model.current_hotel, zone):
		ui.show_toast("A few more Cat Coins and this can be yours.")
		return
	if not _commit(before):
		return
	_rebuild_world()
	_update_ui()
	world.celebrate_build()
	_feedback()
	ui.show_toast("%s improved! +10 Cat Coins / min" % Model.ZONE_NAMES[zone])

func visit_hotel(index: int) -> void:
	_settle()
	if not _prepare_transaction() or index < 0 or index >= model.hotels.size():
		return
	var before: Dictionary = model.serialize()
	if model.hotels[index].owned:
		model.current_hotel = index
	elif not model.unlock_hotel(index):
		ui.show_toast("Reach Meadow level 10 and save 10,000 Cat Coins.")
		return
	if not _commit(before):
		return
	_rebuild_world()
	world.reset_camera()
	ui.close_sheet()
	_update_ui()
	_feedback("open")
	ui.show_toast("Welcome to " + Model.HOTEL_NAMES[index])
	world.focus_hotel()
	world.react_cat(model.life.state.favorite,"arrival")
	commerce.natural_break("hotel_change")

func collect_earnings() -> void:
	_settle()
	if not _prepare_transaction() or model.pending_coins <= 0:
		return
	var before: Dictionary = model.serialize()
	var reward: int = model.claim()
	if not _commit(before):
		return
	_update_ui()
	_feedback("collect")
	ui.show_toast("Collected %s Cat Coins. Welcome back!" % ui.number(reward))

func change_setting(key: String, value: Variant) -> void:
	var numeric_setting: bool = key in ["ui_text_scale", "build_text_scale"]
	if not model.settings.has(key) or (numeric_setting and (not (value is float or value is int) or value not in [1.0,1.25,1.5])) or (not numeric_setting and not value is bool):
		return
	_settle()
	var before: Dictionary = model.serialize()
	model.settings[key] = float(value) if numeric_setting else value
	if key == "ui_text_scale":
		model.settings.build_text_scale = float(value)
	if not _commit(before):
		return
	world.set_motion_enabled(model.settings.motion)
	world.set_evening(model.settings.evening)
	world.apply_life(model)
	ui.relayout()
	if build_panel != null and build_panel.visible:
		build_panel._resize()
		build_panel.restore_preview()
	_update_ui()

func _prepare_transaction() -> bool:
	if not model.started:
		return false
	if save_error != "" and not _save():
		ui.show_toast(save_error)
		return false
	return true

func _commit(before: Dictionary) -> bool:
	if _save():
		return true
	model.restore(before)
	_update_ui()
	ui.show_toast(save_error)
	return false

func _save() -> bool:
	if not model.started:
		return false
	model.last_seen = maxi(model.last_seen, int(Time.get_unix_time_from_system()))
	var success: bool = store.save_model(model)
	save_error = "" if success else store.error_message
	return success

func _rebuild_world() -> void:
	world.show_hotel(model.current_hotel, model.hotels[model.current_hotel].zones, model.wing_count(model.current_hotel))
	world.set_motion_enabled(model.settings.motion)
	world.set_evening(model.settings.evening)
	world.apply_life(model)
	if build_panel != null and build_panel.visible:
		build_panel.restore_preview()

func _update_ui() -> void:
	_sync_audio()
	if not model.started:
		ui.render({"started": false})
		return
	var selected: int = model.current_hotel
	var costs: Array = []
	for zone in range(4):
		costs.append(model.upgrade_cost(selected, zone))
	ui.render(_with_life({"started": true, "repair_remaining": model.repair_remaining(selected), "repair_seconds": Model.REPAIR_SECONDS, "wings": model.wing_count(selected), "rooms": model.room_count(selected), "wing_names": Model.WING_NAMES, "wing_costs": Model.WING_COSTS, "wing_levels": Model.WING_LEVELS, "wing_rates": Model.WING_RATES, "can_expand": model.can_expand(selected), "coins": model.coins, "rate": model.rate(), "hotel": selected, "hotel_name": Model.HOTEL_NAMES[selected], "hotel_names": Model.HOTEL_NAMES, "hotel_level": model.hotel_level(selected), "levels": model.hotels[selected].zones.duplicate(), "purchases": model.hotels[selected].purchases, "zone_names": Model.ZONE_NAMES, "zone_descriptions": Model.ZONE_DETAILS, "costs": costs, "owned": [model.hotels[0].owned, model.hotels[1].owned], "hotel_rates": [model.hotel_rate(0), model.hotel_rate(1)], "meadow_level": model.hotel_level(0), "can_unlock": model.hotel_level(0) >= 10 and model.coins >= 10000 and not model.hotels[1].owned, "pending": model.pending_coins, "pending_seconds": model.pending_seconds, "away_seconds": model.away_seconds, "cats_unlocked": model.discovered_cats(), "cat_names": Model.CAT_NAMES, "cat_traits": Model.CAT_TRAITS, "settings": model.settings.duplicate(), "save_error": save_error}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
		if ui.tab == "Build":
			build_panel.cancel() if build_panel.placing or build_panel.selected_item != "" else build_panel.close()
		else:
			ui.go_back()
		return
	if soundscape != null and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		soundscape.configure(model.settings, model.current_hotel, false, false)
	if soundscape != null and what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		soundscape.configure(model.settings, model.current_hotel, true, model.started and ui.tab == "Hotel")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if closing:
			return
		closing = true
		flush_draft()
		if model.started:
			_settle()
			_save()
		active = false
		if soundscape != null:
			soundscape.shutdown()
		# Give the audio server time to release queued playback before engine teardown.
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()
		return
	if ui == null or not model.started:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		build_input.reset()
		flush_draft()
		if active:
			_settle()
			_save()
			active = false
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not active:
			model.reconcile(int(Time.get_unix_time_from_system()))
			_sync_repairs()
			active = true
			ticks = Time.get_ticks_usec()
			_save()
			_update_ui()
			if model.pending_coins > 0:
				ui.show_offline()

func _unhandled_input(event: InputEvent) -> void:
	if ui != null and ui.tab == "Build":
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				build_panel.cancel() if build_panel.placing or build_panel.selected_item != "" else build_panel.close()
			elif event.keycode == KEY_R and build_panel.placing:
				build_panel.rotate()
			return
		return
	if ui != null and ui.tab == "Hotel":
		if model.settings.watch:
			return
		if OS.has_feature("mobile") and (event is InputEventMouseButton or event is InputEventMouseMotion):
			return
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			if not ui.world_input_contains(event.position):
				return
		world.handle_input(event)

func _setup_audio() -> void:
	soundscape = preload("res://scripts/audio/audio_director.gd").new()
	add_child(soundscape)
	_sync_audio()

func _sync_audio() -> void:
	if soundscape != null:
		soundscape.configure(model.settings, model.current_hotel, active and not ad_showing, model.started and ui.tab == "Hotel")

func _feedback(kind: String = "spend") -> void:
	soundscape.play_effect(kind)
	if model.settings.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(30)

func expand_hotel() -> void:
	_settle()
	if not _prepare_transaction():
		return
	var before: Dictionary = model.serialize()
	var next_wing: int = model.wing_count(model.current_hotel)
	if not model.start_repair(model.current_hotel):
		ui.show_toast("Keep upgrading and saving Cat Coins to add your next wing.")
		return
	if not _commit(before):
		return
	_rebuild_world()
	ui.close_sheet()
	_update_ui()
	_feedback("build")
	world.reset_camera()
	ui.show_toast("Construction cats are repairing %s. Ready in %ds!" % [Model.WING_NAMES[next_wing], Model.REPAIR_SECONDS[next_wing]])

func _sync_repairs() -> void:
	if world.wings != model.wing_count(model.current_hotel):
		_rebuild_world()
		_save()
		world.celebrate_build()
		_feedback("build")
		ui.show_toast("Repairs complete! New floor space is ready. Open Build to place rooms.")

func _input(event: InputEvent) -> void:
	# GUI controls can consume releases; clear gestures even when a drag ends on a menu.
	if world == null:
		return
	if ui != null and ui.tab == "Build" and build_panel.visible:
		for command in build_input.feed(event,build_panel.input_context()):
			build_panel.handle_command(command)
		return
	if event is InputEventMouseButton and not event.pressed:
		world.set_deferred("dragging", false)
		if (ui.tab == "Build" and not build_panel.contains_world(event.position)) or (ui.tab != "Build" and (ui.tab != "Hotel" or not ui.world_input_contains(event.position))):
			world.dragging = false
	if event is InputEventScreenTouch and not event.pressed:
		world.call_deferred("release_touch", event.index)
		if (ui.tab == "Build" and not build_panel.contains_world(event.position)) or (ui.tab != "Build" and (ui.tab != "Hotel" or not ui.world_input_contains(event.position))):
			world.touches.erase(event.index)

func _with_life(data: Dictionary) -> Dictionary:
	data.life = model.life.serialize()
	data.grounds = model.grounds.serialize()
	data.privacy_available = commerce != null and commerce.ad_adapter != null and commerce.ad_adapter.privacy_options_available()
	data.owned = []
	data.hotel_rates = []
	for h in range(model.hotels.size()):
		data.owned.append(model.hotels[h].owned)
		data.hotel_rates.append(model.hotel_rate(h))
	data.room_combos = []
	data.room_furnishings = []
	for room in range(model.room_count(model.current_hotel)):
		data.room_furnishings.append(model.life.room_items(model.current_hotel,room).map(func(instance): return instance.item))
		data.room_combos.append(model.life.room_combos(model.current_hotel,room).map(func(combo): return combo.name))
	data.star_checks = model.life.star_checks(model,model.current_hotel)
	data.event_scores = {}
	for event in Content.EVENTS:
		data.event_scores[event.id] = model.life.event_score(model,model.current_hotel,event.id)
	return data

func perform_action(action: String, payload: Dictionary = {}) -> void:
	if action == "furnish":
		build_panel.open(int(payload.get("room",0)))
		build_panel.preview_item(str(payload.get("item","")))
		return
	_settle()
	if not _prepare_transaction():
		return
	var before: Dictionary = model.serialize()
	var result: Dictionary = model.life.perform(model,action,payload)
	if not result.get("ok",false):
		ui.show_toast(result.message)
		return
	if not _commit(before):
		return
	if result.get("rebuild",false):
		_rebuild_world()
	else:
		world.apply_life(model)
	if result.get("animation","") != "":
		world.react_cat(int(result.get("cat",model.life.state.favorite)),result.animation,result.get("buddy",-1))
	if action=="interact":
		var kind: String = payload.get("kind","pet")
		_feedback("purr" if kind in ["pet","brush","cushion"] else ("bell" if kind=="bell" else "toy"))
	else:
		_feedback("build" if action=="furnish" else "tap")
	_update_ui()
	ui.refresh_after_action(action)
	ui.show_toast(result.message)

func perform_layout(action: String, payload: Dictionary) -> Dictionary:
	_settle()
	if not _prepare_transaction():
		return {"ok":false,"message":save_error}
	var before: Dictionary = model.serialize()
	var history_before: Dictionary = build_history.capture(model)
	var result: Dictionary = Layout.perform(model,action,payload)
	if not result.ok:
		return result
	model.grounds.layout_changed(model,model.current_hotel)
	if not _commit(before):
		return {"ok":false,"message":save_error}
	build_history.record(history_before,model,int(before.coins_units)-model.coins_units)
	_rebuild_world()
	_update_ui()
	_feedback("build")
	return result

func queue_draft(session) -> void:
	draft_session = session
	draft_elapsed = 0.0

func flush_draft() -> void:
	if draft_session == null or draft_store == null: return
	if draft_store.save_session(draft_session):
		draft_session = null
	else:
		draft_elapsed = 0.0
		if build_panel != null: build_panel.show_error(draft_store.error_message)

func discard_draft() -> bool:
	if draft_store != null and not draft_store.clear(): return false
	draft_session = null
	recovered_draft = {}
	return true

func apply_build(session, reviewed_cost: int = -1) -> Dictionary:
	_settle()
	if not _prepare_transaction(): return {"ok":false,"message":save_error}
	var before := model.serialize()
	var history_before: Dictionary = build_history.capture(model)
	var notices: Array = model.life.notices.duplicate(true)
	var edit: Dictionary = session.patch()
	if reviewed_cost >= 0: edit.cost_coins = reviewed_cost
	var result: Dictionary = model.furniture.apply(model,edit)
	if not result.ok: return result
	if not result.already_applied:
		if session.room>=0: model.life.discover_combos(session.hotel,session.room)
		model.life.touch()
		model.grounds.layout_changed(model,session.hotel)
	if not _commit(before):
		model.life.notices = notices
		return {"ok":false,"message":save_error}
	if not result.already_applied: build_history.record(history_before,model,int(before.coins_units)-model.coins_units)
	discard_draft()
	world.apply_life(model)
	_update_ui()
	_feedback("build")
	return result

func transfer_build(source_room: int, target_room: int, instance: Dictionary) -> Dictionary:
	return _build_operation(func(): return model.furniture.transfer(model,model.current_hotel,source_room,target_room,str(instance.uid),int(instance.x),int(instance.y),int(instance.rotation)))

func paste_build(blueprint: Dictionary, candidate: Dictionary) -> Dictionary:
	return _build_operation(func(): return preload("res://scripts/core/room_blueprint.gd").place(model,model.current_hotel,blueprint,candidate),true)

func _build_operation(operation: Callable, rebuild: bool = false) -> Dictionary:
	_settle()
	if not _prepare_transaction(): return {"ok":false,"message":save_error}
	var before: Dictionary = model.serialize()
	var notices: Array = model.life.notices.duplicate(true)
	var history_before: Dictionary = build_history.capture(model)
	var result: Dictionary = operation.call()
	if not result.ok: return result
	for room in range(model.room_count(model.current_hotel)): model.life.discover_combos(model.current_hotel,room)
	model.life.touch()
	model.grounds.layout_changed(model,model.current_hotel)
	if not _commit(before):
		model.life.notices=notices
		return {"ok":false,"message":save_error}
	build_history.record(history_before,model,int(before.coins_units)-model.coins_units)
	if rebuild: _rebuild_world()
	else: world.apply_life(model)
	_update_ui(); _feedback("build")
	return result

func undo_build(redo: bool = false) -> Dictionary:
	_settle()
	if not _prepare_transaction(): return {"ok":false,"message":save_error}
	var before: Dictionary = model.serialize()
	var history_before: Dictionary = build_history.checkpoint()
	var result: Dictionary = build_history.redo(model) if redo else build_history.undo(model)
	if not result.ok: return result
	model.life.touch()
	for hotel in range(model.hotels.size()):
		if not model.hotels[hotel].owned: continue
		var prior: Dictionary={}; var current: Dictionary={}
		for instance in before.furniture.instances:
			if int(instance.hotel)==hotel: prior[str(instance.uid)]=instance
		for instance in model.furniture.state.instances:
			if int(instance.hotel)==hotel: current[str(instance.uid)]=instance
		if prior!=current or before.hotels[hotel].layout!=model.hotels[hotel].layout:
			model.grounds.layout_changed(model,hotel)
	if not _commit(before):
		build_history.restore_checkpoint(history_before)
		return {"ok":false,"message":save_error}
	_rebuild_world(); _update_ui(); _feedback("tap")
	return result

func _fulfill_purchase(product_id: String, token: String) -> void:
	_settle()
	if not _prepare_transaction():
		commerce.fulfilled(token,false)
		return
	var before: Dictionary = model.serialize()
	if not model.life.grant_product(model,product_id):
		commerce.fulfilled(token,false)
		return
	var saved: bool = _commit(before)
	commerce.fulfilled(token,saved)
	if saved:
		_update_ui()
		ui.show_toast("Expansion unlocked. Every ad has been removed.")

func _show_test_ad() -> void:
	if not commerce.preview or commerce.ads_removed:
		return
	ui.tab = "TestAd"
	var col = ui._base_sheet("TEST AD · Preview only",370)
	col.add_child(ui.paragraph("This is an ad-placement test. No advertising service was contacted. Buying any test expansion removes these breaks."))
	col.add_child(ui.button("Close test ad",ui.close_sheet,true))

func take_photo() -> void:
	if DisplayServer.get_name() == "headless":
		return
	ui.close_sheet()
	ui.visible = false
	activity.hide()
	await RenderingServer.frame_post_draw
	var directory: String = "user://photos"
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory + "/hotel-" + str(Time.get_unix_time_from_system()).replace(".","-") + ".png"
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	ui.visible = true
	if error==OK:
		model.life.memory("photo_"+path.get_file(),"A postcard from "+Model.HOTEL_NAMES[model.current_hotel],"Your photo was saved to your hotel photo album on this device.",model.life.state.favorite,model.current_hotel)
		model.life.state.memories[-1].photo = path
		_save()
		_update_ui()
		ui.show_toast("Photo saved to your hotel album.")
	else:
		ui.show_toast("Couldn't save the photo. Please check device storage.")

func select_grounds(action: String, payload: Dictionary) -> void:
	if not model.started or model.settings.watch:
		return
	match action:
		"amenity": ui.open_amenity(str(payload.id))
		"manager": ui._navigate("Manager")
		"kiosk": ui._navigate("Kiosk")
		_: perform_grounds(action,payload)

func perform_grounds(action: String, payload: Dictionary = {}) -> void:
	_settle()
	if not _prepare_transaction():
		return
	var before: Dictionary = model.serialize()
	var result: Dictionary = model.grounds.perform(model,action,payload)
	if not result.ok:
		ui.show_toast(result.message)
		return
	if not _commit(before):
		return
	world.apply_life(model)
	_update_ui()
	if action in ["trim","chase","clean","walk"]:
		ui.close_sheet()
	elif ui.tab in ["Grounds","Amenity","Manager","Kiosk"]:
		ui._refresh_sheet()
	_feedback(result.get("sound","tap"))
	ui.show_toast(result.message)
