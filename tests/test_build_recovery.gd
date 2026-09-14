extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	check(ResourceLoader.exists("res://scripts/core/save_journal.gd"),"Shared checksummed journal exists")
	if failures: quit(1); return
	var Journal = load("res://scripts/core/save_journal.gd")
	var path: String = "res://tmp/draft-journal-test-"+str(Time.get_ticks_usec())
	var journal = Journal.new(path)
	check(journal.write({"draft":"first","coins_spent":0}),"First draft writes")
	check(journal.write({"draft":"second","coins_spent":0}),"Second draft writes")
	var candidates: Array = Journal.new(path).candidates()
	check(candidates.size()==2 and candidates[0].state.draft=="second","New process reads latest draft first")
	var file = FileAccess.open(path+".0.json",FileAccess.WRITE)
	file.store_string("interrupted write")
	file.close()
	candidates = Journal.new(path).candidates()
	check(candidates.size()==1 and candidates[0].state.draft=="first","Corrupt latest draft leaves prior draft recoverable")
	check(journal.clear() and Journal.new(path).candidates().is_empty(),"Discard removes this draft profile's slots")
	var failure = Journal.new("res://tmp/missing-journal-directory/unwritable")
	check(not failure.write({"draft":"not saved"}) and failure.error_message!="","Write failure is explicit")
	var Model = preload("res://scripts/core/hotel_model.gd")
	var Session = preload("res://scripts/core/build_session.gd")
	var Drafts = preload("res://scripts/core/build_draft_store.gd")
	var model = Model.new(); model.new_game(1000)
	var session = Session.new(); session.begin(model,0,0,"recovery-profile")
	check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok,"Recoverable staged purchase")
	var primary = Drafts.new(path+"-play")
	var preview = Drafts.new(path+"-commerce")
	check(primary.save_session(session) and preview.save_session(session),"Separate profiles write separate journals")
	var corrupt: Dictionary = session.serialize(); corrupt.original=[1]
	primary.journal.write(corrupt)
	check(Drafts.new(path+"-play").recover(model).get("ok",false),"Semantically corrupt latest draft falls back to the valid older draft")
	check(primary.clear() and not preview.recover(model).is_empty(),"Discarding one profile preserves the other")
	check(model.furniture.apply(model,session.patch()).ok,"Makeover commits a durable edit receipt")
	check(preview.recover(model).is_empty(),"Recovery ignores a previously applied receipt")
	print("BUILD RECOVERY TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(1 if failures else 0)
