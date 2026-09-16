extends Control
## Native, responsive construction UI. Every edit remains a model-quoted preview until Apply.
const Palette = preload("res://scripts/ui/playful_theme.gd")
const Icon = preload("res://scripts/ui/game_icon.gd")
const Portraits = preload("res://scripts/ui/guest_art.gd")
const MenuArt = preload("res://scripts/ui/menu_art.gd")
const Thumbnail = preload("res://scripts/creative/creative_thumbnail.gd")
const Geometry = preload("res://scripts/creative/lot_geometry.gd")
const Metrics = preload("res://scripts/ui/build_metrics.gd")
const Legacy = preload("res://scripts/core/game_content.gd")
const BODY = preload("res://assets/fonts/Nunito.ttf")
const DISPLAY = preload("res://assets/fonts/Fredoka.ttf")
static var _body_font: FontVariation
static var _display_font: FontVariation
const CATEGORIES: Array[String] = ["Rooms","Shared spaces","Furniture","Outdoors","Storage","Land"]
const TABS: Array[String] = ["Hotel","Cats","Build","Life","Map"]
var app
var world_rect: Rect2 = Rect2()
var safe_rect: Rect2 = Rect2()
var safe_area_override: Rect2 = Rect2()
var build_mode: bool = false
var preview_action: String = ""
var preview_payload: Dictionary = {}
var category: String = "Rooms"
var active_tab: String = "Hotel"
var selected_id: String = ""
var selected_type: String = ""
var selected_cat: int = -1
var care_screen
var _care_return: Dictionary = {}
var _cat_scroll: ScrollContainer
var path_width: int = 2
var _preview_name: String = ""
var _quote: Dictionary = {}
var _message: String = ""
var _desktop: bool = false
var _refreshing: bool = false
var _surface: Control
var _quote_label: Label
var _apply_button: Button
var _wallet_label: Label
var _save_banner_label: Label
var _save_retry_button: Button
var _category_scroll: ScrollContainer
var _category_active: Button
var _toast_label: Label
var _touches: Dictionary = {}
var _pointer_down: bool = false
var _pointer_origin: Vector2 = Vector2.ZERO
var _pointer_last: Vector2 = Vector2.ZERO
var _pointer_moved: bool = false
var _drag_selected: bool = false
var _path_cells: Dictionary = {}
var _path_last: Vector2 = Vector2.ZERO
var _pan_gesture: bool = false
var _tick: float = 0.0
var _text_scale: float = 1.0
var _browse_while_placing: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0 or app == null: return
	_tick = 0.0
	if is_instance_valid(_wallet_label): _wallet_label.text = _wallet_text()

func _catalog() -> Script:
	return load("res://scripts/creative/creative_content.gd")

func refresh() -> void:
	if _refreshing or not is_inside_tree() or app == null: return
	if is_instance_valid(care_screen):
		_layout_care()
		care_screen.update_progress()
		return
	_refreshing = true
	_text_scale = clampf(float(app.model.state.get("settings",{}).get("ui_text_scale",1.0)),1.0,1.5)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_quote_label = null
	_apply_button = null
	_save_banner_label=null
	_save_retry_button=null
	_category_scroll=null
	_category_active=null
	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	var viewport_size: Vector2=size if size.x>=1 and size.y>=1 else get_viewport_rect().size
	var requested_safe: Rect2=safe_area_override if safe_area_override.has_area() else Metrics.safe_area(self)
	safe_rect=requested_safe.intersection(Rect2(Vector2.ZERO,viewport_size))
	if not safe_rect.has_area(): safe_rect=Rect2(Vector2.ZERO,viewport_size)
	_surface.position=safe_rect.position
	_surface.size=safe_rect.size
	var canvas: Vector2=safe_rect.size
	_desktop = canvas.x >= 1000 or (canvas.x >= 740 and canvas.x > canvas.y * 1.25)
	var header_h: float = 70.0 if build_mode and canvas.y<800 else maxf(78,62*_text_scale)
	_header(Rect2(12,12,canvas.x-24,header_h))
	var save_error: String=str(app.get("save_error")) if app.get("save_error")!=null else ""
	var warning_offset: float=0.0
	if not save_error.is_empty():
		var warning_height: float=60*_text_scale
		_save_warning(Rect2(12,header_h+18,canvas.x-24,warning_height),save_error)
		warning_offset=warning_height+8
	var top: float = header_h+24.0+warning_offset
	var bottom: float = canvas.y-100.0
	if build_mode:
		_build_toolbar(Rect2(12,header_h+18+warning_offset,canvas.x-(404 if _desktop else 24),44))
		top = header_h+70+warning_offset
		var tray: Rect2
		if _desktop:
			var tray_width: float = clampf(canvas.x*0.29,344,410)
			tray = Rect2(canvas.x-tray_width-12,header_h+18+warning_offset,tray_width,canvas.y-header_h-32-warning_offset)
			world_rect = Rect2(12,top,canvas.x-tray_width-36,canvas.y-top-14)
		else:
			var target_height: float = canvas.y*(0.50 if not preview_action.is_empty() and not _browse_while_placing else 0.35)
			if warning_offset>0: target_height=minf(target_height,canvas.y-top-190)
			var tray_y: float = top+target_height+8
			world_rect = Rect2(12,top,canvas.x-24,target_height)
			tray = Rect2(8,tray_y,canvas.x-16,canvas.y-tray_y-8)
		_build_sheet(tray)
	elif active_tab in ["Cats","Life","Map","Settings"]:
		var sheet: Rect2
		if _desktop:
			sheet = Rect2(canvas.x-422,top,410,canvas.y-top-100)
			world_rect = Rect2(12,top,canvas.x-446,canvas.y-top-112)
		else:
			sheet = Rect2(8,top,canvas.x-16,canvas.y-top-100)
			world_rect = Rect2()
		_detail_sheet(sheet)
	else:
		var card_h: float = 103.0*_text_scale
		world_rect = Rect2(12,top,canvas.x-24,maxf(80,bottom-top-card_h-14))
		_hotel_card(Rect2(12,bottom-card_h,canvas.x-24,card_h))
	if not build_mode: _dock(Rect2(8,canvas.y-90,canvas.x-16,82))
	world_rect.position+=safe_rect.position
	if is_instance_valid(app.world):
		app.world.set_world_rect(world_rect)
		if app.world.has_method("set_life_context"):
			app.world.set_life_context(app.get("_active")!=false and not bool(app.blocked_save),active_tab=="Hotel" and not build_mode)
	_toast_label = _label(_message,14,Palette.ERROR_INK)
	_toast_label.position = world_rect.position-safe_rect.position+Vector2(8,8)
	_toast_label.size = Vector2(maxf(40,world_rect.size.x-16),54)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_surface.add_child(_toast_label)
	_toast_label.visible = not _message.is_empty() and not world_rect.size.is_zero_approx()
	_refreshing = false
	_update_quote()

