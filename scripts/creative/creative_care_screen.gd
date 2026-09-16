extends Control
## Persistent care UI: reward/save updates never replace the interactive stage.
const Stage = preload("res://scripts/creative/creative_care_stage.gd")
const Art = preload("res://scripts/ui/guest_art.gd")
const Content = preload("res://scripts/core/game_content.gd")
const Palette = preload("res://scripts/ui/playful_theme.gd")
const HELP = {
	"pet":"Stroke your cat, or rest your finger gently.",
	"brush":"Brush gently across your cat’s coat.",
	"wand":"Drag the feather. Watch those little paws!",
	"yarn":"Drag and flick the yarn for a little chase.",
	"cushion":"Tap the room to offer a soft spot to rest.",
	"box":"Tap the room to offer a box. Tap again to peek!"
}
var ui
var cat_index: int = 0
var stage
var meter: ProgressBar
var bond_label: Label
var hint: Label
var message: Label
var tool_buttons: Dictionary = {}
var use_button: Button
var detail_panel: PanelContainer
var _panel: PanelContainer
var _column: VBoxContainer
var _tools: GridContainer
var _portrait: TextureRect
var _last_error: String = ""
var _return_button: Button

func _ready() -> void:
	name="CatCareScreen"; mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop:=ColorRect.new(); backdrop.color=Color("E9E5D7"); backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel=PanelContainer.new(); _panel.add_theme_stylebox_override("panel",Palette.panel(Palette.CREAM,1,22)); add_child(_panel)
	_panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	_column=VBoxContainer.new(); _column.add_theme_constant_override("separation",8); _panel.add_child(_column)
	var header:=HBoxContainer.new(); header.add_theme_constant_override("separation",8); _column.add_child(header)
	_return_button=ui._button("‹ Back",ui.close_cat_care,Color("EEE6D8"),64); _return_button.name="CareBack"; header.add_child(_return_button)
	_portrait=TextureRect.new(); _portrait.texture=Art.portrait(cat_index); _portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _portrait.custom_minimum_size=Vector2(42,42); header.add_child(_portrait)
	var title: Label=ui._label(Content.CAT_NAMES[cat_index],24); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; header.add_child(title)
	bond_label=ui._label("",14,Palette.SECONDARY_INK); _column.add_child(bond_label)
	meter=ProgressBar.new(); meter.show_percentage=false; meter.custom_minimum_size.y=8; meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background",Palette.button_style(Color("E6DFCF"),0.5))
	meter.add_theme_stylebox_override("fill",Palette.button_style(Color("E6A48F"),0.5)); _column.add_child(meter)
	stage=Stage.new(); stage.cat_index=cat_index; stage.hotel_index=int(ui.app.model.state.current_hotel)
	stage.enabled_motion=bool(ui.app.model.state.settings.get("motion",true)); stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size=Vector2(0,150); _column.add_child(stage)
	stage.care_action.connect(_care)
	stage.contact_changed.connect(_contact)
	hint=ui._label(HELP.pet,14); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.y=38; _column.add_child(hint)
	_tools=GridContainer.new(); _tools.columns=3; _tools.add_theme_constant_override("h_separation",6); _tools.add_theme_constant_override("v_separation",6); _column.add_child(_tools)
	for i in range(Stage.TOOLS.size()):
		var kind: String=Stage.TOOLS[i]
		var title_text: String="Feather" if kind=="wand" else kind.capitalize()
		var button: Button=ui._button(title_text,func(): select_tool(kind),Color("F0E9DD"))
		button.name="CareTool_"+kind; button.toggle_mode=true; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.icon=Art.region(Art.TOYS,i,"toy_"+str(i)); button.expand_icon=true; button.add_theme_constant_override("icon_max_width",26)
		button.add_theme_stylebox_override("pressed",Palette.button_style(Palette.MINT,0.75,true))
		button.add_theme_stylebox_override("hover_pressed",Palette.button_style(Palette.MINT.lightened(0.04),0.75,true))
		button.accessibility_name=title_text; button.tooltip_text=title_text
		_tools.add_child(button); tool_buttons[kind]=button
	use_button=ui._button("Use selected tool",func(): stage.use_selected_tool(),Palette.MINT)
	use_button.name="CareUseTool"; _column.add_child(use_button)
	var footer:=HBoxContainer.new(); _column.add_child(footer)
	var details: Button=ui._button("About & friends",show_details,Color("EEE6D8")); details.name="CareDetails"; footer.add_child(details)
	message=ui._label("",12,Palette.SECONDARY_INK); message.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; message.max_lines_visible=2
	message.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; footer.add_child(message)
	resized.connect(_layout)
	select_tool("pet"); update_progress(); _layout()

