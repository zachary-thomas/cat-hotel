extends Button
## The complete illustrated card is one focusable, accessible action.
var _ui: Control
var _column: VBoxContainer
func configure(ui: Control, title: String, detail: String, art: Control, callback: Callable) -> void:
	_ui = ui
	name = "Tile_" + title.validate_node_name().replace(" ", "_")
	accessibility_name = title + (" · " + detail if not detail.is_empty() else "") + " · Open"
	tooltip_text = title
	custom_minimum_size = Vector2(48, 48) * float(ui.metrics.get("unit", 1.0))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_column.add_child(art)
	var heading: Label = ui.label(title, 17)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(heading)
	if not detail.is_empty():
		var copy: Label = ui.paragraph(detail, 16)
		copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(copy)
	_ignore_children(_column)
	pressed.connect(func(): ui.ui_sound_requested.emit(); callback.call())
	resized.connect(_layout)
	_column.minimum_size_changed.connect(_layout)
	_layout()
func _ignore_children(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _ignore_children(child)
func _layout() -> void:
	if _column == null: return
	var unit: float = _ui.metrics.get("unit", 1.0)
	_column.add_theme_constant_override("separation", roundi(8 * unit))
	_column.position = Vector2(12, 12) * unit
	_column.size.x = maxf(0, size.x - 24 * unit)
	custom_minimum_size.y = maxf(48 * unit, _column.get_combined_minimum_size().y + 24 * unit)
