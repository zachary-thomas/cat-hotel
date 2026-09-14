extends "res://scripts/ui/mobile_ui.gd"
signal action_requested(action: String, payload: Dictionary)
signal purchase_requested(product_id: String)
signal restore_requested
signal photo_requested
signal privacy_requested
signal grounds_requested(action: String, payload: Dictionary)
signal manager_mode_requested(enabled: bool)
signal modal_requested
const Grounds = preload("res://scripts/core/grounds_model.gd")
var manager_mode: bool = false
var selected_amenity: String = "pool"
var grounds_buttons: Array = []
var job_status: Label
var maid_status: Label
var grounds_key: String = ""
const Content = preload("res://scripts/core/game_content.gd")
const PetView = preload("res://scripts/ui/cat_interaction.gd")
var selected_cat: int = 0
var selected_room: int = 0
var selected_slot: int = 0
var pet_view
var bond_label: Label
var preference_label: Label
var event_label: Label
var view_button: Button
var quick_bar: HBoxContainer
var watch_exit: Button
var commerce: Dictionary = {}
var purchase_buttons: Array = []
var last_life_revision: int = -1

func _view() -> void:
	super._view()
	view_button = button("Inside" if snapshot.settings.exterior else "Outside", func():
		close_sheet()
		setting_changed.emit("exterior", not snapshot.settings.exterior)
	)
	view_button.name = "HotelViewButton"
	sheet_content.add_child(view_button)
	sheet_content.add_child(button("Watch your favorite", func(): close_sheet(); setting_changed.emit("watch", true)))

func _process(delta: float) -> void:
	super._process(delta)
	if snapshot.get("settings",{}).get("watch",false):
		toast_label.hide()

func _ready() -> void:
	super._ready()
	quick_bar = HBoxContainer.new()
	header.add_child(quick_bar)
	quick_bar.hide()
	pending_button.position.y = 122
	watch_exit = button("Back to hotel",func(): setting_changed.emit("watch",false))
	add_child(watch_exit)
	watch_exit.position = Vector2(16,20)
	watch_exit.size = Vector2(160,52)
	watch_exit.visible = false

func command(action: String, payload: Dictionary = {}) -> void:
	action_requested.emit(action,payload)

func _base_sheet(title: String, height: float = 525) -> VBoxContainer:
	modal_requested.emit()
	return super._base_sheet(title,height)

func render(data: Dictionary) -> void:
	super.render(data)
	if not data.get("started",false) or not data.has("life") or quick_bar == null:
		return
	if is_instance_valid(view_button):
		view_button.text = "Inside" if data.settings.exterior else "Outside"
		view_button.tooltip_text = "Reveal the rooms" if data.settings.exterior else "View the complete hotel with its roof and walls"
	_update_grounds(data)
	var quiet: bool = data.settings.watch
	quick_bar.hide()
	header.visible = not quiet
	footer.visible = not quiet
	if tab == "Build": footer.hide()
	watch_exit.visible = quiet
	if quiet:
		toast_label.hide()
	level_label.text = "Level %d · %d rooms" % [data.hotel_level, data.rooms]
	activity_label.text = "%d rooms · %d happy visits · Day %d" % [data.rooms,data.life.hotels[data.hotel].happy,1+int(data.life.seconds/600)]
	if is_instance_valid(bond_label) and tab == "Pet":
		var cat: Dictionary = data.life.cats[selected_cat]
		bond_label.text = "%d / 100 friendship · %s" % [cat.bond,"Hotel favorite" if cat.bond>=100 else ("Regular" if cat.bond>=20 else "Getting acquainted")]
		if is_instance_valid(preference_label):
			preference_label.text = "Loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[selected_cat]] + "." if cat.preference else "Spend time together to learn a favorite comfort."
	if is_instance_valid(event_label):
		var active_event: Dictionary = data.life.hotels[data.hotel].event
		event_label.text = "Your guests are ready for another gathering." if active_event.is_empty() else "%s · %ds remaining" % [Content.find_event(active_event.id).name,maxi(0,int(ceil(active_event.ends-data.life.seconds)))]
	if last_life_revision != int(data.life.revision):
		last_life_revision = int(data.life.revision)
		if tab in ["Life","Events","Journal","Staff","Discoveries","Shop"] and is_instance_valid(sheet):
			_refresh_sheet()

