extends RefCounted

signal changed(previous: Dictionary)

const DEFAULTS := {"astronaut": {"size": 100, "smoke": "small"}, "app": {
	"autostart": false, "always_on_top": true, "remember_position": true, "theme": "system"}}
const PATH := "user://settings.cfg"
const VERSION := 2
var values: Dictionary = DEFAULTS.duplicate(true)
var bridge: Object
var registration_error := ""

func ensure_resident_login() -> void:
	if OS.has_feature("editor") or bridge == null: return
	# A separate marker prevents a later OS disable from being silently undone.
	var marker := ConfigFile.new()
	var path := "user://resident_login.cfg"
	marker.load(path)
	var executable := OS.get_executable_path()
	if marker.get_value("login", "attempted", "") == executable: return
	marker.set_value("login", "attempted", executable)
	if marker.save(path) != OK:
		registration_error = "无法保存登录项状态。"
		return
	var status := login_status()
	if status.state in ["enabled", "requiresApproval", "disabled"]: return
	var result: Dictionary = bridge.set_autostart(true, executable)
	if not result.get("ok", false): registration_error = result.get("message", "无法注册系统登录项。")

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
	if not registration_error.is_empty(): return {"state": "unavailable", "message": registration_error}
	if OS.has_feature("editor") or bridge == null:
		return {"state": "unavailable", "message": "开机自启动需要使用导出的应用。"}
	return bridge.autostart_status(OS.get_executable_path())

func apply(draft: Dictionary) -> String:
	var error := validate(draft)
	if not error.is_empty(): return error
	# Login registration is independent of whether the pet starts enabled.
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]: file.set_value(section, key, draft[section][key])
	if file.save(PATH + ".pending") != OK: return "无法写入配置，请检查用户目录权限。"
	var rename_error := DirAccess.rename_absolute(PATH + ".pending", PATH)
	if rename_error != OK:
		DirAccess.remove_absolute(PATH + ".pending")
		return "无法保存配置，请重试。"
	var previous := values.duplicate(true)
	values = draft.duplicate(true)
	changed.emit(previous)
	return ""