func _header(rect: Rect2) -> void:
	var row: HBoxContainer = _row_in_panel(rect,Palette.CREAM,12)
	if build_mode:
		if _text_scale<1.4:
			var emblem: Control = Icon.new()
			emblem.kind = "Build"
			emblem.custom_minimum_size = Vector2(34,40)
			row.add_child(emblem)
		var title: Label = _label("BUILD",24)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
	else:
		var titlebox := VBoxContainer.new()
		titlebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(titlebox)
		var definition: Dictionary = app.model.map_definition()
		var hotel_title: Label=_label(str(definition.get("name","Purrington Hotel")),20)
		hotel_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		titlebox.add_child(hotel_title)
		var subtitle: Label=_label("Level %d  ·  %d rooms" % [int(app.model.hotel().get("level",1)),_guest_count()],13,Palette.SECONDARY_INK)
		subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		titlebox.add_child(subtitle)
	var currency := HBoxContainer.new()
	currency.add_theme_constant_override("separation",5)
	row.add_child(currency)
	var coin: Control = Icon.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(27,36)
	currency.add_child(coin)
	_wallet_label = _label(_wallet_text(),17)
	currency.add_child(_wallet_label)
	if build_mode:
		row.add_child(_button("Play",func(): open_tab("Hotel"),Palette.MINT,74))
	else:
		var gear: Button = _button("",func(): open_tab("Settings"),Color("f1e8d7"),44)
		gear.tooltip_text = "Settings"
		row.add_child(gear)
		var settings_icon: Control = Icon.new()
		settings_icon.kind = "settings"
		gear.add_child(settings_icon)
		settings_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		settings_icon.offset_left=10; settings_icon.offset_right=-10

func _wallet_text() -> String:
	if app.model.is_god_mode(): return "FREE"
	if safe_rect.size.x<420 and _text_scale>1.3: return _coins(float(app.model.state.get("coins",0)))
	if build_mode and (safe_rect.size.y<800 or (safe_rect.size.x<390 and _text_scale>1.3)): return _coins(float(app.model.state.get("coins",0)))
	return "%s\n+%d / min" % [_coins(float(app.model.state.get("coins",0))),roundi(float(app.model.rate()))]

func _save_warning(rect: Rect2,detail: String) -> void:
	var row: HBoxContainer=_row_in_panel(rect,Palette.ERROR_FILL,8)
	var protected_save: bool=bool(app.get("blocked_save")) if app.get("blocked_save")!=null else false
	_save_banner_label=_label("Save kept for recovery. Progress is paused." if protected_save else "Couldn't save your progress. Please retry.",14,Palette.ERROR_INK)
	_save_banner_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_save_banner_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_save_banner_label.tooltip_text=detail
	row.add_child(_save_banner_label)
	if not protected_save:
		_save_retry_button=_button("Retry",func(): app.save(); refresh(),Palette.CREAM,64)
		_save_retry_button.tooltip_text="Retry save"
		row.add_child(_save_retry_button)

func _guest_count() -> int:
	var count: int = 0
	for room: Dictionary in app.model.hotel().get("rooms",[]):
		if str(room.get("kind","regular")) in ["regular","suite"]: count += 1
	return count

func _build_toolbar(rect: Rect2) -> void:
	var row := HBoxContainer.new()
	row.position=rect.position; row.size=rect.size
	row.add_theme_constant_override("separation",7)
	_surface.add_child(row)
	row.add_child(_button("Undo",func(): _history("undo"),Palette.CREAM,62))
	row.add_child(_button("Redo",func(): _history("redo"),Palette.CREAM,62))
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_button("Focus",_focus_selection,Palette.CREAM,64))
	row.add_child(_button("Fit lot",func(): app.world.focus_lot(),Palette.CREAM,64))
	for child: Node in row.get_children():
		if child is Button:
			for state: String in ["normal","hover","pressed","disabled"]:
				var style: StyleBoxFlat=child.get_theme_stylebox(state).duplicate()
				style.content_margin_left=6; style.content_margin_right=6
				child.add_theme_stylebox_override(state,style)

func _dock(rect: Rect2) -> void:
	var row: HBoxContainer = _row_in_panel(rect,Palette.CREAM,6)
	for tab: String in TABS:
		var button: Button = _button("",func(): open_tab(tab),Palette.MINT if active_tab==tab else Color.TRANSPARENT,0)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.tooltip_text=tab
		row.add_child(button)
		var column := VBoxContainer.new()
		column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_top=4; column.offset_bottom=-3
		column.add_theme_constant_override("separation",0)
		var art: Control = Icon.new()
		art.kind=tab; art.active=active_tab==tab
		art.custom_minimum_size=Vector2(35,35)
		column.add_child(art)
		var label: Label = _label(tab,13)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)

func _hotel_card(rect: Rect2) -> void:
	var row: HBoxContainer = _row_in_panel(rect,Palette.CREAM,10)
	var art: Control = Thumbnail.new()
	art.item=_catalog().item("fountain")
	art.custom_minimum_size=Vector2(83,70)
	row.add_child(art)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var unfinished: int = 0
	for room: Dictionary in app.model.hotel().get("rooms",[]):
		if not bool(app.model.room_status(str(room.id)).get("ready",false)): unfinished+=1
	var title: Label=_label("Welcome home" if unfinished==0 else "Room to finish",20)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var description: String="Cozy rooms. Happy cats." if unfinished==0 else ("1 unfinished room" if unfinished==1 else "%d unfinished rooms" % unfinished)
	var readiness: Label=_label(description,15,Palette.SECONDARY_INK)
	readiness.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(readiness)
	var pending: int = int(app.model.state.get("pending_coins",0))
	if pending > 0: row.add_child(_button("Collect\n%s" % _coins(pending),func(): _perform("collect",{}),Palette.GOLD,77))
	else: row.add_child(_button("Build",func(): open_tab("Build"),Palette.MINT,64))

