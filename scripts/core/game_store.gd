extends RefCounted
## Two-slot model journal; schema validation and time reconciliation belong here.
const Journal = preload("res://scripts/core/save_journal.gd")
var path: String
var sequence: int = 0
var error_message: String = ""

func _init(save_path: String = "user://hotel-save") -> void:
	path = save_path

func save_model(model) -> bool:
	var journal = Journal.new(path)
	journal.sequence = sequence
	var success: bool = journal.write(model.serialize())
	error_message = journal.error_message
	if success: sequence = journal.sequence
	return success

func load_model(model, now: int) -> bool:
	var journal = Journal.new(path)
	for candidate in journal.candidates():
		if model.restore(candidate.state):
			sequence = candidate.sequence
			model.reconcile(now)
			error_message = ""
			return true
	if FileAccess.file_exists(path+".0.json") or FileAccess.file_exists(path+".1.json"):
		error_message = "Your save couldn't be read. It has been kept for recovery."
	return false
