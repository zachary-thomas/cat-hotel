extends VBoxContainer
## Derived room totals and actual makeover deltas, never raw item promises.
const PlayfulTheme = preload("res://scripts/ui/playful_theme.gd")
const AXES = ["comfort","entertainment","atmosphere"]
const LABELS = ["Comfort","Entertainment","Atmosphere"]
func populate(ui, before: Dictionary, after: Dictionary, text_scale: float = 1.0, compact: bool = false) -> void:
	name="SelectedFurnitureStats" if compact else "RoomStats"
	add_theme_constant_override("separation",roundi(2*text_scale))
	for child in get_children(): child.queue_free()
	for index in range(3):
		var axis: String = AXES[index]
		var old: int = int(before.get(axis,0))
		var value: int = int(after.get(axis,0))
		var delta: int = value-old
		var row = HBoxContainer.new()
		add_child(row)
		var label: Label = ui.canvas_label(LABELS[index],ceili((14 if compact else 16)*text_scale),PlayfulTheme.SECONDARY_INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var numbers: Label = ui.canvas_label(str(value) if delta==0 else "%d → %d (%+d)" % [old,value,delta],ceili((14 if compact else 16)*text_scale),PlayfulTheme.INK if delta>=0 else PlayfulTheme.ERROR_INK)
		numbers.name = "Stat_"+axis
		row.add_child(numbers)
		if compact: continue
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.value = value
		bar.custom_minimum_size.y = 7
		var background := StyleBoxFlat.new(); background.bg_color=PlayfulTheme.GOLD.lightened(0.55)
		var fill := StyleBoxFlat.new(); fill.bg_color=PlayfulTheme.MINT
		bar.add_theme_stylebox_override("background",background)
		bar.add_theme_stylebox_override("fill",fill)
		add_child(bar)
	if compact: return
	var quality: int = after.get("quality",0)
	var mood: String = "Simple" if quality<25 else ("Inviting" if quality<50 else ("Lovely" if quality<75 else "Exceptional"))
	add_child(ui.canvas_paragraph("%s · Room quality %d/100\nFurnishing quality income +%d coins/min" % [mood,quality,after.get("income",0)],ceili(14*text_scale)))
