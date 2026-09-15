extends SceneTree
const Model = preload("res://scripts/creative/creative_model.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func guest(id: int, point: Vector2) -> Dictionary:
	return {"cat":id,"name":"Miso" if id==0 else "Clover","position":point,"phase":"idle","action":"rest","time":2.0,"venue":"","checked_in":true,"preference":"sunny","friend":1-id,"velocity":Vector2.ZERO}

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/creative/creative_moments.gd"):
		check(false,"Nearby cats need an ordered, cancellable conversation timeline")
		quit(1); return
	var model = Model.new(); model.new_game(1000)
	model.hotel().rooms.clear(); model.hotel().objects.clear(); model._invalidate()
	model.social.agents = {0:guest(0,Vector2.ZERO),1:guest(1,Vector2(1.5,0))}
	var moments = load("res://scripts/creative/creative_moments.gd").new()
	for step in range(300):
		moments.advance(0.1,model)
		if not moments.active.is_empty(): break
	check(not moments.active.is_empty(),"Eligible nearby cats start a conversation")
	if moments.active.is_empty(): quit(1); return
	var first: Dictionary = moments.speech()
	check(not String(first.get("text","")).is_empty() and int(first.get("speaker",-1))==0,"First cat speaks a readable line")
	check(moments.holds(0) and moments.holds(1),"Both idle participants have a temporary social window")
	var saw_reply := false
	for step in range(50):
		moments.advance(0.1,model)
		var line: Dictionary = moments.speech()
		if int(line.get("speaker",-1))==1: saw_reply=true
	check(saw_reply,"Second cat replies rather than repeating the first speaker")
	var serial: int = moments.serial
	for step in range(350): moments.advance(0.1,model)
	check(moments.serial==serial,"Participant cooldown prevents another immediate exchange")
	check(not moments.holds(0),"Finishing releases the social window")
	for step in range(1200):
		moments.advance(0.1,model)
		if not moments.active.is_empty(): break
	check(not moments.active.is_empty(),"Pair can converse again after cooldown")
	model.social.agents[1].phase="walk"
	moments.advance(0.1,model)
	check(moments.active.is_empty() and not moments.holds(0),"A new walk cancels speech and releases the partner")
	moments.reset(); model.social.agents.erase(1)
	for step in range(400): moments.advance(0.1,model)
	check(moments.active.is_empty(),"A lone cat never invents a conversation partner")
	model.social.agents[1]=guest(1,Vector2(8,0)); moments.reset()
	for step in range(400): moments.advance(0.1,model)
	check(moments.active.is_empty(),"Distant cats do not speak across the lot")
	model.social.agents[1].position=Vector2(1.5,0)
	model.hotel().rooms=[{"id":"wall","kind":"regular","x":1,"y":-1,"w":4,"h":4,"rotation":0,"paid":0}]
	model._invalidate(); moments.reset()
	for step in range(400): moments.advance(0.1,model)
	check(moments.active.is_empty(),"Cats in different enclosed rooms cannot converse through a wall")
	model.hotel().rooms.clear(); model._invalidate(); moments.reset()
	for step in range(300):
		moments.advance(0.1,model)
		if not moments.active.is_empty(): break
	model.revision+=1; moments.advance(0.1,model)
	check(moments.active.is_empty(),"A layout revision invalidates the active moment")
	check(int(model.hotel().visits)==0,"Decorative conversations never award visits")
	# Exercise the real scheduler and actor integration, not just a standalone timeline.
	var natural=Model.new(); natural.new_game(1000)
	for step in range(2400):
		natural.advance(0.1)
		if not natural.social.moments.active.is_empty(): break
	check(not natural.social.moments.active.is_empty(),"An ordinary starter hotel produces an actual conversation")
	if not natural.social.moments.active.is_empty():
		var participant: int=int(natural.social.moments.active.participants[0])
		var remaining: float=float(natural.social.agents[participant].time)
		var original_phase: String=String(natural.social.agents[participant].phase)
		var visit_count: int=int(natural.hotel().visits)
		var position: Vector2=natural.social.agents[participant].position
		natural.advance(0.5)
		check(is_equal_approx(float(natural.social.agents[participant].time),remaining),"A social pause preserves the underlying activity timer")
		check(Vector2(natural.social.agents[participant].position)==position,"A social pause keeps the reserved cat position")
		natural.social.moments.cancel(); natural.advance(0.1)
		check(float(natural.social.agents[participant].time)<remaining or String(natural.social.agents[participant].phase)!=original_phase,"The original activity resumes or finishes when the conversation ends")
		check(int(natural.hotel().visits)>=visit_count,"Conversation cancellation does not roll back visit accounting")
	print("CREATIVE MOMENTS: %d failures" % failures)
	quit(1 if failures else 0)
