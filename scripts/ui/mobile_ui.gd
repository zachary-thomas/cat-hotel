extends Control

signal build_requested
signal play_requested
signal expansion_requested
signal ui_sound_requested
signal upgrade_requested(zone: int)
signal hotel_requested(index: int)
signal claim_requested
signal setting_changed(key: String, value: Variant)
signal zone_focus_requested(zone: int)
signal reset_camera_requested
signal world_rect_changed(rect: Rect2)
signal hotel_focus_requested

const HomeViews = preload("res://scripts/ui/views/home_views.gd")
const GameSheet = preload("res://scripts/ui/game_sheet.gd")
const GameTile = preload("res://scripts/ui/game_tile.gd")
const DOCK = ["Hotel", "Cats", "Build", "Life", "Map"]
const Badge = preload("res://scripts/ui/cat_badge.gd")
const Icon = preload("res://scripts/ui/game_icon.gd")
const Art = preload("res://scripts/ui/menu_art.gd")
const PhoneLayout = preload("res://scripts/ui/phone_layout.gd")
const BuildMetrics = preload("res://scripts/ui/build_metrics.gd")
const PlayfulTheme = preload("res://scripts/ui/playful_theme.gd")
const DISPLAY_FONT = preload("res://assets/fonts/Fredoka.ttf")
const BODY_FONT = preload("res://assets/fonts/Nunito.ttf")
const INK = PlayfulTheme.INK
const MUTED = PlayfulTheme.SECONDARY_INK
const CREAM = PlayfulTheme.CREAM
const GREEN = PlayfulTheme.MINT
const GOLD = PlayfulTheme.GOLD

var snapshot: Dictionary = {}
var header: Control
var footer: Control
var welcome: Control
var sheet: PanelContainer
var shade: ColorRect
var sheet_content: VBoxContainer
var coins_label: Label
var rate_label: Label
var title_label: Label
var level_label: Label
var objective_label: Label
var progress_label: Label
var pending_button: Button
var toast_label: Label
var toast_timer: float = 0.0
var success_count := 0
var feedback_tween: Tween
var feedback_icon: Control
var inline_error: Label
var tab: String = "Hotel"
var selected_zone: int = 0
var selected_wing: int = -1
var repair_status: Label
var repair_progress: ProgressBar
var state_key: String = ""
var live_buttons: Array = []
var nav_buttons: Dictionary = {}
var objective_progress: ProgressBar
var activity_label: Label
var metrics: Dictionary = {}
var route_parents: Dictionary = {}
var _route_history: Array[String] = []
var _pending_restore: Dictionary = {}
var route_state: Dictionary = {}
var _sheet_route: String = ""
var _sheet_height: float = 525
var dock_panel: PanelContainer
var objective_panel: PanelContainer
var objective_button: Button
var _objective_layout_pending := false
var _metrics_key: String = ""
const PHONE_FONT_META := &"phone_font_units"
const PHONE_BUTTON_META := &"phone_button_primary"
const PHONE_BUTTON_UNIT_META := &"phone_button_last_unit"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	relayout()
	get_viewport().size_changed.connect(relayout)
	var theme_resource = Theme.new()
	theme_resource.default_font_size = _scaled_font_size(16)
	var body_font = FontVariation.new()
	body_font.base_font = BODY_FONT
	body_font.variation_opentype = {2003265652: 650.0}
	theme_resource.default_font = body_font
	theme_resource.set_color("font_color", "Label", INK)
	theme_resource.set_color("font_color", "Button", INK)
	theme_resource.set_color("font_hover_color", "Button", INK)
	theme_resource.set_color("font_focus_color", "Button", INK)
	theme_resource.set_color("font_pressed_color", "Button", INK)
	theme_resource.set_color("font_disabled_color", "Button", Color("909589"))
	theme = theme_resource
	_apply_theme_metrics()
	_build_chrome()
	relayout()

func style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.shadow_color = Color(0.23, 0.27, 0.13, 0.12 if color.a > 0 else 0)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var item := _make_label(text, _scaled_font_size(font_size), color, font_size >= 17)
	item.set_meta(PHONE_FONT_META, font_size)
	return item

func canvas_label(text: String, pixels: int, color: Color = INK) -> Label:
	return _make_label(text, pixels, color, pixels >= 17)

func _make_label(text: String, pixels: int, color: Color, display_face: bool) -> Label:
	var item = Label.new()
	item.text = text
	if display_face:
		var display = FontVariation.new()
		display.base_font = DISPLAY_FONT
		display.variation_opentype = {2003265652: 620.0}
		item.add_theme_font_override("font", display)
	item.add_theme_font_size_override("font_size", pixels)
	item.add_theme_color_override("font_color", color)
	return item

