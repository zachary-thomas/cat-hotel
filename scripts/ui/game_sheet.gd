extends PanelContainer
## Native sheet: the title and primary action stay still while only the body scrolls.
signal back_requested
var scroll: ScrollContainer
var primary: Button
var back: Button
var body: VBoxContainer
var _ui: Control
var _column: VBoxContainer
var _heading: HBoxContainer
var _callback: Callable

func configure(ui: Control, title: String, bounds: Rect2) -> VBoxContainer:
	_ui = ui
	name = "ActiveSheet"
	clip_contents = false
	_column = VBoxContainer.new()
	add_child(_column)
	_heading = HBoxContainer.new()
	_column.add_child(_heading)
	back = ui.button("‹", func(): back_requested.emit())
	back.name = "SheetBack"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.accessibility_name = "Back"
	back.tooltip_text = "Back"
	_heading.add_child(back)
	var title_label: Label = ui.label(title, 24)
	title_label.name = "SheetTitle"
	# Seed the wrapping width before container layout computes its minimum height.
	title_label.size.x = maxf(48, bounds.size.x - 88 * float(ui.metrics.unit))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_child(title_label)
	scroll = ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.clip_contents = true
	_column.add_child(scroll)
	body = VBoxContainer.new()
	body.name = "SheetBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	primary = ui.button("Continue", func(): pass, true)
	primary.name = "SheetPrimary"
	primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary.hide()
	_column.add_child(primary)
	relayout(bounds)
	return body

func set_primary(text: String, callback: Callable, disabled: bool = false) -> Button:
	# Replace the previous action so repeated configuration never stacks callbacks.
	if _callback.is_valid() and primary.pressed.is_connected(_callback):
		primary.pressed.disconnect(_callback)
	_callback = callback
	if _callback.is_valid(): primary.pressed.connect(_callback)
	primary.text = text
	primary.accessibility_name = text + (" · unavailable" if disabled else "")
	primary.disabled = disabled
	primary.show()
	return primary

func relayout(bounds: Rect2) -> void:
	var unit: float = _ui.metrics.get("unit", 1.0)
	position = bounds.position
	size = bounds.size
	add_theme_stylebox_override("panel", _ui.PlayfulTheme.panel(_ui.CREAM, unit, 24))
	_column.add_theme_constant_override("separation", roundi(12 * unit))
	_heading.add_theme_constant_override("separation", roundi(8 * unit))
	body.add_theme_constant_override("separation", roundi(12 * unit))
