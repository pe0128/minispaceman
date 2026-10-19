extends SceneTree

const Geometry = preload("res://scripts/geometry.gd")
const Flight = preload("res://scripts/flight.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var size := Vector2(1920, 1080)
	var origin := Vector2(-1920, 100)
	var local := Vector2(640.5, 300.25)
	check(Geometry.desktop_to_local(Geometry.local_to_desktop(local, origin), origin).is_equal_approx(local), "Negative screen origin roundtrip")
	var scaled := Geometry.map_rect(Rect2(100, 200, 300, 400), Rect2(0, 0, 960, 540), size)
	check(scaled == Rect2(200, 400, 600, 800), "Retina native-to-viewport scaling")
	var tops: Array = Geometry.visible_tops([
		{"bounds": Rect2(300, 0, 200, 400)},
		{"bounds": Rect2(100, 100, 600, 400)}], Rect2(Vector2.ZERO, size))
	check(tops.size() == 3, "Foreground rectangle splits a rear top edge")
	check(tops[1] == Rect2(100, 100, 200, 4) and tops[2] == Rect2(500, 100, 200, 4), "Only unoccluded spans become platforms")
	var hidden: Array = Geometry.visible_tops([
		{"bounds": Rect2(0, 0, 1920, 1000)},
		{"bounds": Rect2(100, 100, 600, 400)}], Rect2(Vector2.ZERO, size))
	check(hidden.size() == 1, "Fully obscured top edge excluded")
	check(Geometry.visible_tops([{"bounds": Rect2(0, -100, 400, 500)}], Rect2(Vector2.ZERO, size)).is_empty(), "Offscreen top is not moved to screen edge")
	var flight := Flight.new()
	var result: Dictionary = flight.step(true, true, true, false, 1.0/60)
	check(result["jump"] and not result["jet"], "First press jumps without immediate jet")
	for tick in range(16):
		result = flight.step(false, false, true, false, 1.0/60)
	check(result["jet"], "Holding initial jump starts backpack")
	check(not flight.step(false, false, false, false, 0.02)["jet"], "Release cuts backpack thrust")
	check(flight.step(false, true, true, false, 0.02)["jet"], "Second airborne press immediately starts jet")
	check(not flight.step(true, false, true, false, 0.02)["jet"], "Landing resets flight state")
	result = flight.step(true, true, true, true, 0.02)
	check(result["drop"] and not result["jump"] and not result["jet"], "Down + space drops rather than jumping")
	flight.reset()
	check(not flight.jetting and not flight.jumped, "Focus loss clears flight latch")
	if ClassDB.class_exists("DesktopBridge"):
		var bridge = ClassDB.instantiate("DesktopBridge")
		var snapshot: Dictionary = bridge.snapshot_windows()
		check(snapshot.has("windows") and not snapshot["displays"].is_empty(), "Native window/display enumeration")
	print("TESTS ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
