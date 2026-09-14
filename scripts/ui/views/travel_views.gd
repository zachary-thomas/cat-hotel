extends RefCounted

const Content = preload("res://scripts/core/game_content.gd")
const MenuArt = preload("res://scripts/ui/menu_art.gd")
const HOTEL_ART := ["hotel_meadow", "hotel_seaside", "hotel_forest", "hotel_snowcap"]
const HOTEL_CENTERS := [Vector2(0.27, 0.70), Vector2(0.79, 0.48), Vector2(0.30, 0.29), Vector2(0.74, 0.12)]

static func _card(ui: Control, parent: Control, tint: Color = Color("FFF8E9")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.PlayfulTheme.panel(tint, ui.metrics.unit, 20))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8 * ui.metrics.unit))
	panel.add_child(column)
	return column

static func map(ui: Control) -> void:
	var content: VBoxContainer = ui._base_sheet("Hotel journey" if ui.metrics.font_scale>1.0 else "Your hotel journey", 650)
	if ui.metrics.font_scale >= 1.5:
		var list := VBoxContainer.new()
		list.name = "DestinationList"
		list.add_theme_constant_override("separation", roundi(8 * ui.metrics.unit))
		content.add_child(list)
		for index in range(4):
			list.add_child(_list_destination(ui, index))
	else:
		var stage := Control.new()
		stage.name = "MapStage"
		stage.custom_minimum_size.y = 204 * ui.metrics.unit
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.clip_contents = true
		content.add_child(stage)
		var illustration: Control = ui.art("world_map", 204 * ui.metrics.unit)
		illustration.name = "MapArt"
		stage.add_child(illustration)
		illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pins: Array[Button] = []
		for i in range(4):
			var index: int = i
			var pin: Button = ui.button(_pin_text(ui, index), func(): _select(ui, index))
			pin.name = "Destination_" + str(index)
			pin.tooltip_text = ui.snapshot.hotel_names[index]
			pin.accessibility_name = ui.snapshot.hotel_names[index] + " · " + _destination_status(ui, index)
			pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pin.clip_text = false
			pin.set_meta(ui.PHONE_FONT_META, 14)
			pin.add_theme_font_size_override("font_size", ui._scaled_font_size(14))
			pin.custom_minimum_size = Vector2(144, 56) * ui.metrics.unit
			pin.size = pin.custom_minimum_size
			var fill: Color = ui.GREEN if index == ui.selected_destination else (ui.GOLD if ui.snapshot.owned[index] else ui.CREAM)
			pin.add_theme_stylebox_override("normal", ui.PlayfulTheme.button_style(fill, ui.metrics.unit))
			stage.add_child(pin)
			pins.append(pin)
		stage.resized.connect(func(): _position_pins(stage, pins, ui.metrics.unit))
		_position_pins.call_deferred(stage, pins, ui.metrics.unit)
	_add_destination_details(ui, ui.selected_destination)

static func _position_pins(stage: Control, pins: Array[Button], unit: float) -> void:
	if not is_instance_valid(stage) or stage.size.x <= 0 or stage.size.y <= 0:
		return
	var source := MenuArt.texture("world-map").get_size()
	var fit := minf(stage.size.x / source.x, stage.size.y / source.y)
	var drawn := source * fit
	var origin := (stage.size - drawn) * 0.5
	for i in range(pins.size()):
		if is_instance_valid(pins[i]):
			pins[i].size = Vector2(144, 56) * unit
			var center: Vector2 = origin + HOTEL_CENTERS[i] * drawn
			var x: float = 0.0 if HOTEL_CENTERS[i].x < 0.5 else stage.size.x - pins[i].size.x
			pins[i].position = Vector2(x, clampf(center.y-pins[i].size.y/2, 0, stage.size.y-pins[i].size.y))

static func _pin_text(ui: Control, index: int) -> String:
	var state: String
	if ui.snapshot.owned[index]: state = "Here" if index == ui.snapshot.hotel else "Open"
	elif index == 1: state = "Ready" if ui.snapshot.can_unlock else "Locked"
	else: state = "Expansion"
	return ui.snapshot.hotel_names[index] + "\n" + state

