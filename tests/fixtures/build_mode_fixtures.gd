extends RefCounted

static func regular(rotation: int = 0) -> Dictionary:
	return {"kind":"regular", "x":1, "y":6, "rotation":rotation}

static func suite(rotation: int = 0) -> Dictionary:
	return {"kind":"suite", "x":1, "y":4, "rotation":rotation}

static func placed(item: String, uid: String, x: int, y: int, rotation: int = 0) -> Dictionary:
	return {"uid":uid, "item":item, "hotel":0, "room":0, "x":x, "y":y, "rotation":rotation}