func _layout() -> void:
	if _panel==null: return
	var width: float=minf(size.x-16,900)
	_panel.position=Vector2((size.x-width)*0.5,8); _panel.size=Vector2(width,size.y-16)
	var compact: bool=size.y<730
	_column.add_theme_constant_override("separation",4 if compact else 8)
	_tools.columns=6 if width>=700 else 3
	for button: Button in tool_buttons.values():
		button.custom_minimum_size.y=44 if compact else 54
		button.add_theme_constant_override("icon_max_width",18 if width<370 else 26)
	stage.custom_minimum_size.y=130 if compact else 220
	hint.custom_minimum_size.y=38 if compact else 44
	if is_instance_valid(detail_panel): _layout_details()

func select_tool(kind: String) -> void:
	stage.set_tool(kind); hint.text=HELP[kind]
	for key: String in tool_buttons:
		tool_buttons[key].set_pressed_no_signal(key==kind)
		tool_buttons[key].add_theme_stylebox_override("normal",Palette.button_style(Palette.MINT if key==kind else Color("F0E9DD"),0.75))
	use_button.accessibility_name="Use "+("Feather" if kind=="wand" else kind.capitalize())
	message.text=""

func _contact(active: bool) -> void:
	if ui.app.soundscape==null: return
	if active: ui.app.soundscape.start_care_purr()
	else: ui.app.soundscape.stop_care_purr()

func _care(kind: String) -> void:
	var result: Dictionary=ui.app.care(cat_index,kind,false)
	if not result.ok:
		message.text=str(result.message); message.add_theme_color_override("font_color",Palette.ERROR_INK)
	elif bool(result.get("progress_changed",false)):
		message.text="A little closer ♥"; message.add_theme_color_override("font_color",Palette.SECONDARY_INK)
	message.tooltip_text=message.text
	update_progress()

func update_progress() -> void:
	if meter==null: return
	var guest: Dictionary=ui.app.model.state.cats[cat_index]
	meter.value=int(guest.bond); bond_label.text="♥ %d / 100 friendship" % int(guest.bond)
	stage.enabled_motion=bool(ui.app.model.state.settings.get("motion",true))
	if str(ui.app.save_error)!=_last_error:
		_last_error=str(ui.app.save_error)
		if not _last_error.is_empty():
			message.text="Save failed. Try again."
			message.tooltip_text="Your friendship is unchanged. "+_last_error

func show_details() -> void:
	stage.suspend()
	if is_instance_valid(detail_panel): return
	detail_panel=PanelContainer.new(); detail_panel.name="CareDetailsPanel"
	detail_panel.add_theme_stylebox_override("panel",Palette.panel(Palette.CREAM,1,22)); add_child(detail_panel)
	detail_panel.minimum_size_changed.connect(func():
		if is_instance_valid(detail_panel): _layout_details.call_deferred())
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",10); detail_panel.add_child(column)
	var back_to_play: Button=ui._button("‹ Back to play",_close_details,Palette.MINT)
	column.add_child(back_to_play); back_to_play.grab_focus()
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	var body:=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",10); scroll.add_child(body)
	for copy in [Content.CAT_TRAITS[cat_index],"Loves "+str(Content.PREFERENCE_COPY[Content.PREFERENCES[cat_index]])+".","Invite a friend","An open lounge and 10 friendship with both cats makes a playdate possible."]:
		var label: Label=ui._label(copy,16); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(label)
	var notice: Label=ui._label("",14); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(notice)
	for i in range(ui.app.model.state.cats.size()):
		if i==cat_index or not ui.app.model.state.cats[i].known: continue
		body.add_child(ui._button("Invite "+Content.CAT_NAMES[i],func():
			var result: Dictionary=ui.app.perform("playdate",{"cat":cat_index,"other":i})
			notice.text=str(result.message),Color("EEE6D8")))
	_layout_details()

func _layout_details() -> void:
	if not is_instance_valid(detail_panel): return
	detail_panel.position=_panel.position; detail_panel.size=_panel.size

func _close_details() -> void:
	remove_child(detail_panel); detail_panel.queue_free(); detail_panel=null
	use_button.grab_focus()

func back() -> void:
	if is_instance_valid(detail_panel): _close_details()
	else: ui.close_cat_care()

func suspend() -> void:
	if is_instance_valid(stage): stage.suspend()
	if ui.app.soundscape!=null: ui.app.soundscape.stop_care_purr(true)

func _exit_tree() -> void:
	suspend()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_WINDOW_FOCUS_OUT] and ui!=null: suspend()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST and ui!=null: back()
