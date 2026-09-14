extends VBoxContainer
## Catalogue presentation only; choosing a card never edits ownership or spends coins.
signal item_selected(item: String, uid: String)
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Thumbnail = preload("res://scripts/ui/furniture_thumbnail.gd")
const PlayfulTheme = preload("res://scripts/ui/playful_theme.gd")
var _entries: Array = []
var _entries_by_key: Dictionary = {}
var _affordable_only: bool = false
var _grid: GridContainer
var _empty_state: Label

func populate(ui, model, hotel: int, category: String, target: float, text_scale: float, affordable: bool = false, sort_by: String = "price", available: float = -1) -> void:
	for child in get_children(): child.queue_free()
	name = "FurnitureCatalogue"
	_entries.clear()
	_entries_by_key.clear()
	_affordable_only = affordable
	var items: Array = []
	if category=="storage":
		for instance in model.furniture.stored_items():
			var definition: Dictionary = Catalog.item(instance.item)
			definition["uid"] = instance.uid
			items.append(definition)
	else:
		for definition in Catalog.all_items():
			var group: String = "sleep" if definition.provides_sleep or definition.family=="seating" else ("play" if definition.interactive else "decor")
			if group==category: items.append(definition)
	var balance: float = model.coins if available<0 else available
	items.sort_custom(func(a,b):
		var a_locked: bool = model.hotel_level(hotel)<a.level or (a.bond>0 and not model.furniture.state.legacy_reuse.has(a.id))
		var b_locked: bool = model.hotel_level(hotel)<b.level or (b.bond>0 and not model.furniture.state.legacy_reuse.has(b.id))
		if a_locked!=b_locked: return not a_locked
		if sort_by in ["comfort","entertainment","atmosphere"] and a.stats[sort_by]!=b.stats[sort_by]: return a.stats[sort_by]>b.stats[sort_by]
		if int(a.cost)!=int(b.cost): return int(a.cost)<int(b.cost)
		return str(a.name)<str(b.name)
	)
	var unit: float = target/48.0
	_grid = GridContainer.new()
	_grid.name = "FurnitureGrid"
	_grid.columns = 1 if text_scale/unit>=1.5 else 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",roundi(10*unit))
	_grid.add_theme_constant_override("v_separation",roundi(10*unit))
	add_child(_grid)
	for definition in items:
		var uid: String = definition.get("uid","")
		var free: bool = uid!="" or model.furniture.state.legacy_reuse.has(definition.id)
		var price: int = 0 if free else int(definition.cost)
		var locked: bool = model.hotel_level(hotel)<definition.level or (definition.bond>0 and not free)
		var item_id: String = str(definition.id)
		var stored_uid: String = uid
		var card: Button = ui.button("",func(): item_selected.emit(item_id,stored_uid))
		card.name = "FurnitureCard_"+(uid if uid!="" else item_id)
		card.custom_minimum_size = Vector2(126*unit,(172 if _grid.columns==1 else 156)*unit)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("normal",PlayfulTheme.button_style(PlayfulTheme.CREAM,unit))
		card.add_theme_stylebox_override("hover",PlayfulTheme.button_style(PlayfulTheme.CREAM.lightened(0.04),unit))
		card.add_theme_stylebox_override("pressed",PlayfulTheme.button_style(PlayfulTheme.MINT,unit,true))
		card.add_theme_stylebox_override("focus",PlayfulTheme.focus_style(unit))
		card.tooltip_text = "Comfort %d · Entertainment %d · Atmosphere %d" % [definition.stats.comfort,definition.stats.entertainment,definition.stats.atmosphere]
		_grid.add_child(card)
		var body = VBoxContainer.new()
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.offset_left=8*unit; body.offset_top=8*unit; body.offset_right=-8*unit; body.offset_bottom=-8*unit
		body.mouse_filter=Control.MOUSE_FILTER_IGNORE
		body.add_theme_constant_override("separation",roundi(3*unit))
		card.add_child(body)
		var art_center = CenterContainer.new()
		art_center.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art_center.size_flags_vertical=Control.SIZE_EXPAND_FILL
		body.add_child(art_center)
		var thumbnail = Thumbnail.new()
		thumbnail.name = "FurnitureArt"
		thumbnail.item_id = definition.id
		thumbnail.custom_minimum_size = Vector2.ONE*(84 if _grid.columns==1 else 76)*unit
		art_center.add_child(thumbnail)
		var price_copy: String = "Stored · Free" if uid!="" else ("Free reuse" if free else "%d coins each" % price)
		if locked: price_copy = "Friendship 20 gift" if definition.bond>0 else "Hotel level %d" % definition.level
		var title: Label = ui.canvas_paragraph(str(definition.name),roundi(16*text_scale),PlayfulTheme.INK)
		title.name="FurnitureName"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.max_lines_visible=2
		body.add_child(title)
		var price_label: Label = ui.canvas_paragraph(price_copy,roundi(14*text_scale),PlayfulTheme.SECONDARY_INK)
		price_label.name="FurniturePrice"; price_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; price_label.max_lines_visible=2
		body.add_child(price_label)
		var entry: Dictionary={"button":card,"price_label":price_label,"definition":definition,"uid":uid,"free":free,"locked":locked,"price":price}
		_entries.append(entry)
		_entries_by_key[("stored:"+uid) if uid!="" else ("item:"+item_id)]=entry
	_empty_state=ui.canvas_paragraph("No stored furniture yet. Store an object from a room to reuse it here." if category=="storage" else "No items match this filter. Try showing all items.",roundi(16*text_scale))
	_empty_state.name="FurnitureEmptyState"
	add_child(_empty_state)
	update_availability(balance)

func update_availability(available: float) -> void:
	var visible_count: int=0
	for entry in _entries:
		if not is_instance_valid(entry.price_label): continue
		var definition: Dictionary=entry.definition
		var unavailable: bool=entry.locked or (not entry.free and entry.uid=="" and float(entry.price)>available)
		var copy: String
		if entry.locked:
			copy="Friendship 20 gift" if int(definition.bond)>0 else "Hotel level %d" % int(definition.level)
		elif entry.uid!="": copy="Stored · Free"
		elif entry.free: copy="Free reuse"
		elif float(entry.price)>available: copy="Need %d more · %d coins" % [ceili(float(entry.price)-available),int(entry.price)]
		else: copy="%d coins" % int(entry.price)
		entry.price_label.text=copy
		entry.price_label.add_theme_color_override("font_color",PlayfulTheme.ERROR_INK if unavailable else PlayfulTheme.SECONDARY_INK)
		entry.button.accessibility_description=copy
		entry.button.modulate=Color(1,1,1,0.78) if unavailable else Color.WHITE
		entry.button.visible=not _affordable_only or not unavailable
		if entry.button.visible: visible_count+=1
	if is_instance_valid(_grid): _grid.visible=visible_count>0
	if is_instance_valid(_empty_state): _empty_state.visible=visible_count==0
