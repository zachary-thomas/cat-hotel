extends Control
## Ambient feedback mirrors current service rates; it never grants extra currency.
var world
var ui
var model
var elapsed: float = 0.0
var display_font: FontVariation
var ink = Color("294638")
var bubble: StyleBoxFlat
var repair_markers: Array[Button] = []
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_font = FontVariation.new()
	display_font.base_font = preload("res://assets/fonts/Fredoka.ttf")
	display_font.variation_opentype = {2003265652: 550.0}
	bubble = StyleBoxFlat.new()
	bubble.bg_color = Color("fff9e8")
	bubble.set_corner_radius_all(18)
	bubble.shadow_color = Color(0.19, 0.25, 0.10, 0.16)
	bubble.shadow_size = 5
	bubble.shadow_offset = Vector2(0, 3)
	for wing in range(3):
		var marker = Button.new()
		marker.name = "RepairWing%d" % wing
		marker.custom_minimum_size = Vector2(142, 46)
		marker.size = marker.custom_minimum_size
		marker.add_theme_font_override("font", display_font)
		marker.add_theme_font_size_override("font_size", 13)
		marker.add_theme_color_override("font_color", ink)
		marker.add_theme_color_override("font_hover_color", ink)
		marker.add_theme_color_override("font_pressed_color", ink)
		marker.add_theme_stylebox_override("normal", bubble)
		var hover = bubble.duplicate()
		hover.bg_color = Color("e5edd5")
		marker.add_theme_stylebox_override("hover", hover)
		marker.add_theme_stylebox_override("pressed", hover)
		var focus = bubble.duplicate()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("54775b")
		focus.set_border_width_all(3)
		marker.add_theme_stylebox_override("focus", focus)
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.pressed.connect(func(): ui.open_expansions(wing))
		add_child(marker)
		repair_markers.append(marker)
func _process(delta: float) -> void:
	if ui == null or model == null:
		return
	visible = ui.visible and model.started and ui.tab == "Hotel" and not model.settings.get("watch",false)
	if visible:
		for wing in range(3):
			var marker = repair_markers[wing]
			var p: Vector2 = world.camera.unproject_position(Vector3(0, 0.45, -9.35-wing*3.3))
			var compact: bool = world.camera.size > 30
			marker.custom_minimum_size = Vector2(122,38) if wing == world.wings else Vector2(91,30)
			marker.size = marker.custom_minimum_size
			marker.add_theme_font_size_override("font_size",12 if compact else 13)
			marker.position = p - marker.size / 2
			marker.visible = not world.exterior_view and wing >= world.wings and p.x > 0 and p.x < size.x and p.y > 145 and p.y < size.y - 175
			var remaining: float = model.repair_remaining(model.current_hotel)
			var status: String = "Level %d · %s coins" % [model.WING_LEVELS[wing], ui.number(model.WING_COSTS[wing])]
			if wing == world.wings and remaining > 0:
				status = "Repairing · %ds" % ceili(remaining)
			elif wing == world.wings and model.can_expand(model.current_hotel):
				status = "Repair · %s coins" % ui.number(model.WING_COSTS[wing])
			marker.text = model.WING_NAMES[wing] + "\n" + status if wing == world.wings else ["Garden","Courtyard","Skyview"][wing]+" · Lv%d" % model.WING_LEVELS[wing]
			marker.tooltip_text = "View repair details for " + model.WING_NAMES[wing]
	if world.motion_enabled:
		elapsed += delta
	queue_redraw()