func _refresh_sheet() -> void:
	match tab:
		"Grounds": _grounds()
		"Amenity": _amenity()
		"Manager": _manager()
		"Kiosk": _kiosk()
		"Life": _life()
		"Decorate": _decorate()
		"Pet": _pet()
		"Events": _events()
		"Journal": _journal()
		"Staff": _staff()
		"Discoveries": _discoveries()
		"Shop": _shop()
		_: super._refresh_sheet()

func _life() -> void:
	var col = _base_sheet("Life at " + snapshot.hotel_name,620)
	var h: Dictionary = snapshot.life.hotels[snapshot.hotel]
	col.add_child(paragraph(Content.HOTEL_MECHANICS[snapshot.hotel]))
	col.add_child(paragraph(h.review,15,INK))
	for item in [["Amenities & garden","Grounds"],["Manager & housekeeping","Manager"],["Visit Paw Mart","Kiosk"],["Decorate rooms","Decorate"],["Host an event","Events"],["Train your cat staff","Staff"],["Scrapbook & photos","Journal"],["Discoveries & hotel stars","Discoveries"]]:
		col.add_child(button(item[0]+"  →",func(): _navigate(item[1])))
	col.add_child(button("Watch your favorite cat",func(): close_sheet(); setting_changed.emit("watch",true)))
	col.add_child(label("Your hotel specialty",21))
	for option in Content.SPECIALTIES:
		var b = button(("✓ " if h.specialty == option.id else "") + option.name,func(): command("specialty",{"id":option.id}))
		b.disabled = snapshot.hotel_level < 3
		col.add_child(b)
		col.add_child(paragraph(option.copy,13))
	if snapshot.hotel_level < 3:
		col.add_child(paragraph("Specialties open at hotel level 3."))

func _decorate() -> void:
	close_sheet()
	build_requested.emit()

func _expansions() -> void:
	super._expansions()
	var decorate = button("Decorate open rooms",func(): _navigate("Decorate"))
	sheet_content.add_child(decorate)

func open_cat(index: int) -> void:
	selected_cat = index
	open_route("Pet", tab)

