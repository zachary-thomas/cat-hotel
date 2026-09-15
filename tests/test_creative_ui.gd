extends SceneTree
var failures: int = 0

class TestWorld extends Node:
	var last_preview: Dictionary = {}
	var rect: Rect2
	var origin: Vector2=Vector2(-20,-20)
	func set_world_rect(value: Rect2) -> void: rect = value
	func set_preview(action: String, payload: Dictionary, valid: bool) -> void:
		last_preview = {"action":action,"payload":payload.duplicate(true),"valid":valid}
	func clear_preview() -> void: last_preview.clear()
	func world_point(screen: Vector2) -> Vector2: return screen / 25.0+origin
	func focus_hotel() -> void: pass
	func focus_lot() -> void: pass
	func focus_bounds(_rect: Rect2) -> void: pass
	func pan(_delta: Vector2) -> void: pass
	func zoom(_factor: float) -> void: pass
	func set_outside(_value: bool) -> void: pass

class TestApp extends Node:
	var model: RefCounted
	var world: Node
	var reject_save: bool = false
	var save_error: String=""
	var blocked_save: bool=false
	func perform(action: String, payload: Dictionary) -> Dictionary:
		if action=="undo": return model.undo(save)
		if action=="redo": return model.redo(save)
		return model.commit(action, payload, save)
	func save(_model = null) -> bool: return not reject_save
	func apply_settings() -> void: pass

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if "--capture-ui" in OS.get_cmdline_user_args():
		await capture_ui()
		quit(1 if failures else 0)
		return
	if not FileAccess.file_exists("res://scripts/creative/creative_ui.gd"):
		check(false, "Creative UI must support safe world input, editable previews and retry after save failure")
		quit(1)
		return
	var ui_script: Script = load("res://scripts/creative/creative_ui.gd")
	var model_script: Script = load("res://scripts/creative/creative_model.gd")
	var app := TestApp.new()
	app.model = model_script.new()
	app.model.new_game(1000)
	app.world = TestWorld.new()
	root.add_child(app)
	app.add_child(app.world)
	var ui: Control = ui_script.new()
	ui.app = app
	app.add_child(ui)
	await process_frame
	ui.size = Vector2(450, 900)
	ui.open_tab("Build")
	check(ui.build_mode, "Build dock opens construction mode")
	check(ui.world_rect.size.y >= 900 * 0.35, "Browsing leaves at least 35 percent of the phone for the world")
	check(not ui.world_input_allowed(Vector2(225, 850)), "Bottom catalogue cannot receive world gestures")
	ui.begin_preview("place_room", {"kind":"regular","x":30,"y":30,"w":4,"h":4,"rotation":0}, "Guest room")
	check(ui.world_rect.size.y >= 900 * 0.48, "Placement leaves about half of the phone for the world")
	ui.rotate_preview()
	check(ui.preview_payload.rotation == 1, "Rotate edits the pending room, before payment")
	ui.cancel_preview()
	check(ui.preview_action.is_empty() and app.world.last_preview.is_empty(), "Cancel removes placement ghost")
	ui.start_path("gravel")
	check(ui._apply_button.disabled,"An empty path stroke cannot create an empty edit")
	ui.add_path_segment(Vector2(0, 0), Vector2(5, 0))
	var cells: Array = ui.preview_payload.cells
	check(cells.size() == 12, "A six-cell stroke covers a continuous two-cell path")
	ui.add_path_segment(Vector2(5, 0), Vector2(0, 0))
	check(ui.preview_payload.cells.size() == 12, "Painting back over a preview does not duplicate its charge")
	check(not app.model.hotel().paths.has("5,1"), "A path stroke stays a preview before Apply")
	ui.start_path("erase")
	ui.add_path_segment(Vector2(0,0),Vector2(1,0))
	check(app.model.quote(ui.preview_action,ui.preview_payload).ok, "Erase path uses a valid erasing command")
	ui.cancel_preview()
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=ui.world_rect.get_center()
	ui._input(press)
	var release:=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; release.position=Vector2(225,899)
	ui._input(release)
	check(not ui._pointer_down, "Releasing a world drag over the catalogue always ends the gesture")
	ui.cancel_preview()
	var geometry: Script=load("res://scripts/creative/lot_geometry.gd")
	var first: Dictionary=app.model.hotel().objects[0]
	var object_screen: Vector2=(geometry.object_rect(first).get_center()-app.world.origin)*25.0
	press.position=object_screen; release.position=object_screen
	ui._input(press); ui._input(release)
	check(ui.selected_id==str(first.id) and ui.selected_type=="object","A pointer selects the real object's footprint")
	ui._edit_selection("move")
	var previous: Dictionary=app.model.serialize()
	press.position=Vector2(200,250); release.position=press.position
	ui._input(press); ui._input(release)
	check(ui.preview_action=="move_object" and app.model.serialize()==previous,"Moving with a pointer changes only the preview before Apply")
	var before_outside: Dictionary=ui.preview_payload.duplicate(true)
	press.position=Vector2(200,870); release.position=press.position
	ui._input(press); ui._input(release)
	check(ui.preview_payload==before_outside,"A menu-area tap cannot move the pending object")
	var rotate:=InputEventKey.new(); rotate.keycode=KEY_R; rotate.pressed=true
	ui._input(rotate)
	check(int(ui.preview_payload.rotation)==(int(before_outside.rotation)+1)%4,"R rotates the active pointer preview")
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	ui._input(escape)
	check(ui.preview_action.is_empty(),"Escape cancels the pointer preview")
	ui.begin_preview("place_object",{"item":"plant","x":0,"y":0,"rotation":0},"Leafy planter")
	var finger:=InputEventScreenTouch.new(); finger.index=0; finger.pressed=true; finger.position=Vector2(200,250)
	ui._input(finger)
	var position_before_pinch: Dictionary=ui.preview_payload.duplicate(true)
	var other_finger:=InputEventScreenTouch.new(); other_finger.index=1; other_finger.pressed=true; other_finger.position=Vector2(260,250)
	ui._input(other_finger)
	var pinch:=InputEventScreenDrag.new(); pinch.index=0; pinch.position=Vector2(180,250); pinch.relative=Vector2(-20,0)
	ui._input(pinch)
	check(ui.preview_payload==position_before_pinch,"Two-finger camera gestures preserve the pending object's location")
	finger.pressed=false; other_finger.pressed=false
	ui._input(finger); ui._input(other_finger)
	check(not ui._pointer_down and ui._touches.is_empty(),"Lifting both fingers completes the touch gesture")
	ui.cancel_preview()
	ui.start_path("earth")
	var path_before: Dictionary=app.model.serialize()
	press.position=Vector2(200,250); ui._input(press)
	var drag:=InputEventMouseMotion.new(); drag.position=Vector2(275,250); drag.relative=Vector2(75,0); ui._input(drag)
	release.position=drag.position; ui._input(release)
	check(ui.preview_payload.cells.size()>=8 and app.model.serialize()==path_before,"A pointer path stroke previews a continuous two-cell strip before payment")
	ui.cancel_preview()
	ui.selected_id=str(app.model.hotel().rooms[0].id); ui.selected_type="room"
	ui._edit_selection("resize")
	ui.resize_preview(-2,-3)
	check(ui._quote.get("displaced",[]).size()>0 and ui._quote_label.text.contains("Storage"),"Shrinking a room explains which pieces will move to Storage before payment")
	check(app.model.state.storage.is_empty(),"Resize warnings leave furniture in place until Apply")
	ui.cancel_preview()
	app.model.state.coins = 10000
	ui.begin_preview("buy_plot", {"id":"east"}, "East garden")
	app.reject_save = true
	ui.apply_preview()
	check(ui.preview_action == "buy_plot", "Failed save keeps the exact editable preview for retry")
	check(not app.model.hotel().plots.has("east"), "Failed UI action preserves plot ownership")
	app.reject_save = false
	ui.apply_preview()
	check(ui.preview_action.is_empty() and app.model.hotel().plots.has("east"), "Retry commits the original plot preview")
	ui._history("undo")
	check(not app.model.hotel().plots.has("east"),"Undo button reverses the completed land edit")
	ui._history("redo")
	check(app.model.hotel().plots.has("east"),"Redo button restores the completed land edit")
	app.save_error="Test write failure"
	ui.refresh()
	check(is_instance_valid(ui._save_banner_label) and is_instance_valid(ui._save_retry_button),"A persistent save error stays visible with a Retry action")
	app.blocked_save=true
	ui.refresh()
	check(ui._save_banner_label.text.contains("kept for recovery") and ui._save_retry_button==null,"A protected recovery save shows its status without an overwrite action")
	app.blocked_save=false; app.save_error=""
	ui.safe_area_override=Rect2(14,30,422,820)
	ui.refresh()
	check(ui.safe_rect==ui.safe_area_override and ui.world_rect.position.x==26,"Safe-area offsets are included in global world input coordinates")
	check(is_equal_approx(ui.world_rect.size.y,820*0.35),"Browse uses 35 percent of safe height")
	ui.begin_preview("place_object",{"item":"plant","x":0,"y":0,"rotation":0},"Leafy planter")
	check(is_equal_approx(ui.world_rect.size.y,820*0.5) and app.world.rect==ui.world_rect,"Placement uses half the safe height and gives the renderer the same global rectangle")
	check(not ui.world_input_allowed(Vector2(225,20)) and not ui.world_input_allowed(Vector2(225,880)),"Notch and home-bar regions never receive world input")
	ui.cancel_preview()
	ui.size = Vector2(1400, 900)
	ui.safe_area_override=Rect2(Vector2.ZERO,ui.size)
	ui.refresh()
	check(ui.world_rect.size.x >= 900 and ui.world_rect.size.y >= 600, "Desktop Build uses a side panel and retains a generous world")
	ui.open_tab("Hotel")
	check(not ui.build_mode and ui.preview_action.is_empty(), "Play clears construction controls")
	app.queue_free()
	await process_frame
	print("CREATIVE UI: %d failures" % failures)
	quit(1 if failures else 0)