func _draw() -> void:
	if world == null or not visible:
		return
	_draw_ground_labels()
	if world.exterior_view or world.camera.size >= 25:
		return
	for zone in [0, 1]:
		if model.life.state.seconds > 50:
			continue
		var level: int = world.zone_levels[zone]
		if level <= 0:
			continue
		var p: Vector2 = world.camera.unproject_position(world.zone_centers[zone] + Vector3(0.1, 2.1, 0.7))
		p.y += sin(elapsed * 1.6 + zone * PI) * 3
		p.x = clampf(p.x, 59, size.x - 59)
		if p.y < 235 or p.y > size.y - 260:
			continue
		var rect = Rect2(p - Vector2(56, 18), Vector2(112, 36))
		draw_style_box(bubble, rect)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 15), p + Vector2(3, 24), p + Vector2(11, 15)]), bubble.bg_color)
		coin(p + Vector2(-37, 0))
		draw_string(display_font, p + Vector2(-19, 6), "+%d/min" % (level * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var guest: int = 2 if int(elapsed / 7) % 2 == 0 else 3
	if world.actors.size() > guest:
		var actor = world.actors[guest]
		var p: Vector2 = world.camera.unproject_position(actor.global_position + Vector3(0, 1.7, 0))
		var captions: Dictionary = {"walk": " is exploring", "work": " is tidying up", "rest": " is settling in", "play": " found a cozy spot"}
		var identity: String = model.Content.STAFF[int(actor.get_meta("cat_index")) % 3].name if actor.is_staff else model.CAT_NAMES[int(actor.get_meta("cat_index"))]
		var caption: String = identity + captions.get(actor.action, " is feeling cozy")
		var width: float = display_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24
		p.x = clampf(p.x, width / 2 + 12, size.x - width / 2 - 12)
		if p.y > 390 and p.y < size.y - 266:
			draw_style_box(bubble, Rect2(p - Vector2(width / 2, 15), Vector2(width, 30)))
			draw_string(display_font, p + Vector2(-width / 2 + 12, 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	# Very subtle firefly-like pollen over the garden, disabled by reduced motion.
	if world.motion_enabled:
		for i in range(9):
			var p = Vector2(fmod(i * 91.0 + elapsed * 4, size.x), 250 + fmod(i * 59.0 - elapsed * 7 + 5000, maxf(1, size.y - 500)))
			draw_circle(p, 1.3, Color(1.0, 0.96, 0.67, 0.42 + sin(elapsed + i) * 0.23))
func coin(p: Vector2) -> void:
	draw_circle(p + Vector2(0, 1), 12.5, Color("c69535"))
	draw_circle(p, 11, Color("eebd4f"))
	draw_arc(p, 9.2, 0, TAU, 24, Color("ffe69d"), 1.1, true)
	draw_circle(p + Vector2(0, 3), 3.5, Color("fff0b5"))
	for v in [Vector2(-5, -1), Vector2(-2, -5), Vector2(3, -5), Vector2(6, -1)]:
		draw_circle(p + v, 2.0, Color("fff0b5"))

func _draw_ground_labels() -> void:
	if world.neighborhood == null or world.neighborhood.model == null:
		return
	var scene = world.neighborhood
	var data: Dictionary = model.grounds.hotels[model.current_hotel]
	var occupied: Array[Rect2] = []
	for marker in repair_markers:
		if marker.visible:
			occupied.append(marker.get_rect().grow(3))
	if is_instance_valid(scene.manager) and not (world.exterior_view and world.contains_hotel(scene.manager.position)):
		var p: Vector2 = world.camera.unproject_position(scene.manager.global_position+Vector3(0,1.6,0))
		if p.y > 145 and p.y < size.y-165:
			var rect = Rect2(p-Vector2(19,11),Vector2(38,22))
			occupied.append(rect.grow(3))
			draw_style_box(bubble,rect)
			draw_string(display_font,p+Vector2(-11,4),"You",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ad545d"))
	var labels: Array = scene.targets.duplicate()
	var priorities = {"kiosk":0,"amenity":1,"trim":2,"chase":2,"clean":3,"yarn":4}
	labels.sort_custom(func(a,b): return priorities.get(a.action,5) < priorities.get(b.action,5))
	for target in labels:
		target.screen_rect = Rect2()
		if world.exterior_view and world.contains_hotel(target.position):
			continue
		var origin: Vector2 = world.camera.unproject_position(target.position)
		var p: Vector2 = origin
		var text: String = target.label
		if target.action == "amenity":
			text = {"pool":"Pool","litter":"Litter nook","playpen":"Playpen","picnic":"Picnic"}[target.payload.id]
			if not data.amenities.has(target.payload.id):
				text += " +"
			p.y -= 28
		elif target.action == "yarn":
			p += Vector2(10,-23)
		elif target.action == "trim":
			p.y += 15
		elif target.action == "clean":
			if not scene.manager_control:
				continue
			p.y -= 10
		else:
			p.y -= 13
		if origin.x < 0 or origin.x > size.x or p.y < 145 or p.y > size.y-165:
			continue
		var width: float = display_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+14
		var rect: Rect2
		var placed: bool = false
		for offset in [Vector2.ZERO,Vector2(0,-28),Vector2(0,28),Vector2(-36,0),Vector2(36,0),Vector2(0,-56),Vector2(0,56)]:
			var candidate: Vector2 = p+offset
			candidate.x = clampf(candidate.x,width/2+6,size.x-width/2-6)
			rect = Rect2(candidate-Vector2(width/2,12),Vector2(width,24))
			if rect.position.y < 138 or rect.end.y > size.y-155:
				continue
			if not occupied.any(func(other): return other.intersects(rect.grow(2))):
				placed = true
				break
		if not placed:
			continue
		target.screen_rect = rect
		occupied.append(rect)
		if rect.get_center().distance_to(origin)>18:
			draw_line(origin,rect.get_center(),Color(0.25,0.42,0.36,0.45),1.2,true)
		draw_style_box(bubble,rect)
		draw_string(display_font,rect.position+Vector2(7,16),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
