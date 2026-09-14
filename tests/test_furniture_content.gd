extends SceneTree

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Quality = preload("res://scripts/core/room_quality.gd")
const Thumbnail = preload("res://scripts/ui/furniture_thumbnail.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func test_catalogue() -> void:
	var shop: Array = Catalog.all_items()
	var complete: Array = Catalog.all_items(true)
	check(shop.size() == 18, "Catalogue exposes exactly 18 obtainable types")
	check(complete.size() == 21, "Complete catalogue includes three fixtures")
	var ids := {}
	for definition in complete:
		check(not ids.has(definition.id), "Catalogue IDs are unique: " + definition.id)
		ids[definition.id] = true
		check(definition.footprint.x is int and definition.footprint.y is int and definition.footprint.x > 0 and definition.footprint.y > 0, "Footprints are positive integral cells: " + definition.id)
		check(definition.layer in ["floor", "rug"], "Layer is supported: " + definition.id)
		check(not definition.family.is_empty(), "Family is defined: " + definition.id)
		for axis in ["comfort", "entertainment", "atmosphere"]:
			check(definition.stats[axis] >= 0 and definition.stats[axis] <= 100, "Stats are bounded: " + definition.id + "/" + axis)
		if definition.interactive:
			check(not definition.approaches.is_empty(), "Interactive items have approach cells: " + definition.id)
			var target: Vector3 = definition.animation_target
			check(target.x > 0.0 and target.x < definition.footprint.x and target.z > 0.0 and target.z < definition.footprint.y, "Interactive target is inside the continuous footprint: " + definition.id)
			for rotation in range(4):
				var rotated: Vector2 = Vector2(target.x, target.z)
				var rotated_size: Vector2i = definition.footprint
				for turn in range(rotation):
					rotated = Vector2(rotated_size.y - rotated.y, rotated.x)
					rotated_size = Vector2i(rotated_size.y, rotated_size.x)
				check(rotated.x > 0.0 and rotated.x < rotated_size.x and rotated.y > 0.0 and rotated.y < rotated_size.y, "Rotated target stays inside its footprint: %s/%d" % [definition.id, rotation])
	check(Catalog.item("mat").cost == 0 and Catalog.item("mat").tags == [], "Starter mat preserves legacy price and tags")
	check(Catalog.item("heated").cost == 320 and Catalog.item("heated").tags == ["warm"], "Heated bed preserves legacy price and tags")
	check(Catalog.item("blanket").bond == 20 and Catalog.item("blanket").provides_sleep, "Friendship blanket preserves its gate and sleep capability")
	check(Catalog.item("adventure_tree").stats.entertainment == 62 and Catalog.item("canopy_bed").cost == 900, "Premium definitions use approved values")
	check(Catalog.item("mat").animation_target == Vector3(1.5,0.64,2.0), "Bed target uses the footprint center and mattress surface")
	check(Catalog.item("cloud_sofa").animation_target == Vector3(1.5,0.58,1.0), "Sofa target uses the fitted seat center")
	var tree_target: Vector3 = Catalog.item("adventure_tree").animation_target
	check(tree_target.x < 1.0 and tree_target.z < 1.0 and is_equal_approx(tree_target.y,1.98), "Adventure target follows its fitted upper-left platform")
	var surface_heights := {"mat":0.64,"sun_cushion":0.82,"cave":0.64,"heated":0.64,"blanket":0.66,"box":0.15,"perch":1.22,"tunnel":0.15,"tower":1.48,"table":0.72,"scratch":0.40,"cloud_sofa":0.58,"adventure_tree":1.98,"canopy_bed":0.64,"suite_sofa":0.58}
	for id in surface_heights:
		check(is_equal_approx(Catalog.item(id).animation_target.y, surface_heights[id]), "Animation target keeps its geometry support height: " + id)
	check(Catalog.item("room_nightstand").included_only and not shop.has(Catalog.item("room_nightstand")), "Included fixtures stay out of the shop")
	for id in ["cloud_sofa","adventure_tree","canopy_bed","room_nightstand","suite_sofa","suite_table"]:
		var thumbnail := Thumbnail.new()
		thumbnail.item_id = id
		check(thumbnail.custom_minimum_size == Vector2(56,56), "Thumbnail is available for catalogue and stored item: " + id)
		thumbnail.free()
	check(Catalog.item("unknown").is_empty(), "Unknown catalogue IDs are rejected")

func test_quality() -> void:
	var starter = [{"item":"mat"},{"item":"box"},{"item":"plant"}]
	var q: Dictionary = Quality.summarize(starter)
	check([q.comfort,q.entertainment,q.atmosphere,q.quality] == [12,10,8,10], "Starter scores")
	var upgraded = [{"uid":"bed","item":"heated"},{"uid":"box","item":"box"},{"uid":"plant","item":"plant"},{"uid":"scratch","item":"scratch"},{"uid":"rug","item":"rug"}]
	q = Quality.summarize(upgraded)
	check([q.comfort,q.entertainment,q.atmosphere,q.quality,q.income] == [62,34,36,46,1], "Actual makeover value")
	check(q.contributions.bed.comfort == 52 and q.contributions.rug.atmosphere == 18, "Contribution report uses stable UIDs")
	var plants = [{"item":"plant"},{"item":"plant"},{"item":"plant"}]
	var before: Dictionary = Quality.summarize(plants)
	plants.append({"item":"plant"})
	check(before.atmosphere == 14 and Quality.summarize(plants).atmosphere == 14, "Fourth plant adds zero")
	var replacement_before: Dictionary = Quality.summarize([{"item":"mat"},{"item":"sun_cushion"}])
	var replacement_after: Dictionary = Quality.summarize([{"item":"canopy_bed"},{"item":"sun_cushion"}])
	check(replacement_after.comfort - replacement_before.comfort == 52, "Replacement deltas recompute family diminishing returns")
	var capped := []
	for i in range(10):
		capped.append({"item":"canopy_bed"})
	check(Quality.summarize(capped).comfort == 100, "Axis scores clamp to 100")
	check(Quality.guest_fit(q, ["warm"], "warm") == 61, "Guest fit applies preference weights and matching tag bonus")
	check(Quality.guest_fit(q, [], "play") == 38, "Guest fit works without a tag bonus")

func run() -> void:
	test_catalogue()
	test_quality()
	print("FURNITURE CONTENT TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
