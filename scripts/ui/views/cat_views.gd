extends RefCounted
const Content = preload("res://scripts/core/game_content.gd")
const Art = preload("res://scripts/ui/guest_art.gd")
const Tile = preload("res://scripts/ui/game_tile.gd")
const Badge = preload("res://scripts/ui/cat_badge.gd")
const PetView = preload("res://scripts/ui/cat_interaction.gd")

static func collection(ui: Control) -> void:
	var col: VBoxContainer = ui._base_sheet("Your little regulars", 650)
	var known: int = ui.snapshot.life.cats.filter(func(cat): return cat.known).size()
	col.add_child(ui.paragraph("%d travelers met · Little paws, big personalities" % known))
	var filters := HBoxContainer.new()
	col.add_child(filters)
	for choice in ["Met", "To meet"]:
		var action: Button = ui.button(choice, func():
			ui.cat_filter = choice
			ui.route_state["Cats"] = {"scroll":0}
			ui.sheet.scroll.scroll_vertical = 0
			collection(ui)
		)
		action.name = "CatFilter_" + choice.replace(" ", "_")
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if choice == ui.cat_filter: ui._apply_primary_button_style(action)
		filters.add_child(action)
	var grid := GridContainer.new()
	grid.name = "CatCollection"
	col.add_child(grid)
	for index in range(Content.CAT_NAMES.size()):
		var cat: Dictionary = ui.snapshot.life.cats[index]
		if cat.known != (ui.cat_filter == "Met"): continue
		var portrait := Badge.new()
		portrait.cat_index = index
		portrait.locked = not cat.known
		var card := Tile.new()
		var detail: String = Content.CAT_TRAITS[index] if cat.known else ("Expansion traveler" if Content.cat_pack(index) != "" else "Discover a favorite room")
		card.configure(ui, Content.CAT_NAMES[index] if cat.known else "A future friend", detail, portrait, func(): ui.open_cat(index))
		card.name = "CatCard_" + str(index)
		if cat.known:
			var bond: Label = ui.paragraph("♥ %d / 100" % cat.bond, 16, ui.INK)
			bond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card._column.add_child(bond)
			var progress := ProgressBar.new()
			progress.show_percentage = false
			progress.value = cat.bond
			progress.custom_minimum_size.y = 8 * ui.metrics.unit
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.add_theme_stylebox_override("background", progress_style(Color("E9E1D2")))
			progress.add_theme_stylebox_override("fill", progress_style(Color("F5A18F")))
			card._column.add_child(progress)
		grid.add_child(card)
	relayout(ui)

