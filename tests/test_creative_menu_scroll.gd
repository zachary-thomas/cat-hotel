extends SceneTree
## Exercise GUI dispatch, including swipes that begin on interactive children.
var failures := 0
var ui: Control

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(5): await process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed=pressed
	root.push_input(event,true)

func motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point; event.global_position=point; event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)

func swipe(target: Control, horizontal: bool, label: String) -> void:
	var scroll: Node=target.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	check(scroll!=null,label+" has a scrolling ancestor")
	if scroll==null: return
	scroll.ensure_control_visible(target)
	await settle()
	var visible: Rect2=target.get_global_rect().intersection(scroll.get_global_rect())
	var start: Vector2=visible.get_center()
	var pressed := [0]
	if target is BaseButton: target.pressed.connect(func(): pressed[0]+=1)
	var before: int=scroll.scroll_horizontal if horizontal else scroll.scroll_vertical
	motion(start,Vector2.ZERO,false)
	mouse_button(start,true)
	for step in range(1,7):
		var delta:=Vector2(-10,0) if horizontal else Vector2(0,-10)
		motion(start+delta*step,delta,true)
		await process_frame
	var after: int=scroll.scroll_horizontal if horizontal else scroll.scroll_vertical
	mouse_button(start+(Vector2(-60,0) if horizontal else Vector2(0,-60)),false)
	print("%s: scroll %d -> %d; activations %d" % [label,before,after,pressed[0]])
	check(after>before+20,label+" scrolls when the swipe begins on content")
	check(pressed[0]==0,label+" does not activate a control during a swipe")
	await settle()

func first_card() -> Control:
	for button in ui.find_children("*","Button",true,false):
		if button.clip_contents: return button
	return null

func tap(target: Control, label: String) -> void:
	var point: Vector2=target.get_global_rect().get_center()
	var pressed := [0]
	target.pressed.connect(func(): pressed[0]+=1)
	motion(point,Vector2.ZERO,false)
	mouse_button(point,true)
	motion(point+Vector2(2,1),Vector2(2,1),true)
	mouse_button(point+Vector2(2,1),false)
	check(pressed[0]==1,label+" activates once with slight finger movement")
	await settle()

func run() -> void:
	# ScrollContainer uses mouse events emitted from touch on Android. Enabling
	# touchscreen emulation exercises that same native drag path on desktop.
	Input.emulate_touch_from_mouse=true
	check(DisplayServer.is_touchscreen_available(),"Touchscreen emulation is available")
	root.size=Vector2i(360,640); root.content_scale_size=root.size
	var helpers=load("res://tests/test_creative_ui.gd")
	var app=helpers.TestApp.new()
	app.model=load("res://scripts/creative/creative_model.gd").new()
	app.model.new_game(1000)
	app.model.state.settings.ui_text_scale=1.5
	for cat in app.model.state.cats: cat.known=true
	app.world=helpers.TestWorld.new()
	root.add_child(app); app.add_child(app.world)
	ui=load("res://scripts/creative/creative_ui.gd").new()
	ui.app=app; app.add_child(ui)
	await settle()
	ui.open_tab("Build"); await settle()
	await swipe(first_card(),false,"Build item card")
	ui.cancel_preview(false); ui.open_tab("Build"); await settle()
	var rail: HBoxContainer=ui._category_scroll.find_children("*","HBoxContainer",true,false)[0]
	await swipe(rail.get_child(1),true,"Build category rail")
	ui.open_tab("Settings"); await settle()
	await swipe(ui.find_children("*","CheckButton",true,false)[0],false,"Settings switch")
	ui.open_tab("Cats"); await settle()
	await swipe(first_card(),false,"Cat card")
	ui.open_tab("Map"); await settle()
	var panels=ui.find_children("*","PanelContainer",true,false)
	for panel in panels:
		if panel.get_parent() is VBoxContainer and panel.get_parent().get_parent() is ScrollContainer:
			await swipe(panel,false,"Map card")
			break
	ui.open_tab("Life"); await settle()
	for panel in ui.find_children("*","PanelContainer",true,false):
		if panel.get_parent() is VBoxContainer and panel.get_parent().get_parent() is ScrollContainer:
			await swipe(panel,false,"Life card")
			break
	ui.open_tab("Build"); await settle()
	await tap(first_card(),"Build item")
	check(not ui.preview_action.is_empty(),"Tapping an item opens its placement preview")
	ui.open_tab("Settings"); await settle()
	var music: CheckButton=ui.find_children("*","CheckButton",true,false)[1]
	var music_scroll: ScrollContainer=music.get_parent().get_parent()
	music_scroll.ensure_control_visible(music); await settle()
	var before_music: bool=app.model.state.settings.music
	await tap(music,"Settings switch")
	check(app.model.state.settings.music!=before_music,"Tapping a switch still updates its setting")
	# Desktop wheel scrolling must continue to work over cards too.
	ui.open_tab("Cats"); ui.selected_cat=-1; ui.refresh(); await settle()
	var card: Control=first_card()
	var wheel:=InputEventMouseButton.new()
	wheel.position=card.get_global_rect().get_center()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true
	root.push_input(wheel,true); await settle()
	var cats_scroll: ScrollContainer=card.get_parent().get_parent().get_parent()
	check(cats_scroll.scroll_vertical>0,"Mouse wheel scrolls over cat cards")
	check(not ui._pointer_down and ui._touches.is_empty(),"Menu gestures do not start a world gesture")
	app.free()
	Input.emulate_touch_from_mouse=false
	print("CREATIVE MENU SCROLL: %d failures" % failures)
	quit(1 if failures else 0)
