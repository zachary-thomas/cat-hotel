extends RefCounted
const Journal = preload("res://scripts/core/save_journal.gd")
const Session = preload("res://scripts/core/build_session.gd")
var journal
var error_message := ""
func _init(path: String) -> void:
	journal = Journal.new(path + "-draft")
	journal.candidates()
func save_session(session) -> bool:
	var ok: bool = journal.write(session.serialize())
	error_message = "" if ok else "Couldn't save your makeover draft. Keep the game open and try again."
	return ok
func clear() -> bool:
	return journal.clear()
func recover(model) -> Dictionary:
	var last := {}
	for entry in journal.candidates():
		var session = Session.new()
		var result: Dictionary = session.restore(entry.state,model)
		if result.ok: return {"ok":true,"session":session,"message":"Resume your room makeover?"}
		if result.code == "already_applied":
			clear()
			return {}
		last = result
	return last
