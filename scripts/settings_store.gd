extends RefCounted

signal changed(previous: Dictionary)

const DEFAULTS := {"astronaut": {"size": 100, "smoke": "small"}, "app": {
	"autostart": false, "always_on_top": true, "remember_position": true, "theme": "system"}}
const PATH := "user://settings.cfg"
const VERSION := 1
var values: Dictionary = DEFAULTS.duplicate(true)
var bridge: Object

func _init(native_bridge: Object = null) -> void:
	bridge = native_bridge
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for section: String in DEFAULTS:
			for key: String in DEFAULTS[section]:
				values[section][key] = file.get_value(section, key, DEFAULTS[section][key])
		if not validate(values).is_empty():
			values = DEFAULTS.duplicate(true)

func art_scale() -> float:
	return float(values.astronaut.size) / 50.0

func validate(draft: Dictionary) -> String:
	if not draft.has_all(["astronaut", "app"]): return "配置缺少分类。"
	if draft.astronaut.get("size") not in [50, 100, 150, 200]: return "请选择有效的宇航员大小。"
	if draft.astronaut.get("smoke") not in ["small", "medium", "large"]: return "请选择有效的喷气效果。"
	if draft.app.get("theme") not in ["system", "light", "dark"]: return "请选择有效的主题。"
	for key: String in ["autostart", "always_on_top", "remember_position"]:
		if typeof(draft.app.get(key)) != TYPE_BOOL: return "应用配置格式错误。"
	return ""

func login_status() -> Dictionary:
	if OS.has_feature("editor") or bridge == null:
		return {"state": "unavailable", "message": "开机自启动需要使用导出的应用。"}
	return bridge.autostart_status(OS.get_executable_path())

func apply(draft: Dictionary) -> String:
	var error := validate(draft)
	if not error.is_empty(): return error
	var status := login_status()
	var requested: bool = draft.app.autostart
	var registered: bool = status.state in ["enabled", "requiresApproval"]
	var alter_login: bool = status.state != "unavailable" and (
		(requested and not registered) or (not requested and status.state in ["enabled", "requiresApproval", "notFound"]))
	if requested != values.app.autostart and status.state == "unavailable": return status.message
	# Prepare the complete file before changing OS state; publish atomically afterwards.
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]: file.set_value(section, key, draft[section][key])
	if file.save(PATH + ".pending") != OK: return "无法写入配置，请检查用户目录权限。"
	if alter_login:
		var result: Dictionary = bridge.set_autostart(requested, OS.get_executable_path())
		if not result.get("ok", false):
			DirAccess.remove_absolute(PATH + ".pending")
			return result.get("message", "无法更改系统登录项。")
	var rename_error := DirAccess.rename_absolute(PATH + ".pending", PATH)
	if rename_error != OK:
		DirAccess.remove_absolute(PATH + ".pending")
		if alter_login: bridge.set_autostart(registered, OS.get_executable_path())
		return "无法保存配置，系统登录项已尝试恢复。请重试。"
	var previous := values.duplicate(true)
	values = draft.duplicate(true)
	changed.emit(previous)
	return ""