static func profile(ui: Control, cat_index: int) -> void:
	var cat: Dictionary = ui.snapshot.life.cats[cat_index]
	var col: VBoxContainer = ui._base_sheet(Content.CAT_NAMES[cat_index] if cat.known else "A future friend", 650)
	ui.pet_view = null
	ui.bond_label = null
	ui.preference_label = null
	if not cat.known:
		col.add_child(ui.paragraph("A little traveler is waiting to meet you. Discover a favorite room or send an invitation."))
		var portrait := Badge.new()
		portrait.locked = true
		portrait.custom_minimum_size = Vector2(88, 88) * float(ui.metrics.unit)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(portrait)
		var pack: String = Content.cat_pack(cat_index)
		var locked: bool = pack != "" and not ui.snapshot.life.entitlements.has(pack)
		var invite: Button = ui.button("Meet them in the expansion shop" if locked else "Invite this traveler", func():
			if locked: ui.open_route("Shop", "Pet")
			else: ui.command("invite", {"cat":cat_index})
		, true)
		invite.name = "CatExpansion" if locked else "InviteTraveler"
		invite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(invite)
		return
	ui.pet_view = PetView.new()
	ui.pet_view.name = "PettingView"
	ui.pet_view.cat_index = cat_index
	ui.pet_view.enabled_motion = ui.snapshot.settings.motion
	ui.pet_view.interacted.connect(func(kind): ui.command("interact", {"cat":cat_index, "kind":kind}))
	col.add_child(ui.pet_view)
	var trait_label: Label = ui.label(Content.CAT_TRAITS[cat_index], 21)
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(trait_label)
	ui.bond_label = ui.paragraph("♥ %d / 100 friendship" % cat.bond, 16, ui.INK)
	ui.bond_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ui.bond_label)
	var friendship := ProgressBar.new()
	friendship.name = "CareFriendship"
	friendship.show_percentage = false
	friendship.value = cat.bond
	friendship.custom_minimum_size.y = 10 * ui.metrics.unit
	friendship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	friendship.add_theme_stylebox_override("background", progress_style(Color("E9E1D2")))
	friendship.add_theme_stylebox_override("fill", progress_style(Color("F5A18F")))
	col.add_child(friendship)
	ui.preference_label = ui.paragraph("Loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[cat_index]] + "." if cat.preference else "Spend time together to learn a favorite comfort.")
	ui.preference_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ui.preference_label)
	var toys := GridContainer.new()
	toys.name = "toys"
	col.add_child(toys)
	var choices := [["Pet","pet"],["Brush","brush"],["Feather","wand"],["Yarn","yarn"],["Cushion","cushion"],["Box","box"]]
	for index in range(choices.size()):
		var item: Array = choices[index]
		var action := Tile.new()
		action.configure(ui, item[0], "", Art.toy(index), func(): ui.pet_view.play(item[1]))
		action.name = "Interact_" + item[1]
		action.accessibility_name = item[0]
		toys.add_child(action)
	var invite: Button = ui.button("Invite a friend  ›", func(): ui.open_route("Invitations", "Pet"))
	invite.name = "CatInvitations"
	col.add_child(invite)
	var favorite: Button = ui.button("♥  Hotel favorite" if ui.snapshot.life.favorite == cat_index else "♡  Make hotel favorite", func(): ui.command("favorite", {"cat":cat_index}))
	favorite.name = "CatFavorite"
	favorite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(favorite)
	col.add_child(ui.paragraph("Stroke your cat or hold gently for a little purr."))
	relayout(ui)

static func invitations(ui: Control, cat_index: int) -> void:
	var col: VBoxContainer = ui._base_sheet("Friends for " + Content.CAT_NAMES[cat_index], 650)
	var invite: Button = ui.button("Invite to this hotel", func(): ui.command("invite", {"cat":cat_index}), true)
	invite.name = "InviteHotel"
	invite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(invite)
	col.add_child(ui.paragraph("Playdates need an open lounge and 10 friendship with both cats. Spend a little time together to get acquainted."))
	for index in range(Content.CAT_NAMES.size()):
		if index == cat_index or not ui.snapshot.life.cats[index].known: continue
		var cat: Dictionary = ui.snapshot.life.cats[index]
		var ready: bool = ui.snapshot.levels[2] > 0 and cat.bond >= 10 and ui.snapshot.life.cats[cat_index].bond >= 10
		var action: Button = ui.button("Play with " + Content.CAT_NAMES[index], func(): ui.command("playdate", {"cat":cat_index, "other":index}))
		action.name = "Playdate_" + str(index)
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.disabled = not ready
		col.add_child(action)
		col.add_child(ui.paragraph("%d / 10 friendship · %s" % [mini(cat.bond,10), "Ready to play" if ready else "Getting acquainted"]))

static func relayout(ui: Control) -> void:
	if not is_instance_valid(ui.sheet): return
	var unit: float = ui.metrics.unit
	var large: bool = ui.metrics.font_scale >= 1.5
	for grid_name in ["CatCollection", "toys"]:
		var grid = ui.sheet.find_child(grid_name, true, false)
		if grid == null: continue
		var toy_columns: int = 2 if ui.metrics.font_scale>1.0 or ui._sheet_bounds().size.x/unit-40<328 else 3
		grid.columns = (1 if large else 2) if grid_name == "CatCollection" else toy_columns
		grid.add_theme_constant_override("h_separation", roundi(8 * unit))
		grid.add_theme_constant_override("v_separation", roundi(12 * unit))
	if ui.tab == "Pet" and is_instance_valid(ui.pet_view):
		ui.pet_view.custom_minimum_size = Vector2(48, 220) * unit

static func progress_style(color: Color) -> StyleBoxFlat:
	var surface := StyleBoxFlat.new()
	surface.bg_color = color
	surface.set_corner_radius_all(8)
	return surface
