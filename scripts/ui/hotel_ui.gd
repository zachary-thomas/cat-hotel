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
const LifeViews = preload("res://scripts/ui/views/life_views.gd")
const GroundsViews = preload("res://scripts/ui/views/grounds_views.gd")
var selected_staff: int = 0
const CatViews = preload("res://scripts/ui/views/cat_views.gd")
const PetView = preload("res://scripts/ui/cat_interaction.gd")
var selected_cat: int = 0
var cat_filter: String = "Met"
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
		bond_label.text = "♥ %d / 100 friendship · %s" % [cat.bond,"Hotel favorite" if cat.bond>=100 else ("Regular" if cat.bond>=20 else "Getting acquainted")]
		var friendship = sheet.find_child("CareFriendship", true, false)
		if friendship != null: friendship.value = cat.bond
		var favorite = sheet.find_child("CatFavorite", true, false)
		if favorite != null: favorite.text = "♥  Hotel favorite" if data.life.favorite == selected_cat else "♡  Make hotel favorite"
		if is_instance_valid(preference_label):
			preference_label.text = "Loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[selected_cat]] + "." if cat.preference else "Spend time together to learn a favorite comfort."
	LifeViews.update(self)
	if last_life_revision != int(data.life.revision):
		last_life_revision = int(data.life.revision)
		if tab in ["Life","Journal","Staff","Discoveries","Shop"] and is_instance_valid(sheet):
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
		"Invitations": _invitations()
		"Events": _events()
		"Journal": _journal()
		"Staff": _staff()
		"Discoveries": _discoveries()
		"Shop": _shop()
		_: super._refresh_sheet()

func _life() -> void:
	LifeViews.hub(self)

func _decorate() -> void:
	close_sheet()
	build_requested.emit()

func _expansions() -> void:
	super._expansions()
	var decorate = button("Decorate open rooms",func(): _navigate("Decorate"))
	sheet_content.add_child(decorate)

func open_cat(index: int) -> void:
	selected_cat = index
	open_route("Pet", "Cats" if tab == "Hotel" else tab)

func _pet() -> void:
	CatViews.profile(self, selected_cat)

func _cats() -> void:
	CatViews.collection(self)

func _invitations() -> void:
	CatViews.invitations(self, selected_cat)

func relayout() -> void:
	super.relayout()
	CatViews.relayout(self)
	LifeViews.relayout(self)

func _events() -> void:
	LifeViews.events(self)

func _staff() -> void:
	LifeViews.staff(self)

func _discoveries() -> void:
	LifeViews.discoveries(self)

func _journal() -> void:
	LifeViews.journal(self)

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
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	GroundsViews.garden(self)

func _amenity() -> void:
	GroundsViews.amenity(self)

func _manager() -> void:
	GroundsViews.manager(self)

func _kiosk() -> void:
	GroundsViews.kiosk(self)