func paragraph(text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var phone_size := maxi(16, font_size)
	var item := canvas_paragraph(text, _scaled_font_size(phone_size), color)
	item.set_meta(PHONE_FONT_META, phone_size)
	return item

func canvas_paragraph(text: String, pixels: int, color: Color = MUTED) -> Label:
	var item = _make_label(text, pixels, color, false)
	var body = FontVariation.new()
	body.base_font = BODY_FONT
	body.variation_opentype = {2003265652: 650.0}
	item.add_theme_font_override("font", body)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

func button(text: String, action: Callable, primary: bool = false) -> Button:
	var item = Button.new()
	item.text = text
	item.clip_text = true
	var unit: float = metrics.get("unit", 1.0)
	item.custom_minimum_size = Vector2(48, 56 if primary else 48) * unit
	item.set_meta(PHONE_FONT_META, 19)
	item.set_meta(PHONE_BUTTON_META, primary)
	item.set_meta(PHONE_BUTTON_UNIT_META, unit)
	item.accessibility_name = text.strip_edges() if not text.strip_edges().is_empty() else "Button"
	var display = FontVariation.new()
	display.base_font = DISPLAY_FONT
	display.variation_opentype = {2003265652: 550.0}
	item.add_theme_font_override("font", display)
	item.add_theme_font_size_override("font_size", _scaled_font_size(19))
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(func():
		ui_sound_requested.emit()
		action.call()
	)
	if primary:
		_apply_primary_button_style(item)
	return item

func _scaled_font_size(phone_units: int) -> int:
	return maxi(1, roundi(phone_units * float(metrics.get("unit", 1.0)) * float(metrics.get("font_scale", 1.0))))

func relayout() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var safe: Rect2 = BuildMetrics.safe_area(self)
	var phone_scale: float = BuildMetrics.phone_scale(self)
	var text_scale: float = float(snapshot.get("settings", {}).get("ui_text_scale", 1.0))
	metrics = PhoneLayout.measure(viewport, safe, phone_scale, text_scale)
	world_rect_changed.emit(metrics.world_rect)
	_metrics_key = str(viewport) + str(safe) + str(phone_scale) + str(text_scale)
	_apply_theme_metrics()
	_apply_control_metrics(self)
	_apply_shell_geometry()
	_layout_navigation()
	_layout_home()
	if is_instance_valid(sheet):
		sheet.relayout(_sheet_bounds())

func _apply_theme_metrics() -> void:
	if theme == null:
		return
	theme.default_font_size = _scaled_font_size(16)
	var unit: float = metrics.get("unit", 1.0)
	theme.set_stylebox("normal", "Button", PlayfulTheme.button_style(CREAM, unit))
	theme.set_stylebox("hover", "Button", PlayfulTheme.button_style(CREAM.lightened(0.05), unit))
	theme.set_stylebox("pressed", "Button", PlayfulTheme.button_style(CREAM.darkened(0.05), unit, true))
	theme.set_stylebox("disabled", "Button", PlayfulTheme.button_style(Color("e7e6da"), unit))
	theme.set_stylebox("focus", "Button", PlayfulTheme.focus_style(unit))

func _apply_control_metrics(node: Node) -> void:
	if node is Control and node.has_meta(PHONE_FONT_META):
		node.add_theme_font_size_override("font_size", _scaled_font_size(int(node.get_meta(PHONE_FONT_META))))
	if node is Button and node.has_meta(PHONE_BUTTON_META):
		var primary: bool = bool(node.get_meta(PHONE_BUTTON_META))
		var unit: float = float(metrics.get("unit", 1.0))
		var previous_unit: float = maxf(0.1, float(node.get_meta(PHONE_BUTTON_UNIT_META, unit)))
		var authored_size: Vector2 = node.custom_minimum_size / previous_unit
		var target_size := Vector2(48, 56 if primary else 48)
		node.custom_minimum_size = Vector2(maxf(authored_size.x, target_size.x), maxf(authored_size.y, target_size.y)) * unit
		node.set_meta(PHONE_BUTTON_UNIT_META, unit)
		if primary:
			_apply_primary_button_style(node)
	for child in node.get_children():
		_apply_control_metrics(child)
	if node is GameTile:
		node.relayout()

func _apply_primary_button_style(item: Button) -> void:
	var unit: float = float(metrics.get("unit", 1.0))
	item.add_theme_stylebox_override("normal", PlayfulTheme.button_style(GREEN, unit))
	item.add_theme_stylebox_override("hover", PlayfulTheme.button_style(GREEN.lightened(0.07), unit))
	item.add_theme_stylebox_override("pressed", PlayfulTheme.button_style(GREEN.darkened(0.07), unit, true))
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", INK)
	item.add_theme_color_override("font_pressed_color", INK)

func _apply_shell_geometry() -> void:
	var safe: Rect2 = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport_rect().size))
	for shell in [header, footer, welcome]:
		if not is_instance_valid(shell):
			continue
		shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
		shell.position = safe.position
		shell.size = safe.size

func panel_at(parent: Node, top: float, bottom: float, from_bottom: bool = false) -> PanelContainer:
	var panel = PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = 0
	panel.anchor_right = 1
	panel.anchor_top = 1 if from_bottom else 0
	panel.anchor_bottom = panel.anchor_top
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = top
	panel.offset_bottom = bottom
	panel.add_theme_stylebox_override("panel", style(CREAM))
	return panel

func icon(kind: String, dimensions: Vector2 = Vector2(32, 32)) -> Control:
	var item = Icon.new()
	item.kind = kind
	item.custom_minimum_size = dimensions
	item.size = dimensions
	return item

