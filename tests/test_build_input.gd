extends SceneTree
var failures: int = 0
var InputRouter
var Metrics
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func touch(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	return event
func drag(index: int, at: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	return event
func run() -> void:
	check(ResourceLoader.exists("res://scripts/ui/build_input.gd"),"Build gesture router is implemented")
	check(ResourceLoader.exists("res://scripts/ui/build_metrics.gd"),"Build safe-area metrics are implemented")
	if failures: quit(1); return
	InputRouter = load("res://scripts/ui/build_input.gd")
	Metrics = load("res://scripts/ui/build_metrics.gd")
	var context: Dictionary = {"world_rect":Rect2(0,80,360,420),"move_rect":Rect2(140,240,60,60),"ui_scale":1.0,"mobile":true}
	var router = InputRouter.new()
	router.feed(touch(0,Vector2(100,200),true),context)
	var result: Array = router.feed(touch(0,Vector2(100,200),false),context)
	check(result.size()==1 and result[0].kind=="tap_world","Tap releases select the world once")
	router.feed(touch(0,Vector2(100,200),true),context)
	router.feed(touch(1,Vector2(200,200),true),context)
	result = router.feed(drag(1,Vector2(230,200),Vector2(30,0)),context)
	check(result.any(func(c): return c.kind=="zoom"),"Pinch emits zoom")
	check(not result.any(func(c): return c.kind in ["move_ghost","tap_world"]),"Pinch never moves or taps an object")
	check(router.feed(touch(1,Vector2(230,200),false),context).is_empty(),"First pinch release is not a tap")
	check(router.feed(touch(0,Vector2(100,200),false),context).is_empty(),"Last pinch release is not a tap")
	router.feed(touch(0,Vector2(100,650),true),context)
	check(router.feed(drag(0,Vector2(100,300),Vector2(0,-350)),context).is_empty(),"Catalogue pointer cannot become world drag")
	check(router.feed(touch(0,Vector2(100,300),false),context).is_empty(),"Catalogue release cannot select furniture")
	router.feed(touch(0,Vector2(160,260),true),context)
	result = router.feed(drag(0,Vector2(170,290),Vector2(10,30)),context)
	check(result.any(func(c): return c.kind=="move_ghost"),"Selected object's move handle drags the ghost")
	check(router.feed(touch(0,Vector2(170,600),false),context).is_empty(),"Object release over actions cannot tap")
	router.feed(touch(0,Vector2(160,260),true),context)
	router.feed(drag(0,Vector2(160,600),Vector2(0,340)),context)
	check(router.feed(drag(0,Vector2(170,280),Vector2(10,-320)),context).is_empty(),"World gesture cannot resume after crossing UI")
	router.reset()
	router.feed(touch(0,Vector2(100,200),true),context)
	var resized: Dictionary = context.duplicate()
	resized.world_rect = Rect2(0,80,430,490)
	check(router.feed(drag(0,Vector2(200,300),Vector2(100,100)),resized).is_empty(),"Resizing cancels old-coordinate gestures")
	check(router.pointer_count()==0,"Resize releases captures")
	router.feed(touch(0,Vector2(100,200),true),context)
	check(router.feed(touch(0,Vector2(100,200),false,true),context).is_empty(),"Canceled touch never taps")
	check(router.pointer_count()==0,"Cancellation clears all captured pointers")
	router.feed(touch(0,Vector2(100,200),true),context)
	router.feed(touch(1,Vector2(200,200),true),context)
	router.feed(touch(2,Vector2(250,200),true),context)
	check(router.feed(drag(1,Vector2(230,200),Vector2(30,0)),context).is_empty(),"Third finger freezes gesture")
	router.reset()
	var mouse = InputEventMouseButton.new()
	mouse.position = Vector2(100,200)
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	check(router.feed(mouse,context).is_empty() and router.pointer_count()==0,"Mobile ignores emulated mouse")
	var desktop: Dictionary = context.duplicate()
	desktop.mobile = false
	router.feed(mouse,desktop)
	mouse.pressed = false
	check(router.feed(mouse,desktop).size()==1,"Desktop mouse tap has touch parity")
	for index in range(2):
		router.feed(touch(0,Vector2(100,200),true),context)
		check(router.feed(touch(0,Vector2(100,200),false),context).size()==1,"Rapid taps emit one selection each")
	router.feed(touch(0,Vector2(100,200),true),context)
	check(router.feed(touch(0,Vector2(-10,-10),false),context).is_empty() and router.pointer_count()==0,"Outside-window release cancels without trapping pointer")
	for viewport in [Vector2(360,640),Vector2(360,800),Vector2(390,844),Vector2(430,932),Vector2(768,1024),Vector2(1280,800)]:
		for text_scale in [1.0,1.5]:
			var safe = Rect2(10,24,viewport.x-20,viewport.y-44)
			var metrics = Metrics.measure(viewport,safe,1.0,text_scale)
			check(safe.encloses(metrics.actions_rect) and safe.encloses(metrics.panel_rect),"Build controls respect every safe edge")
			check(not metrics.actions_rect.intersects(metrics.world_rect),"Fixed actions never cover world input")
			check(metrics.min_target>=48,"Touch target floor survives layout measurement")
			if viewport.x<850:
				check(metrics.world_rect.size.y>=safe.size.y*0.5,"Portrait placement preserves half the safe height for room")
	var scaled = Metrics.measure(Vector2(450,1000),Rect2(0,0,450,1000),0.8,1.0)
	check(scaled.min_target>=60,"450-unit viewport needs 60 units for a 48-unit phone target at 0.8 scaling")
	print("BUILD INPUT TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(1 if failures else 0)
