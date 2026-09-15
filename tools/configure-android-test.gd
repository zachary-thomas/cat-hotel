extends SceneTree
## Configure only the isolated Android preview copy, never the source project.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected Android debug template, version name and version code")
		quit(1)
		return
	var project := ConfigFile.new()
	var presets := ConfigFile.new()
	if project.load("res://project.godot") != OK or presets.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	project.set_value("application", "config/name", "Purrington Hotel Preview")
	project.set_value("rendering", "textures/vram_compression/import_etc2_astc", true)
	project.set_value("editor_plugins", "enabled", PackedStringArray())
	# Native commerce plugins are not part of the creative test app.
	var translations := PackedStringArray()
	for path in project.get_value("internationalization", "locale/translations", PackedStringArray()):
		if not str(path).begins_with("res://addons/"):
			translations.append(path)
	project.set_value("internationalization", "locale/translations", translations)
	var options := ""
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") == "Android Test":
			options = section + ".options"
	if options.is_empty():
		push_error("Android Test export preset is missing")
		quit(1)
		return
	presets.set_value(options, "custom_template/debug", args[0])
	presets.set_value(options, "version/name", args[1])
	presets.set_value(options, "version/code", int(args[2]))
	if project.save("res://project.godot") != OK or presets.save("res://export_presets.cfg") != OK:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/licenses")
	var notices := FileAccess.open("res://assets/licenses/GODOT_NOTICES.txt", FileAccess.WRITE)
	if notices == null:
		quit(1)
		return
	notices.store_string("GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\n" + JSON.stringify(Engine.get_copyright_info(), "  "))
	for name in Engine.get_license_info():
		notices.store_string("\n\n" + str(name) + "\n\n" + str(Engine.get_license_info()[name]))
	notices.close()
	quit(0)