func _build_sheet(rect: Rect2) -> void:
	var body: VBoxContainer = _column_in_panel(rect,Palette.CREAM,12)
	body.add_theme_constant_override("separation",8)
	if not preview_action.is_empty() and not _desktop and not _browse_while_placing:
		var details: VBoxContainer=_scroll_column(body)
		_preview_controls(details)
		if rect.size.y>270:
			var art: Control
			if preview_action=="place_object": art=Thumbnail.new(); art.item=_catalog().item(str(preview_payload.item))
			elif preview_action=="place_template": art=Thumbnail.new(); art.arrangement=_catalog().template(str(preview_payload.template))
			if art!=null: art.custom_minimum_size.y=100; details.add_child(art)
		var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",7); body.add_child(actions)
		actions.add_child(_button("Browse",func(): _browse_while_placing=true; refresh(),Color("efe8d8"),76))
		_apply_button=_button("Place",apply_preview,Palette.MINT,0)
		_apply_button.custom_minimum_size.y=49
		_apply_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(_apply_button)
		return
	if not selected_id.is_empty() and preview_action.is_empty() and not _desktop:
		_selection_controls(_scroll_column(body))
		return
	if not preview_action.is_empty():
		if _desktop or not _browse_while_placing: _preview_controls(body)
	elif not selected_id.is_empty(): _selection_controls(body)
	elif _desktop:
		var heading: Label=_label("Make room for happy cats",22)
		heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(heading)
		var hint: Label=_label("Choose a piece, then tap its place in the hotel.",13,Palette.SECONDARY_INK)
		hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		body.add_child(hint)
	var tabs: Container
	if _desktop:
		var grid:=GridContainer.new()
		grid.columns=3
		grid.add_theme_constant_override("h_separation",5)
		grid.add_theme_constant_override("v_separation",4)
		tabs=grid
		body.add_child(tabs)
	else:
		_category_scroll=ScrollContainer.new()
		_category_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		_category_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
		_category_scroll.custom_minimum_size.y=54
		body.add_child(_category_scroll)
		var rail:=HBoxContainer.new()
		rail.add_theme_constant_override("separation",6)
		_category_scroll.add_child(rail)
		tabs=rail
	for title: String in CATEGORIES:
		var tab_button: Button = _button(title,func(): _change_category(title),Palette.MINT if category==title else Color("f4ecde"),0)
		if _desktop and _text_scale>1.3 and title=="Shared spaces": tab_button.text="Shared\nspaces"
		tab_button.add_theme_font_size_override("font_size",roundi(13*_text_scale))
		for state: String in ["normal","hover","pressed","disabled"]:
			var style: StyleBoxFlat=tab_button.get_theme_stylebox(state).duplicate()
			style.content_margin_left=3 if _desktop else 10; style.content_margin_right=3 if _desktop else 10
			tab_button.add_theme_stylebox_override(state,style)
		if _desktop: tab_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		tab_button.tooltip_text=title
		tab_button.custom_minimum_size.y=35 if _desktop else 42
		if _desktop: tab_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs.add_child(tab_button)
		if category==title: _category_active=tab_button
	if not _desktop: _reveal_category.call_deferred()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	match category:
		"Rooms": _room_catalog(content)
		"Shared spaces": _template_catalog(content)
		"Furniture","Outdoors": _object_catalog(content)
		"Storage": _storage_catalog(content)
		"Land": _land_catalog(content)
	if not preview_action.is_empty():
		var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",7); body.add_child(actions)
		if not _desktop: actions.add_child(_button("Less",func(): _browse_while_placing=false; refresh(),Color("efe8d8"),58))
		_apply_button = _button("Place",apply_preview,Palette.MINT,0)
		_apply_button.custom_minimum_size.y=49
		_apply_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(_apply_button)

func _preview_controls(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	body.add_child(row)
	var title: Label = _label(_preview_name,20)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var icon_controls: bool=_text_scale>1.3 and not _desktop
	if preview_action not in ["buy_plot","paint_path","erase_path","remove_room","store_object","resize_room"]:
		var rotate: Button=_button("↻" if icon_controls else "Rotate",rotate_preview,Color("f1e8d7"),44 if icon_controls else 62)
		rotate.tooltip_text="Rotate"
		row.add_child(rotate)
	var cancel: Button=_button("×" if icon_controls else "Cancel",cancel_preview,Color("f1e8d7"),44 if icon_controls else 62)
	cancel.tooltip_text="Cancel"
	row.add_child(cancel)
	_quote_label=_label("",13,Palette.SECONDARY_INK)
	_quote_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_quote_label)
	if preview_action=="place_template":
		var description: Label=_label(str(_catalog().template(str(preview_payload.template)).get("description","")),13,Palette.SECONDARY_INK)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		body.add_child(description)
	if preview_action in ["place_room","resize_room"]:
		var sizes := VBoxContainer.new()
		body.add_child(sizes)
		sizes.add_child(_label("Width %d × depth %d" % [int(preview_payload.get("w",4)),int(preview_payload.get("h",4))],14))
		var dimensions:=HBoxContainer.new(); sizes.add_child(dimensions)
		for change: Array in [["W−",-1,0],["W+",1,0],["D−",0,-1],["D+",0,1]]:
			dimensions.add_child(_button(str(change[0]),func(): resize_preview(int(change[1]),int(change[2])),Color("efe8d8"),44))
	if preview_action in ["paint_path","erase_path"]:
		var row2 := VBoxContainer.new()
		body.add_child(row2)
		row2.add_child(_label("Drag to %s" % ("erase" if preview_action=="erase_path" else "paint"),14))
		var widths:=HBoxContainer.new(); row2.add_child(widths)
		for width: int in [1,2,3]: widths.add_child(_button("%d wide" % width,func(): path_width=width; refresh(),Palette.MINT if path_width==width else Color("efe8d8"),62))

func _selection_controls(body: VBoxContainer) -> void:
	var data: Dictionary = _selected_data()
	if data.is_empty(): selected_id=""; return
	var selected_title: Label=_label(str(data.get("name",_catalog().item(str(data.get("item",""))).get("name","Selected room"))),21)
	selected_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(selected_title)
	if selected_type=="room":
		var status: Dictionary=app.model.room_status(selected_id)
		var message: String=str(status.get("message",status.get("status","")))
		var detail: Label=_label(message,13,Palette.SECONDARY_INK if bool(status.get("ready",false)) else Palette.ERROR_INK)
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		body.add_child(detail)
	else:
		for venue: Dictionary in app.model.venues():
			if str(venue.id)==selected_id:
				var status: Label=_label(str(venue.get("status","")),14,Palette.SECONDARY_INK if bool(venue.get("open",false)) else Palette.ERROR_INK)
				status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				body.add_child(status)
				break
	var actions := GridContainer.new()
	actions.columns=3 if selected_type=="room" else 2
	body.add_child(actions)
	actions.add_child(_button("Move",func(): _edit_selection("move"),Palette.MINT,58))
	actions.add_child(_button("Rotate",func(): _edit_selection("rotate"),Color("efe8d8"),62))
	if selected_type=="room":
		actions.add_child(_button("Resize",func(): _edit_selection("resize"),Color("efe8d8"),60))
		actions.add_child(_button("Copy",func(): _edit_selection("copy"),Color("efe8d8"),52))
		body.add_child(_button("Remove room\nFurniture goes to Storage",func(): begin_preview("remove_room",{"id":selected_id},"Remove room"),Color("f6d9cd"),0))
	else:
		actions.add_child(_button("Store",func(): _perform("store_object",{"id":selected_id}); selected_id=""; refresh(),Color("efe8d8"),58))
	actions.add_child(_button("Done",func(): selected_id=""; refresh(),Color("efe8d8"),52))

