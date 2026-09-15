extends RefCounted
const Grounds = preload("res://scripts/core/grounds_model.gd")
const Life = preload("res://scripts/ui/views/life_views.gd")

static func garden(ui: Control) -> void:
	ui.grounds_buttons.clear()
	var col: VBoxContainer = ui._base_sheet("The garden & neighborhood",650)
	col.add_child(ui.art("grounds",150*ui.metrics.unit))
	col.add_child(ui.paragraph("Favorite places for little paws. Every open amenity adds Cat Coins at this hotel."))
	var state: Dictionary = ui.snapshot.grounds.hotels[ui.snapshot.hotel]
	col.add_child(Life.action(ui,"Arrange the garden",func(): ui.garden_edit_requested.emit(""),true))
	col.add_child(Life.heading(ui,"Room to grow"))
	col.add_child(ui.paragraph("Open land to the west, east or behind your hotel, in any order. Move amenities onto your new grounds for free."))
	for plot in Grounds.Garden.PLOTS:
		var owned: bool=state.get("plots",[]).has(plot.id)
		var button: Button = ui.grounds_button(plot.name+" · "+("Open" if owned else str(plot.cost)+" Cat Coins"),"expand_plot",{"id":plot.id})
		button.name="ExpandPlot_"+plot.id; button.disabled=owned or ui.snapshot.coins<plot.cost
		col.add_child(button)
	for item in Grounds.AMENITIES:
		var box := Life.card(ui,col)
		box.add_child(ui.art(item.id,88*ui.metrics.unit))
		box.add_child(Life.heading(ui,item.name))
		box.add_child(ui.paragraph("+%d Cat Coins / min · Hotel level %d" % [item.rate,item.level]))
		box.add_child(ui.grounds_button("Open for guests" if state.amenities.has(item.id) else "Open · %d Cat Coins" % item.cost,"amenity",{"id":item.id},true))
		box.add_child(Life.action(ui,"About this amenity  ›",func(): ui.open_amenity(item.id)))
	col.add_child(Life.action(ui,"Explore as the manager",func(): ui.manager_mode_requested.emit(true),true))
	col.add_child(Life.action(ui,"Visit Paw Mart",func(): ui.open_route("Kiosk","Grounds")))
	ui._update_grounds(ui.snapshot)

static func amenity(ui: Control) -> void:
	ui.grounds_buttons.clear()
	var item: Dictionary = Grounds.amenity(ui.selected_amenity)
	var col: VBoxContainer = ui._base_sheet(item.name,650)
	col.add_child(ui.art(item.id,160*ui.metrics.unit))
	var box := Life.card(ui,col,Color("E3F3E9"))
	box.add_child(ui.paragraph(item.copy))
	box.add_child(Life.heading(ui,"+%d Cat Coins / min" % item.rate))
	if ui.snapshot.grounds.hotels[ui.snapshot.hotel].amenities.has(item.id):
		box.add_child(ui.paragraph("Open for guests. Watch the cats make themselves at home."))
		var move := Life.action(ui,"Move this amenity · Free",func(): ui.garden_edit_requested.emit(item.id),true)
		move.name="MoveOwnedAmenity"; box.add_child(move)
	else:
		box.add_child(ui.paragraph("%d Cat Coins · Hotel level %d required" % [item.cost,item.level]))
		box.add_child(ui.grounds_button("Open · %d Cat Coins" % item.cost,"amenity",{"id":item.id},true))
	col.add_child(Life.action(ui,"All amenities",func(): ui.open_route("Grounds","Life")))
	ui._update_grounds(ui.snapshot)

static func manager(ui: Control) -> void:
	ui.grounds_buttons.clear()
	var col: VBoxContainer = ui._base_sheet("A little help around the hotel",650)
	var state: Dictionary = ui.snapshot.grounds.hotels[ui.snapshot.hotel]
	var current := Life.card(ui,col,Color("FFF1D6"))
	current.add_child(ui.art("manager",88*ui.metrics.unit))
	ui.job_status = ui.paragraph("")
	current.add_child(ui.job_status)
	current.add_child(Life.action(ui,"Stop directing the manager" if ui.manager_mode else "Control the manager",func(): ui.manager_mode_requested.emit(not ui.manager_mode),true))
	col.add_child(ui.paragraph("You’re the cat in the coral vest. Choose a job or tap a bush, mouse or untidy room to help."))
	for index in range(2):
		var box := Life.card(ui,col,Color("E3F3E9"))
		box.add_child(ui.grounds_button("Trim %s bush · +15 Cat Coins" % ("front" if index == 0 else "poolside"),"trim",{"index":index}))
	var chase := Life.card(ui,col,Color("F1EBFA"))
	chase.add_child(ui.grounds_button("Chase the mouse · +12 Cat Coins","chase"))
	var dirty: int = 0
	for room in range(ui.snapshot.rooms):
		if state.dirty[room]:
			dirty += 1
			col.add_child(ui.grounds_button("Tidy room %d · +10 Cat Coins" % (room+1),"clean",{"index":room}))
	col.add_child(ui.paragraph("%d rooms need tidying. %d rooms cleaned so far." % [dirty,state.cleaned]))
	var daisy := Life.card(ui,col,Color("F1EBFA"))
	daisy.name = "DaisyCard"
	daisy.add_child(ui.art("staff",115*ui.metrics.unit))
	daisy.add_child(Life.heading(ui,"A helping paw from Daisy"))
	if state.maid:
		ui.maid_status = ui.paragraph("")
		daisy.add_child(ui.maid_status)
		daisy.add_child(ui.paragraph("Daisy sweeps untidy rooms automatically, leaving you free to manage the garden."))
	else:
		daisy.add_child(ui.paragraph("Housekeeping opens at hotel level 3. Hire Daisy once for 600 Cat Coins."))
		daisy.add_child(ui.grounds_button("Hire Daisy · 600 Cat Coins","hire_maid",{},true))
	ui._update_grounds(ui.snapshot)

static func kiosk(ui: Control) -> void:
	ui.grounds_buttons.clear()
	var col: VBoxContainer = ui._base_sheet("Paw Mart",650)
	col.add_child(ui.art("kiosk",155*ui.metrics.unit))
	col.add_child(ui.paragraph("A little shop on your doorstep. Everything here uses earned Cat Coins."))
	var picnic := Life.card(ui,col,Color("FFF1D6"))
	picnic.add_child(Life.heading(ui,"Treats for the neighbors"))
	picnic.add_child(ui.paragraph("A 25-second picnic adds 3 friendship for your favorite. Available every two minutes."))
	picnic.add_child(ui.grounds_button("Share treats · 30 Cat Coins","treats",{},true))
	col.add_child(Life.action(ui,"Shop garden amenities",func(): ui.open_route("Grounds","Kiosk")))
	col.add_child(Life.action(ui,"Hire a housekeeping cat",func(): ui.open_route("Manager","Kiosk")))
	col.add_child(Life.heading(ui,"Found any loose yarn?"))
	col.add_child(ui.paragraph("Collect colorful yarn around the grounds for 5 Cat Coins each. More appear after 35 seconds."))
	for index in range(3): col.add_child(ui.grounds_button("Collect %s yarn · +5 Cat Coins" % ["pink","purple","gold"][index],"yarn",{"index":index}))
	ui._update_grounds(ui.snapshot)
