extends RefCounted
## Schema-neutral two-slot journal. Callers validate candidates before using their state.
var path: String
var sequence: int = 0
var error_message: String = ""
func _init(file_path: String) -> void:
	path = file_path

func write(data: Dictionary) -> bool:
	var next: int = sequence+1
	var payload: String = JSON.stringify(data)
	var envelope: Dictionary = {"sequence":next,"payload":payload,"sha256":payload.sha256_text()}
	var slot: String = path+"."+str(next%2)+".json"
	var file = FileAccess.open(slot+".tmp",FileAccess.WRITE)
	if file==null:
		error_message = "Couldn't save your hotel. Check available storage."
		return false
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status!=OK:
		error_message = "The save couldn't finish. Your previous save is safe."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(slot+".tmp"),ProjectSettings.globalize_path(slot))!=OK:
		error_message = "Couldn't commit your save. Please try again."
		return false
	sequence = next
	error_message = ""
	return true

func candidates() -> Array:
	var result: Array = []
	for index in range(2):
		var file = FileAccess.open(path+"."+str(index)+".json",FileAccess.READ)
		if file==null: continue
		var parser = JSON.new()
		var error: Error = parser.parse(file.get_as_text())
		file.close()
		if error!=OK: continue
		var envelope = parser.data
		if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("sha256") is String: continue
		var seq = envelope.get("sequence")
		if not (seq is int or seq is float) or not is_finite(float(seq)) or seq<1 or seq>9000000000000000 or floor(float(seq))!=float(seq): continue
		if envelope.payload.sha256_text()!=envelope.sha256 or parser.parse(envelope.payload)!=OK: continue
		if parser.data is Dictionary: result.append({"sequence":int(seq),"state":parser.data})
	result.sort_custom(func(a,b): return a.sequence>b.sequence)
	if not result.is_empty(): sequence = maxi(sequence,result[0].sequence)
	return result

func clear() -> bool:
	var success: bool = true
	for index in range(2):
		for suffix in [".json",".json.tmp"]:
			var file: String = path+"."+str(index)+suffix
			if FileAccess.file_exists(file) and DirAccess.remove_absolute(ProjectSettings.globalize_path(file))!=OK: success = false
	if success: sequence = 0
	else: error_message = "Couldn't discard the saved makeover."
	return success