func capture_ui() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/creative-preview/screenshots")
	DirAccess.make_dir_recursive_absolute("res://tmp/creative-ui-captures")
	var scene: PackedScene=load("res://scenes/creative_hotel.tscn")
	var app: Node=scene.instantiate()
	app.save_path="res://tmp/creative-ui-captures/preview-"+str(Time.get_ticks_usec())
	root.add_child(app)
	app._active=false
	app.model.advance(3)
	for dimensions: Vector2i in [Vector2i(360,640),Vector2i(360,800),Vector2i(390,844),Vector2i(430,932),Vector2i(1280,800)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		await process_frame
		for text_scale: float in [1.0,1.5]:
			app.model.state.settings.ui_text_scale=text_scale
			for mode: String in ["browse","place","selected","resize","expanded"]:
				app.ui.open_tab("Hotel")
				app.ui.open_tab("Build")
				app.ui.category="Shared spaces"
				if mode in ["place","expanded"]:
					app.ui.begin_preview("place_object",{"item":"perch","x":2,"y":2,"rotation":0},"Window perch")
					app.ui._browse_while_placing=mode=="expanded"
				elif mode=="resize": app.ui.begin_preview("place_room",{"kind":"regular","x":0,"y":0,"w":4,"h":3,"rotation":0},"Guest room")
				elif mode=="selected": app.ui.selected_id=str(app.model.hotel().objects[0].id); app.ui.selected_type="object"
				app.ui.refresh()
				await process_frame
				await RenderingServer.frame_post_draw
				var name: String="%s-%dx%d-text%d" % [mode,dimensions.x,dimensions.y,roundi(text_scale*100)]
				root.get_texture().get_image().save_png("res://docs/creative-preview/screenshots/"+name+".png")
				for control: Node in app.ui._surface.get_children():
					if control is PanelContainer or control is HBoxContainer:
						check(control.get_global_rect().end.x<=dimensions.x+2,"Panel stays on screen at "+name)
						check(control.get_global_rect().end.y<=dimensions.y+2,"Panel stays above screen bottom at "+name)
				if dimensions.x<700:
					check(app.ui.world_rect.size.y>=dimensions.y*(0.5 if mode in ["place","resize"] else 0.35)-1,"Visible world meets target at "+name)
				if dimensions==Vector2i(360,640) and mode in ["browse","expanded"]:
					var card: Button=null
					for node: Node in app.ui.find_children("*","Button",true,false):
						if node.tooltip_text.begins_with("Welcoming lobby ·"): card=node; break
					check(card!=null,"The visible catalogue contains its first complete arrangement")
					if card!=null:
						var clip: Node=card.get_parent()
						while clip!=null and not clip is ScrollContainer: clip=clip.get_parent()
						check(clip!=null and clip.get_global_rect().encloses(card.get_global_rect()),"A whole item card including price and function fits at "+name)
	root.size=Vector2i(430,932)
	root.content_scale_size=Vector2i(430,932)
	app.model.state.settings.ui_text_scale=1.0
	await process_frame
	for tab: String in ["Hotel","Cats","Life","Map","Settings"]:
		app.ui.open_tab(tab)
		if tab=="Cats": app.ui.selected_cat=0; app.ui.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/creative-preview/screenshots/"+tab.to_lower()+"-430x932.png")
	app.queue_free()
	await process_frame
	print("CREATIVE UI CAPTURES: %d failures" % failures)
