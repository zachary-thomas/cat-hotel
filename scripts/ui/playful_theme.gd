extends RefCounted
## Accessible color and surface tokens shared by the phone UI.

const INK := Color("24483e")
const SECONDARY_INK := Color("53635b")
const CREAM := Color("fff8e9")
const MINT := Color("5cc8a1")
const CORAL := Color("f5a18f")
const GOLD := Color("ffcc68")
const LILAC := Color("dcd2f3")
const ERROR_INK := Color("9c3f3f")
const ERROR_FILL := Color("fff0ec")

static func panel(fill: Color, unit: float, radius: float = 20) -> StyleBoxFlat:
	var scale := maxf(0.0, unit)
	var surface := StyleBoxFlat.new()
	surface.bg_color = fill
	surface.shadow_color = Color(0.23, 0.27, 0.13, 0.12 if fill.a > 0 else 0)
	surface.shadow_size = roundi(2.0 * scale)
	surface.shadow_offset = Vector2(0, 2.0 * scale)
	surface.set_corner_radius_all(roundi(radius * scale))
	surface.content_margin_left = 16.0 * scale
	surface.content_margin_right = 16.0 * scale
	surface.content_margin_top = 12.0 * scale
	surface.content_margin_bottom = 12.0 * scale
	return surface

static func button_style(fill: Color, unit: float, pressed: bool = false) -> StyleBoxFlat:
	var scale := maxf(0.0, unit)
	var surface := panel(fill, scale, 18.0)
	surface.shadow_size = roundi(1.0 * scale) if fill.a > 0 else 0
	surface.border_color = fill.darkened(0.15)
	surface.border_width_bottom = roundi((1.0 if pressed else 3.0) * scale) if fill.a > 0 else 0
	surface.content_margin_top = (10.0 if pressed else 7.0) * scale
	surface.content_margin_bottom = (6.0 if pressed else 9.0) * scale
	surface.shadow_color = Color(0.18, 0.28, 0.23, 0.28 if fill.a > 0 else 0)
	surface.shadow_offset = Vector2(0, (1.0 if pressed else 3.0) * scale)
	return surface

static func focus_style(unit: float) -> StyleBoxFlat:
	var scale := maxf(0.0, unit)
	var surface := panel(Color.TRANSPARENT, scale, 18.0)
	surface.shadow_size = 0
	surface.shadow_offset = Vector2.ZERO
	surface.border_color = INK
	surface.set_border_width_all(roundi(3.0 * scale))
	return surface
