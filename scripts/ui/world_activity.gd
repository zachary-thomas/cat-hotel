extends Control
## All world annotations share one clipping rectangle and a three-label budget.
var world
var ui
var model
var elapsed := 0.0
var display_font: FontVariation
var bubble: StyleBoxFlat
var ink := Color("24483e")
var repair_markers: Array[Button] = []
var placed_labels: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_font = FontVariation.new()
	display_font.base_font = preload("res://assets/fonts/Nunito.ttf")
	display_font.variation_opentype = {2003265652:650.0}
	bubble = StyleBoxFlat.new()
	bubble.bg_color = Color("fff8e9")
	bubble.set_corner_radius_all(16)
	bubble.shadow_color = Color(0.19,0.25,0.10,0.16)
	bubble.shadow_size = 4
	bubble.shadow_offset = Vector2(0,3)
	for wing in range(3):
		var marker := Button.new()
		marker.name = "RepairWing%d" % wing
		marker.add_theme_font_override("font",display_font)
		for state in ["normal","hover","pressed"]: marker.add_theme_stylebox_override(state,bubble)
		for state in ["font_color","font_hover_color","font_pressed_color"]: marker.add_theme_color_override(state,ink)
		var focus := bubble.duplicate()
		focus.border_color = Color("24483e")
		focus.set_border_width_all(3)
		marker.add_theme_stylebox_override("focus",focus)
		marker.pressed.connect(func(): ui.open_expansions(wing))
		add_child(marker)
		repair_markers.append(marker)

func _process(delta: float) -> void:
	if ui == null or model == null: return
	visible = ui.visible and model.started and ui.tab == "Hotel" and not model.settings.get("watch",false)
	placed_labels.clear()
	for marker in repair_markers:
		marker.hide()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world.neighborhood != null:
		for target in world.neighborhood.targets: target.screen_rect = Rect2()
	# The cats' in-world speech is represented by the same budget, rather than unbounded Label3Ds.
	for actor in world.actors:
		if actor.thought != null: actor.thought.hide()
	if visible: _place_candidates()
	if world.motion_enabled: elapsed += delta
	queue_redraw()

func _place_candidates() -> void:
	var region: Rect2 = ui.metrics.world_rect.grow(-4 * float(ui.metrics.unit))
	var unit: float = ui.metrics.unit
	var font_size := roundi(14 * unit * float(ui.metrics.font_scale))
	var candidates: Array[Dictionary] = []
	var protected: Array[Rect2] = []
	if not world.exterior_view and world.room_builder != null:
		for room in range(world.room_builder.room_nodes.size()):
			var bed: Vector3 = world.room_builder.bed_position(room)
			var bed_rect := Rect2(world.camera.unproject_position(bed),Vector2.ZERO)
			for x in [-0.8,0.8]:
				for y in [0.0,1.5]:
					for z in [-0.8,0.8]: bed_rect = bed_rect.expand(world.camera.unproject_position(bed+Vector3(x,y,z)))
			protected.append(bed_rect)
	var remaining: float = model.repair_remaining(model.current_hotel)
	if not world.exterior_view:
		for wing in range(world.wings,3):
			var caption: String = ["Garden","Courtyard","Skyview"][wing] + " · Lv%d" % model.WING_LEVELS[wing]
			if wing == world.wings:
				caption = "Repair · %s coins" % ui.number(model.WING_COSTS[wing])
				if remaining > 0: caption = "Repairing · %ds" % ceili(remaining)
			candidates.append({"text":caption,"point":Vector3(0,2.8,-9.35-wing*3.3),"priority":0 if ui.selected_wing==wing else (1 if wing==world.wings and remaining>0 else 2),"wing":wing})
	var scene = world.neighborhood
	if scene != null and scene.model != null:
		var state: Dictionary = model.grounds.hotels[model.current_hotel]
		if is_instance_valid(scene.manager) and scene.manager.is_visible_in_tree() and not (world.exterior_view and world.contains_hotel(scene.manager.global_position)):
			if not state.job.is_empty():
				candidates.append({"text":"On the job","point":scene.manager.global_position+Vector3(0,1.5,0),"priority":1})
			elif scene.manager_control:
				candidates.append({"text":"You","point":scene.manager.global_position+Vector3(0,1.5,0),"priority":0})
		for target in scene.targets:
			if world.exterior_view and world.contains_hotel(target.position): continue
			if target.action=="clean" and not scene.manager_control: continue
			var caption: String = target.label
			if target.action=="amenity": caption = {"pool":"Pool","litter":"Litter nook","playpen":"Playpen","picnic":"Picnic"}[target.payload.id]
			candidates.append({"text":caption,"point":target.position+Vector3(0,0.7,0),"priority":0 if scene.selected_target==str(target.action)+str(target.payload) else 2,"target":target})
	if not world.exterior_view:
		for actor in world.actors:
			if actor.is_staff or not actor.visible: continue
			var identity: String = model.CAT_NAMES[int(actor.get_meta("cat_index"))]
			candidates.append({"text":identity + (" found a cozy spot" if actor.action=="sleep" else " is exploring"),"point":actor.global_position+Vector3(0,1.5,0),"priority":0 if world.follow_cat==int(actor.get_meta("cat_index")) else 3})
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		candidate.order = index
		candidate.screen = world.camera.unproject_position(candidate.point)
		candidate.distance = candidate.screen.distance_squared_to(region.get_center())
	candidates.sort_custom(func(a,b):
		if a.priority != b.priority: return a.priority < b.priority
		if not is_equal_approx(a.distance,b.distance): return a.distance < b.distance
		return a.order < b.order)
	for candidate in candidates:
		if placed_labels.size() >= 3: break
		if not region.has_point(candidate.screen): continue
		var clickable: bool = candidate.has("wing") or candidate.has("target")
		var width := maxf(48 * unit,display_font.get_string_size(candidate.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20*unit)
		var dimensions := Vector2(width,(48 if clickable else 32)*unit)
		var rect := Rect2(candidate.screen-dimensions*0.5,dimensions)
		if not region.encloses(rect): continue
		if protected.any(func(bed_rect): return bed_rect.intersects(rect)): continue
		if placed_labels.any(func(other): return other.rect.grow(4*unit).intersects(rect)): continue
		candidate.rect = rect
		candidate.font_size = font_size
		placed_labels.append(candidate)
		if candidate.has("wing"):
			var marker: Button = repair_markers[candidate.wing]
			marker.text = candidate.text
			marker.add_theme_font_size_override("font_size",font_size)
			marker.custom_minimum_size = dimensions
			marker.size = dimensions
			marker.position = rect.position
			marker.mouse_filter = Control.MOUSE_FILTER_STOP
			marker.show()
		elif candidate.has("target"): candidate.target.screen_rect = rect

func _draw() -> void:
	for candidate in placed_labels:
		if candidate.has("wing"): continue
		var rect: Rect2 = candidate.rect
		draw_style_box(bubble,rect)
		draw_string(display_font,rect.position+Vector2(10*float(ui.metrics.unit),rect.size.y*0.5+candidate.font_size*0.34),candidate.text,HORIZONTAL_ALIGNMENT_LEFT,-1,candidate.font_size,ink)