func _room_catalog(body: VBoxContainer) -> void:
	var grid: GridContainer=_grid(body)
	for kind: String in ["regular","suite","cottage"]:
		var title: String={"regular":"Guest room","suite":"Grand suite","cottage":"Garden cottage"}[kind]
		var depth: int={"regular":3,"suite":5,"cottage":4}[kind]
		var payload: Dictionary={"kind":"regular" if kind=="cottage" else kind,"w":4,"h":depth,"rotation":0,"x":0,"y":0,"name":title}
		var price: float=app.model.catalog_price("place_room",payload)
		var art: Control=Thumbnail.new(); art.room_kind=kind
		_catalog_card(grid,title,"%s · 4 × %d" % [_coins(price),depth],art,func(): begin_preview("place_room",payload,title,true))
	var note: Label=_label("Start with a shell. Add a bed and connect the door to a path to welcome guests. Every room can be moved, rotated, resized or copied.",13,Palette.SECONDARY_INK)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	body.add_child(_label("Your rooms",18))
	for room: Dictionary in app.model.hotel().get("rooms",[]):
		var status: Dictionary=app.model.room_status(str(room.id))
		var title: String="%s  ·  %s" % [str(room.get("name","Room")),"Ready" if bool(status.get("ready",false)) else "Unfinished"]
		var room_button: Button=_button(title,func(): selected_id=str(room.id); selected_type="room"; app.world.focus_bounds(_room_rect(room)); refresh(),Color("f3ebdc"),0)
		room_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		room_button.tooltip_text=title
		body.add_child(room_button)

func _template_catalog(body: VBoxContainer) -> void:
	var grid: GridContainer=_grid(body)
	for entry: Dictionary in _catalog().templates():
		var price: int=roundi(app.model.catalog_price("place_template",{"template":entry.id}))
		var art: Control=Thumbnail.new(); art.arrangement=entry
		var surface: String="Outdoors" if str(entry.kind)=="terrace" else "Indoors"
		_catalog_card(grid,str(entry.name),"%s · %d pieces\n%s · Social space" % [_coins(price),entry.get("objects",[]).size(),surface],art,func(): begin_preview("place_template",{"template":entry.id,"x":0,"y":0,"rotation":0},str(entry.name),true))
	var note: Label=_label("Complete social spaces. Every counter, chair and plant stays individually editable after placement.",13,Palette.SECONDARY_INK)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

func _object_catalog(body: VBoxContainer) -> void:
	if category=="Outdoors":
		body.add_child(_label("Paths · drag to paint",18))
		var paths:=HBoxContainer.new(); body.add_child(paths)
		for style: String in ["earth","gravel","brick","erase"]:
			var action: Button=_button(style.capitalize(),func(): start_path(style),Color("efe8d8"),0)
			action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			paths.add_child(action)
	var grid: GridContainer=_grid(body)
	for entry: Dictionary in _catalog().items(category):
		var art: Control=Thumbnail.new(); art.item=entry
		var tags: Array=entry.get("tags",[])
		var tag: String=str(tags[0]).capitalize() if not tags.is_empty() else str(entry.get("role","decoration")).capitalize()
		var surfaces: Array=entry.get("surfaces",[])
		var surface: String="Any floor" if surfaces.size()>1 else ("Outdoors" if surfaces.has("outdoor") else "Indoors")
		var role: String={"bed":"Bed","seat":"Seating","reception":"Welcome","bar":"Treats","play":"Play","sun":"Sunny seat","warm":"Warm rest","decoration":"Decor","amenity":"Amenity","fence":"Boundary","gate":"Entrance"}.get(str(entry.get("role","decoration")),tag)
		var requirement: String=" · %d bond" % int(entry.bond) if entry.has("bond") and not app.model.is_god_mode() else ""
		var price: int=roundi(app.model.catalog_price("place_object",{"item":entry.id}))
		_catalog_card(grid,str(entry.name),"%s · %s\n%s%s" % [_coins(price),role,surface,requirement],art,func(): begin_preview("place_object",{"item":entry.id,"x":0,"y":0,"rotation":0},str(entry.name),true))

func _storage_catalog(body: VBoxContainer) -> void:
	var stored: Array=app.model.state.get("storage",[])
	if stored.is_empty():
		body.add_child(_label("Your storage is empty",20))
		var copy: Label=_label("Stored furniture and pieces displaced by a room resize appear here. Place them again without buying another copy.",14,Palette.SECONDARY_INK)
		copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(copy)
		return
	var grid: GridContainer=_grid(body)
	for object: Dictionary in stored:
		var entry: Dictionary=_catalog().item(str(object.item))
		var art: Control=Thumbnail.new(); art.item=entry
		_catalog_card(grid,str(entry.get("name","Furniture")),"Owned · place again",art,func(): begin_preview("retrieve_object",{"id":object.id,"x":0,"y":0,"rotation":int(object.get("rotation",0))},str(entry.get("name","Furniture")),true))

func _land_catalog(body: VBoxContainer) -> void:
	body.add_child(_label("A little more room to grow",19))
	var note: Label=_label("Tap a marked plot in the world, or choose one here. Purchased land can hold cottages, social spaces and gardens.",13,Palette.SECONDARY_INK)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(note)
	for plot: Dictionary in app.model.map_definition().get("plots",[]):
		var owned: bool=app.model.hotel().get("plots",[]).has(str(plot.id))
		var button: Button=_button("%s\n%s" % [str(plot.name),"Owned" if owned else _coins(int(plot.cost))],func(): _select_plot(plot),Palette.MINT if str(preview_payload.get("id",""))==str(plot.id) and preview_action=="buy_plot" else Color("efe8d8"),0)
		button.disabled=owned
		button.custom_minimum_size.y=66
		body.add_child(button)

func _select_plot(plot: Dictionary) -> void:
	category="Land"
	begin_preview("buy_plot",{"id":str(plot.id)},str(plot.name))
	var r: Array=plot.rect
	app.world.focus_bounds(Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])))

func _detail_sheet(rect: Rect2) -> void:
	var body: VBoxContainer=_column_in_panel(rect,Palette.CREAM,14)
	var header:=HBoxContainer.new(); body.add_child(header)
	var title: Label=_label(active_tab,26); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
	header.add_child(_button("Close",func(): open_tab("Hotel"),Color("efe8d8"),64))
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroll)
	if active_tab=="Cats": _cat_scroll=scroll
	var inner:=VBoxContainer.new(); inner.size_flags_horizontal=Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation",12); scroll.add_child(inner)
	match active_tab:
		"Cats": _cats_sheet(inner)
		"Life": _life_sheet(inner)
		"Map": _map_sheet(inner)
		"Settings": _settings_sheet(inner)
	if not _message.is_empty():
		var notice: Label=_label(_message,14,Palette.ERROR_INK); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(notice)

func _cats_sheet(body: VBoxContainer) -> void:
	var cats: Array=app.model.state.get("cats",[])
	var grid: GridContainer=_grid(body,2)
	for i in range(cats.size()):
		var cat: Dictionary=cats[i]
		if not bool(cat.get("known",false)): continue
		var art:=TextureRect.new(); art.texture=Portraits.portrait(i); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_catalog_card(grid,str(cat.get("name",Legacy.CAT_NAMES[i])),"%d / 100 bond" % int(cat.get("bond",0)),art,func(): open_cat_care(i),122)
	var hint: Label=_label("Cats discover your hotel through comfortable rooms and welcoming social spaces.",14,Palette.SECONDARY_INK); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(hint)