static func _list_destination(ui: Control, index: int) -> Button:
	var choice: Button = ui.button("", func(): _select(ui, index))
	choice.name = "Destination_" + str(index)
	choice.accessibility_name = ui.snapshot.hotel_names[index] + " · " + _destination_status(ui, index)
	choice.custom_minimum_size.y = 104 * ui.metrics.unit
	choice.clip_contents = true
	if index == ui.selected_destination:
		choice.add_theme_stylebox_override("normal", ui.PlayfulTheme.button_style(ui.GREEN, ui.metrics.unit))
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(row)
	var picture: Control = ui.art(HOTEL_ART[index], 64 * ui.metrics.unit)
	picture.name = "DestinationArt_" + str(index)
	picture.custom_minimum_size.x = 72 * ui.metrics.unit
	picture.size = Vector2(72, 64) * ui.metrics.unit
	row.add_child(picture)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var heading: Label = ui.label(ui.snapshot.hotel_names[index], 17)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(heading)
	var status: Label = ui.paragraph(_destination_status(ui, index))
	status.name = "DestinationStatus_" + str(index)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(status)
	choice.resized.connect(func(): _layout_list_destination(choice, row, picture, copy, ui.metrics.unit))
	copy.minimum_size_changed.connect(func(): _layout_list_destination(choice, row, picture, copy, ui.metrics.unit))
	_layout_list_destination.call_deferred(choice, row, picture, copy, ui.metrics.unit)
	return choice

static func _layout_list_destination(choice: Button, row: Control, picture: Control, copy: VBoxContainer, unit: float) -> void:
	if not is_instance_valid(choice) or not is_instance_valid(copy): return
	var inset := Vector2(12, 8) * unit
	row.position = inset
	row.size.x = maxf(0, choice.size.x - inset.x * 2)
	picture.size = Vector2(72, 64) * unit
	copy.position = Vector2(84 * unit, 0)
	copy.size.x = maxf(0, row.size.x - copy.position.x)
	var content_height: float = maxf(picture.size.y, copy.get_combined_minimum_size().y)
	var required_height: float = maxf(104 * unit, content_height + inset.y * 2)
	if not is_equal_approx(choice.custom_minimum_size.y, required_height):
		choice.custom_minimum_size.y = ceilf(required_height)
	row.size.y = maxf(content_height, choice.size.y - inset.y * 2)
	picture.position = Vector2(0, maxf(0, (row.size.y - picture.size.y) / 2))
	copy.size.y = row.size.y

static func _select(ui: Control, index: int) -> void:
	ui.selected_destination = index
	map(ui)
	var selected: Control = ui.sheet.find_child("Destination_" + str(index), true, false)
	if ui.metrics.font_scale>1.0:
		ui._pending_restore["reveal"] = "DestinationDetails"
	elif selected != null:
		selected.grab_focus.call_deferred()

static func _destination_status(ui: Control, index: int) -> String:
	if ui.snapshot.owned[index]:
		return "Current hotel" if index == ui.snapshot.hotel else "Open"
	if index == 1:
		return ("Ready" if ui.snapshot.can_unlock else "Locked") + " · Meadow level %d of 10 · %s of 10,000 coins" % [ui.snapshot.meadow_level, ui.number(ui.snapshot.coins)]
	return "Expansion"

