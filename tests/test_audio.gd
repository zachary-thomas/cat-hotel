extends SceneTree
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var audio = preload("res://scripts/audio/audio_director.gd").new()
	root.add_child(audio)
	audio.configure({"music":true,"sound":true}, 0, true, true)
	await process_frame
	check(audio.music_players[audio.current_player].playing, "Music begins on its own player")
	var track = audio.music_players[audio.current_player].stream
	check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.get_length() > 40, "Soundtrack has a full-length loop")
	audio.play_effect("spend")
	audio.play_effect("collect")
	check(audio.recent_events == ["spend","collect"], "Purchase and collection select different cues")
	audio.note_income(0.8)
	audio._process(6)
	check(not audio.recent_events.has("income"), "Ambient coin cue requires earned coins")
	audio.note_income(0.2)
	audio._process(0.01)
	check(audio.recent_events[-1] == "income", "Accrued currency produces a throttled coin cue")
	var events: int = audio.recent_events.size()
	audio.note_income(10)
	audio._process(0.01)
	check(audio.recent_events.size() == events, "High income cannot spam a coin cue each frame")
	audio.meow()
	check(audio.recent_events[-1] == "meow", "Cat interaction has a meow cue")
	events = audio.recent_events.size()
	audio.meow()
	check(audio.recent_events.size() == events, "Meow cooldown limits repeated taps")
	audio.configure({"music":true,"sound":false}, 0, true, true)
	audio.play_effect("collect")
	check(audio.recent_events.size() == events and audio.music_players[audio.current_player].playing, "Muting effects preserves music")
	audio.configure({"music":false,"sound":true}, 0, true, true)
	check(not audio.music_players[0].playing and not audio.music_players[1].playing, "Music can be muted independently")
	audio.play_effect("build")
	check(audio.recent_events[-1] == "build", "Effects remain audible while music is off")
	audio.configure({"music":true,"sound":true}, 1, true, true)
	check(audio.current_hotel == 1 and audio.music_players[audio.current_player].stream.get_length() < 45, "Visiting Seaside changes the music")
	audio.configure({"music":true,"sound":true}, 1, false, false)
	for player in audio.music_players:
		check(not player.playing or player.stream_paused, "Music pauses in the background")
	for player in audio.voices:
		check(not player.playing, "Effects stop in the background")
	audio.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("AUDIO TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