func art(kind: String, height: float = 138, seaside: bool = false) -> Control:
	var item = Art.new()
	item.kind = kind
	item.seaside = seaside
	item.custom_minimum_size.y = height
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func _build_chrome() -> void:
	header = Control.new()
	add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar = Control.new()
	bar.name = "HotelStatus"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(bar)
	var background = Panel.new()
	background.name = "HeaderPaper"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel",style(CREAM,18))
	var hotel_art = art("hotel",48)
	hotel_art.name = "HeaderHotelArt"
	bar.add_child(hotel_art)
	title_label = label("Meadow House",16)
	bar.add_child(title_label)
	level_label = label("Level 1 · 2 rooms",14,MUTED)
	bar.add_child(level_label)
	coins_label = label("1,000",16)
	bar.add_child(coins_label)
	rate_label = label("+10 / min",14,INK)
	bar.add_child(rate_label)
	var coin = icon("coin",Vector2(20,20))
	coin.name = "HeaderCoin"
	bar.add_child(coin)
	var settings = button("",func(): _open_settings())
	settings.name = "SettingsButton"
	settings.accessibility_name = "Settings"
	bar.add_child(settings)
	var cog = icon("settings",Vector2(28,28))
	cog.name = "SettingsIcon"
	settings.add_child(cog)
	activity_label = label("", 12, GREEN)
	header.add_child(activity_label)
	activity_label.hide()
	pending_button = button("Collect away earnings", func(): show_offline())
	header.add_child(pending_button)
	pending_button.position = Vector2(16, 118)
	pending_button.custom_minimum_size.y = 44
	pending_button.add_theme_font_size_override("font_size", 14)
	pending_button.visible = false
	footer = Control.new()
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective = panel_at(footer, -146, -99, true)
	objective_panel = objective
	var objective_style = style(CREAM, 14)
	objective_style.content_margin_top = 5
	objective_style.content_margin_bottom = 5
	objective_style.content_margin_left = 10
	objective_style.content_margin_right = 8
	objective.add_theme_stylebox_override("panel", objective_style)
	var objective_row = HBoxContainer.new()
	objective.add_child(objective_row)
	var texts = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	objective_row.add_child(texts)
	objective_label = label("A cozier hotel", 16)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(objective_label)
	progress_label = label("Open your next improvement", 14, MUTED)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(progress_label)
	objective_progress = ProgressBar.new()
	objective_progress.max_value = 2
	objective_progress.hide()
	texts.add_child(objective_progress)
	var next = button("›", _open_next_action)
	objective_button = next
	next.name = "NextHotelAction"
	next.tooltip_text = "Open your next hotel action"
	next.custom_minimum_size = Vector2(48,48)
	next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next.focus_mode = Control.FOCUS_NONE
	objective_row.add_child(next)
	# The whole card is the action; the chevron is only its visible cue.
	objective_button = button("",_open_next_action)
	objective_button.name = "ObjectiveCardAction"
	for state in ["normal","hover","pressed"]:
		objective_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	objective.add_child(objective_button)
	var navigation = panel_at(footer, -90, -12, true)
	dock_panel = navigation
	navigation.name = "HotelDock"
	navigation.add_theme_stylebox_override("panel", style(CREAM, 24, Color("fffced"), 2))
	var nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	navigation.add_child(nav)
	for name in DOCK:
		var n = button("", func(): _navigate(name))
		n.name = "Dock_" + name
		n.accessibility_name = name
		n.tooltip_text = name
		n.custom_minimum_size.y = 57
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(n)
		var col = VBoxContainer.new()
		n.add_child(col)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_top = 3
		col.offset_bottom = -2
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var drawing = icon(name, Vector2(30, 30))
		drawing.name = "DockIcon"
		drawing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(drawing)
		var caption = label(name, 12)
		caption.name = "DockCaption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(caption)
		nav_buttons[name] = n
	toast_label = label("", 15, CREAM)
	add_child(toast_label)
	toast_label.add_theme_stylebox_override("normal", style(INK, 18))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.anchor_right = 1
	toast_label.anchor_top = 1
	toast_label.anchor_bottom = 1
	toast_label.offset_left = 24
	toast_label.offset_right = -24
	toast_label.offset_top = -207
	toast_label.offset_bottom = -155
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	_build_welcome()
	_update_nav()

func _build_welcome() -> void:
	HomeViews.welcome(self)

