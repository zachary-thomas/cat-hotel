extends VBoxContainer
## Catalogue presentation only; choosing a card never edits ownership or spends coins.
signal item_selected(item: String, uid: String)
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Thumbnail = preload("res://scripts/ui/furniture_thumbnail.gd")

func populate(ui, model, hotel: int, category: String, target: float, text_scale: float, affordable: bool = false, sort_by: String = "price", available: float = -1) -> void:
	for child in get_children(): child.queue_free()
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
	var count: int = 0
	for definition in items:
		var uid: String = definition.get("uid","")
		var free: bool = uid!="" or model.furniture.state.legacy_reuse.has(definition.id)
		var price: int = 0 if free else int(definition.cost)
		var locked: bool = model.hotel_level(hotel)<definition.level or (definition.bond>0 and not free)
		if affordable and (price>balance or locked): continue
		count += 1
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		add_child(row)
		var thumbnail = Thumbnail.new()
		thumbnail.item_id = definition.id
		thumbnail.custom_minimum_size = Vector2(target,target)
		row.add_child(thumbnail)
		var price_copy: String = "Stored · Free" if uid!="" else ("Free reuse" if free else "%d coins each" % price)
		if locked: price_copy = "Friendship 20 gift" if definition.bond>0 else "Hotel level %d" % definition.level
		var label: String = "%s\n%s · %d × %d" % [definition.name,price_copy,definition.footprint.x,definition.footprint.y]
		var button: Button = ui.button(label,func(): item_selected.emit(definition.id,uid))
		button.name = "FurnitureCard_"+(uid if uid!="" else str(definition.id))
		button.custom_minimum_size = Vector2(target,target+16*text_scale)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",roundi(16*text_scale))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "Comfort %d · Entertainment %d · Atmosphere %d" % [definition.stats.comfort,definition.stats.entertainment,definition.stats.atmosphere]
		row.add_child(button)
		var effects: Label = ui.paragraph("Comfort %d · Play %d · Atmosphere %d" % [definition.stats.comfort,definition.stats.entertainment,definition.stats.atmosphere],roundi(14*text_scale))
		add_child(effects)
	if count==0:
		add_child(ui.paragraph("No stored furniture yet. Store an object from a room to reuse it here." if category=="storage" else "No items match this filter. Try showing all items.",roundi(16*text_scale)))
