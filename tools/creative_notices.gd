extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/creative-social")
	var file:=FileAccess.open("res://builds/creative-social/GODOT_NOTICES.txt",FileAccess.WRITE)
	file.store_string("GODOT ENGINE\n\n"+Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  "))
	for name in Engine.get_license_info(): file.store_string("\n\n"+str(name)+"\n\n"+str(Engine.get_license_info()[name]))
	file.close(); quit(0)