func render(data: Dictionary) -> void:
	snapshot = data
	relayout()
	if not is_node_ready():
		return
	var started: bool = bool(data.get("started", false))
	header.visible = started and tab != "Build"
	footer.visible = started and tab != "Build"
	welcome.visible = not started
	if not started:
		var pre_key := str(data.get("settings",{})) + str(data.get("save_error",""))
		if state_key != pre_key:
			state_key = pre_key
			if tab == "Settings": _settings()
		return
	if tab == "Offline" and is_instance_valid(sheet):
		if data.get("pending",0)<=0: close_sheet()
		else: show_inline_error(data.get("save_error",""))
	elif tab in ["Settings","Upgrades"] and is_instance_valid(sheet):
		show_inline_error(data.get("save_error",""))
	coins_label.text = number(float(data.coins))
	rate_label.text = "+%s / min" % number(float(data.rate))
	title_label.text = data.hotel_name
	level_label.text = "Level %d · %d rooms" % [data.hotel_level,data.rooms]
	_layout_home()
	pending_button.visible = data.pending > 0
	var remaining: float = data.get("repair_remaining", 0)
	var action := next_action(data)
	objective_label.text = action.title
	progress_label.text = action.detail
	objective_button.accessibility_name = action.title
	if not _objective_layout_pending:
		_objective_layout_pending = true
		_settle_objective_layout.call_deferred()
	if is_instance_valid(repair_status):
		repair_status.text = "Construction cats at work · %ds left" % ceili(remaining)
	if is_instance_valid(repair_progress) and data.wings < 3:
		repair_progress.value = 100 * (1 - remaining / data.repair_seconds[data.wings])
	activity_label.text = "%d guest rooms  ·  %d / 3 wings built" % [data.rooms, data.wings]
	var new_key: String = str(data.get("repair_remaining", 0) > 0) + str(data.hotel) + str(data.wings) + str(data.levels) + str(data.owned) + str(data.cats_unlocked) + str(data.settings)
	if new_key != state_key:
		state_key = new_key
		if sheet != null and is_instance_valid(sheet) and tab in ["Upgrades", "Rooms", "Map", "Cats", "Settings"]:
			_refresh_sheet()
	for item in live_buttons:
		if not is_instance_valid(item.button):
			continue
		if item.kind == "upgrade":
			var zone: int = item.zone
			var cost: int = int(data.costs[zone])
			item.button.disabled = cost <= 0 or data.coins < cost or data.save_error != ""
			item.button.text = "Fully upgraded" if cost <= 0 else ("Upgrade  ·  ● %s" % number(cost) if data.coins >= cost else "Need %s more coins" % number(ceil(cost - data.coins)))
		elif item.kind == "expansion":
			var n: int = item.get("wing", data.wings)
			item.button.disabled = n != data.wings or not data.can_expand or data.save_error != ""
			if n < data.wings:
				item.button.text = "Open for guests"
			elif remaining > 0:
				item.button.text = "Repair in progress" if n == data.wings else "Finish the current repair first"
			elif n != data.wings:
				item.button.text = "Repair %s first" % data.wing_names[data.wings]
			elif data.hotel_level < data.wing_levels[n]:
				item.button.text = "Hotel level %d required" % data.wing_levels[n]
			elif data.coins < data.wing_costs[n]:
				item.button.text = "Save %s more coins" % number(ceil(data.wing_costs[n] - data.coins))
			else:
				item.button.text = "Repair · %s coins" % number(data.wing_costs[n])
		elif item.kind == "unlock":
			item.button.disabled = not data.can_unlock or data.save_error != ""
			item.button.text = "Open Seaside  ·  ● 10,000" if data.can_unlock else "Keep growing to unlock"

func number(value: float) -> String:
	var raw: String = str(int(floor(value)))
	var result: String = ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0:
			result += ","
		result += raw[i]
	return result

func parent_tab(route: String) -> String:
	if route in ["Cats", "Pet", "Invitations"]: return "Cats"
	if route in ["Life", "Events", "Staff", "Journal", "Discoveries", "Grounds", "Amenity", "Manager", "Kiosk"]: return "Life"
	if route in ["Map", "Shop"]: return "Map"
	if route == "Build": return "Build"
	return "Hotel"

func _navigate(destination: String) -> void:
	if destination == "Build":
		close_sheet()
		build_requested.emit()
		footer.hide()
		return
	if destination == "Hotel":
		close_sheet()
		return
	if destination == "Rooms": selected_wing = -1
	open_route(destination, "Hotel" if destination in DOCK else tab)

func open_route(route: String, parent_route: String = "Hotel") -> void:
	if route in ["Hotel", "Build"]:
		_navigate(route)
		return
	_remember_sheet()
	if route != tab:
		route_parents[route] = parent_route
		if route in DOCK:
			_route_history.assign(["Hotel"])
		elif parent_route == tab:
			_route_history.append(parent_route)
		else:
			_route_history.clear()
			if parent_route != "Hotel": _route_history.append("Hotel")
			_route_history.append(parent_route)
	tab = route
	_refresh_sheet()
	_update_nav()

func go_back() -> void:
	if tab == "Build": return # Main owns contextual Build cancellation.
	var destination: String = _route_history.pop_back() if not _route_history.is_empty() else "Hotel"
	_remember_sheet()
	if destination == "Hotel" or destination == tab or destination == "Build":
		close_sheet()
	else:
		tab = destination
		_refresh_sheet()
		_update_nav()

