extends SceneTree

const Shared = preload("res://scripts/core/shared_layout.gd")
const Furniture = preload("res://scripts/core/furniture_layout.gd")
const Model = preload("res://scripts/core/hotel_model.gd")
const Builder = preload("res://scripts/world/room_builder.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)

func placed(uid: String, x: int, y: int, item: String = "plant") -> Dictionary:
	return {"uid":uid,"item":item,"hotel":0,"room":-2,"x":x,"y":y,"rotation":0}

func _initialize() -> void:
	var hotels := [{"owned":true,"wings":0,"layout":[
		{"kind":"regular","x":0,"y":9,"rotation":0},
		{"kind":"regular","x":6,"y":9,"rotation":2}]}]
	var data: Dictionary = Shared.data(hotels,0)
	check(data.kind == "shared" and Furniture.dimensions("shared") == Vector2i(20,42),"Shared grid spans the guest floor and main lobby at interior resolution")
	check(Shared.validate(data,[placed("f1",19,39)]).ok,"A usable part of the main lobby accepts furniture")
	check(Shared.validate(data,[placed("f1",19,39),placed("f2",19,39)]).code == "overlap","Shared furniture uses normal collision layers")
	check(Shared.validate(data,[placed("f1",1,19)]).code == "room_overlap","Furniture cannot overlap a room shell")
	check(Shared.validate(data,[placed("f1",1,1)]).code == "locked","Furniture cannot occupy an unrestored wing")
	check(Shared.validate(data,[placed("f1",8,21)]).code == "door_blocked","Furniture cannot block a bedroom entrance")
	check(Shared.validate(data,[placed("f1",9,30)]).code == "circulation_blocked","Furniture cannot block the fixed lobby route")
	check(Shared.validate(data,[placed("f1",3,27)]).code == "fixed_overlap","Furniture cannot overlap the public lounge furniture")
	check(Shared.validate(data,[placed("f1",18,32)]).code == "fixed_overlap","The right lobby divider rejects intersecting furniture")
	check(Shared.validate(data,[placed("f1",15,38)]).code == "circulation_blocked","Public play routine keeps its swept body corridor")
	check(not Shared.validate(data,[placed("f1",18,39)]).ok,"Public route clearance also protects its endpoint")
	check(Shared.validate(data,[placed("f1",19,41)]).code == "outside","The grid cannot authorize furniture beyond the front wall")
	check(not Shared.validate(data,[placed("f1",19,40)]).ok,"A footprint crossing the front wall is blocked")
	check(Shared.validate(data,[placed("f1",12,25)]).code == "fixed_overlap","The dining counter overhang is protected")
	var open_cells := 0
	var masks: Dictionary=Shared._masks(data)
	for y in range(24,40):
		for x in range(20):
			if Shared._reason_with(data,Vector2i(x,y),masks).is_empty(): open_cells+=1
	print("SAFE LOBBY FURNITURE CELLS: ",open_cells)
	check(open_cells>=20,"Safety masks retain useful lobby decorating space")
	var medium_spaces := 0
	for y in range(24,39):
		for x in range(18):
			var fits := true
			for dy in range(2):
				for dx in range(3):
					if not Shared._reason_with(data,Vector2i(x+dx,y+dy),masks).is_empty(): fits=false
			if fits: medium_spaces+=1
	print("SAFE LOBBY 3x2 FOOTPRINT POSITIONS: ",medium_spaces)
	check(medium_spaces>0,"The lobby retains space for furniture larger than one cell")

	var point := Vector2(19.5,39.5)
	check(Furniture.world_to_local(data,Furniture.local_to_world(data,point)).is_equal_approx(point),"Shared local/world coordinates are canonical inverses")
	var guest := {"kind":"regular","x":0,"y":9,"rotation":0}
	check(Furniture.validate(guest,[{"uid":"bed","item":"mat","hotel":0,"room":0,"x":0,"y":0,"rotation":0}]).ok,"Shared support leaves guest-room rules unchanged")
	var model=Model.new(); model.new_game(1000)
	var builder=Builder.new(); root.add_child(builder); builder.sync(model)
	check(builder.renderer(-2)!=null,"RoomBuilder exposes a stable shared-space renderer")
	var draft: Array=[placed("draft:shared:0",19,39)]
	check(builder.show_draft(-2,draft)==builder.renderer(-2) and builder.renderer(-2).objects.has("draft:shared:0"),"Shared drafts render through UID-stable furniture objects")
	builder.clear_draft()
	check(not builder.renderer(-2).objects.has("draft:shared:0"),"Clearing a shared draft restores committed presentation")
	builder.free()
	print("SHARED LAYOUT TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)

