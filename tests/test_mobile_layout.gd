extends SceneTree

var failures: int = 0

class FailingStore:
	extends RefCounted
	var error_message: String = "Simulated settings save failure"
	func save_model(_model) -> bool:
		return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in ["res://scripts/ui/phone_layout.gd", "res://scripts/ui/playful_theme.gd"]:
		check(ResourceLoader.exists(path), "Mobile foundation exists: " + path)
	if failures:
		finish()
		return
	var Layout = load("res://scripts/ui/phone_layout.gd")
	var PlayfulTheme = load("res://scripts/ui/playful_theme.gd")
	for phone in [Vector2(360,640), Vector2(360,800), Vector2(390,844), Vector2(430,932)]:
		var scale: float = phone.x / 450.0
		var viewport: Vector2 = phone / scale
		for text_scale in [1.0, 1.25, 1.5]:
			var safe := Rect2(Vector2(12,32) / scale, (phone - Vector2(24,56)) / scale)
			var m: Dictionary = Layout.measure(viewport, safe, scale, text_scale)
			check(m.target * scale >= 48.0, "Minimum target measured in phone units")
			for key in ["header_rect", "footer_rect", "objective_rect", "world_rect", "content_rect"]:
				check(safe.encloses(m[key]), "Safe-area containment: " + key)
			check(not m.world_rect.intersects(m.footer_rect), "World excludes dock")
	var desktop_safe := Rect2(24, 18, 1232, 752)
	var desktop: Dictionary = Layout.measure(Vector2(1280, 800), desktop_safe, 1.0, 1.5)
	for key in ["header_rect", "footer_rect", "objective_rect", "world_rect", "content_rect"]:
		check(desktop_safe.encloses(desktop[key]), "Desktop inset containment: " + key)
	check(desktop.target >= 48 and not desktop.world_rect.intersects(desktop.footer_rect), "Desktop layout preserves targets and dock exclusion")
	var tiny: Dictionary = Layout.measure(Vector2(32, 24), Rect2(4, 5, 3, 2), 0.8, 1.5)
	for key in ["header_rect", "footer_rect", "objective_rect", "world_rect", "content_rect"]:
		check(tiny[key].size.x >= 0 and tiny[key].size.y >= 0, "Invalid geometry clamps: " + key)
		check(tiny.safe_rect.encloses(tiny[key]), "Clamped geometry remains safe: " + key)
	check(tiny.font_scale == 1.5 and is_equal_approx(tiny.unit, 1.25), "Scale inputs are normalized")

	check(PlayfulTheme.INK == Color("24483e") and PlayfulTheme.MINT == Color("5cc8a1") and PlayfulTheme.CORAL == Color("f5a18f") and PlayfulTheme.GOLD == Color("ffcc68"), "Playful controls use the specified accessible palette")
	var normal: StyleBoxFlat = PlayfulTheme.button_style(PlayfulTheme.MINT, 2.0)
	var pressed: StyleBoxFlat = PlayfulTheme.button_style(PlayfulTheme.MINT, 2.0, true)
	var focus: StyleBoxFlat = PlayfulTheme.focus_style(2.0)
	check(normal.shadow_offset.y == 6 and pressed.shadow_offset.y == 2, "Pressed buttons reduce their lower edge from three to one phone units")
	check(focus.border_width_left == 6 and focus.border_color == PlayfulTheme.INK, "Focused buttons have a three-unit dark-pine outline")

	var UI = load("res://scripts/ui/mobile_ui.gd")
	var ui = UI.new()
	for phone_width in [360,390,430,1280]:
		var phone_scale := float(phone_width)/450.0
		for text_scale in [1.0,1.25,1.5]:
			ui.metrics = {"unit":1.0/phone_scale,"font_scale":text_scale}
			for minimum in [12,14,16]:
				check(ui._scaled_font_size(minimum)*phone_scale>=minimum*text_scale,"Fractional conversion preserves exact physical text minimum")
	ui.metrics = {"unit": 1.25, "font_scale": 1.5}
	var scaled_label: Label = ui.label("Scaled", 16)
	var canvas_label: Label = ui.canvas_label("Canvas", 16, PlayfulTheme.INK)
	var canvas_paragraph: Label = ui.canvas_paragraph("Canvas body", 16, PlayfulTheme.SECONDARY_INK)
	var minimum_paragraph: Label = ui.paragraph("Readable body", 15)
	var primary: Button = ui.button("Open hotel", func(): pass, true)
	check(scaled_label.get_theme_font_size("font_size") == 30, "Labels convert phone units and global text scale")
	check(canvas_label.get_theme_font_size("font_size") == 16 and canvas_paragraph.get_theme_font_size("font_size") == 16, "Canvas helpers preserve Build's converted text sizes")
	check(minimum_paragraph.get_theme_font_size("font_size") == 30, "Body helper enforces the 16-phone-unit minimum")
	check(primary.custom_minimum_size == Vector2(60, 70), "Primary buttons convert the 48 by 56 phone-unit target")
	check(primary.accessibility_name == "Open hotel", "Buttons expose a readable accessibility name")
	check(primary.get_theme_color("font_color") == PlayfulTheme.INK and primary.get_theme_color("font_hover_color") == PlayfulTheme.INK and primary.get_theme_color("font_pressed_color") == PlayfulTheme.INK, "Light primary buttons retain dark ink in every state")
	scaled_label.free()
	canvas_label.free()
	canvas_paragraph.free()
	minimum_paragraph.free()
	primary.free()
	ui.free()

	await check_live_relayout(UI)

	var Model = load("res://scripts/core/hotel_model.gd")
	var source = Model.new()
	source.new_game(1000)
	var old_save: Dictionary = source.serialize()
	old_save.settings.erase("build_text_scale")
	old_save.settings.erase("ui_text_scale")
	var restored = Model.new()
	check(restored.restore(old_save) and restored.settings.ui_text_scale == 1.0 and restored.settings.build_text_scale == 1.0, "Old saves without a scale use the default")
	var build_only: Dictionary = source.serialize()
	build_only.settings.build_text_scale = 1.5
	build_only.settings.erase("ui_text_scale")
	check(restored.restore(build_only) and restored.settings.ui_text_scale == 1.5 and restored.settings.build_text_scale == 1.5, "Build-only saves migrate their scale to the global preference")
	var separate: Dictionary = source.serialize()
	separate.settings.build_text_scale = 1.25
	separate.settings.ui_text_scale = 1.5
	check(restored.restore(separate) and restored.settings.ui_text_scale == 1.5 and restored.settings.build_text_scale == 1.25, "New saves restore both scale preferences")
	for invalid in [0, 2, NAN, true, "1.25"]:
		var corrupt: Dictionary = source.serialize()
		corrupt.settings.ui_text_scale = invalid
		var before: Dictionary = restored.serialize()
		check(not restored.restore(corrupt) and restored.serialize() == before, "Invalid global text scale is rejected atomically: " + str(invalid))

	await check_controller_transaction(Model)
	finish()

