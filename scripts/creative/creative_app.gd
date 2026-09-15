extends Node
## Separate entry point: never opens or migrates the legacy game profile.
const Model=preload("res://scripts/creative/creative_model.gd")
const Store=preload("res://scripts/core/game_store.gd")
@export var save_path: String="user://creative-social-preview-save"
var model
var world
var ui
var store
var soundscape
var save_error: String=""
var blocked_save:=false
var _save_elapsed:=0.0
var _active:=true
var _close_dialog: ConfirmationDialog

func _ready() -> void:
	DisplayServer.window_set_title("Purrington Hotel · Creative Social Preview")
	get_tree().auto_accept_quit=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="): save_path=arg.trim_prefix("--save-path=")
	model=Model.new(); store=Store.new(save_path)
	if not store.load_model(model,int(Time.get_unix_time_from_system())):
		blocked_save=store.error_message!=""
		save_error=store.error_message
		model.new_game(int(Time.get_unix_time_from_system()))
		if not blocked_save: save()
	world=load("res://scripts/creative/creative_world.gd").new()
	add_child(world); world.setup(model)
	var layer:=CanvasLayer.new(); layer.layer=1; add_child(layer)
	ui=load("res://scripts/creative/creative_ui.gd").new()
	ui.app=self; layer.add_child(ui)
	soundscape=load("res://scripts/audio/audio_director.gd").new(); add_child(soundscape)
	apply_settings(); ui.refresh(); world.focus_hotel()

func save(_value=null) -> bool:
	if blocked_save: return false
	var previous_error:=save_error
	model.state.last_seen=int(Time.get_unix_time_from_system())
	var success: bool=store.save_model(model)
	save_error="" if success else store.error_message
	if not success and save_error.is_empty(): save_error="Your progress could not be saved. Please retry."
	if previous_error!=save_error and is_instance_valid(ui): ui.refresh.call_deferred()
	return success

func perform(action: String, payload: Dictionary={}) -> Dictionary:
	if blocked_save: return {"ok":false,"message":save_error,"cost":0,"displaced":[]}
	var result: Dictionary
	if action=="undo": result=model.undo(Callable(self,"save"))
	elif action=="redo": result=model.redo(Callable(self,"save"))
	elif action in ["collect","claim"]:
		var before: Dictionary=model.serialize()
		var amount: float=float(model.state.pending_coins)
		model.state.coins=float(model.state.coins)+amount; model.state.pending_coins=0.0
		if save(): result={"ok":true,"message":"Collected %d Cat Coins" % int(amount),"cost":-amount}
		else: model.state=before; result={"ok":false,"message":"Could not save. Your earnings are waiting.","cost":0}
	elif action=="playdate":
		result=_playdate(payload)
	else: result=model.commit(action,payload,Callable(self,"save"))
	if result.ok:
		world.sync()
		if soundscape!=null: soundscape.play_effect("build" if float(result.get("cost",0))>=0 else "collect")
	return result

func travel(index: int) -> Dictionary:
	if blocked_save: return {"ok":false,"message":save_error}
	var result: Dictionary=model.travel(index,Callable(self,"save"))
	if result.ok:
		world.clear_preview(); world.sync(); world.focus_hotel(); apply_settings()
	return result

func care(cat: int, action: String) -> Dictionary:
	var before: Dictionary=model.serialize()
	var result: Dictionary=model.care(cat,action)
	if result.ok and not save(): model.state=before; return {"ok":false,"message":"Could not save. Try again."}
	if result.ok:
		if soundscape!=null: soundscape.play_effect("purr" if action in ["pet","brush"] else "toy")
		if world.get("actors")!=null and world.actors.has(cat): world.actors[cat].react("purr" if action in ["pet","brush"] else "play",3)
	return result

func set_god_mode(enabled: bool) -> Dictionary:
	if blocked_save: return {"ok":false,"message":save_error}
	var result: Dictionary=model.set_god_mode(enabled,Callable(self,"save"))
	if result.ok:
		world.clear_preview(); world.sync(); apply_settings()
	return result

func _playdate(p: Dictionary) -> Dictionary:
	var first:=int(p.get("cat",0)); var second:=int(p.get("other",1))
	if first<0 or second<0 or first>=18 or second>=18 or first==second: return {"ok":false,"message":"Choose two different cats."}
	for id in [first,second]:
		if not model.is_god_mode() and (not model.state.cats[id].known or int(model.state.cats[id].bond)<10): return {"ok":false,"message":"Get to know both cats first · 10 friendship each."}
	var open:=false
	for venue in model.venues():
		if venue.open and venue.role=="seat" and int(venue.service)==2: open=true
	if not open: return {"ok":false,"message":"Create a reachable social lounge first."}
	var before: Dictionary=model.serialize()
	model.state.cats[first]["friend"]=second; model.state.cats[second]["friend"]=first
	if not save(): model.state=before; return {"ok":false,"message":"Could not save. Try again."}
	return {"ok":true,"message":"A new friendship! Your guests can spend time together."}

func test_purchase(product: String) -> Dictionary:
	if product not in ["purrington.forest_lodge","purrington.snowcap_spa","purrington.cat_club"]: return {"ok":false,"message":"Choose a preview expansion."}
	if model.state.entitlements.has(product): return {"ok":true,"message":"Already available in this test preview."}
	var before: Dictionary=model.serialize()
	model.state.entitlements.append(product)
	if product=="purrington.cat_club":
		for cat in [12,13,14]: model.state.cats[cat].known=true
	elif product=="purrington.forest_lodge": model.state.cats[16].known=true
	else:
		for cat in [15,17]: model.state.cats[cat].known=true
	if not save(): model.state=before; return {"ok":false,"message":"Could not save. Try again."}
	return {"ok":true,"message":"Test expansion added · no real purchase"}

func apply_settings() -> void:
	if model==null: return
	if soundscape!=null: soundscape.configure(model.state.settings,int(model.state.current_hotel),_active,true)
	if world!=null:
		world.set_outside(bool(model.state.settings.get("exterior",false)))
		if world.has_method("apply_visual_settings"): world.apply_visual_settings()

func _process(delta: float) -> void:
	if model==null or not _active or blocked_save: return
	model.advance(delta)
	_save_elapsed+=delta
	if _save_elapsed>=15: _save_elapsed=0; save()

func _notification(what: int) -> void:
	if model==null: return
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()
	elif what==NOTIFICATION_APPLICATION_PAUSED:
		_active=false; save(); apply_settings()
	elif what==NOTIFICATION_APPLICATION_RESUMED:
		model.reconcile(int(Time.get_unix_time_from_system())); _active=true; apply_settings()

func request_close() -> void:
	if blocked_save or save():
		if soundscape!=null: soundscape.shutdown()
		get_tree().quit(); return
	if not is_instance_valid(_close_dialog):
		_close_dialog=ConfirmationDialog.new()
		_close_dialog.title="Your progress needs to be saved"
		_close_dialog.dialog_text="Saving did not finish. Retry to keep your latest progress, or keep playing and try again."
		_close_dialog.ok_button_text="Retry save"
		_close_dialog.cancel_button_text="Keep playing"
		_close_dialog.add_button("Exit without saving",false,"discard")
		_close_dialog.confirmed.connect(request_close)
		_close_dialog.custom_action.connect(func(action: String):
			if action=="discard": get_tree().quit())
		add_child(_close_dialog)
	_close_dialog.popup_centered(Vector2i(360,190))