func _life_sheet(body: VBoxContainer) -> void:
	var hotel: Dictionary=app.model.hotel()
	body.add_child(_label("A hotel full of little stories",21))
	body.add_child(_label("%d visits · %d happy guests" % [int(hotel.get("visits",0)),int(hotel.get("happy",0))],14,Palette.SECONDARY_INK))
	var housekeeper: VBoxContainer=_inline_panel(body)
	housekeeper.add_child(_label("Housekeeping",19))
	var hired: bool=bool(hotel.get("maid",false))
	housekeeper.add_child(_label("Attendant hired · %d rooms cleaned" % int(hotel.get("cleaned",0)) if hired else ("Available now · free in God mode" if app.model.is_god_mode() else "Hire help at hotel level 3"),14,Palette.SECONDARY_INK))
	if not hired:
		var hire: Dictionary=app.model.quote("hire_housekeeper",{})
		var hire_button: Button=_button("Hire attendant · %s" % _coins(0 if app.model.is_god_mode() else maxi(600,int(hire.get("cost",600)))),func(): _perform("hire_housekeeper",{}),Palette.MINT,0)
		hire_button.disabled=not bool(hire.get("ok",false))
		housekeeper.add_child(hire_button)
	body.add_child(_label("Services",21))
	for i in range(4):
		var service_name: String=["Rooms & housekeeping","Kitchen & milkshakes","Lounge & play","Reception & arrivals"][i]
		var quote: Dictionary=app.model.quote("upgrade",{"service":i})
		var level: int=int(hotel.get("upgrades",[0,0,0,0])[i])
		var panel: VBoxContainer=_inline_panel(body)
		panel.add_child(_label(service_name,18))
		panel.add_child(_label("Level %d" % level,13,Palette.SECONDARY_INK))
		var upgrade: Button=_button("Fully upgraded" if level>=10 else "Upgrade · %s" % _coins(int(quote.get("cost",0))),func(): _perform("upgrade",{"service":i}),Palette.MINT,0)
		upgrade.disabled=level>=10
		panel.add_child(upgrade)
	body.add_child(_label("Your team",21))
	for i in range(3):
		var staff: Dictionary=Legacy.STAFF[i]
		var quote: Dictionary=app.model.quote("train",{"staff":i})
		var row:=HBoxContainer.new(); body.add_child(row)
		var portrait:=TextureRect.new(); portrait.texture=MenuArt.staff_portrait(i); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.custom_minimum_size=Vector2(70,88); row.add_child(portrait)
		var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(box)
		box.add_child(_label(str(staff.name)+" · "+str(staff.job),17))
		box.add_child(_label("Training level %d" % int(hotel.get("staff",[0,0,0])[i]),13,Palette.SECONDARY_INK))
		var train: Button=_button("Fully trained" if int(hotel.staff[i])>=3 else "Train · %s" % _coins(int(quote.get("cost",0))),func(): _perform("train",{"staff":i}),Color("efdfba"),0)
		train.disabled=int(hotel.staff[i])>=3
		box.add_child(train)
	body.add_child(_label("What's open",21))
	for venue: Dictionary in app.model.venues():
		var text: String="%s · %s" % [str(venue.get("name","Space")),str(venue.get("status","Closed"))]
		var label: Label=_label(text,14,Palette.SECONDARY_INK); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(label)

func _map_sheet(body: VBoxContainer) -> void:
	body.add_child(_label("Four places to feel at home",21))
	var maps: Script=load("res://scripts/creative/creative_maps.gd")
	for i in range(4):
		var definition: Dictionary=maps.definition(i)
		var panel: VBoxContainer=_inline_panel(body)
		var art: Control=MenuArt.new(); art.kind=["hotel_meadow","hotel_seaside","hotel_forest","hotel_snowcap"][i]; art.custom_minimum_size=Vector2(180,114); panel.add_child(art)
		panel.add_child(_label(str(definition.name),21))
		panel.add_child(_label(str(definition.get("theme","")),14,Palette.SECONDARY_INK))
		var gate: Dictionary=app.model.can_travel(i)
		var current: bool=int(app.model.state.get("current_hotel",0))==i
		var copy: Label=_label("You are here" if current else str(gate.get("message","Ready to visit")),13,Palette.SECONDARY_INK); copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; panel.add_child(copy)
		if not current:
			var button: Button=_button("Travel" if int(gate.get("cost",0))==0 else "Unlock · %s" % _coins(int(gate.cost)),func(): _travel(i),Palette.MINT,0)
			button.disabled=not bool(gate.get("ok",false)); panel.add_child(button)
			if i>=2 and not bool(gate.get("ok",false)) and app.has_method("test_purchase"):
				var product: String="purrington.forest_lodge" if i==2 else "purrington.snowcap_spa"
				panel.add_child(_button("Preview store · test unlock",func(): var result: Dictionary=app.test_purchase(product); _message=str(result.get("message","Preview expansion unlocked")); refresh(),Color("efe2c5"),0))

func _settings_sheet(body: VBoxContainer) -> void:
	var heading: Label=_label("Make yourself comfortable",21)
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(heading)
	var settings: Dictionary=app.model.state.get("settings",{})
	for entry: Array in [["god_mode","God mode",false],["music","Music",true],["sound","Sound effects",true],["motion","Animated motion",true],["exterior","Show exterior walls",false]]:
		var checkbox:=CheckButton.new(); checkbox.text=str(entry[1]); checkbox.button_pressed=bool(settings.get(str(entry[0]),bool(entry[2]))); checkbox.custom_minimum_size.y=52; checkbox.add_theme_font_override("font",_font()); checkbox.add_theme_font_size_override("font_size",roundi(18*_text_scale))
		checkbox.mouse_filter=Control.MOUSE_FILTER_PASS
		# Wait for release so the parent can cancel a toggle when a swipe starts.
		checkbox.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
		checkbox.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; checkbox.tooltip_text=str(entry[1])
		for state: String in ["font_color","font_pressed_color","font_hover_color","font_hover_pressed_color","font_focus_color"]: checkbox.add_theme_color_override(state,Palette.INK)
		checkbox.toggled.connect(func(value: bool): _setting(str(entry[0]),value))
		body.add_child(checkbox)
		if entry[0]=="god_mode":
			var help: Label=_label("Unlock all maps, land and cats. Build and upgrade for free. Turning it off restores prices; your creations and unlocks stay. Switching modes restarts Undo history.",13,Palette.SECONDARY_INK)
			help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(help)
	body.add_child(_label("Text size",20))
	var options:=HBoxContainer.new(); body.add_child(options)
	for scale_value: float in [1.0,1.25,1.5]:
		options.add_child(_button("%d%%" % roundi(scale_value*100),func(): _setting("ui_text_scale",scale_value),Palette.MINT if is_equal_approx(_text_scale,scale_value) else Color("efe8d8"),78))
	var helper: Label=_label("Build: drag to pan, scroll or pinch to zoom. Select a room or furniture to edit it. R rotates a preview; Escape cancels it.",15,Palette.SECONDARY_INK); helper.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(helper)
	if app.has_method("request_new_game"):
		body.add_child(_button("Start fresh",func(): app.request_new_game(),Color("efe8d8"),0))
		var reset_help: Label=_label("Begin again with the latest starter hotel and garden. You'll confirm before your progress is reset.",13,Palette.SECONDARY_INK)
		reset_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(reset_help)

