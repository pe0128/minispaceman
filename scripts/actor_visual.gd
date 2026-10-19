extends Node2D

const Assets = preload("res://scripts/assets.gd")
const Config = preload("res://scripts/config.gd")
var animation_name := "idle"
var frame := 0
var elapsed := 0.0
var aim := Vector2.RIGHT
var facing := 1.0
var assembled := false
var carrying := ""
var throwing := false
var jetting := false
var recoil := 0.0
var _clock := 0.0
var _glove: Texture2D

func _ready() -> void:
	scale = Vector2.ONE * Config.ART_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The authored sampling mask omits the two bright glove pixels.
	var source := Assets.texture("parts/glove.png").get_image()
	var image := Image.create(6, 5, false, Image.FORMAT_RGBA8)
	for sample: Array in Assets.rig()["helperAttachment"]["gloveSamples"]:
		image.blit_rect(source, Rect2i(sample[0], sample[1], sample[2], sample[3]), Vector2i(sample[0], sample[1]))
	_glove = ImageTexture.create_from_image(image)

func play(action: String) -> void:
	if action == animation_name:
		return
	animation_name = action
	frame = 0
	elapsed = 0.0

func _process(delta: float) -> void:
	_clock += delta
	recoil = move_toward(recoil, 0.0, delta * 22.0)
	var data := Assets.animation(animation_name)
	if animation_name != "jump":
		elapsed += delta
		var durations: Array = data.get("frameDurationsMs", [])
		var duration := 1.0 / float(data["fps"])
		if not durations.is_empty():
			duration = float(durations[frame]) / 1000.0
		while elapsed >= duration:
			elapsed -= duration
			frame = (frame + 1) % int(data["frameCount"]) if data["loop"] else mini(frame + 1, int(data["frameCount"]) - 1)
	queue_redraw()

func _frame_data() -> Dictionary:
	return Assets.animation(animation_name)["frames"][frame]

func _shoulder() -> Vector2:
	return Assets.point(_frame_data()["shoulder"]) - Config.ROOT

func _helper_shoulder() -> Vector2:
	return Assets.point(_frame_data()["leftShoulder"]) - Config.ROOT + Vector2(0, -2)

func palm_local() -> Vector2:
	var offset := Vector2(5, 11)
	if not carrying.is_empty():
		offset = Vector2(8, 5)
	if throwing:
		var offsets: Array = Assets.animation("throw")["handOffsets"]
		offset = Vector2(offsets[frame][0], offsets[frame][1])
	return (_helper_shoulder() + offset) * Vector2(facing, 1)

func _grip() -> Vector2:
	var direction := Vector2(aim.x * facing, aim.y).normalized()
	var elbow_angle := clampf(direction.angle() + 0.65, -PI * 0.5, PI * 0.5)
	return _shoulder() + Vector2.from_angle(elbow_angle) * 6.0 + direction * (7.0 - recoil)

func muzzle_global() -> Vector2:
	var direction := Vector2(aim.x * facing, aim.y).normalized()
	var local := _grip() + (Vector2(20, 2) - Vector2(4, 7)).rotated(direction.angle())
	return to_global(local * Vector2(facing, 1))

func _transform_at(point: Vector2, angle: float = 0.0) -> void:
	draw_set_transform(point * Vector2(facing, 1), angle * facing, Vector2(facing, 1))

func _bone(start: Vector2, end: Vector2, width: float) -> void:
	_transform_at(start, (end - start).angle())
	draw_texture_rect(Assets.texture("parts/sleeve.png"), Rect2(0, -width * 0.5, start.distance_to(end), width), false)

func _helper(front: bool) -> void:
	var is_front := not carrying.is_empty() or throwing
	if front != is_front:
		return
	var shoulder := _helper_shoulder()
	var palm := palm_local() * Vector2(facing, 1)
	var vector := palm - shoulder
	var distance := clampf(vector.length(), 0.1, 12.99)
	var bend := acos(clampf((36.0 + distance * distance - 49.0) / (12.0 * distance), -1, 1))
	var elbow := shoulder + vector.normalized().rotated(-bend) * 6
	_bone(shoulder, elbow, 7)
	_bone(elbow, palm, 6)
	_transform_at(palm)
	draw_texture(_glove, Vector2(-3, -2))
	if not carrying.is_empty():
		var prop := Assets.texture("projectiles/" + carrying + ".png")
		draw_texture(prop, -Assets.prop_anchor(carrying))

func _draw() -> void:
	if assembled:
		_transform_at(Vector2.ZERO)
		draw_texture_rect_region(Assets.texture("assembled/sheets/idle.png"), Rect2(-Config.ROOT, Vector2(96, 96)), Rect2(frame * 96, 0, 96, 96))
		return
	_helper(false)
	_transform_at(Vector2.ZERO)
	draw_texture_rect_region(Assets.texture("body/sheets/" + animation_name + ".png"), Rect2(-Config.ROOT, Vector2(96, 96)), Rect2(frame * 96, 0, 96, 96))
	_helper(true)
	var direction := Vector2(aim.x * facing, aim.y).normalized()
	var grip := _grip()
	var elbow := grip - direction * (7.0 - recoil)
	# Aim above the helmet must remain behind the authored helmet/collar spans.
	# Runtime clipping is applied to the arm overlay in _draw_primary_masked().
	_draw_primary_masked(_shoulder(), elbow, grip, direction)
	if jetting:
		_transform_at(Vector2(-12, 1))
		var jet_frame := int(_clock * 12) % 6
		draw_texture_rect_region(Assets.texture("effects/jet-small/sheet.png"), Rect2(-16, 0, 32, 32), Rect2(jet_frame * 32, 0, 32, 32))
	draw_set_transform(Vector2.ZERO)

func _draw_primary_masked(shoulder: Vector2, elbow: Vector2, grip: Vector2, direction: Vector2) -> void:
	_bone(shoulder, elbow, 7)
	_bone(elbow, grip, 6)
	_transform_at(grip, direction.angle())
	draw_texture(Assets.texture("parts/gun.png"), -Vector2(4, 7))
	# Redraw only the authored helmet spans, preserving gun pixels outside it.
	_transform_at(Vector2.ZERO)
	var body := Assets.texture("body/sheets/" + animation_name + ".png")
	for span: Array in _frame_data().get("helmetSpans", []):
		var rect := Rect2(span[0], span[1], span[2], 1)
		draw_texture_rect_region(body, Rect2(rect.position - Config.ROOT, rect.size), Rect2(rect.position + Vector2(frame * 96, 0), rect.size))