func _update_nav() -> void:
	var unit: float = metrics.get("unit", 1.0)
	for destination in nav_buttons:
		var selected: bool = parent_tab(tab) == destination
		var control: Button = nav_buttons[destination]
		control.accessibility_name = destination + (" · selected" if selected else "")
		for state in ["normal", "hover", "pressed"]:
			var fill: Color = GREEN if selected else (PlayfulTheme.CORAL.lightened(0.22) if destination == "Build" else Color.TRANSPARENT)
			var surface = PlayfulTheme.button_style(fill, unit, state == "pressed")
			surface.content_margin_left = 0
			surface.content_margin_right = 0
			control.add_theme_stylebox_override(state, surface)
		var drawing = control.find_child("DockIcon", true, false)
		if drawing != null:
			drawing.active = selected
			drawing.queue_redraw()
	if is_instance_valid(objective_panel): objective_panel.visible = not is_instance_valid(sheet)

func _layout_navigation() -> void:
	if not is_instance_valid(dock_panel): return
	var unit: float = metrics.unit
	var bounds: Rect2 = metrics.footer_rect
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.position = metrics.objective_rect.position - footer.position + Vector2(6,0) * unit
	objective_panel.size = metrics.objective_rect.size - Vector2(12,0) * unit
	if is_instance_valid(shade): shade.offset_bottom = bounds.position.y - size.y
	dock_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dock_panel.position = bounds.position - footer.position + Vector2(6, 2) * unit
	dock_panel.size = bounds.size - Vector2(12, 6) * unit
	var surface = PlayfulTheme.panel(CREAM, unit, 24)
	surface.content_margin_left = 5 * unit
	surface.content_margin_right = 5 * unit
	surface.content_margin_top = 4 * unit
	surface.content_margin_bottom = 4 * unit
	dock_panel.add_theme_stylebox_override("panel", surface)
	var settings = header.find_child("SettingsButton", true, false)
	if settings != null:
		settings.custom_minimum_size = Vector2(48, 48) * unit
		settings.set_meta(PHONE_BUTTON_UNIT_META, unit)
		var cog = settings.find_child("SettingsIcon", true, false)
		cog.custom_minimum_size = Vector2(28, 28) * unit
		cog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cog.offset_left = -14 * unit
		cog.offset_top = -14 * unit
		cog.offset_right = 14 * unit
		cog.offset_bottom = 14 * unit
	var nav = dock_panel.get_child(0)
	nav.add_theme_constant_override("separation", roundi(3 * unit))
	for control in nav_buttons.values():
		control.custom_minimum_size = Vector2(48, 64) * unit
		control.set_meta(PHONE_BUTTON_UNIT_META, unit)
		var drawing = control.find_child("DockIcon", true, false)
		drawing.custom_minimum_size = Vector2(30, 30) * unit
	_update_nav()

func open_upgrades(zone: int = 0) -> void:
	selected_zone = clampi(zone, 0, 3)
	zone_focus_requested.emit(selected_zone)
	open_route("Upgrades", tab)

func _remember_sheet() -> void:
	if not is_instance_valid(sheet): return
	var focused := get_viewport().gui_get_focus_owner()
	route_state[_sheet_route] = {"scroll": sheet.scroll.scroll_vertical, "focus": str(focused.name) if focused != null and sheet.is_ancestor_of(focused) else ""}

func _restore_sheet(target: Control, route: String) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	_pending_restore = {"target": weakref(target), "route": route, "frames": 3, "focus_id": focused.get_instance_id() if focused != null else 0}

# Count completed layout opportunities without keeping suspended calls alive on freed sheets.
func _advance_sheet_restore() -> void:
	if _pending_restore.is_empty(): return
	_pending_restore.frames -= 1
	if _pending_restore.frames > 0: return
	var pending := _pending_restore
	_pending_restore = {}
	var target = pending.target.get_ref()
	if not is_instance_valid(target) or target != sheet: return
	var route: String = pending.route
	var initial_focus_id: int = pending.focus_id
	target.relayout(_sheet_bounds())
	var saved: Dictionary = route_state.get(route, {})
	var focus_name: String = saved.get("focus", "")
	var focus_target = target.find_child(focus_name, true, false) if not focus_name.is_empty() else null
	var current_focus := get_viewport().gui_get_focus_owner()
	var current_focus_id: int = current_focus.get_instance_id() if current_focus != null else 0
	if current_focus_id == initial_focus_id:
		if focus_target is Control: focus_target.grab_focus()
		else: target.back.grab_focus()
	target.scroll.scroll_vertical = int(saved.get("scroll", 0))

func close_sheet() -> void:
	_remember_sheet()
	_dispose_sheet()
	_route_history.clear()
	tab = "Hotel"
	_update_nav()

func _dispose_sheet() -> void:
	_stop_feedback()
	inline_error = null
	_pending_restore.clear()
	for node in [shade, sheet]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	shade = null
	sheet = null
	sheet_content = null
	live_buttons.clear()

func _sheet_bounds() -> Rect2:
	var bounds: Rect2 = metrics.content_rect
	var unit: float = metrics.unit
	bounds.position.x += 8 * unit
	bounds.size.x -= 16 * unit
	var height: float = minf(_sheet_height * unit, bounds.size.y)
	bounds.position.y = bounds.end.y - height
	bounds.size.y = height
	return bounds