func _setting(key: String, value: Variant) -> void:
	if key=="god_mode":
		var result: Dictionary=app.set_god_mode(bool(value))
		_message=str(result.message); refresh(); return
	var old: Variant=app.model.state.settings.get(key)
	app.model.state.settings[key]=value
	if not app.save(): app.model.state.settings[key]=old; _message="Couldn't save that setting. Please try again."
	else:
		if app.has_method("apply_settings"): app.apply_settings()
		if key=="exterior": app.world.set_outside(bool(value))
	refresh()

func open_tab(tab: String) -> void:
	if is_instance_valid(care_screen):
		care_screen.suspend()
		remove_child(care_screen); care_screen.queue_free(); care_screen=null
	selected_cat=-1
	if tab!=active_tab: cancel_preview(false)
	active_tab=tab
	build_mode=tab=="Build"
	selected_id=""
	_message=""
	refresh()

func open_cat_care(cat_id: int, return_context: Dictionary = {}) -> void:
	if cat_id<0 or cat_id>=app.model.state.cats.size() or not app.model.state.cats[cat_id].known: return
	if build_mode or is_instance_valid(care_screen): return
	_care_return={"tab":active_tab,"scroll":_cat_scroll.scroll_vertical if active_tab=="Cats" and is_instance_valid(_cat_scroll) else 0}
	_care_return.merge(return_context,true)
	_pointer_down=false; _pointer_moved=false; _pan_gesture=false; _touches.clear()
	selected_cat=cat_id; active_tab="Care"
	_surface.hide()
	care_screen=load("res://scripts/creative/creative_care_screen.gd").new()
	care_screen.ui=self; care_screen.cat_index=cat_id
	add_child(care_screen); _layout_care()
	app.apply_settings()

func _layout_care() -> void:
	var requested: Rect2=safe_area_override if safe_area_override.has_area() else Metrics.safe_area(self)
	var bounds: Rect2=requested.intersection(Rect2(Vector2.ZERO,size))
	if not bounds.has_area(): bounds=Rect2(Vector2.ZERO,size)
	care_screen.position=bounds.position; care_screen.size=bounds.size

func close_cat_care() -> void:
	if not is_instance_valid(care_screen): return
	care_screen.suspend(); remove_child(care_screen); care_screen.queue_free(); care_screen=null
	active_tab=str(_care_return.get("tab","Hotel")); selected_cat=-1
	refresh()
	if active_tab=="Cats" and is_instance_valid(_cat_scroll):
		_cat_scroll.set_deferred("scroll_vertical",int(_care_return.get("scroll",0)))
	app.apply_settings()

func _change_category(value: String) -> void:
	category=value
	selected_id=""
	refresh()

func _reveal_category() -> void:
	if is_instance_valid(_category_scroll) and is_instance_valid(_category_active):
		_category_scroll.ensure_control_visible(_category_active)

func begin_preview(action: String,payload: Dictionary,title: String,center: bool=false) -> void:
	preview_action=action
	preview_payload=payload.duplicate(true)
	_preview_name=title
	_browse_while_placing=false
	_quote={}
	_message=""
	selected_id=""
	_path_cells.clear()
	if center and app!=null: _position_preview(app.world.world_point(world_rect.get_center()))
	refresh()
	_update_quote()

func cancel_preview(rebuild: bool=true) -> void:
	preview_action=""
	preview_payload={}
	_quote={}
	_path_cells.clear()
	_pointer_down=false
	if app!=null and is_instance_valid(app.world): app.world.clear_preview()
	if rebuild: refresh()

func rotate_preview() -> void:
	if preview_action.is_empty() or not preview_payload.has("rotation"): return
	preview_payload.rotation=(int(preview_payload.rotation)+1)%4
	_update_quote()

func resize_preview(dx: int,dy: int) -> void:
	preview_payload.w=clampi(int(preview_payload.get("w",4))+dx,3,20)
	preview_payload.h=clampi(int(preview_payload.get("h",4))+dy,3,20)
	refresh()

func _update_quote() -> void:
	if preview_action.is_empty() or app==null: return
	_quote=app.model.quote(preview_action,preview_payload)
	var valid: bool=bool(_quote.get("ok",false))
	if preview_action in ["paint_path","erase_path"] and preview_payload.get("cells",[]).is_empty():
		valid=false
		_quote.message="Drag across the lot to preview a path"
	app.world.set_preview(preview_action,preview_payload,valid)
	var cost: int=int(_quote.get("cost",0))
	if is_instance_valid(_quote_label):
		var copy: String=str(_quote.get("message","Choose a position"))
		if valid:
			copy="Ready · tap the world to adjust"
			if preview_action in ["paint_path","erase_path"]: copy="%d cells · drag to extend the path" % preview_payload.get("cells",[]).size()
			elif preview_action=="buy_plot": copy="This land will become part of your hotel"
			elif preview_action=="resize_room": copy="Previewing the new room outline"
		if not _message.is_empty(): copy=_message+" · "+copy
		var displaced: Array=_quote.get("displaced",[])
		if not displaced.is_empty(): copy+=" · %d pieces will move to Storage" % displaced.size()
		if preview_action=="remove_room": copy+=" · Room furnishings move to Storage"
		_quote_label.text=copy
		_quote_label.add_theme_color_override("font_color",Palette.SECONDARY_INK if valid else Palette.ERROR_INK)
	if is_instance_valid(_apply_button):
		var verb: String="Apply" if preview_action in ["paint_path","erase_path","resize_room","move_room","move_object"] else "Place"
		if preview_action=="buy_plot": verb="Buy land"
		if preview_action=="remove_room": verb="Remove room"
		_apply_button.text="%s · %s" % [verb,("Refund "+_coins(-cost)) if cost<0 else _coins(cost)]
		_apply_button.disabled=not valid

func apply_preview() -> void:
	if preview_action.is_empty(): return
	var result: Dictionary=app.perform(preview_action,preview_payload.duplicate(true))
	_message=str(result.get("message",""))
	if bool(result.get("ok",false)): cancel_preview(false)
	refresh()

func _perform(action: String,payload: Dictionary) -> void:
	var result: Dictionary=app.perform(action,payload)
	_message=str(result.get("message",""))
	refresh()

