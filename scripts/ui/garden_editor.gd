extends Control
## A placement preview never changes saved land or amenities until Move is pressed.
const Garden = preload("res://scripts/core/garden_layout.gd")
const Grounds = preload("res://scripts/core/grounds_model.gd")
const Metrics = preload("res://scripts/ui/build_metrics.gd")
var app
var ui
var router = preload("res://scripts/ui/build_input.gd").new()
var selected_id := ""
var point := Vector2.ZERO
var turn := 0
var validity := {}
var metrics := {}
var preview: Node3D
var hidden_source: Node3D
var status: Label
var confirm_button: Button

func _ready() -> void:
	theme=ui.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	hide()
	get_viewport().size_changed.connect(_refresh)

func open(id: String = "") -> void:
	if not app.model.started: return
	if app.build_panel.visible: app.build_panel.close()
	ui.close_sheet(); ui.tab="GardenEdit"
	app.world.follow_cat=-1
	app.world.overview=false
	app.world.neighborhood.manager_control=false; ui.manager_mode=false
	show(); selected_id=""; router.reset(); _refresh()
	if id!="": select_amenity(id)
	else: app.world.reset_camera()

func close() -> void:
	_clear_preview(); router.reset(); hide(); selected_id=""
	ui.tab="Hotel"; app.world.set_ui_world_rect(ui.metrics.world_rect); app._update_ui()

func dismiss_for_menu() -> void:
	if not visible: return
	var destination: String=ui.tab
	close(); ui.tab=destination

func _process(_delta: float) -> void:
	if not visible: return
	ui.header.hide(); ui.footer.hide()
	if selected_id!="" and is_instance_valid(app.world.neighborhood.details):
		var current = app.world.neighborhood.details.get_node_or_null(selected_id.capitalize())
		if current != hidden_source: _update_preview()

func _button(text: String, callback: Callable, parent: Node, id: String, primary: bool = false) -> Button:
	var button: Button=ui.button(text,callback,primary)
	button.name=id; button.custom_minimum_size=Vector2(metrics.min_target,metrics.min_target)
	button.add_theme_font_size_override("font_size",ceili(16*metrics.unit*app.model.settings.ui_text_scale))
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _refresh() -> void:
	if not visible: return
	router.reset()
	metrics=Metrics.measure(get_viewport_rect().size,Metrics.safe_area(self),Metrics.phone_scale(self),app.model.settings.ui_text_scale)
	for child in get_children(): remove_child(child); child.queue_free()
	var header := HBoxContainer.new(); add_child(header)
	header.position=metrics.header_rect.position; header.size=metrics.header_rect.size
	_button("Garden",func(): cancel(),header,"GardenHome")
	_button("Fit hotel",func(): app.world.reset_camera(),header,"GardenFit")
	_button("Play",close,header,"GardenPlay",true)
	var surface := PanelContainer.new(); surface.name="GardenPanel"; add_child(surface)
	surface.position=metrics.panel_rect.position; surface.size=metrics.panel_rect.size
	surface.add_theme_stylebox_override("panel",preload("res://scripts/ui/playful_theme.gd").panel(Color("fff8e9"),metrics.unit,16))
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; surface.add_child(scroll)
	var col := VBoxContainer.new(); col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(col)
	var text_size := ceili(16*metrics.unit*app.model.settings.ui_text_scale)
	status=ui.canvas_paragraph("Tap an amenity to arrange your garden. Drag to pan; scroll or pinch to zoom.",text_size)
	status.name="GardenStatus"; col.add_child(status)
	if selected_id=="":
		for item in Grounds.AMENITIES:
			if app.model.grounds.hotels[app.model.current_hotel].amenities.has(item.id):
				_button("Move "+item.name,func(): select_amenity(item.id),col,"Arrange_"+item.id)
		_button("Open amenities & land",func(): close(); ui.open_route("Grounds","Life"),col,"GardenLand")
	else:
		var heading: Label=ui.canvas_paragraph(Grounds.amenity(selected_id).name+" · Tap a spot or drag its preview. Drag elsewhere to pan.",text_size)
		col.add_child(heading)
		_button("Rotate ↻",rotate,col,"RotateAmenity")
		var nudges := HBoxContainer.new(); col.add_child(nudges)
		for direction in [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]:
			_button(direction[0],func(): move_to(point+direction[1]*0.5),nudges,"GardenNudge"+direction[0])
	var actions := HBoxContainer.new(); add_child(actions)
	actions.position=metrics.actions_rect.position; actions.size=metrics.actions_rect.size
	_button("Cancel" if selected_id!="" else "Done",cancel if selected_id!="" else close,actions,"CancelGarden")
	confirm_button=null
	if selected_id!="": confirm_button=_button("Move · Free",confirm,actions,"MoveAmenity",true)
	app.world.set_ui_world_rect(metrics.world_rect)
	_update_preview()