func _base_sheet(title: String, height: float = 525) -> VBoxContainer:
	_remember_sheet()
	_dispose_sheet()
	_sheet_route = tab
	_sheet_height = height
	shade = ColorRect.new()
	shade.name = "SheetShade"
	shade.color = Color(0.13, 0.20, 0.15, 0.20)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_bottom = metrics.footer_rect.position.y - size.y
	shade.gui_input.connect(func(event):
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			go_back()
	)
	sheet = GameSheet.new()
	add_child(sheet)
	sheet_content = sheet.configure(self, title, _sheet_bounds())
	sheet.back_requested.connect(go_back)
	_restore_sheet(sheet, tab)
	_update_nav()
	return sheet_content

func set_primary_action(text: String, callback: Callable, disabled: bool = false) -> Button:
	if not is_instance_valid(sheet): return null
	return sheet.set_primary(text, callback, disabled)

func _view() -> void:
	var content = _base_sheet("Your hotel view", 320)
	content.add_child(button("Hotel view", func(): close_sheet(); hotel_focus_requested.emit()))
	content.add_child(button("Fit the full hotel", func(): close_sheet(); reset_camera_requested.emit()))

func _refresh_sheet() -> void:
	if snapshot.is_empty():
		return
	match tab:
		"Upgrades": _upgrades()
		"Map": _map()
		"Rooms": _expansions()
		"Cats": _cats()
		"Settings": _settings()
		"View": _view()
		"Offline": HomeViews.offline(self)

func _upgrades() -> void:
	HomeViews.upgrades(self)

func _map() -> void:
	var content = _base_sheet("Your hotel journey", 650)
	content.add_child(paragraph("New places. Familiar paws. Every hotel you open keeps earning for you."))
	var subtitles = ["A garden full of small beginnings", "Salt air and sunlit window seats", "An autumn hideaway", "A cozy mountain escape"]
	for i in range(4):
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", style(Color("e8ecdc") if i == 0 else Color("e0ecea") if i == 1 else Color("ebe7de"), 16))
		content.add_child(card)
		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 7)
		card.add_child(col)
		col.add_child(art("hotel", 126, i == 1))
		col.add_child(label("%02d  %s" % [i + 1, snapshot.hotel_names[i]], 21))
		col.add_child(paragraph(subtitles[i], 13))
		if i < 2 and snapshot.owned[i]:
			col.add_child(label("OPEN  ·  +%d Cat Coins / min" % snapshot.hotel_rates[i], 12, GREEN))
			col.add_child(button("You're here" if i == snapshot.hotel else "Visit hotel  →", func():
				hotel_requested.emit(i)
				close_sheet()
			))
		elif i == 1:
			col.add_child(label("Meadow House level %d / 10" % snapshot.meadow_level, 13))
			col.add_child(label("Opening cost: 10,000 Cat Coins", 13, GOLD))
			var unlock = button("Keep growing to unlock", func(): hotel_requested.emit(1), true)
			unlock.name = "UnlockHotel"
			col.add_child(unlock)
			live_buttons.append({"button": unlock, "kind": "unlock"})
		else:
			col.add_child(label("COMING LATER", 12, MUTED))
	render(snapshot)

func _cats() -> void:
	var content = _base_sheet("Your little regulars", 620)
	content.add_child(paragraph("%d / 12 guests discovered. Improve your hotels to meet more travelers." % snapshot.cats_unlocked))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for i in range(12):
		var card = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var portrait = Badge.new()
		portrait.custom_minimum_size = Vector2(140, 105)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.locked = i >= snapshot.cats_unlocked
		portrait.coat = [Color("d99c51"), Color("999e93"), Color("343e35"), Color("e3d5b9")][i % 4]
		card.add_child(portrait)
		card.add_child(label(snapshot.cat_names[i] if not portrait.locked else "A future friend", 16))
		card.add_child(label(snapshot.cat_traits[i] if not portrait.locked else "Keep upgrading", 12, MUTED))

func _open_settings() -> void:
	open_route("Settings", tab)

func _settings() -> void:
	HomeViews.settings(self)

func show_offline() -> void:
	if snapshot.get("pending",0)<=0: return
	tab = "Offline"
	HomeViews.offline(self)

func duration(seconds: int) -> String:
	return "%dh %dm" % [int(seconds / 3600), int(seconds / 60) % 60] if seconds >= 3600 else "%dm" % maxi(1, int(seconds / 60))

func show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_label.move_to_front()
	toast_timer = 3.5
	_layout_toast()

func _process(delta: float) -> void:
	_advance_sheet_restore()
	var viewport: Vector2 = get_viewport_rect().size
	var safe: Rect2 = BuildMetrics.safe_area(self)
	var phone_scale: float = BuildMetrics.phone_scale(self)
	var text_scale: float = float(snapshot.get("settings", {}).get("ui_text_scale", 1.0))
	var current_key := str(viewport) + str(safe) + str(phone_scale) + str(text_scale)
	if current_key != _metrics_key:
		relayout()
	if toast_timer > 0:
		toast_timer -= delta
		toast_label.visible = toast_timer > 0

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and tab != "Build":
		get_viewport().set_input_as_handled()
		go_back()



