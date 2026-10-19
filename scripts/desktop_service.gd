extends RefCounted

const Geometry = preload("res://scripts/geometry.gd")
var bridge: Object

func _init() -> void:
	if ClassDB.class_exists("DesktopBridge"):
		bridge = ClassDB.instantiate("DesktopBridge")

func capture_desktop(screen: int) -> Dictionary:
	if bridge == null:
		return {"error": "桌面扩展尚未构建，请先运行 tools/build_native.ps1 或 tools/build_native.sh。"}
	if not bridge.screen_capture_allowed():
		bridge.request_screen_capture()
		return {"error": "请在系统设置中允许屏幕录制，然后重启桌宠。"}
	var image := DisplayServer.screen_get_image(screen)
	if image == null or image.is_empty():
		return {"error": "无法截取当前显示器，请检查屏幕录制权限。"}
	var origin := Vector2(DisplayServer.screen_get_position(screen))
	var size := Vector2(DisplayServer.screen_get_size(screen))
	var raw: Dictionary = bridge.snapshot_windows()
	var native_bounds := Rect2(origin, size)
	var best := INF
	for display: Dictionary in raw["displays"]:
		var bounds: Rect2 = display["bounds"]
		var score := bounds.position.distance_squared_to(origin)
		if score < best:
			best = score
			native_bounds = bounds
	var windows: Array = []
	for record: Dictionary in raw["windows"]:
		windows.append({"bounds": Geometry.map_rect(record["bounds"], native_bounds, size), "id": record["id"]})
	return {"image": image, "screen": screen, "origin": origin, "size": size,
		"platforms": Geometry.visible_tops(windows, Rect2(Vector2.ZERO, size)), "windows": windows}
