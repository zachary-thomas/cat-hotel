extends SceneTree
## Rendered regression: sunlit turf must not acquire shadow-map stripes.
## Run with tools/test-creative.ps1 -Rendered -Suites test_creative_lighting.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Lighting regression requires -Rendered")
		quit(1)
		return
	root.size = Vector2i(900,1000)
	root.content_scale_size = root.size
	var model = load("res://scripts/creative/creative_model.gd").new()
	model.new_game(1000)
	model.state.settings.motion = false
	var world = load("res://scripts/creative/creative_world.gd").new()
	root.add_child(world)
	world.setup(model)
	world.set_world_rect(Rect2(0,0,900,1000))
	world.focus_hotel()
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	# Empty sunlit lawn above the starter hotel, away from geometry edges.
	# Neighbor differences reject the high-frequency self-shadow pattern while
	# allowing the material's gentle, low-frequency color variation.
	var variation := 0.0
	var samples := 0
	for y in range(80,140):
		for x in range(430,520):
			variation += absf(image.get_pixel(x,y).get_luminance()-image.get_pixel(x+1,y).get_luminance())
			samples += 1
	variation /= samples
	print("Sunlit lawn neighbor variation: %.6f" % variation)
	if variation > 0.008:
		failures += 1
		push_error("Sunlit lawn has striped self-shadows")
	# A real tree shadow must remain visibly darker than the adjacent lawn.
	var lit: float = image.get_pixel(590,100).get_luminance()
	var shaded: float = image.get_pixel(730,100).get_luminance()
	if lit-shaded < 0.10:
		failures += 1
		push_error("Cast tree shadows must remain visible")
	DirAccess.make_dir_recursive_absolute("res://tmp/lighting-verification")
	image.save_png("res://tmp/lighting-verification/meadow.png")
	world.free()
	print("CREATIVE LIGHTING: %d failures" % failures)
	quit(1 if failures else 0)