static func _add_destination_details(ui: Control, index: int) -> void:
	# Enlarged text keeps destination details in the scroll body; the action remains pinned.
	var scroll_details: bool = ui.metrics.font_scale > 1.0
	var details := _card(ui, ui.sheet_content if scroll_details else ui.sheet._column, Color("FFF1D6") if index == 1 else ui.CREAM)
	var panel: PanelContainer = details.get_parent()
	if not scroll_details: ui.sheet._column.move_child(panel, ui.sheet.primary.get_index())
	details.name = "DestinationDetails"
	if scroll_details:
		details.focus_mode = Control.FOCUS_ALL
		details.accessibility_name = ui.snapshot.hotel_names[index]+" details"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(12 * ui.metrics.unit))
	details.add_child(row)
	if ui.metrics.font_scale < 1.5:
		var postcard: Control = ui.art(HOTEL_ART[index], 64 * ui.metrics.unit)
		postcard.custom_minimum_size.x = 76 * ui.metrics.unit
		postcard.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(postcard)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var heading: Label = ui.label(ui.snapshot.hotel_names[index], 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(heading)
	if ui.snapshot.owned[index]:
		copy.add_child(ui.paragraph("%d stars · +%d coins/min" % [ui.snapshot.life.hotels[index].stars, ui.snapshot.hotel_rates[index]], 16, ui.GREEN))
	elif index == 1:
		var level: Label = ui.paragraph("Meadow level %d / 10" % ui.snapshot.meadow_level)
		level.name = "RequirementLevel"
		copy.add_child(level)
		var coins: Label = ui.paragraph("%s / 10,000 Cat Coins" % ui.number(ui.snapshot.coins), 16, ui.MUTED)
		coins.name = "RequirementCoins"
		copy.add_child(coins)
	else:
		copy.add_child(ui.paragraph("Available as an expansion."))
	var action: Button
	if ui.snapshot.owned[index]:
		action = ui.set_primary_action("You're here" if index == ui.snapshot.hotel else "Visit hotel", func(): ui.hotel_requested.emit(index), index == ui.snapshot.hotel)
	elif index == 1:
		var state: Dictionary = _seaside_action(ui)
		action = ui.set_primary_action(state.text, func(): ui.hotel_requested.emit(index), state.disabled)
		action.name = "UnlockHotel"
	else:
		action = ui.set_primary_action("View expansion", func(): _open_product(ui, index), false)

static func update_map(ui: Control) -> void:
	if not is_instance_valid(ui.sheet): return
	var destination: Button = ui.sheet.find_child("Destination_1", true, false)
	if destination != null:
		if not destination.text.is_empty(): destination.text = _pin_text(ui, 1)
		destination.accessibility_name = ui.snapshot.hotel_names[1] + " · " + _destination_status(ui, 1)
	var destination_status: Label = ui.sheet.find_child("DestinationStatus_1", true, false)
	if destination_status != null:
		destination_status.text = _destination_status(ui, 1)
	if ui.selected_destination != 1 or ui.snapshot.owned[1]: return
	var level: Label = ui.sheet.find_child("RequirementLevel", true, false)
	var coins: Label = ui.sheet.find_child("RequirementCoins", true, false)
	if level != null: level.text = "Meadow level %d / 10" % ui.snapshot.meadow_level
	if coins != null: coins.text = "%s / 10,000 Cat Coins" % ui.number(ui.snapshot.coins)
	var action: Button = ui.sheet.find_child("UnlockHotel", true, false)
	if action == null: return
	var state: Dictionary = _seaside_action(ui)
	action.text = state.text
	action.disabled = state.disabled
	action.accessibility_name = action.text + (" · unavailable" if action.disabled else "")

static func _seaside_action(ui: Control) -> Dictionary:
	var text: String = "Open Seaside · 10,000" if ui.snapshot.can_unlock else ("Reach Meadow level 10" if ui.snapshot.meadow_level < 10 else "Save %s more coins" % ui.number(maxf(0, 10000 - ui.snapshot.coins)))
	return {"text":text, "disabled":not ui.snapshot.can_unlock or ui.snapshot.save_error != ""}

static func _open_product(ui: Control, hotel_index: int) -> void:
	for product in Content.PRODUCTS:
		if product.hotels.has(hotel_index):
			ui.shop_focus_product = product.id
			break
	ui.open_route("Shop", "Map")

static func shop(ui: Control) -> void:
	var content: VBoxContainer = ui._base_sheet("More places. More paws.", 650)
	ui.purchase_buttons.clear()
	var owned: bool = not ui.snapshot.life.entitlements.is_empty()
	content.add_child(ui.paragraph("Thank you! Your game is permanently ad-free." if owned else "Any expansion purchase removes every ad throughout the app.", 16, ui.MUTED))
	var status: Label = ui.paragraph("")
	status.name = "ShopStatus"
	content.add_child(status)
	for product in Content.PRODUCTS:
		var box := _card(ui, content)
		box.name = "ProductCard_" + product.id.replace(".", "_")
		var art_kind: String = "hotel_meadow"
		if product.hotels.has(2): art_kind = "hotel_forest"
		elif product.hotels.has(3): art_kind = "hotel_snowcap"
		box.add_child(ui.art(art_kind, (72 if ui.metrics.font_scale >= 1.5 else 104) * ui.metrics.unit))
		var heading: Label = ui.label(product.name, 22)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(heading)
		box.add_child(ui.paragraph(product.copy))
		box.add_child(ui.paragraph(_included(ui, product), 16))
		box.add_child(ui.paragraph("Includes permanent ad removal.", 16, ui.GREEN))
		var price: Label = ui.paragraph("")
		price.name = "Price_" + product.id.replace(".", "_")
		box.add_child(price)
		var id: String = product.id
		var purchase: Button = ui.button("Store unavailable", func(): ui.purchase_requested.emit(id), true)
		purchase.name = "Purchase_" + id.replace(".", "_")
		purchase.set_meta("product_id", id)
		box.add_child(purchase)
		ui.purchase_buttons.append(purchase)
	var restore: Button = ui.button("Restore purchases", func(): ui.restore_requested.emit())
	restore.name = "RestorePurchases"
	content.add_child(restore)
	content.add_child(ui.paragraph("Restoring a purchase also restores ad removal. Your free cats can reach every base-game star."))
	if ui.snapshot.get("privacy_available", false):
		var privacy: Button = ui.button("Advertising privacy choices", func(): ui.privacy_requested.emit())
		privacy.name = "PrivacyChoices"
		content.add_child(privacy)
	update_shop(ui)
	if not ui.shop_focus_product.is_empty():
		ui.call_deferred("_focus_shop_product")

static func _included(ui: Control, product: Dictionary) -> String:
	var parts: Array[String] = []
	if not product.hotels.is_empty():
		parts.append("Hotel: " + ui.snapshot.hotel_names[int(product.hotels[0])])
	if not product.cats.is_empty():
		parts.append("Cats: " + ", ".join(product.cats.map(func(index): return ui.snapshot.cat_names[int(index)])))
	return " · ".join(parts)

static func update_shop(ui: Control) -> void:
	if not is_instance_valid(ui.sheet):
		return
	var status: Label = ui.sheet.find_child("ShopStatus", true, false)
	if status != null:
		status.text = ui.commerce.get("message", "Connecting to the store…")
	var ready: bool = ui.commerce.get("ready", false)
	var busy: bool = ui.commerce.get("busy", false)
	var preview: bool = ui.commerce.get("preview", false)
	var prices: Dictionary = ui.commerce.get("prices", {})
	for purchase in ui.purchase_buttons:
		if not is_instance_valid(purchase): continue
		var id: String = purchase.get_meta("product_id", "")
		var purchased: bool = ui.snapshot.life.entitlements.has(id)
		var price: String = prices.get(id, "")
		var available: bool = ready and (preview or not price.is_empty())
		purchase.text = "Owned · Thank you!" if purchased else ("Try expansion · Test purchase" if preview else ("Buy · " + price if available else "Store unavailable"))
		purchase.disabled = purchased or busy or not available
		purchase.accessibility_name = purchase.text + (" · unavailable" if purchase.disabled else "")
		var price_label: Label = ui.sheet.find_child("Price_" + id.replace(".", "_"), true, false)
		if price_label != null:
			price_label.text = "Test purchase · No money is charged" if preview else (price if not price.is_empty() else "Store unavailable")
	var restore: Button = ui.sheet.find_child("RestorePurchases", true, false)
	if restore != null:
		restore.disabled = not ui.commerce.get("can_restore", false) or busy