func _history(action: String) -> void:
	if not preview_action.is_empty(): cancel_preview(false)
	selected_id=""
	_perform(action,{})

func _travel(index: int) -> void:
	var result: Dictionary=app.travel(index)
	_message=str(result.get("message",""))
	if bool(result.get("ok",false)): open_tab("Hotel")
	else: refresh()

func start_path(style: String) -> void:
	category="Outdoors"
	begin_preview("erase_path" if style=="erase" else "paint_path",{"cells":[],"style":"earth" if style=="erase" else style},"Erase path" if style=="erase" else style.capitalize()+" path")

func add_path_segment(from: Vector2,to: Vector2) -> void:
	var start:=Vector2i(floori(from.x),floori(from.y))
	var finish:=Vector2i(floori(to.x),floori(to.y))
	var steps: int=maxi(absi(finish.x-start.x),absi(finish.y-start.y))
	for step in range(steps+1):
		var t: float=float(step)/float(maxi(1,steps))
		var point:=Vector2i(roundi(lerpf(start.x,finish.x,t)),roundi(lerpf(start.y,finish.y,t)))
		var horizontal: bool=absi(finish.x-start.x)>=absi(finish.y-start.y)
		for offset in range(path_width):
			var cell: Vector2i=point+(Vector2i(0,offset) if horizontal else Vector2i(offset,0))
			_path_cells["%d,%d" % [cell.x,cell.y]]=[cell.x,cell.y]
	preview_payload.cells=_path_cells.values()
	_update_quote()

func world_input_allowed(point: Vector2) -> bool:
	return not is_instance_valid(care_screen) and world_rect.has_point(point) and world_rect.size.x>0 and world_rect.size.y>0

func _input(event: InputEvent) -> void:
	if app==null: return
	if is_instance_valid(care_screen):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			care_screen.back(); get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and (event.device==InputEvent.DEVICE_ID_EMULATION or OS.has_feature("mobile")): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if not preview_action.is_empty(): cancel_preview()
			elif not selected_id.is_empty(): selected_id=""; refresh()
			elif active_tab!="Hotel": open_tab("Hotel")
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_R and build_mode and not preview_action.is_empty():
			rotate_preview(); get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and world_input_allowed(event.position):
			app.world.zoom(0.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.12); get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
			if event.pressed and world_input_allowed(event.position):
				_pan_gesture=event.button_index!=MOUSE_BUTTON_LEFT
				_pointer_start(event.position); get_viewport().set_input_as_handled()
			elif not event.pressed and _pointer_down:
				_pointer_end(event.position); get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_down:
		_pointer_move(event.position); get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and world_input_allowed(event.position):
			_touches[event.index]=event.position
			if _touches.size()==1: _pan_gesture=false; _pointer_start(event.position)
			else: _pointer_moved=true; _pan_gesture=true
			get_viewport().set_input_as_handled()
		elif not event.pressed and _touches.has(event.index):
			_touches.erase(event.index)
			if _touches.is_empty(): _pointer_end(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		if _touches.size()>=2:
			var keys: Array=_touches.keys()
			var before: float=Vector2(_touches[keys[0]]).distance_to(Vector2(_touches[keys[1]]))
			_touches[event.index]=event.position
			var after: float=Vector2(_touches[keys[0]]).distance_to(Vector2(_touches[keys[1]]))
			if before>8 and after>8: app.world.zoom(before/after)
			if world_input_allowed(event.position): app.world.pan(event.relative*0.5)
		else:
			_touches[event.index]=event.position
			_pointer_move(event.position)
		get_viewport().set_input_as_handled()

func _pointer_start(point: Vector2) -> void:
	_pointer_down=true; _pointer_moved=false; _pointer_origin=point; _pointer_last=point; _drag_selected=false
	if _pan_gesture: return
	if preview_action in ["paint_path","erase_path"]:
		_path_last=app.world.world_point(point)
		add_path_segment(_path_last,_path_last)
	elif not preview_action.is_empty():
		if preview_action not in ["buy_plot","resize_room","remove_room"]: _position_preview(app.world.world_point(point)); _update_quote()
	elif build_mode:
		var hit: Dictionary=_hit_test(app.world.world_point(point))
		if str(hit.get("id",""))==selected_id and str(hit.get("type",""))==selected_type and not selected_id.is_empty(): _drag_selected=true

func _pointer_move(point: Vector2) -> void:
	if not world_input_allowed(point): _pointer_last=point; return
	var delta: Vector2=point-_pointer_last
	if point.distance_to(_pointer_origin)>8: _pointer_moved=true
	if _pan_gesture: app.world.pan(delta)
	elif preview_action in ["paint_path","erase_path"]:
		var lot_point: Vector2=app.world.world_point(point)
		add_path_segment(_path_last,lot_point); _path_last=lot_point
	elif not preview_action.is_empty():
		if preview_action not in ["buy_plot","resize_room","remove_room"]: _position_preview(app.world.world_point(point)); _update_quote()
	elif _drag_selected and _pointer_moved:
		_edit_selection("move")
		_position_preview(app.world.world_point(point)); _update_quote()
	elif _pointer_moved: app.world.pan(delta)
	_pointer_last=point

func _pointer_end(point: Vector2) -> void:
	# A release beyond the drag threshold is never a selection, even when the
	# platform coalesced its intermediate move events.
	if point.distance_to(_pointer_origin)>8: _pointer_moved=true
	if _pointer_down and not _pointer_moved and not build_mode and active_tab=="Hotel" and not _pan_gesture and world_input_allowed(point):
		var guest: int=app.world.pick_guest(point)
		if guest>=0: open_cat_care(guest)
	if _pointer_down and not _pointer_moved and preview_action.is_empty() and not _pan_gesture and world_input_allowed(point) and build_mode:
		var hit: Dictionary=_hit_test(app.world.world_point(point))
		if str(hit.get("type",""))=="plot": _select_plot(hit.data)
		else:
			selected_id=str(hit.get("id","")); selected_type=str(hit.get("type","")); refresh()
	_pointer_down=false; _pan_gesture=false

func _position_preview(point: Vector2) -> void:
	var step: float=0.5 if preview_action in ["place_object","move_object","retrieve_object"] else 1.0
	preview_payload.x=snappedf(point.x,step)
	preview_payload.y=snappedf(point.y,step)

func _hit_test(point: Vector2) -> Dictionary:
	var hotel: Dictionary=app.model.hotel()
	var objects: Array=hotel.get("objects",[])
	for i in range(objects.size()-1,-1,-1):
		var object: Dictionary=objects[i]
		if Geometry.object_rect(object).has_point(point): return {"type":"object","id":str(object.id)}
	for room: Dictionary in hotel.get("rooms",[]):
		if _room_rect(room).has_point(point): return {"type":"room","id":str(room.id)}
	for plot: Dictionary in app.model.map_definition().get("plots",[]):
		var r: Array=plot.rect
		if not hotel.get("plots",[]).has(str(plot.id)) and Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])).has_point(point): return {"type":"plot","id":str(plot.id),"data":plot}
	return {}

