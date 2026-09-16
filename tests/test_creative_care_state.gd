extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const Audio=preload("res://scripts/audio/audio_director.gd")
class CareApp extends "res://scripts/creative/creative_app.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
class CountingStore extends RefCounted:
	var calls:=0
	var succeed:=true
	var error_message:="Storage is unavailable."
	func save_model(_model) -> bool:
		calls+=1
		return succeed
class CareUI extends Node:
	var refresh_count:=0
	func refresh() -> void: refresh_count+=1
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=Model.new()
	model.new_game()
	var favorite: String=Model.Legacy.FAVORITE_ACTIONS[0]
	var ordinary: String="brush" if favorite=="pet" else "pet"
	var result: Dictionary=model.care(0,ordinary)
	check(result.ok and result.progress_changed and model.state.cats[0].bond==3,"Ordinary care awards three friendship")
	var snapshot: Dictionary=model.serialize()
	result=model.care(0,favorite)
	check(result.ok and not result.progress_changed and model.serialize()==snapshot,"Cooldown permits interaction without changing state")
	model.state.time=11.999
	check(not model.care(0,favorite).progress_changed,"Cooldown lasts the full twelve seconds")
	model.state.time=12.0
	check(model.care(0,favorite).progress_changed and model.state.cats[0].bond==9,"Favorite care awards six at the cooldown boundary")
	model.state.cats[0].bond=99
	model.state.time=24.0
	check(model.care(0,favorite).progress_changed and model.state.cats[0].bond==100,"Friendship caps at one hundred")
	model.state.time=36.0
	snapshot=model.serialize()
	check(not model.care(0,favorite).progress_changed and model.serialize()==snapshot,"A fully befriended cat does not mutate its care timestamp")
	check(not model.care(0,"invalid").ok and not model.care(17,"pet").ok,"Unknown cats and invalid tools cannot receive progress")
	var app=CareApp.new()
	app.model=Model.new(); app.model.new_game()
	app.store=CountingStore.new()
	app.ui=CareUI.new(); app.add_child(app.ui)
	root.add_child(app)
	app.blocked_save=true; app.save_error="Protected profile"
	snapshot=app.model.serialize()
	result=app.care(0,"pet",false)
	check(not result.ok and not result.progress_changed and app.model.serialize()==snapshot and app.store.calls==0,"Blocked saves reject care before mutation")
	app.blocked_save=false; app.save_error=""
	app.store.succeed=false
	result=app.care(0,"pet",false)
	check(not result.ok and not result.progress_changed and app.model.serialize()==snapshot,"Failed saves roll back the bond, timestamp and last-seen state")
	await process_frame
	check(app.ui.refresh_count==0 and not app.save_error.is_empty(),"Care save errors remain available without rebuilding the screen")
	app.store.succeed=true
	check(app.care(0,"pet",false).progress_changed and app.store.calls==2,"A retry saves care progress once")
	check(not app.care(0,"brush",false).progress_changed and app.store.calls==2,"Continuous care does not save during cooldown")
	app.model.state.cats[0].bond=100; app.model.state.time=30.0
	check(not app.care(0,"pet",false).progress_changed and app.store.calls==2,"Care at maximum friendship never writes a save")
	await process_frame
	check(app.ui.refresh_count==0 and app.save_error.is_empty(),"Successful care retry clears its error without rebuilding")
	app.queue_free(); await process_frame
	var audio=Audio.new()
	root.add_child(audio)
	audio.configure({"music":false,"sound":true},0,true,false)
	audio.start_care_purr()
	check(audio.care_purr_active and audio.purr_player.playing,"Affectionate contact starts purring")
	check(audio.purr_player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and Audio.EFFECTS.purr.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Care loops a private stream without changing one-shot purrs")
	var stream=audio.purr_player.stream
	var count: int=audio.recent_events.size()
	for index in range(20): audio.start_care_purr()
	check(audio.purr_player.stream==stream and audio.recent_events.size()==count,"Repeated contact updates keep a single uninterrupted purr")
	audio.stop_care_purr()
	check(not audio.care_purr_active and audio.purr_player.playing,"Ending contact begins a fade")
	await create_timer(0.12).timeout
	audio.start_care_purr()
	check(audio.care_purr_active and audio.recent_events.size()==count,"Renewed contact cancels the fade without restarting audio")
	audio.stop_care_purr()
	await create_timer(0.45).timeout
	check(not audio.purr_player.playing,"Purring stops after its short fade")
	audio.start_care_purr()
	audio.configure({"music":false,"sound":false},0,true,false)
	check(not audio.purr_player.playing and not audio.care_purr_active,"Muting immediately stops care audio")
	audio.start_care_purr()
	check(not audio.purr_player.playing,"Contact cannot start purring while muted")
	audio.configure({"music":false,"sound":true},0,true,false)
	audio.start_care_purr()
	audio.configure({"music":false,"sound":true},0,false,false)
	check(not audio.purr_player.playing and not audio.care_purr_active,"Backgrounding clears continuous contact audio")
	audio.configure({"music":false,"sound":true},0,true,false)
	audio.play_effect("purr")
	check(audio.purr_player.playing and audio.purr_player.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Legacy one-shot purr still plays without looping")
	audio.start_care_purr(); audio.shutdown()
	check(not audio.purr_player.playing and not audio.care_purr_active,"Shutdown stops the loop")
	audio.queue_free(); await process_frame
	# AudioServer releases stopped playback resources on its next mix callback.
	await create_timer(0.15).timeout
	print("CREATIVE CARE STATE: %d failures" % failures)
	quit(1 if failures else 0)
