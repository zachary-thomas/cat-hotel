extends RefCounted
## Welcome and service moments use live native text around reviewed scene art.

static func welcome(ui: Control) -> void:
	ui.welcome = PanelContainer.new()
	ui.welcome.name = "Welcome"
	ui.add_child(ui.welcome)
	ui.welcome.add_theme_stylebox_override("panel",ui.style(ui.CREAM,24))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	ui.welcome.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	var crest: Control = ui.icon("paw",Vector2(28,28)*float(ui.metrics.unit))
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(crest)
	var title: Label = ui.paragraph("PURRINGTON\nHOTEL",28,ui.INK)
	title.name = "WelcomeTitle"
	var display := FontVariation.new()
	display.base_font = ui.DISPLAY_FONT
	display.variation_opentype = {2003265652:620.0}
	title.add_theme_font_override("font",display)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle: Label = ui.paragraph("Cozy stays. Happy cats.")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var illustration: Control = ui.art("welcome",220 * float(ui.metrics.unit))
	illustration.name = "WelcomeArt"
	content.add_child(illustration)
	var play: Button = ui.button("Open your hotel",func(): ui.play_requested.emit(),true)
	play.name = "PlayButton"
	play.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(play)
	var paw: Control = ui.icon("paw",Vector2(26,26)*float(ui.metrics.unit))
	paw.name = "PlayPaw"
	play.add_child(paw)
	paw.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	paw.position = Vector2(12, (play.custom_minimum_size.y-paw.size.y)/2)
	var settings: Button = ui.button("Settings",func(): ui._open_settings())
	settings.name = "WelcomeSettings"
	content.add_child(settings)
	var copy: Label = ui.paragraph("Your hotel earns while you’re away.",16)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(copy)

static func upgrades(ui: Control) -> void:
	var content: VBoxContainer = ui._base_sheet("A cozier hotel",680)
	var selector := GridContainer.new()
	selector.name = "ServiceTabs"
	selector.columns = 2 if float(ui.metrics.font_scale)>1.0 else 4
	selector.add_theme_constant_override("h_separation",roundi(6*float(ui.metrics.unit)))
	selector.add_theme_constant_override("v_separation",roundi(6*float(ui.metrics.unit)))
	content.add_child(selector)
	for i in range(4):
		var choice: Button = ui.button(["Suites","Kitchen","Lounge","Desk"][i],func(): ui.open_upgrades(i))
		choice.name = "Service_"+str(i)
		choice.set_meta(ui.PHONE_FONT_META,16)
		choice.add_theme_font_size_override("font_size",ui._scaled_font_size(16))
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for state in ["normal","hover","pressed"]:
			var surface = ui.PlayfulTheme.button_style(ui.GREEN if ui.selected_zone==i else ui.CREAM,float(ui.metrics.unit),state=="pressed")
			surface.content_margin_left = 3*float(ui.metrics.unit)
			surface.content_margin_right = 3*float(ui.metrics.unit)
			choice.add_theme_stylebox_override(state,surface)
		choice.accessibility_description = "Selected service" if ui.selected_zone==i else "Show this service"
		selector.add_child(choice)
	var scene: Control = ui.art(["suite","kitchen","upgrade_lounge","desk"][ui.selected_zone],120*float(ui.metrics.unit))
	scene.name = "UpgradeArt"
	content.add_child(scene)
	var level: int = ui.snapshot.levels[ui.selected_zone]
	content.add_child(ui.paragraph(ui.snapshot.zone_names[ui.selected_zone],24,ui.INK))
	content.add_child(ui.paragraph("Level %d → %d" % [level,mini(10,level+1)] if level<10 else "Level 10 · Fully upgraded",24,ui.INK))
	content.add_child(ui.paragraph("+%d → +%d / min" % [level*10,mini(10,level+1)*10] if level<10 else "+100 / min",20,ui.INK))
	content.add_child(ui.paragraph(ui.snapshot.zone_descriptions[ui.selected_zone]))
	var purchase: Button = ui.set_primary_action("Upgrade",func(): ui.upgrade_requested.emit(ui.selected_zone))
	purchase.name = "PurchaseUpgrade"
	ui.live_buttons.append({"button":purchase,"kind":"upgrade","zone":ui.selected_zone})
	content.add_child(ui.button("Build & decorate",func(): ui._navigate("Build")))
	if ui.selected_zone==0: content.add_child(ui.button("Add rooms",func(): ui.open_expansions()))
	ui.show_inline_error(ui.snapshot.get("save_error",""))
	ui.render(ui.snapshot)