func _room_rect(room: Dictionary) -> Rect2:
	return Geometry.room_rect(room)

func _selected_data() -> Dictionary:
	for item: Dictionary in app.model.hotel().get("rooms" if selected_type=="room" else "objects",[]):
		if str(item.id)==selected_id: return item
	return {}

func _focus_selection() -> void:
	var selected: Dictionary=_selected_data()
	if selected.is_empty(): app.world.focus_hotel()
	elif selected_type=="room": app.world.focus_bounds(Geometry.room_rect(selected))
	else: app.world.focus_bounds(Geometry.object_rect(selected))

func _edit_selection(action: String) -> void:
	var item: Dictionary=_selected_data()
	if item.is_empty(): return
	var title: String=str(item.get("name",_catalog().item(str(item.get("item",""))).get("name","Room")))
	var command: String="move_room" if selected_type=="room" else "move_object"
	var payload: Dictionary={"id":selected_id,"x":item.x,"y":item.y,"rotation":int(item.get("rotation",0))}
	if action=="rotate": payload.rotation=(int(payload.rotation)+1)%4
	elif action=="resize": command="resize_room"; payload={"id":selected_id,"w":int(item.w),"h":int(item.h)}
	elif action=="copy": command="copy_room"; payload.x=float(item.x)+float(item.w)+1
	begin_preview(command,payload,title)

func _grid(parent: Control,columns: int=2) -> GridContainer:
	var grid:=GridContainer.new(); grid.columns=1 if columns==2 and not _desktop and (safe_rect.size.x<430 and _text_scale>1.3 or _browse_while_placing) else columns; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); parent.add_child(grid); return grid

func _catalog_card(parent: Control,title: String,subtitle: String,art: Control,action: Callable,art_height: float=98) -> void:
	if not _desktop and safe_rect.size.y<700: art_height=minf(art_height,68 if _text_scale>1.3 else 90)
	var button: Button=_button("",action,Color("fffaf0"),0)
	button.clip_contents=true
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var detail_lines: int=subtitle.count("\n")+1
	var compact_row: bool=not _desktop and _browse_while_placing and not preview_action.is_empty()
	var text_height: float=24*_text_scale+detail_lines*18*_text_scale
	button.custom_minimum_size=Vector2(0,(maxf(art_height,text_height) if compact_row else art_height+text_height)+14)
	button.tooltip_text=title+" · "+subtitle
	parent.add_child(button)
	var layout: BoxContainer=HBoxContainer.new() if compact_row else VBoxContainer.new()
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(layout); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layout.offset_left=6; layout.offset_right=-6; layout.offset_top=3; layout.offset_bottom=-7; layout.add_theme_constant_override("separation",6 if compact_row else 1)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size=Vector2(72,0) if compact_row else Vector2(40,art_height)
	art.size_flags_horizontal=Control.SIZE_FILL if compact_row else Control.SIZE_EXPAND_FILL
	art.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(art)
	var column: VBoxContainer
	if compact_row:
		column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.size_flags_vertical=Control.SIZE_SHRINK_CENTER; column.mouse_filter=Control.MOUSE_FILTER_IGNORE; layout.add_child(column)
	else: column=layout
	var label: Label=_label(title,15); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if compact_row else HORIZONTAL_ALIGNMENT_CENTER; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(label)
	var detail: Label=_label(subtitle,12,Palette.SECONDARY_INK); detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if compact_row else HORIZONTAL_ALIGNMENT_CENTER; detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(detail)

func _inline_panel(parent: Control) -> VBoxContainer:
	var panel:=PanelContainer.new(); panel.add_theme_stylebox_override("panel",Palette.panel(Color("f3ebdb"),0.8,18)); parent.add_child(panel)
	panel.mouse_filter=Control.MOUSE_FILTER_PASS
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",7); panel.add_child(box); return box

func _scroll_column(parent: Control) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	scroll.add_child(body)
	return body

func _column_in_panel(rect: Rect2,color: Color,padding: int) -> VBoxContainer:
	var panel: PanelContainer=_panel(rect,color,padding)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",8); panel.add_child(column); return column

func _row_in_panel(rect: Rect2,color: Color,padding: int) -> HBoxContainer:
	var panel: PanelContainer=_panel(rect,color,padding)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); panel.add_child(row); return row

func _panel(rect: Rect2,color: Color,padding: int) -> PanelContainer:
	var panel:=PanelContainer.new(); panel.position=rect.position; panel.size=rect.size
	var style: StyleBoxFlat=Palette.panel(color,1.0,22)
	style.content_margin_left=padding; style.content_margin_right=padding; style.content_margin_top=padding; style.content_margin_bottom=padding
	panel.add_theme_stylebox_override("panel",style); _surface.add_child(panel); return panel

func _label(value: String,font_size: int=16,color: Color=Palette.INK) -> Label:
	var label:=Label.new(); label.text=value; label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.add_theme_color_override("font_color",color); label.add_theme_font_override("font",_font(font_size>=20)); label.add_theme_font_size_override("font_size",roundi(font_size*_text_scale)); return label

func _button(value: String,action: Callable,fill: Color=Palette.CREAM,width: float=0) -> Button:
	var button:=Button.new(); button.text=value; button.custom_minimum_size=Vector2(width,42); button.add_theme_font_override("font",_font()); button.add_theme_font_size_override("font_size",roundi(15*_text_scale)); button.add_theme_color_override("font_color",Palette.INK); button.add_theme_color_override("font_hover_color",Palette.INK); button.add_theme_color_override("font_pressed_color",Palette.INK); button.add_theme_color_override("font_disabled_color",Palette.SECONDARY_INK)
	# Let ScrollContainer receive touch-emulated mouse drags from cards/tabs.
	# Its scroll-begin notification cancels the button press after the deadzone.
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.add_theme_stylebox_override("normal",Palette.button_style(fill,0.75)); button.add_theme_stylebox_override("hover",Palette.button_style(fill.lightened(0.04),0.75)); button.add_theme_stylebox_override("pressed",Palette.button_style(fill.darkened(0.03),0.75,true)); button.add_theme_stylebox_override("disabled",Palette.button_style(Color("e7e1d4"),0.75)); button.add_theme_stylebox_override("focus",Palette.focus_style(0.8)); button.pressed.connect(action); return button

func _font(display: bool=false) -> FontVariation:
	if _body_font==null:
		_body_font=FontVariation.new(); _body_font.base_font=BODY; _body_font.variation_opentype={2003265652:650.0}
		_display_font=FontVariation.new(); _display_font.base_font=DISPLAY; _display_font.variation_opentype={2003265652:620.0}
	return _display_font if display else _body_font

func _coins(value: float) -> String:
	var number: String=str(roundi(value))
	var result: String=""
	for i in range(number.length()):
		if i>0 and (number.length()-i)%3==0: result+=","
		result+=number[i]
	return result
