extends RefCounted

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const AXES := ["comfort", "entertainment", "atmosphere"]
const WEIGHTS := [1.0, 0.5, 0.25]
const FIT_WEIGHTS := {
	"sunny":[0.45,0.15,0.40], "explore":[0.20,0.60,0.20],
	"play":[0.15,0.70,0.15], "quiet":[0.65,0.10,0.25],
	"food":[0.30,0.30,0.40], "social":[0.25,0.45,0.30],
	"warm":[0.60,0.10,0.30],
}

static func summarize(instances: Array) -> Dictionary:
	var totals := {"comfort":0, "entertainment":0, "atmosphere":0}
	var contributions: Dictionary = {}
	for index in range(instances.size()):
		contributions[str(instances[index].get("uid", index))] = {"comfort":0.0, "entertainment":0.0, "atmosphere":0.0}
	for axis in AXES:
		var families: Dictionary = {}
		for index in range(instances.size()):
			var definition := Catalog.item(str(instances[index].get("item", "")))
			if definition.is_empty():
				continue
			var family: String = definition.family
			if not families.has(family):
				families[family] = []
			families[family].append({"value":float(definition.stats[axis]), "index":index})
		var total := 0.0
		for values in families.values():
			values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)
			for rank in range(mini(3, values.size())):
				var effective: float = values[rank].value * WEIGHTS[rank]
				total += effective
				var key := str(instances[values[rank].index].get("uid", values[rank].index))
				contributions[key][axis] = effective
		totals[axis] = int(floor(clampf(total, 0.0, 100.0) + 0.5))
	var quality := int(floor(0.40 * totals.comfort + 0.35 * totals.entertainment + 0.25 * totals.atmosphere + 0.5))
	return {
		"comfort":totals.comfort, "entertainment":totals.entertainment,
		"atmosphere":totals.atmosphere, "quality":quality,
		"income":clampi(int(floor(maxi(0, quality - 25) / 15.0)), 0, 5),
		"contributions":contributions,
	}

static func guest_fit(report: Dictionary, tags: Array, preference: String) -> int:
	if not FIT_WEIGHTS.has(preference):
		return 0
	var weights: Array = FIT_WEIGHTS[preference]
	var value: float = float(report.get("comfort", 0)) * float(weights[0])
	value += float(report.get("entertainment", 0)) * weights[1]
	value += float(report.get("atmosphere", 0)) * weights[2]
	return mini(100, int(floor(value)) + (10 if tags.has(preference) else 0))
