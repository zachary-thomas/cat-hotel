extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/windows")
	var file = FileAccess.open("res://builds/windows/GODOT_NOTICES.txt", FileAccess.WRITE)
	file.store_string("GODOT ENGINE\n============\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHTS\n======================\n\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(), "  "))
	file.store_string("\n\nTHIRD-PARTY LICENSE TEXTS\n========================\n\n")
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		file.store_string(str(name) + "\n\n" + str(licenses[name]) + "\n\n")
	file.close()
	quit()
