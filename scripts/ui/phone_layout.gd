extends RefCounted
## Shared phone shell geometry. Measurements are returned in canvas coordinates.

static func measure(viewport: Vector2, safe: Rect2, phone_scale: float, text_scale: float) -> Dictionary:
	var unit := 1.0 / clampf(phone_scale, 0.1, 10.0)
	var font_scale := clampf(text_scale, 1.0, 1.5)
	var safe_rect: Rect2 = safe.abs()
	var gap := 8.0 * unit
	var header_h := (112.0 if font_scale > 1.0 else 64.0) * unit
	var dock_h := 80.0 * unit
	var objective_h := (80.0 if font_scale > 1.0 else 64.0) * unit
	var header := _inside(safe_rect, Rect2(safe_rect.position, Vector2(safe_rect.size.x, header_h)))
	var footer := _inside(safe_rect, Rect2(Vector2(safe_rect.position.x, safe_rect.end.y - dock_h), Vector2(safe_rect.size.x, dock_h)))
	var objective := _inside(safe_rect, Rect2(Vector2(safe_rect.position.x, footer.position.y - gap - objective_h), Vector2(safe_rect.size.x, objective_h)))
	var world := _inside(safe_rect, Rect2(Vector2(safe_rect.position.x, header.end.y + gap), Vector2(safe_rect.size.x, objective.position.y - header.end.y - gap * 2.0)))
	var content := _inside(safe_rect, Rect2(Vector2(safe_rect.position.x, header.end.y + gap), Vector2(safe_rect.size.x, footer.position.y - header.end.y - gap * 2.0)))
	# Round upward so converting back to phone pixels never slips below 48 through float precision.
	var target := ceilf(48.0 * unit * 1000.0) / 1000.0
	return {"unit":unit,"font_scale":font_scale,"target":target,"safe_rect":safe_rect,"header_rect":header,"footer_rect":footer,"objective_rect":objective,"world_rect":world,"content_rect":content,"viewport":viewport}

static func _inside(safe: Rect2, candidate: Rect2) -> Rect2:
	var position := Vector2(
		clampf(candidate.position.x, safe.position.x, safe.end.x),
		clampf(candidate.position.y, safe.position.y, safe.end.y)
	)
	var requested := Vector2(maxf(0.0, candidate.size.x), maxf(0.0, candidate.size.y))
	return Rect2(position, Vector2(
		minf(requested.x, maxf(0.0, safe.end.x - position.x)),
		minf(requested.y, maxf(0.0, safe.end.y - position.y))
	))