static func offline(ui: Control) -> void:
	var content: VBoxContainer = ui._base_sheet("Welcome back!",660)
	content.add_theme_constant_override("separation",roundi(8*float(ui.metrics.unit)))
	var illustration: Control = ui.art("reward",124*float(ui.metrics.unit))
	illustration.name = "RewardArt"
	content.add_child(illustration)
	var amount: Label = ui.paragraph(ui.number(ui.snapshot.pending)+" Cat Coins",24,ui.INK)
	amount.name = "RewardAmount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(amount)
	content.add_child(ui.paragraph("Away · %s   Credited · %s" % [ui.duration(ui.snapshot.away_seconds),ui.duration(ui.snapshot.pending_seconds)]))
	content.add_child(ui.paragraph("Earn offline for up to 8 hours."))
	var claim: Button = ui.set_primary_action("Collect "+ui.number(ui.snapshot.pending),func(): ui.claim_requested.emit())
	claim.name = "CollectEarnings"
	var later: Button = ui.button("Later",func(): ui.close_sheet())
	later.name = "LaterEarnings"
	ui.sheet._column.add_child(later)
	ui.show_inline_error(ui.snapshot.get("save_error",""))

static func settings(ui: Control) -> void:
	var content: VBoxContainer = ui._base_sheet("Make yourself comfy",800)
	var heading := HBoxContainer.new()
	heading.add_child(ui.icon("Cats",Vector2(64,64)*float(ui.metrics.unit)))
	heading.add_child(ui.paragraph("Little comforts, your way."))
	content.add_child(heading)
	for group in [["Sound",[["music","Music"],["sound","Sound effects"]]],["Comfort",[["motion","Gentle animations"],["haptics","Touch feedback"],["evening","Evening lighting"],["weather","Seasonal weather"]]]]:
		content.add_child(ui.label(group[0],22))
		for option in group[1]: _preference(ui,content,option[0],option[1])
	content.add_child(ui.label("Text size",22))
	var scale_row: BoxContainer = VBoxContainer.new() if float(ui.metrics.font_scale)>1.0 else HBoxContainer.new()
	scale_row.name = "TextScaleChoices"
	content.add_child(scale_row)
	for scale in [1.0,1.25,1.5]:
		var selected: bool = is_equal_approx(float(ui.snapshot.settings.get("ui_text_scale",1.0)),scale)
		var choice: Button = ui.button("%d%%" % int(scale*100),func(): ui.setting_changed.emit("ui_text_scale",scale),selected)
		choice.name = "TextScale_%d" % int(scale*100)
		choice.accessibility_name = "Text size %d percent" % int(scale*100)
		choice.accessibility_description = "Selected" if selected else "Change text size"
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale_row.add_child(choice)
	var status: Label = ui.paragraph("Preferences will save when you open your hotel." if not ui.snapshot.get("started",false) else "Saved on this device.")
	status.name = "SaveStatus"
	content.add_child(status)
	if ui.snapshot.get("save_error","")!="": status.text = "Changes could not be saved."
	if ui.snapshot.get("started",false):
		var privacy_heading: Label = ui.label("Purchases & privacy",22)
		privacy_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(privacy_heading)
		var purchases: Button = ui.button("Expansions & restore purchases",func(): ui.open_route("Shop","Settings"))
		purchases.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(purchases)
		if ui.snapshot.get("privacy_available",false):
			var privacy: Button = ui.button("Advertising privacy choices",func(): ui.privacy_requested.emit())
			privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(privacy)
		content.add_child(ui.button("Hotel view",func(): ui.open_route("View","Settings")))
	ui.show_inline_error(ui.snapshot.get("save_error",""))

static func _preference(ui: Control, parent: Control, key: String, caption: String) -> void:
	var enabled: bool = ui.snapshot.settings.get(key,true)
	var row: Button = ui.button("",func(): ui.setting_changed.emit(key,not enabled))
	row.name = "Setting_"+key
	row.accessibility_name = caption
	row.accessibility_description = "On" if enabled else "Off"
	parent.add_child(row)
	var layout := HBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation",roundi(8*float(ui.metrics.unit)))
	row.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 8*float(ui.metrics.unit)
	layout.offset_right = -8*float(ui.metrics.unit)
	layout.offset_top = 6*float(ui.metrics.unit)
	layout.offset_bottom = -6*float(ui.metrics.unit)
	layout.add_child(ui.icon(key,Vector2(36,36)*float(ui.metrics.unit)))
	var name_label: Label = ui.paragraph(caption,16,ui.INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(name_label)
	var state: Label = ui.label("On" if enabled else "Off",16,ui.INK)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.add_theme_stylebox_override("normal",ui.style(ui.GREEN if enabled else Color("E6E2D9"),16))
	layout.add_child(state)
	row.custom_minimum_size.y = (80 if float(ui.metrics.font_scale)>1.0 else 60)*float(ui.metrics.unit)
