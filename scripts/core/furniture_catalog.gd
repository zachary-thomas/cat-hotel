extends RefCounted

const Content = preload("res://scripts/core/game_content.gd")

const DEFINITIONS := {
	"mat": {"family":"sleep", "stats":[12,0,0], "footprint":[3,4], "layer":"floor", "approaches":[[3,2]], "pose":"rest", "target":[1.5,0.64,2.0], "sleep":true},
	"sun_cushion": {"family":"sleep", "stats":[28,0,8], "footprint":[3,4], "layer":"floor", "approaches":[[3,2]], "pose":"rest", "target":[1.5,0.82,2.0], "sleep":true},
	"cave": {"family":"sleep", "stats":[38,0,4], "footprint":[3,4], "layer":"floor", "approaches":[[3,2]], "pose":"loaf", "target":[1.5,0.64,2.0], "sleep":true},
	"heated": {"family":"sleep", "stats":[52,0,10], "footprint":[3,4], "layer":"floor", "approaches":[[3,2]], "pose":"rest", "target":[1.5,0.64,2.0], "sleep":true},
	"blanket": {"family":"sleep", "stats":[38,0,10], "footprint":[3,4], "layer":"floor", "approaches":[[3,2]], "pose":"blanket", "target":[1.5,0.66,2.0], "sleep":true},
	"box": {"family":"hide_play", "stats":[0,10,0], "footprint":[2,2], "layer":"floor", "approaches":[[-1,0],[2,0],[0,-1],[0,2]], "pose":"box", "target":[1.0,0.15,1.0]},
	"perch": {"family":"climb", "stats":[8,20,8], "footprint":[2,2], "layer":"floor", "approaches":[[-1,0],[2,0],[0,-1],[0,2]], "pose":"stretch", "target":[1.0,1.22,1.0]},
	"tunnel": {"family":"hide_play", "stats":[0,32,0], "footprint":[3,2], "layer":"floor", "approaches":[[-1,0],[3,0]], "pose":"pounce", "target":[1.5,0.15,1.0]},
	"tower": {"family":"climb", "stats":[6,42,6], "footprint":[2,2], "layer":"floor", "approaches":[[-1,0],[2,0],[0,-1],[0,2]], "pose":"stretch", "target":[1.0,1.48,1.0]},
	"table": {"family":"social", "stats":[8,18,10], "footprint":[2,3], "layer":"floor", "approaches":[[0,-1],[1,-1]], "pose":"sniff", "target":[1.0,0.72,1.5]},
	"plant": {"family":"greenery", "stats":[0,0,8], "footprint":[1,1], "layer":"floor"},
	"rug": {"family":"textile", "stats":[10,0,18], "footprint":[4,2], "layer":"rug"},
	"scratch": {"family":"scratch", "stats":[0,24,0], "footprint":[1,2], "layer":"floor", "approaches":[[-1,0],[1,0],[0,-1],[0,2]], "pose":"stretch", "target":[0.5,0.4,1.0]},
	"lamp": {"family":"lighting", "stats":[4,0,30], "footprint":[1,1], "layer":"floor"},
	"flowers": {"family":"greenery", "stats":[0,0,24], "footprint":[1,1], "layer":"floor"},
	"cloud_sofa": {"family":"seating", "stats":[32,8,14], "footprint":[3,2], "layer":"floor", "approaches":[[0,-1],[1,-1],[2,-1]], "pose":"loaf", "target":[1.5,0.58,1.0]},
	# The adventure tree target sits over the added upper-left platform after prototype fitting.
	"adventure_tree": {"family":"climb", "stats":[10,62,14], "footprint":[3,3], "layer":"floor", "approaches":[[-1,1],[3,1],[1,-1],[1,3]], "pose":"stretch", "target":[0.75,1.98,0.85]},
	"canopy_bed": {"family":"sleep", "stats":[72,0,24], "footprint":[4,4], "layer":"floor", "approaches":[[4,1],[4,2]], "pose":"rest", "target":[2.0,0.64,2.0], "sleep":true},
	"room_nightstand": {"name":"Room nightstand", "cost":0, "level":1, "tags":[], "family":"fixture", "stats":[0,0,0], "footprint":[1,1], "layer":"floor", "included":true},
	"suite_sofa": {"name":"Suite sofa", "cost":0, "level":1, "tags":["social"], "family":"seating", "stats":[18,4,6], "footprint":[3,2], "layer":"floor", "approaches":[[0,-1],[1,-1],[2,-1]], "pose":"loaf", "target":[1.5,0.58,1.0], "included":true},
	"suite_table": {"name":"Suite table", "cost":0, "level":1, "tags":[], "family":"fixture", "stats":[0,0,4], "footprint":[2,2], "layer":"floor", "included":true},
}

static func _build(id: String) -> Dictionary:
	if not DEFINITIONS.has(id):
		return {}
	var metadata: Dictionary = DEFINITIONS[id]
	var legacy: Dictionary = Content.find_item(id)
	var values: Array = metadata.stats
	var size: Array = metadata.footprint
	var approaches: Array[Vector2i] = []
	for cell in metadata.get("approaches", []):
		approaches.append(Vector2i(int(cell[0]), int(cell[1])))
	var target: Array = metadata.get("target", [0.0,0.0,0.0])
	return {
		"id": id,
		"name": str(metadata.get("name", legacy.get("name", id))),
		"cost": int(metadata.get("cost", legacy.get("cost", 0))),
		"level": int(metadata.get("level", legacy.get("level", 1))),
		"tags": Array(metadata.get("tags", legacy.get("tags", []))).duplicate(),
		"family": str(metadata.family),
		"stats": {"comfort":int(values[0]), "entertainment":int(values[1]), "atmosphere":int(values[2])},
		"footprint": Vector2i(int(size[0]), int(size[1])),
		"layer": str(metadata.layer),
		"interactive": not approaches.is_empty(),
		"approaches": approaches,
		"pose": str(metadata.get("pose", "")),
		"animation_target": Vector3(float(target[0]), float(target[1]), float(target[2])),
		"provides_sleep": bool(metadata.get("sleep", false)),
		"included_only": bool(metadata.get("included", false)),
		"bond": int(metadata.get("bond", legacy.get("bond", 0))),
	}

static func item(id: String) -> Dictionary:
	return _build(id)

static func all_items(include_fixtures: bool = false) -> Array:
	var result: Array = []
	for content_item in Content.FURNITURE:
		result.append(_build(str(content_item.id)))
	if include_fixtures:
		for id in ["room_nightstand", "suite_sofa", "suite_table"]:
			result.append(_build(id))
	return result