func select_amenity(id: String) -> void:
	var data: Dictionary=app.model.grounds.hotels[app.model.current_hotel]
	if not data.amenities.has(id): return
	_clear_preview(); selected_id=id
	point=Garden.position(data,Grounds.amenity(id)); turn=Garden.rotation(data,id)
	_refresh()
	app.world.overview=false
	app.world.set_zoom(25)
	var p := Vector3(point.x,0,point.y)
	var projected := Vector2(p.dot(app.world.ISO_RIGHT),p.dot(app.world.ISO_UP))
	app.world._center_projected(Rect2(projected,Vector2.ZERO))

func cancel() -> void:
	_clear_preview(); selected_id=""; _refresh()

func rotate() -> void:
	if selected_id=="": return
	turn=(turn+1)%4; _update_preview()

func move_to(value: Vector2) -> void:
	if selected_id=="": return
	point=value.snapped(Vector2(0.5,0.5)); _update_preview()

func confirm() -> void:
	if selected_id=="" or not validity.get("ok",false): return
	if app.perform_grounds("move_amenity",{"id":selected_id,"x":point.x,"z":point.y,"rotation":turn}):
		_clear_preview(); selected_id=""; _refresh()
	else:
		status.text=app.save_error if app.save_error!="" else "Couldn't move this amenity. Try another spot."

func _clear_preview() -> void:
	if is_instance_valid(hidden_source): hidden_source.show()
	hidden_source=null
	if is_instance_valid(preview): preview.get_parent().remove_child(preview); preview.queue_free()
	preview=null

func _update_preview() -> void:
	_clear_preview()
	if selected_id=="": return
	var data: Dictionary=app.model.grounds.hotels[app.model.current_hotel]
	validity=Garden.validate(data,Grounds.AMENITIES,selected_id,point,turn,app.model.wing_count(app.model.current_hotel))
	status.text=validity.message; confirm_button.disabled=not validity.ok
	hidden_source=app.world.neighborhood.details.get_node_or_null(selected_id.capitalize())
	if not is_instance_valid(hidden_source): return
	preview=hidden_source.duplicate(0)
	preview.name="AmenityPreview"; preview.process_mode=Node.PROCESS_MODE_DISABLED
	app.world.add_child(preview)
	preview.position=Vector3(point.x,0.12,point.y); preview.rotation.y=turn*PI*0.5
	preview.show(); hidden_source.hide()
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("63be89") if validity.ok else Color("e26c70")
	for side in [-1,1]:
		for vertical in [false,true]:
			var edge := MeshInstance3D.new(); var mesh := BoxMesh.new()
			mesh.size=Vector3(0.10,0.06,3.75) if vertical else Vector3(4.65,0.06,0.10)
			edge.mesh=mesh; edge.material_override=material
			edge.position=Vector3(side*2.3,0.20,0) if vertical else Vector3(0,0.20,side*1.85)
			preview.add_child(edge)

func _world_point(screen: Vector2) -> Vector2:
	var camera: Camera3D=app.world.camera
	var start := camera.project_ray_origin(screen); var direction := camera.project_ray_normal(screen)
	var p := start+direction*((0.12-start.y)/direction.y)
	return Vector2(p.x,p.z)

func handle_input(event: InputEvent) -> void:
	var handle := Rect2()
	if selected_id!="":
		var bounds := Garden.footprint(point,turn)
		var first := true
		for p in [bounds.position,bounds.end,Vector2(bounds.end.x,bounds.position.y),Vector2(bounds.position.x,bounds.end.y)]:
			var screen: Vector2=app.world.camera.unproject_position(Vector3(p.x,0.3,p.y))
			handle=Rect2(screen,Vector2.ZERO) if first else handle.expand(screen); first=false
	for command in router.feed(event,{"world_rect":metrics.world_rect,"move_rect":handle,"ui_scale":Metrics.phone_scale(self),"mobile":OS.has_feature("mobile")}):
		match command.kind:
			"pan": app.world._pan(command.relative)
			"zoom": app.world.set_zoom(app.world.camera.size/command.factor)
			"move_ghost": move_to(_world_point(command.position))
			"tap_world":
				if selected_id!="": move_to(_world_point(command.position))
				else:
					var p := _world_point(command.position)
					var data: Dictionary=app.model.grounds.hotels[app.model.current_hotel]
					for item in Grounds.AMENITIES:
						if Garden.footprint(Garden.position(data,item),Garden.rotation(data,item.id)).has_point(p): select_amenity(item.id); break
