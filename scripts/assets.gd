extends RefCounted

const BASE := "res://assets/spaceman/"
static var _rig: Dictionary = {}
static var _textures: Dictionary = {}

static func rig() -> Dictionary:
	if _rig.is_empty():
		_rig = JSON.parse_string(FileAccess.get_file_as_string(BASE + "rig.json"))
	return _rig

static func animation(name: String) -> Dictionary:
	for entry: Dictionary in rig()["animations"]:
		if entry["name"] == name:
			return entry
	return rig()["animations"][0]

static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(BASE + path)
	return _textures[path]

static func point(value: Dictionary) -> Vector2:
	return Vector2(value["x"], value["y"])

static func prop_anchor(kind: String) -> Vector2:
	match kind:
		"amber": return Vector2(9, 15)
		"violet": return Vector2(11, 18)
	return Vector2(7, 11)