func open_expansions(wing: int = -1) -> void:
	selected_wing = wing
	open_route("Rooms", tab)

func _expansions() -> void:
	var n: int = clampi(selected_wing if selected_wing >= 0 else snapshot.wings, 0, 2)
	var content = _base_sheet(snapshot.wing_names[n], 365)
	content.add_child(paragraph("Restore this part of your hotel with a little help from the construction cats."))
	content.add_child(label("30 building tiles · +%d coins / min" % snapshot.wing_rates[n], 21, GREEN))
	if n < snapshot.wings:
		content.add_child(paragraph("Repaired and ready to design. Open Build to place regular rooms or suites on this floor."))
	elif n == snapshot.wings and snapshot.get("repair_remaining", 0) > 0:
		repair_status = label("Construction cats at work", 18)
		content.add_child(repair_status)
		repair_progress = ProgressBar.new()
		repair_progress.custom_minimum_size.y = 16
		repair_progress.show_percentage = false
		content.add_child(repair_progress)
		content.add_child(paragraph("You can keep playing or close the game. Your builders will finish the job.", 14))
	else:
		content.add_child(paragraph("%s Cat Coins · %ds repair · Hotel level %d" % [number(snapshot.wing_costs[n]), snapshot.repair_seconds[n], snapshot.wing_levels[n]], 14))
		var build = button("Repair wing", func(): expansion_requested.emit(), true)
		build.name = "BuildExpansion"
		content.add_child(build)
		live_buttons.append({"button":build, "kind":"expansion", "wing":n})
		if snapshot.hotel_level < snapshot.wing_levels[n]:
			content.add_child(button("Improve services to level up", func(): open_upgrades(0)))
	var chooser = HBoxContainer.new()
	chooser.add_theme_constant_override("separation", 6)
	content.add_child(chooser)
	for i in range(3):
		var choice = button(["Garden", "Courtyard", "Skyview"][i], func(): open_expansions(i))
		choice.custom_minimum_size.y = 44
		choice.add_theme_font_size_override("font_size", 14)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chooser.add_child(choice)
	render(snapshot)

func world_input_contains(point: Vector2) -> bool:
	return metrics.get("world_rect",Rect2()).has_point(point)

func _layout_home() -> void:
	if not is_instance_valid(header): return
	var unit: float = metrics.unit
	var large: bool = metrics.font_scale>1.0
	var bar: Control = header.find_child("HotelStatus",true,false)
	bar.position = metrics.header_rect.position-header.position+Vector2(6,2)*unit
	bar.size = metrics.header_rect.size-Vector2(12,4)*unit
	var available: float = bar.size.x/unit
	var art_node: Control = bar.find_child("HeaderHotelArt",true,false)
	var show_art: bool = not large and available>=370
	art_node.visible = show_art
	art_node.position = Vector2(4,4)*unit
	art_node.size = Vector2(48,48)*unit
	var left: float = 58 if show_art else 10
	var gear: Control = bar.find_child("SettingsButton",true,false)
	gear.position = Vector2(available-54,4)*unit
	gear.custom_minimum_size = Vector2.ONE*float(metrics.target)
	gear.size = Vector2.ONE*float(metrics.target)
	var coin: Control = bar.find_child("HeaderCoin",true,false)
	if large:
		title_label.position = Vector2(10,2)*unit
		level_label.position = Vector2(10,34)*unit
		coin.position = Vector2(10,77)*unit
		coins_label.position = Vector2(36,72)*unit
		rate_label.position = Vector2(available-10-rate_label.get_minimum_size().x/unit,75)*unit
	else:
		title_label.position = Vector2(left,4)*unit
		level_label.position = Vector2(left,29)*unit
		var wallet_x: float = available-62-maxf(coins_label.get_minimum_size().x,rate_label.get_minimum_size().x)/unit
		coins_label.position = Vector2(wallet_x,4)*unit
		rate_label.position = Vector2(wallet_x,29)*unit
		coin.position = Vector2(wallet_x-23,6)*unit
	coin.size = Vector2(20,20)*unit
	for item in [title_label,level_label,coins_label,rate_label]: item.size = item.get_minimum_size()
	pending_button.position = Vector2(12,metrics.header_rect.size.y+8*unit)
	pending_button.size = Vector2(metrics.safe_rect.size.x-24*unit,48*unit)
	if is_instance_valid(welcome):
		var illustration: Control = welcome.find_child("WelcomeArt",true,false)
		if illustration != null: illustration.custom_minimum_size.y = minf((welcome.size.x-32*unit)/1.5,260*unit)
	_layout_toast()

func show_inline_error(message: String) -> void:
	if not is_instance_valid(sheet): return
	if not is_instance_valid(inline_error):
		inline_error = paragraph("",16,Color("9C3F3F"))
		inline_error.name = "InlineError"
		inline_error.add_theme_stylebox_override("normal",style(Color("FFF0EC"),12))
		sheet._column.add_child(inline_error)
		sheet._column.move_child(inline_error,sheet.primary.get_index())
	inline_error.text = "! " + message if message!="" else ""
	inline_error.visible = message!=""
	if tab == "Settings":
		var status = sheet.find_child("SaveStatus",true,false)
		if status != null: status.text = "Changes could not be saved." if message!="" else ("Saved on this device." if snapshot.get("started",false) else "Preferences will save when you open your hotel.")

