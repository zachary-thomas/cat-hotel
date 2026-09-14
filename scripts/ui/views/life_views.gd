extends RefCounted
const Content = preload("res://scripts/core/game_content.gd")
const MenuArt = preload("res://scripts/ui/menu_art.gd")
const Tile = preload("res://scripts/ui/game_tile.gd")
const Badge = preload("res://scripts/ui/cat_badge.gd")
static var thumbnails: Dictionary = {}

static func card(ui: Control, parent: Control, tint: Color = Color("FFF8E9")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.PlayfulTheme.panel(tint, ui.metrics.unit, 20))
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", roundi(8 * ui.metrics.unit))
	panel.add_child(col)
	return col

static func heading(ui: Control, text: String, size: int = 22) -> Label:
	var result: Label = ui.label(text, size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func action(ui: Control, text: String, callback: Callable, primary: bool = false) -> Button:
	var result: Button = ui.button(text, callback, primary)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func picture(texture: Texture2D, height: float) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size.y = height
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return result

static func hub(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("Life at " + ui.snapshot.hotel_name, 650)
	var featured := card(ui, col, Color("FFF1D6"))
	var featured_art: Control = ui.art("nap", (24 if ui.metrics.font_scale >= 1.5 else 68) * ui.metrics.unit)
	featured_art.name = "FeaturedEventArt"
	featured.add_child(featured_art)
	var featured_name: Label = heading(ui, "Great Nap Championship",18 if ui.metrics.font_scale >= 1.5 else 20)
	featured_name.name = "FeaturedEventName"
	featured.add_child(featured_name)
	var featured_status: Label = ui.paragraph("")
	featured_status.name = "FeaturedEventStatus"
	featured.add_child(featured_status)
	var ready := action(ui, "Get ready  ›", func(): ui.open_route("Events", "Life"), true)
	ready.name = "Life_Events"
	featured.add_child(ready)
	var grid := GridContainer.new()
	grid.name = "grid"
	col.add_child(grid)
	var routes = {"Garden":"Grounds","Manager":"Manager","Staff":"Staff","Scrapbook":"Journal","Discoveries":"Discoveries","Paw Mart":"Kiosk"}
	for title in routes:
		var route: String = routes[title]
		var tile := Tile.new()
		grid.add_child(tile)
		tile.configure(ui,title,"",ui.art(route.to_lower(),88*ui.metrics.unit),func(): ui.open_route(route,"Life"))
		tile.name = "Life_" + route
	var watch := action(ui, "Watch your favorite  ›", func(): ui.close_sheet(); ui.setting_changed.emit("watch",true))
	watch.name = "Life_Watch"
	col.add_child(watch)
	col.add_child(heading(ui, "Hotel specialty"))
	var h: Dictionary = ui.snapshot.life.hotels[ui.snapshot.hotel]
	for option in Content.SPECIALTIES:
		var choice := action(ui, ("✓ " if h.specialty == option.id else "") + ("Balanced" if option.id == "balanced" else option.name), func(): ui.command("specialty",{"id":option.id}))
		choice.name = "Specialty_" + option.id
		choice.disabled = ui.snapshot.hotel_level < 3
		col.add_child(choice)
		col.add_child(ui.paragraph(option.copy))
	if ui.snapshot.hotel_level < 3: col.add_child(ui.paragraph("Specialties open at hotel level 3."))
	relayout(ui)
	update(ui)

static func events(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("Let’s get together",650)
	ui.event_label = ui.paragraph("")
	col.add_child(ui.event_label)
	for item in Content.EVENTS:
		if item.hotel >= 0 and item.hotel != ui.snapshot.hotel: continue
		var box := card(ui,col,Color("FFF1D6") if item.id == "nap" else Color("FFF8E9"))
		var illustration: Control = ui.art(item.id, (95 if ui.metrics.font_scale >= 1.5 else 145) * ui.metrics.unit)
		illustration.name = "EventArt_"+item.id
		box.add_child(illustration)
		box.add_child(heading(ui,item.name))
		var score: Label = ui.paragraph("")
		score.name = "EventScore_" + item.id
		box.add_child(score)
		var progress := ProgressBar.new()
		progress.name = "EventProgress_" + item.id
		progress.show_percentage = false
		progress.custom_minimum_size.y = 10 * ui.metrics.unit
		progress.add_theme_stylebox_override("background",preload("res://scripts/ui/views/cat_views.gd").progress_style(Color("E9E1D2")))
		progress.add_theme_stylebox_override("fill",preload("res://scripts/ui/views/cat_views.gd").progress_style(Color("F5A18F")))
		box.add_child(progress)
		box.add_child(ui.paragraph(item.copy))
		var reward: Label = ui.paragraph("")
		reward.name = "EventReward_" + item.id
		box.add_child(reward)
		var host := action(ui,"Host gathering",func(): ui.command("event",{"id":item.id}),true)
		host.name = "Event_"+item.id
		box.add_child(host)
	col.add_child(action(ui,"Ring the dinner bell",func(): ui.command("interact",{"cat":ui.snapshot.life.favorite,"kind":"bell"})))
	update(ui)

static func update(ui: Control) -> void:
	if not is_instance_valid(ui.sheet): return
	var h: Dictionary = ui.snapshot.life.hotels[ui.snapshot.hotel]
	if ui.tab == "Life":
		var featured: Dictionary = _featured_event(ui,h)
		var art = ui.sheet.find_child("FeaturedEventArt",true,false)
		var title: Label = ui.sheet.find_child("FeaturedEventName",true,false)
		var status: Label = ui.sheet.find_child("FeaturedEventStatus",true,false)
		var route: Button = ui.sheet.find_child("Life_Events",true,false)
		if art != null:
			art.kind = featured.id
			art.queue_redraw()
		if title != null: title.text = featured.name
		if status != null: status.text = featured.status
		if route != null:
			route.text = featured.action
			route.accessibility_name = featured.action.replace("›","").strip_edges()
	if ui.tab == "Events":
		var cooldown: int = maxi(0,ceili(60-(ui.snapshot.life.seconds-h.last_event)))
		if is_instance_valid(ui.event_label):
			ui.event_label.text = ("Gathering complete! Next gathering in %ds." % cooldown if cooldown > 0 else "Your guests are ready for a gathering.") if h.event.is_empty() else "%s · %ds remaining" % [Content.find_event(h.event.id).name,maxi(0,ceili(h.event.ends-ui.snapshot.life.seconds))]
		for item in Content.EVENTS:
			var host = ui.sheet.find_child("Event_"+item.id,true,false)
			if host == null: continue
			var running: bool = h.event.get("id","") == item.id
			host.disabled = not h.event.is_empty() or cooldown > 0 or ui.snapshot.save_error != ""
			host.text = "Gathering in progress" if running else ("Ready in %ds" % cooldown if cooldown > 0 else "Host gathering")
			var score: int = h.event.score if running else ui.snapshot.event_scores[item.id]
			ui.sheet.find_child("EventScore_"+item.id,true,false).text = "Ready score: %d / 100 · %d sec" % [score,item.seconds]
			ui.sheet.find_child("EventProgress_"+item.id,true,false).value = score
			ui.sheet.find_child("EventReward_"+item.id,true,false).text = "★ Trophy earned" if h.trophies.has(item.id) else "★ First trophy · +250 Cat Coins"
	if ui.tab == "Staff":
		var train = ui.sheet.find_child("StaffTrain",true,false)
		if train != null:
			var index: int = ui.selected_staff
			train.disabled = h.staff[index]>=3 or ui.snapshot.coins<250*(h.staff[index]+1) or ui.snapshot.levels[Content.STAFF[index].zone]==0 or ui.snapshot.save_error != ""

static func _featured_event(ui: Control, h: Dictionary) -> Dictionary:
	var cooldown: int = maxi(0,ceili(60-(ui.snapshot.life.seconds-h.last_event)))
	var event: Dictionary = {}
	if not h.event.is_empty():
		event = Content.find_event(str(h.event.id))
	elif cooldown > 0:
		event = Content.find_event(str(h.get("last_completed_event","")))
	if event.is_empty(): event = Content.find_event("nap")
	if not h.event.is_empty():
		var remaining: int = maxi(0,ceili(float(h.event.ends)-float(ui.snapshot.life.seconds)))
		return {"id":event.id,"name":event.name,"status":"%ds left · Score %d / 100" % [remaining,int(h.event.score)],"action":"View gathering  ›"}
	if cooldown > 0:
		return {"id":event.id,"name":event.name,"status":"Gathering complete · Ready again in %ds" % cooldown,"action":"See results · %ds  ›" % cooldown}
	var available_copy: String = "Available again · choose a gathering." if float(h.last_event) >= 0 else "Ready for a gathering."
	return {"id":event.id,"name":event.name,"status":available_copy,"action":"Get ready  ›"}

static func staff(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("The cats behind the comfort",650)
	var selector := GridContainer.new()
	selector.name = "StaffSelector"
	selector.columns = 3
	col.add_child(selector)
	for index in range(3):
		var tile := Tile.new()
		tile.configure(ui,Content.STAFF[index].name,"",picture(MenuArt.staff_portrait(index),80*ui.metrics.unit),func(): ui.selected_staff=index; staff(ui))
		tile.name = "StaffSelect_"+str(index)
		if index == ui.selected_staff: ui._apply_primary_button_style(tile)
		selector.add_child(tile)
	var index: int = ui.selected_staff
	var member: Dictionary = Content.STAFF[index]
	var h: Dictionary = ui.snapshot.life.hotels[ui.snapshot.hotel]
	var box := card(ui,col,Color("F1EBFA"))
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation",roundi(8*ui.metrics.unit))
	box.add_child(identity)
	var portrait := picture(MenuArt.staff_portrait(index),88*ui.metrics.unit)
	portrait.custom_minimum_size.x = 88*ui.metrics.unit
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(details)
	details.add_child(heading(ui,member.name+" · "+member.job,20))
	details.add_child(ui.paragraph("Training %d / 3 · +%d Cat Coins / min" % [h.staff[index],h.staff[index]*2]))
	var train := action(ui,"Training complete" if h.staff[index]>=3 else "Train · %s Cat Coins" % ui.number(250*(h.staff[index]+1)),func(): ui.command("train",{"staff":index}),true)
	train.name = "StaffTrain"
	box.add_child(train)
	box.add_child(ui.paragraph(member.copy))
	if ui.snapshot.levels[member.zone]==0: box.add_child(ui.paragraph("Open the %s service to start training." % ui.snapshot.zone_names[member.zone]))
	box.add_child(heading(ui,"A special skill",20))
	for skill in range(2):
		var choice := action(ui,("✓ " if h.skills[index]==skill else "")+member.skills[skill],func(): ui.command("skill",{"staff":index,"skill":skill}))
		choice.name = "StaffSkill_"+str(skill)
		choice.disabled = h.staff[index]==0
		box.add_child(choice)
	if h.staff[index]==0: box.add_child(ui.paragraph("Train once to choose a skill."))
	relayout(ui)
	update(ui)

static func discoveries(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("Little discoveries, big dreams",650)
	var guide := card(ui,col,Color("FFF1D6"))
	guide.add_child(ui.art("discoveries",88*ui.metrics.unit))
	guide.add_child(heading(ui,"The Whisker Guide"))
	guide.add_child(ui.paragraph(ui.snapshot.life.hotels[ui.snapshot.hotel].review))
	for item in ui.snapshot.star_checks: guide.add_child(ui.paragraph(("✓ " if item.ready else "○ ")+item.name))
	var inspect := action(ui,"Invite Inspector Whiskers",func(): ui.command("inspect"),true)
	inspect.name = "InviteInspector"
	inspect.disabled = ui.snapshot.life.hotels[ui.snapshot.hotel].inspection >= 0
	guide.add_child(inspect)
	col.add_child(heading(ui,"Furniture combinations"))
	for combo in Content.COMBOS:
		var found: bool = ui.snapshot.life.combos.has(combo.id)
		var box := card(ui,col,Color("E3F3E9") if found else Color("FFF8E9"))
		box.add_child(heading(ui,("✓ " if found else "? ")+combo.name,20))
		box.add_child(ui.paragraph((" + ".join(combo.items.map(func(id): return Content.find_item(id).name))+" · +%d/min" % combo.bonus) if found else combo.clue))
		var pin := action(ui,"Pinned" if ui.snapshot.life.pinned==combo.id else "Pin discovery",func(): ui.command("pin",{"id":combo.id}))
		pin.name = "Combo_"+combo.id
		box.add_child(pin)

static func thumbnail(path: String) -> Texture2D:
	if not thumbnails.has(path):
		var image := Image.load_from_file(path)
		if image == null or image.is_empty(): return null
		var ratio := minf(1.0,640.0/maxi(image.get_width(),image.get_height()))
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		if thumbnails.size() >= 80: thumbnails.erase(thumbnails.keys()[0])
		thumbnails[path] = ImageTexture.create_from_image(image)
	return thumbnails[path]

static func prune_thumbnails(entries: Array) -> void:
	# Protect the displayed newest-first set before inserting a new photo into a full album.
	var displayed := {}
	for entry in entries.slice(0,80):
		if entry.has("photo"): displayed[entry.photo] = true
	for path in thumbnails.keys():
		if not displayed.has(path): thumbnails.erase(path)

static func journal(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("Our little scrapbook",650)
	col.add_child(ui.paragraph("Small moments. Big purrs."))
	var photo := action(ui,"Take a hotel photo",func(): ui.photo_requested.emit(),true)
	photo.name = "TakeHotelPhoto"
	var photo_row := HBoxContainer.new()
	col.add_child(photo_row)
	var camera := preload("res://scripts/ui/game_icon.gd").new()
	camera.kind = "camera"
	camera.custom_minimum_size = Vector2(32,32) * float(ui.metrics.unit)
	camera.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	photo_row.add_child(camera)
	photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	photo_row.add_child(photo)
	if ui.snapshot.life.memories.is_empty():
		col.add_child(ui.art("journal",200*ui.metrics.unit))
		col.add_child(heading(ui,"Your first memory is waiting"))
		col.add_child(ui.paragraph("Spend a moment with a cat or take a postcard of your hotel."))
		col.add_child(action(ui,"Visit your cats  ›",func(): ui.open_route("Cats","Journal")))
	var entries: Array = ui.snapshot.life.memories.duplicate()
	entries.reverse()
	prune_thumbnails(entries)
	for entry in entries.slice(0,80):
		var box := card(ui,col,Color("FFF1D6"))
		var saved: Texture2D = thumbnail(entry.photo) if entry.has("photo") and FileAccess.file_exists(entry.photo) else null
		if saved != null:
			var image := picture(saved,200*ui.metrics.unit)
			image.name = "JournalPhoto"
			box.add_child(image)
		else:
			var portrait := Badge.new()
			portrait.cat_index = entry.cat
			portrait.locked = not ui.snapshot.life.cats[entry.cat].known
			portrait.custom_minimum_size = Vector2.ONE * 88 * float(ui.metrics.unit)
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(portrait)
		box.add_child(heading(ui,entry.title,20))
		box.add_child(ui.paragraph(entry.text))
		box.add_child(ui.paragraph("Day %d · %s" % [entry.day,ui.snapshot.hotel_names[entry.hotel]]))
		var visit: Button = action(ui,"Visit "+Content.CAT_NAMES[entry.cat],func(): ui.open_cat(entry.cat))
		visit.name = "JournalVisit_" + str(entry.id).md5_text()
		box.add_child(visit)

static func relayout(ui: Control) -> void:
	if not is_instance_valid(ui.sheet): return
	var enlarged: bool = ui.metrics.font_scale >= 1.5
	var featured_art: Control = ui.sheet.find_child("FeaturedEventArt",true,false)
	var featured_name: Label = ui.sheet.find_child("FeaturedEventName",true,false)
	if featured_art != null: featured_art.custom_minimum_size.y = (24 if enlarged else 68) * ui.metrics.unit
	if featured_name != null:
		var title_size: int = 18 if enlarged else 20
		featured_name.set_meta(ui.PHONE_FONT_META,title_size)
		featured_name.add_theme_font_size_override("font_size",ui._scaled_font_size(title_size))
	for name in ["grid","StaffSelector"]:
		var grid = ui.sheet.find_child(name,true,false)
		if grid == null: continue
		grid.columns = 1 if ui.metrics.font_scale >= 1.5 else (3 if name == "StaffSelector" else 2)
		grid.add_theme_constant_override("h_separation",roundi(8*ui.metrics.unit))
		grid.add_theme_constant_override("v_separation",roundi(12*ui.metrics.unit))