func check_controller_transaction(Model) -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var path := "res://tmp/mobile-settings-%d" % Time.get_ticks_usec()
	var app = load("res://scenes/main.tscn").instantiate()
	app.save_path = path
	root.add_child(app)
	await process_frame
	app.start_game()
	app.active = false
	var initial_title_size: int = app.ui.title_label.get_theme_font_size("font_size")
	app.change_setting("ui_text_scale", 1.5)
	var reloaded = Model.new()
	check(app.model.settings.ui_text_scale == 1.5 and app.model.settings.build_text_scale == 1.5, "Global text size updates both preferences in one controller transaction")
	check(app.store.load_model(reloaded, int(Time.get_unix_time_from_system())) and reloaded.settings.ui_text_scale == 1.5 and reloaded.settings.build_text_scale == 1.5, "Global text size reloads from the committed save")
	check(app.ui.metrics.font_scale == 1.5, "Committed text size recalculates shared UI metrics")
	check(app.ui.title_label.get_theme_font_size("font_size") > initial_title_size and app.ui.title_label.get_theme_font_size("font_size") == ceili(16 * app.ui.metrics.unit * 1.5), "Global text size updates the 16-unit hotel identity in place")
	app.build_panel.open(0)
	await process_frame
	var build_title: Label = app.build_panel.get_node("BuildHeader").get_child(0)
	check(build_title.get_theme_font_size("font_size") == ceili(17 * app.build_panel._font_scale), "Build title consumes its already-converted canvas size once")
	var real_store = app.store
	app.store = FailingStore.new()
	app.change_setting("ui_text_scale", 1.25)
	check(app.model.settings.ui_text_scale == 1.5 and app.model.settings.build_text_scale == 1.5, "Failed settings save rolls back both values")
	app.store = real_store
	app.save_error = ""
	app.change_setting("ui_text_scale", 1.25)
	build_title = app.build_panel.get_node("BuildHeader").get_child(0)
	check(app.build_panel._font_scale == 1.25 * app.build_panel.metrics.unit and build_title.get_theme_font_size("font_size") == ceili(17 * app.build_panel._font_scale), "Committed global text size relayouts a visible builder without double scaling")
	app.change_setting("build_text_scale", 1.5)
	check(app.model.settings.ui_text_scale == 1.25 and app.model.settings.build_text_scale == 1.5, "Legacy Build-only changes preserve the global preference")
	app.build_panel.close()
	app.soundscape.shutdown()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	preload("res://scripts/core/save_journal.gd").new(path).clear()

func check_live_relayout(UI) -> void:
	var BuildMetrics = load("res://scripts/ui/build_metrics.gd")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(450, 900)
	root.add_child(viewport)
	var live_ui = UI.new()
	viewport.add_child(live_ui)
	await process_frame
	check(live_ui.metrics.safe_rect == BuildMetrics.safe_area(live_ui) and is_equal_approx(live_ui.metrics.unit, 1.0 / BuildMetrics.phone_scale(live_ui)), "MobileUI reuses BuildMetrics safe-area and phone-scale conversion")
	var settings: Button = live_ui.find_child("SettingsButton", true, false)
	check(settings.custom_minimum_size.x >= 48 * live_ui.metrics.unit, "Live relayout preserves the header settings target")
	var shell_size_before: Vector2 = live_ui.header.size
	var normal_before: StyleBox = live_ui.theme.get_stylebox("normal", "Button")
	viewport.size = Vector2i(1280, 800)
	await process_frame
	await process_frame
	check(live_ui.metrics.viewport == Vector2(1280, 800) and live_ui.header.size != shell_size_before and live_ui.header.size == live_ui.metrics.safe_rect.size, "1280 by 800 viewport change reflows the existing MobileUI shell")
	var normal: StyleBoxFlat = live_ui.theme.get_stylebox("normal", "Button")
	check(normal != normal_before and normal.corner_radius_top_left == roundi(18 * live_ui.metrics.unit), "Viewport change reapplies metric-dependent theme styles")
	viewport.queue_free()
	await process_frame

func finish() -> void:
	print("MOBILE LAYOUT TESTS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