func _layout_toast() -> void:
	if not is_instance_valid(toast_label): return
	var unit: float = metrics.unit
	var safe: Rect2 = metrics.safe_rect
	toast_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast_label.size.x = safe.size.x-32*unit
	var height: float = maxf(48*unit,toast_label.get_minimum_size().y)
	var bottom: float = metrics.objective_rect.position.y-8*unit
	if is_instance_valid(sheet):
		bottom = sheet.primary.global_position.y-8*unit if sheet.primary.visible else sheet.get_global_rect().end.y-12*unit
	toast_label.position = Vector2(safe.position.x+16*unit,maxf(safe.position.y,bottom-height))
	toast_label.size.y = height

func _stop_feedback() -> void:
	if feedback_tween != null and feedback_tween.is_valid(): feedback_tween.kill()
	feedback_tween = null
	if is_instance_valid(feedback_icon): feedback_icon.queue_free()
	feedback_icon = null
	if is_instance_valid(sheet): sheet.modulate = Color.WHITE

func success_feedback(kind: String) -> void:
	success_count += 1
	_stop_feedback()
	if not snapshot.get("settings",{}).get("motion",true): return
	feedback_icon = icon("heart" if kind in ["purr","toy"] else "coin",Vector2(32,32)*float(metrics.unit))
	feedback_icon.name = "SuccessReaction"
	add_child(feedback_icon)
	var origin: Vector2 = metrics.objective_rect.position + Vector2(metrics.objective_rect.size.x/2,0)
	if is_instance_valid(sheet): origin = sheet.primary.global_position+Vector2(sheet.primary.size.x/2,-32*float(metrics.unit))
	feedback_icon.position = origin
	feedback_tween = create_tween().set_parallel(true)
	feedback_tween.tween_property(feedback_icon,"position",origin-Vector2(0,16)*float(metrics.unit),0.18)
	feedback_tween.tween_property(feedback_icon,"modulate:a",0.0,0.18)
	if is_instance_valid(sheet):
		sheet.modulate = Color("E3F3E9")
		feedback_tween.tween_property(sheet,"modulate",Color.WHITE,0.18)
	feedback_tween.chain().tween_callback(_stop_feedback)

func _settle_objective_layout() -> void:
	# Autowrapped labels initially shape at zero width. Refit once the row has its real width.
	await get_tree().process_frame
	await get_tree().process_frame
	_objective_layout_pending = false
	_layout_navigation()

func next_action(data: Dictionary) -> Dictionary:
	if data.get("pending",0) > 0:
		return {"title":"Your cats earned coins!","detail":"Collect %s Cat Coins" % number(data.pending),"route":"Offline","payload":{}}
	var grounds: Dictionary = data.get("grounds",{})
	if not grounds.is_empty():
		var job: Dictionary = grounds.hotels[data.hotel].job
		if not job.is_empty():
			return {"title":"Your manager is helping","detail":"%s · %ds left" % [str(job.kind).capitalize(),ceili(maxf(0,job.duration-job.elapsed))],"route":"Manager","payload":{}}
	if data.get("repair_remaining",0) > 0:
		return {"title":"A new wing is on its way","detail":"Construction cats · %ds left" % ceili(data.repair_remaining),"route":"Rooms","payload":{"wing":data.wings}}
	var pinned: String = data.get("life",{}).get("pinned","")
	if pinned != "":
		for combo in preload("res://scripts/core/game_content.gd").COMBOS:
			if combo.id != pinned: continue
			var count: int = 0
			for furnishings in data.get("room_furnishings",[]):
				count = maxi(count,combo.items.filter(func(item): return furnishings.has(item)).size())
			return {"title":combo.name,"detail":"%d / %d together in one room" % [count,combo.items.size()],"route":"Discoveries","payload":{"id":pinned}}
	var costs: Array = data.get("costs",[])
	if not costs.is_empty():
		var zone: int = -1
		for index in range(costs.size()):
			if costs[index] > 0 and (zone == -1 or costs[index] < costs[zone]): zone = index
		if zone == -1: return {"title":"Every service feels like home","detail":"Spend a moment with your cats","route":"Cats","payload":{}}
		var shortfall: int = maxi(0,ceili(costs[zone]-data.coins))
		return {"title":"A cozier %s" % str(data.zone_names[zone]).to_lower(),"detail":"%s more Cat Coins" % number(shortfall) if shortfall > 0 else "Upgrade · %s Cat Coins" % number(costs[zone]),"route":"Upgrades","payload":{"zone":zone}}
	return {"title":"Welcome home","detail":"Find your next cozy improvement","route":"Life","payload":{}}

func _open_next_action() -> void:
	var action := next_action(snapshot)
	match action.route:
		"Upgrades": open_upgrades(int(action.payload.zone))
		"Rooms": open_expansions(int(action.payload.wing))
		"Offline": show_offline()
		_: open_route(action.route,"Hotel")
