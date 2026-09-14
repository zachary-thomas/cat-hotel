extends RefCounted
## Measurements are in canvas coordinates; ui_scale converts canvas units to phone units.
static func measure(viewport: Vector2, safe: Rect2, ui_scale: float = 1.0, text_scale: float = 1.0) -> Dictionary:
	var scale: float = clampf(ui_scale,0.1,10.0)
	var unit: float = 1.0/scale
	var target: float = 48.0*unit
	var gap: float = 8.0*unit
	var header: float = ceilf(56.0*unit)
	var actions: float = ceilf(56.0*unit)
	var panel_width: float = 336.0*unit
	var wide: bool = safe.size.x >= panel_width+480.0*unit+gap*2
	var action_rect: Rect2
	var panel_rect: Rect2
	var world_rect: Rect2
	var browse_rect: Rect2
	if wide:
		var x: float = safe.end.x-panel_width
		action_rect = Rect2(x,safe.end.y-actions,panel_width,actions)
		panel_rect = Rect2(x,safe.position.y+header+gap,panel_width,maxf(0,safe.size.y-header-actions-gap*2))
		world_rect = Rect2(safe.position.x,safe.position.y+header,safe.size.x-panel_width-gap,maxf(0,safe.size.y-header))
		browse_rect = panel_rect
	else:
		var maximum: float = maxf(0,safe.size.y*0.5-header-actions-gap*2)
		var panel_height: float = minf(176.0*clampf(text_scale,1.0,1.5)*unit,minf(safe.size.y*0.3,maximum))
		action_rect = Rect2(safe.position.x,safe.end.y-actions,safe.size.x,actions)
		panel_rect = Rect2(safe.position.x,action_rect.position.y-gap-panel_height,safe.size.x,panel_height)
		world_rect = Rect2(safe.position.x,safe.position.y+header,safe.size.x,maxf(0,panel_rect.position.y-gap-safe.position.y-header))
		var browse_height: float = minf(safe.size.y*0.45,maxf(panel_height,safe.size.y-header-actions-gap*2-target))
		browse_rect = Rect2(safe.position.x,action_rect.position.y-gap-browse_height,safe.size.x,browse_height)
	return {"wide":wide,"world_rect":world_rect,"panel_rect":panel_rect,"browse_rect":browse_rect,"actions_rect":action_rect,"header_rect":Rect2(safe.position,Vector2(safe.size.x,header)),"min_target":target,"unit":unit,"gap":gap,"viewport":viewport}

static func safe_area(control: Control) -> Rect2:
	var viewport: Vector2 = control.get_viewport_rect().size
	if not OS.has_feature("mobile"): return Rect2(Vector2.ZERO,viewport)
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x<=0 or screen.y<=0 or safe.size.x<=0 or safe.size.y<=0: return Rect2(Vector2.ZERO,viewport)
	var scale: Vector2 = viewport/Vector2(screen)
	return Rect2(Vector2(safe.position)*scale,Vector2(safe.size)*scale)

static func phone_scale(control: Control) -> float:
	# At a 360-wide desktop preview, a 450-unit canvas uses 0.8 screen units per canvas unit.
	# On Android, screen DPI translates physical pixels into dp before the same conversion.
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var viewport: Vector2 = control.get_viewport_rect().size
	if viewport.x<=0 or window.x<=0: return 1.0
	var density: float = maxf(1.0,float(DisplayServer.screen_get_dpi())/160.0) if OS.has_feature("mobile") else 1.0
	return clampf(window.x/viewport.x/density,0.1,10.0)