func _pet() -> void:
	var cat: Dictionary = snapshot.life.cats[selected_cat]
	var col = _base_sheet(Content.CAT_NAMES[selected_cat],650)
	col.add_child(paragraph(Content.CAT_TRAITS[selected_cat],14))
	if not cat.known:
		col.add_child(paragraph("A traveler who loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[selected_cat]] + ". Prepare a room and send an invitation."))
		var pack: String = Content.cat_pack(selected_cat)
		if pack != "" and not snapshot.life.entitlements.has(pack):
			col.add_child(button("Meet them in the expansion shop",func(): _navigate("Shop")))
		else:
			col.add_child(button("Invite this traveler",func(): command("invite",{"cat":selected_cat}),true))
		return
	pet_view = PetView.new()
	pet_view.name = "PettingView"
	pet_view.cat_index = selected_cat
	pet_view.enabled_motion = snapshot.settings.motion
	pet_view.interacted.connect(func(kind): command("interact",{"cat":selected_cat,"kind":kind}))
	col.add_child(pet_view)
	col.add_child(paragraph("Stroke your cat, hold gently, or use a button below.",13))
	bond_label = label("",14,GREEN)
	col.add_child(bond_label)
	bond_label.text = "%d / 100 friendship" % cat.bond
	preference_label = paragraph("Loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[selected_cat]] + "." if cat.preference else "Spend time together to learn a favorite comfort.",14)
	col.add_child(preference_label)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	col.add_child(grid)
	for item in [["Pet","pet"],["Brush","brush"],["Feather","wand"],["Yarn","yarn"],["Cushion","cushion"],["Box","box"]]:
		var b = button(item[0],func(): pet_view.play(item[1]))
		b.name = "Interact_"+item[1]
		b.add_theme_font_size_override("font_size",15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	col.add_child(button("Favorite & follow " + Content.CAT_NAMES[selected_cat],func(): command("favorite",{"cat":selected_cat})))
	col.add_child(button("Invite to this hotel",func(): command("invite",{"cat":selected_cat})))
	col.add_child(label("Invite a friend to play",19))
	for i in range(snapshot.life.cats.size()):
		if i != selected_cat and snapshot.life.cats[i].known:
			var b = button(Content.CAT_NAMES[i],func(): command("playdate",{"cat":selected_cat,"other":i}))
			b.disabled = cat.bond < 10 or snapshot.life.cats[i].bond < 10 or snapshot.levels[2] == 0
			col.add_child(b)
	col.add_child(paragraph("Playdates need an open lounge and 10 friendship with both cats. Staff also build friendship through good hospitality.",13))

func _cats() -> void:
	if not snapshot.has("life"):
		super._cats()
		return
	var col = _base_sheet("Your little regulars",650)
	var count: int = 0
	for cat in snapshot.life.cats:
		if cat.known:
			count += 1
	col.add_child(paragraph("%d travelers met. Every cat has a favorite comfort and a story." % count))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",12)
	col.add_child(grid)
	for i in range(Content.CAT_NAMES.size()):
		var portrait = Badge.new()
		portrait.coat = Color(Content.COATS[i])
		portrait.locked = not snapshot.life.cats[i].known
		var card = GameTile.new()
		card.configure(self, Content.CAT_NAMES[i], Content.CAT_TRAITS[i] if not portrait.locked else ("Expansion traveler" if i >= 12 else "Discover a favorite room"), portrait, func(): open_cat(i))
		grid.add_child(card)

func _events() -> void:
	var col = _base_sheet("Something to look forward to",630)
	var h: Dictionary = snapshot.life.hotels[snapshot.hotel]
	event_label = paragraph("",16,GREEN)
	col.add_child(event_label)
	col.add_child(paragraph("Prepare rooms before starting. Each event awards a trophy; your first win earns 250 coins. Events finish while you are away, too.",14))
	for item in Content.EVENTS:
		if item.hotel >= 0 and item.hotel != snapshot.hotel:
			continue
		col.add_child(label(item.name,20))
		col.add_child(paragraph(item.copy,14))
		col.add_child(paragraph("Ready score: %d/100 · %ds · %s" % [snapshot.event_scores[item.id],item.seconds,"Trophy earned" if h.trophies.has(item.id) else "New trophy"],13,GREEN))
		var b = button("Host this event",func(): command("event",{"id":item.id}),true)
		b.name = "Event_"+item.id
		b.disabled = not h.event.is_empty() or snapshot.life.seconds-h.last_event < 60
		col.add_child(b)
	col.add_child(button("Ring the dinner bell",func(): command("interact",{"cat":snapshot.life.favorite,"kind":"bell"})))

func _staff() -> void:
	var col = _base_sheet("The cats behind the comfort",630)
	var h: Dictionary = snapshot.life.hotels[snapshot.hotel]
	for i in range(3):
		var member: Dictionary = Content.STAFF[i]
		col.add_child(label(member.name+" · "+member.job,21))
		col.add_child(paragraph(member.copy,14))
		var b = button("Training complete" if h.staff[i]>=3 else "Train · %s coins" % number(250*(h.staff[i]+1)),func(): command("train",{"staff":i}),true)
		b.disabled = h.staff[i]>=3 or snapshot.coins<250*(h.staff[i]+1) or snapshot.levels[member.zone]==0
		col.add_child(b)
		col.add_child(paragraph("Training %d/3 · +%d coins/min" % [h.staff[i],h.staff[i]*2],13))
		for skill in range(2):
			var option = button(("✓ " if h.skills[i]==skill else "")+member.skills[skill],func(): command("skill",{"staff":i,"skill":skill}))
			option.disabled = h.staff[i]==0
			col.add_child(option)

func _discoveries() -> void:
	var col = _base_sheet("Little discoveries, big dreams",650)
	col.add_child(label("The Whisker Guide",23))
	col.add_child(paragraph(snapshot.life.hotels[snapshot.hotel].review,14))
	for item in snapshot.star_checks:
		col.add_child(paragraph(("✓ " if item.ready else "○ ")+item.name,14,GREEN if item.ready else MUTED))
	var inspect = button("Invite Inspector Whiskers",func(): command("inspect"),true)
	inspect.name = "InviteInspector"
	inspect.disabled = snapshot.life.hotels[snapshot.hotel].inspection >= 0
	col.add_child(inspect)
	col.add_child(label("Furniture combinations",23))
	for combo in Content.COMBOS:
		var found: bool = snapshot.life.combos.has(combo.id)
		col.add_child(label(("✓ " if found else "? ")+combo.name,19))
		col.add_child(paragraph((" + ".join(combo.items.map(func(id): return Content.find_item(id).name))+" · +%d/min" % combo.bonus) if found else combo.clue,14))
		col.add_child(button("Pinned" if snapshot.life.pinned==combo.id else "Pin discovery",func(): command("pin",{"id":combo.id})))

func _journal() -> void:
	var col = _base_sheet("The Purrington scrapbook",650)
	col.add_child(paragraph("Little moments saved automatically. Your cats keep their stories even when you visit another hotel."))
	col.add_child(button("Take a hotel photo",func(): photo_requested.emit(),true))
	if snapshot.life.memories.is_empty():
		col.add_child(paragraph("Your first memory is waiting. Pet a cat or discover a room combination."))
	var entries: Array = snapshot.life.memories.duplicate()
	entries.reverse()
	for entry in entries.slice(0,80):
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel",style(Color("e8ecd9"),16))
		col.add_child(card)
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation",6)
		card.add_child(box)
		if entry.has("photo") and FileAccess.file_exists(entry.photo):
			var photo = TextureRect.new()
			photo.texture = ImageTexture.create_from_image(Image.load_from_file(entry.photo))
			photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			photo.custom_minimum_size.y = 220
			box.add_child(photo)
		else:
			var portrait = Badge.new()
			portrait.coat = Color(Content.COATS[entry.cat])
			portrait.custom_minimum_size.y = 95
			box.add_child(portrait)
		box.add_child(paragraph(entry.title,19,INK))
		box.add_child(paragraph(entry.text,14))
		box.add_child(paragraph("Day %d · %s" % [entry.day,snapshot.hotel_names[entry.hotel]],12))
		box.add_child(button("Visit "+Content.CAT_NAMES[entry.cat],func(): open_cat(entry.cat)))

func _map() -> void:
	if not snapshot.has("life"):
		super._map()
		return
	var col = _base_sheet("Your hotel journey",650)
	col.add_child(paragraph("Meadow House and Seaside are free. Every purchased expansion also removes all ads."))
	for i in range(4):
		col.add_child(art("hotel",110,i==1))
		col.add_child(label(snapshot.hotel_names[i],24))
		col.add_child(paragraph(Content.HOTEL_MECHANICS[i],14))
		if snapshot.owned[i]:
			col.add_child(paragraph("%d stars · +%d coins/min" % [snapshot.life.hotels[i].stars,snapshot.hotel_rates[i]],14,GREEN))
			col.add_child(button("You're here" if snapshot.hotel==i else "Visit hotel",func(): hotel_requested.emit(i)))
		elif i==1:
			col.add_child(paragraph("Meadow level %d/10 · 10,000 Cat Coins" % snapshot.meadow_level))
			var b = button("Open Seaside",func(): hotel_requested.emit(1),true)
			b.name = "UnlockHotel"
			col.add_child(b)
			live_buttons.append({"button":b,"kind":"unlock"})
		else:
			col.add_child(button("View expansion",func(): _navigate("Shop")))
	# Update affordability without recursively rebuilding this sheet.
	for item in live_buttons:
		if item.kind=="unlock":
			item.button.disabled = not snapshot.can_unlock

func _shop() -> void:
	var col = _base_sheet("More places. More paws.",650)
	purchase_buttons.clear()
	var owned: bool = not snapshot.life.entitlements.is_empty()
	col.add_child(paragraph("Thank you! Your game is permanently ad-free." if owned else "The base game is free. Any expansion purchase removes every ad throughout the app.",16,GREEN))
	col.add_child(paragraph(commerce.get("message","Connecting to the store…"),13))
	for product in Content.PRODUCTS:
		col.add_child(label(product.name,23))
		col.add_child(paragraph(product.copy,14))
		var purchased: bool = snapshot.life.entitlements.has(product.id)
		var price: String = commerce.get("prices",{}).get(product.id,"")
		var title: String = "Owned · Thank you!" if purchased else ("Try expansion · Test purchase" if commerce.get("preview",false) else ("Buy · "+price if price!="" else "Store unavailable"))
		var b = button(title,func(): purchase_requested.emit(product.id),not purchased)
		b.name = "Purchase_"+product.id.replace(".","_")
		b.disabled = purchased or not commerce.get("ready",false) or commerce.get("busy",false)
		col.add_child(b)
		purchase_buttons.append(b)
	var restore = button("Restore purchases",func(): restore_requested.emit())
	restore.disabled = not commerce.get("can_restore",false) or commerce.get("busy",false)
	col.add_child(restore)
	col.add_child(paragraph("Restoring a purchase also restores ad removal. Cat packs add personalities and stories; your free cats can reach every base-game star.",13))

func update_commerce(data: Dictionary) -> void:
	commerce = data
	if tab=="Shop" and snapshot.get("started",false):
		_shop()

func _settings() -> void:
	super._settings()
	var toggle = CheckButton.new()
	toggle.text = "Seasonal weather"
	toggle.custom_minimum_size.y = 52
	toggle.button_pressed = snapshot.settings.get("weather",true)
	toggle.toggled.connect(func(value): setting_changed.emit("weather",value))
	sheet_content.add_child(toggle)
	sheet_content.add_child(button("Expansions & restore purchases",func(): _navigate("Shop")))
	if snapshot.get("privacy_available",false):
		sheet_content.add_child(button("Advertising privacy choices",func(): privacy_requested.emit()))

func refresh_after_action(action: String) -> void:
	if action in ["interact","favorite"] and tab=="Pet":
		return
	if action=="playdate":
		close_sheet()
		return
	if is_instance_valid(sheet):
		_refresh_sheet()

func show_toast(message: String) -> void:
	if snapshot.get("settings",{}).get("watch",false):
		return
	super.show_toast(message)
	if tab != "Hotel":
		toast_label.anchor_top = 0
		toast_label.anchor_bottom = 0
		toast_label.offset_top = 82
		toast_label.offset_bottom = 135
	else:
		toast_label.anchor_top = 1
		toast_label.anchor_bottom = 1
		toast_label.offset_top = -207
		toast_label.offset_bottom = -155

func open_amenity(id: String) -> void:
	selected_amenity = id
	_navigate("Amenity")

func grounds_button(text: String, action: String, payload: Dictionary = {}, primary: bool = false) -> Button:
	var b = button(text,func(): grounds_requested.emit(action,payload),primary)
	b.name = "Grounds_"+action+str(payload.get("id",payload.get("index","")))
	grounds_buttons.append({"button":b,"action":action,"payload":payload})
	return b

func _update_grounds(data: Dictionary) -> void:
	if not data.has("grounds"):
		return
	var state: Dictionary = data.grounds.hotels[data.hotel]
	var seconds: float = data.grounds.seconds
	var job: Dictionary = state.job
	if is_instance_valid(job_status):
		job_status.text = "Ready for your next task." if job.is_empty() else "%s · %ds remaining" % [str(job.kind).capitalize(),ceili(maxf(0,job.duration-job.elapsed))]
	if is_instance_valid(maid_status):
		maid_status.text = "Daisy is ready for the next room." if state.maid_job.is_empty() else "Daisy is cleaning room %d · %ds" % [int(state.maid_job.room)+1,ceili(maxf(0,state.maid_job.duration-state.maid_job.elapsed))]
	for entry in grounds_buttons:
		if not is_instance_valid(entry.button):
			continue
		var allowed: bool = true
		var index: int = int(entry.payload.get("index",0))
		match entry.action:
			"amenity":
				var item: Dictionary = Grounds.amenity(entry.payload.id)
				allowed = not state.amenities.has(item.id) and data.hotel_level >= item.level and data.coins >= item.cost
			"hire_maid": allowed = not state.maid and data.hotel_level >= Grounds.MAID_LEVEL and data.coins >= Grounds.MAID_COST
			"trim": allowed = job.is_empty() and seconds >= state.bush_ready[index]
			"chase": allowed = job.is_empty() and seconds >= state.mouse_ready
			"clean": allowed = job.is_empty() and state.dirty[index] and (state.maid_job.is_empty() or int(state.maid_job.room) != index)
			"treats": allowed = data.coins >= 30 and seconds >= state.treat_ready
			"yarn": allowed = seconds >= state.yarn_ready[index]
		entry.button.disabled = not allowed or data.save_error != ""
	var next_key: String = str(state.amenities)+str(state.dirty)+str(state.maid)+str(job.is_empty())+str(state.maid_job.is_empty())
	if next_key != grounds_key:
		grounds_key = next_key
		if tab in ["Grounds","Amenity","Manager","Kiosk"] and is_instance_valid(sheet):
			_refresh_sheet()

func _grounds() -> void:
	grounds_buttons.clear()
	var col = _base_sheet("The garden & neighborhood",560)
	col.add_child(paragraph("Create favorite places for your guests. Every open amenity adds income at this hotel. Repair each room wing to open another fenced garden plot."))
	var state: Dictionary = snapshot.grounds.hotels[snapshot.hotel]
	for item in Grounds.AMENITIES:
		var owned: bool = state.amenities.has(item.id)
		col.add_child(button(item.name+ (" · Open" if owned else " · %d coins" % item.cost),func(): open_amenity(item.id)))
		col.add_child(paragraph("+%d coins/min · Level %d" % [item.rate,item.level],13))
	col.add_child(button("Explore as the manager",func(): manager_mode_requested.emit(true),true))
	col.add_child(button("Visit Paw Mart",func(): _navigate("Kiosk")))
	render(snapshot)

func _amenity() -> void:
	grounds_buttons.clear()
	var item: Dictionary = Grounds.amenity(selected_amenity)
	var col = _base_sheet(item.name,335)
	var state: Dictionary = snapshot.grounds.hotels[snapshot.hotel]
	col.add_child(paragraph(item.copy,17))
	col.add_child(label("+%d Cat Coins / min" % item.rate,24,GREEN))
	if state.amenities.has(item.id):
		col.add_child(paragraph("Open for guests. Watch the cats make themselves at home."))
	else:
		col.add_child(paragraph("%d coins · Hotel level %d required" % [item.cost,item.level]))
		col.add_child(grounds_button("Open amenity · %d coins" % item.cost,"amenity",{"id":item.id},true))
	col.add_child(button("All amenities",func(): _navigate("Grounds")))
	render(snapshot)

func _manager() -> void:
	grounds_buttons.clear()
	var col = _base_sheet("Your shift as hotel manager",575)
	var state: Dictionary = snapshot.grounds.hotels[snapshot.hotel]
	col.add_child(paragraph("You are the cat in the coral vest. Tap a bush, mouse or untidy room to walk over and help. Jobs reward coins when the work is done."))
	job_status = label("",17,GREEN)
	col.add_child(job_status)
	col.add_child(button("Stop directing the manager" if manager_mode else "Control the manager",func(): manager_mode_requested.emit(not manager_mode),true))
	col.add_child(label("Little jobs around the hotel",21))
	for index in range(2):
		col.add_child(grounds_button("Trim %s bush · +15 coins" % ("front" if index == 0 else "poolside"),"trim",{"index":index}))
	col.add_child(grounds_button("Chase the mouse · +12 coins","chase"))
	var dirty: int = 0
	for room in range(snapshot.rooms):
		if state.dirty[room]:
			dirty += 1
			col.add_child(grounds_button("Tidy room %d · +10 coins" % (room+1),"clean",{"index":room}))
	col.add_child(paragraph("%d rooms need tidying. %d rooms cleaned so far." % [dirty,state.cleaned],13))
	col.add_child(label("A helping paw",21))
	if state.maid:
		maid_status = label("",15,GREEN)
		col.add_child(maid_status)
		col.add_child(paragraph("Daisy visits untidy rooms and sweeps automatically, leaving you free to manage the garden.",14))
	else:
		col.add_child(paragraph("Unlock housekeeping at hotel level 3. Hire Daisy once for 600 coins; she handles room cleaning from then on.",14))
		col.add_child(grounds_button("Hire Daisy · 600 coins","hire_maid"))
	col.add_child(button("Garden amenities",func(): _navigate("Grounds")))
	render(snapshot)

func _kiosk() -> void:
	grounds_buttons.clear()
	var col = _base_sheet("Paw Mart",460)
	col.add_child(paragraph("A little shop on your doorstep. Everything here uses earned Cat Coins."))
	col.add_child(label("Invite the neighbors for treats",22))
	col.add_child(paragraph("Passing cats stop for a 25-second picnic. Your favorite gains 3 friendship. Available every two minutes.",15))
	col.add_child(grounds_button("Share treats · 30 coins","treats",{},true))
	col.add_child(button("Shop garden amenities",func(): _navigate("Grounds")))
	col.add_child(button("Hire a housekeeping cat",func(): _navigate("Manager")))
	col.add_child(label("Found any loose yarn?",20))
	col.add_child(paragraph("Tap the colorful yarn balls around the grounds for 5 coins each. More appear after 35 seconds.",14))
	for index in range(3):
		col.add_child(grounds_button("Collect %s yarn · +5 coins" % ["pink","purple","gold"][index],"yarn",{"index":index}))
	render(snapshot)
