extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not FileAccess.file_exists("res://scripts/creative/creative_speech_overlay.gd"):
		check(false,"Speech must remain readable and clear of controls at phone size"); quit(1); return
	root.size=Vector2i(360,640); root.content_scale_size=root.size
	var overlay=load("res://scripts/creative/creative_speech_overlay.gd").new()
	root.add_child(overlay); await process_frame
	var area:=Rect2(12,100,336,360)
	var line: Dictionary={"speaker":0,"text":"I saved you a sunbeam.","elapsed":1.0,"duration":3.1,"gesture":"talk"}
	overlay.present(line,"Miso",Vector2(25,200),area,[],1.5,false)
	await process_frame
	check(overlay.visible and overlay.bubble_rect.has_area(),"Full speech appears at large text size")
	check(area.encloses(overlay.bubble_rect),"Bubble stays inside the usable view near an edge")
	check(overlay.body_label.get_theme_font_size("font_size")>=25,"Camera-independent text respects 150 percent scaling")
	check(overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE and overlay.body_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Speech lets hotel gestures pass through")
	var previous: Rect2=overlay.bubble_rect
	overlay.present(line,"Miso",Vector2(25,200),area,[previous],1.5,true)
	check(not overlay.visible or not previous.grow(3).intersects(overlay.bubble_rect),"Room warnings get priority over dialogue")
	overlay.present(line,"Miso",Vector2(-100,200),area,[],1.0,true)
	check(not overlay.visible,"Offscreen speakers do not leave edge-clamped ghost bubbles")
	overlay.present(line,"Miso",Vector2(100,200),Rect2(),[],1.0,true)
	check(not overlay.visible,"A covered hotel view suppresses speech")
	overlay.present(line,"Clover",Vector2(276,375),Rect2(17,100,356,500),[Rect2(170,294,25,24),Rect2(276,380,20,18)],1.5,false)
	check(overlay.visible,"A crowded ordinary phone view still finds room for large dialogue above the speaker")
	overlay.queue_free(); await process_frame
	print("CREATIVE SPEECH: %d failures" % failures); quit(1 if failures else 0)
