extends Control
## A single reusable screen-space bubble, anchored to the current speaking cat.
const BODY = preload("res://assets/fonts/Nunito.ttf")
const DISPLAY = preload("res://assets/fonts/Fredoka.ttf")
var bubble_rect: Rect2 = Rect2()
var body_label: Label
var name_label: Label
var _style: StyleBoxFlat
var _anchor: Vector2
var _tail: PackedVector2Array = PackedVector2Array()
var _heart: bool = false
var _last_text: String = ""
var _last_width: float = 0.0
var _last_scale: float = 0.0
var _body_font: FontVariation
var _name_font: FontVariation

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style=StyleBoxFlat.new()
	_style.bg_color=Color("fff8e9")
	_style.set_corner_radius_all(17)
	_style.border_color=Color("dfcbb0")
	_style.set_border_width_all(2)
	_style.shadow_color=Color(0.15,0.23,0.16,0.18)
	_style.shadow_size=4; _style.shadow_offset=Vector2(0,3)
	_body_font=FontVariation.new(); _body_font.base_font=BODY; _body_font.variation_opentype={2003265652:650.0}
	_name_font=FontVariation.new(); _name_font.base_font=DISPLAY; _name_font.variation_opentype={2003265652:550.0}
	name_label=Label.new(); name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font",_name_font)
	name_label.add_theme_color_override("font_color",Color("688e73"))
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_label)
	body_label=Label.new(); body_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body_label.add_theme_font_override("font",_body_font)
	body_label.add_theme_color_override("font_color",Color("24483e"))
	body_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(body_label)
	hide()

func present(line: Dictionary, speaker_name: String, anchor: Vector2, area: Rect2, protected: Array, text_scale: float, motion: bool) -> void:
	if line.is_empty() or not area.has_area() or not area.has_point(anchor):
		hide(); return
	var scale_value: float=clampf(text_scale,1.0,1.5)
	var padding: float=12.0
	var width: float=minf(260.0*scale_value,area.size.x-8.0)
	if width<120.0: hide(); return
	var body_size: int=roundi(17*scale_value)
	var name_size: int=roundi(13*scale_value)
	var value: String=String(line.get("text",""))
	if value!=_last_text or not is_equal_approx(width,_last_width) or not is_equal_approx(scale_value,_last_scale):
		body_label.text=value
		body_label.add_theme_font_size_override("font_size",body_size)
		name_label.add_theme_font_size_override("font_size",name_size)
		_last_text=value; _last_width=width; _last_scale=scale_value
	var available: float=width-padding*2.0
	var measured: Vector2=_body_font.get_multiline_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,available,body_size,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND)
	var name_h: float=_name_font.get_height(name_size)+2.0
	var body_h: float=maxf(measured.y,_body_font.get_height(body_size))
	var dimensions:=Vector2(width,padding*2.0+name_h+body_h)
	if dimensions.y+14>area.size.y: hide(); return
	var elapsed: float=float(line.get("elapsed",1.0))
	var lift: float=(1.0-clampf(elapsed/0.16,0,1))*5.0 if motion else 0.0
	var candidates: Array[Vector2]=[
		anchor-Vector2(width*0.5,dimensions.y+16-lift),
		anchor+Vector2(18,-dimensions.y-12+lift),
		anchor-Vector2(width+18,dimensions.y+12-lift),
		anchor-Vector2(width*0.5,dimensions.y+58-lift)
	]
	# Nearby cats and reception staff can fill the first few positions. Search
	# the remaining safe height before giving up on a readable conversation.
	var higher: float=anchor.y-dimensions.y-82.0
	while higher>=area.position.y:
		candidates.append(Vector2(anchor.x-width*0.5,higher))
		higher-=24.0
	candidates.append(anchor+Vector2(-width*0.5,42.0))
	var placed: bool=false
	for point in candidates:
		point.x=clampf(point.x,area.position.x+2,area.end.x-width-2)
		var candidate:=Rect2(point.round(),dimensions)
		if not area.encloses(candidate): continue
		var overlaps: bool=false
		for region in protected:
			if Rect2(region).grow(4).intersects(candidate): overlaps=true; break
		if overlaps: continue
		bubble_rect=candidate; placed=true; break
	if not placed: hide(); return
	_anchor=anchor
	var tail_x: float=clampf(anchor.x,bubble_rect.position.x+20,bubble_rect.end.x-20)
	var below: bool=bubble_rect.position.y>anchor.y
	var edge: float=bubble_rect.position.y+1 if below else bubble_rect.end.y-1
	_tail=PackedVector2Array([Vector2(tail_x-7,edge),Vector2(tail_x+7,edge),anchor+Vector2(0,3 if below else -3)])
	name_label.text=speaker_name
	name_label.position=bubble_rect.position+Vector2(padding,padding-1)
	name_label.size=Vector2(available,name_h)
	body_label.position=bubble_rect.position+Vector2(padding,padding+name_h)
	body_label.size=Vector2(available,body_h)
	_heart=String(line.get("gesture",""))=="happy"
	var alpha: float=1.0
	if motion: alpha=minf(clampf(elapsed/0.14,0,1),clampf((float(line.get("duration",3.1))-elapsed)/0.22,0,1))
	modulate.a=alpha
	show(); queue_redraw()

func _draw() -> void:
	if _style==null or not bubble_rect.has_area(): return
	draw_colored_polygon(_tail,Color("fff8e9"))
	draw_line(_tail[0],_tail[2],Color("dfcbb0"),1.5,true)
	draw_line(_tail[1],_tail[2],Color("dfcbb0"),1.5,true)
	draw_style_box(_style,bubble_rect)
	if _heart:
		var at:=bubble_rect.position+Vector2(bubble_rect.size.x-19,17)
		draw_circle(at+Vector2(-3,-2),3.7,Color("dc8d98"))
		draw_circle(at+Vector2(3,-2),3.7,Color("dc8d98"))
		draw_colored_polygon(PackedVector2Array([at+Vector2(-6,0),at+Vector2(6,0),at+Vector2(0,7)]),Color("dc8d98"))
