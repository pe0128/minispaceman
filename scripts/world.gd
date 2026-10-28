extends Node2D

const Config = preload("res://scripts/config.gd")
const Player = preload("res://scripts/player.gd")
const Prop = preload("res://scripts/prop.gd")
var world_size := Vector2(1920, 1080)
var player: CharacterBody2D
var props: Array[RigidBody2D] = []
var platforms: Array[StaticBody2D] = []
var bullets: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var platform_rects: Array[Rect2] = []
var portal: ColorRect
var hint: Label
var _hint_time := 8.0
var _portal_material: ShaderMaterial
var _pending_platforms: Array[Rect2] = []
var _platform_refresh_pending := false
var _platform_exclusions: Array[Dictionary] = []
var _paused := false

func build(snapshot: Dictionary, start: Vector2, art_scale: float = 2.0, smoke_style: String = "small") -> void:
	world_size = snapshot["size"]
	# Alpha-zero layered pixels can pass mouse input through on Windows. Keep
	# one alpha step over the whole display while showing the real compositor.
	var input_surface := ColorRect.new()
	input_surface.color = Color(0, 0, 0, 1.0 / 255.0 if OS.get_name() == "Windows" else 0.0)
	input_surface.size = world_size
	input_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_surface.z_index = -10
	add_child(input_surface)
	_add_platform(Rect2(0, world_size.y - 8, world_size.x, 32), false)
	_add_platform(Rect2(-32, -200, 32, world_size.y + 232), false)
	_add_platform(Rect2(world_size.x, -200, 32, world_size.y + 232), false)
	player = Player.new()
	player.art_scale = art_scale
	player.smoke_style = smoke_style
	player.world = self
	player.position = start
	player.z_index = 2
	add_child(player)
	for index in range(3):
		var item := Prop.new()
		item.art_scale = art_scale
		item.kind = ["cyan", "amber", "violet"][index]
		item.position = Vector2(world_size.x * float(index + 1) / 4.0, world_size.y - 28)
		item.z_index = 1
		add_child(item)
		props.append(item)
	update_platforms(snapshot["platforms"])
	_apply_platforms()
	_make_ui(start)

func _add_platform(rect: Rect2, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 6
	body.add_child(collision)
	add_child(body)
	return body

func update_platforms(rects: Array) -> void:
	if rects == platform_rects and not _platform_refresh_pending: return
	_pending_platforms.assign(rects)
	_platform_refresh_pending = true

func _apply_platforms() -> void:
	if not _platform_refresh_pending: return
	_platform_refresh_pending = false
	var old: Dictionary = {}
	for index in platforms.size(): old[platform_rects[index]] = platforms[index]
	var next: Array[StaticBody2D] = []
	for rect: Rect2 in _pending_platforms:
		if old.has(rect):
			next.append(old[rect])
			old.erase(rect)
		else:
			var body := _add_platform(rect, true)
			next.append(body)
			var actors: Array[PhysicsBody2D] = [player]
			for prop: RigidBody2D in props: actors.append(prop)
			for actor: PhysicsBody2D in actors:
				if actor.world_bounds().intersects(rect.grow(6)):
					actor.add_collision_exception_with(body)
					_platform_exclusions.append({"actor": actor, "body": body, "rect": rect})
			if player.is_dropping_through(): player.add_collision_exception_with(body)
	for body: StaticBody2D in old.values():
		body.collision_layer = 0
		body.queue_free()
	platforms = next
	platform_rects = _pending_platforms.duplicate()
	queue_redraw()

func _has_exclusion(actor: PhysicsBody2D, body: StaticBody2D) -> bool:
	for entry: Dictionary in _platform_exclusions:
		if entry.actor == actor and entry.body == body: return true
	return false

func _release_platform_exclusions() -> void:
	for index in range(_platform_exclusions.size() - 1, -1, -1):
		var entry: Dictionary = _platform_exclusions[index]
		if not is_instance_valid(entry.body) or not is_instance_valid(entry.actor):
			_platform_exclusions.remove_at(index)
		elif not entry.actor.world_bounds().intersects(entry.rect.grow(6)):
			if entry.actor != player or not player.is_dropping_through():
				entry.actor.remove_collision_exception_with(entry.body)
			_platform_exclusions.remove_at(index)

func apply_appearance(art_scale: float, smoke_style: String) -> void:
	player.apply_appearance(art_scale, smoke_style)
	for prop: RigidBody2D in props: prop.apply_art_scale(art_scale)

func _make_ui(start: Vector2) -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	hint = Label.new()
	hint.text = "桌宠世界   A/D 移动 · 空格 跳跃/喷气 · 鼠标 瞄准/射击 · Q 拾取 · E 投掷 · Esc 返回"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.position = Vector2(24, 20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)
	portal = ColorRect.new()
	portal.size = world_size
	portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal_material = ShaderMaterial.new()
	_portal_material.shader = preload("res://shaders/portal.gdshader")
	_portal_material.set_shader_parameter("center", start / world_size)
	_portal_material.set_shader_parameter("viewport_size", world_size)
	portal.material = _portal_material
	hud.add_child(portal)

func set_portal_progress(progress: float) -> void:
	_portal_material.set_shader_parameter("progress", progress)
	portal.visible = progress < 1.0

func set_paused(paused: bool) -> void:
	_paused = paused
	PhysicsServer2D.space_set_active(get_world_2d().space, not paused)
	process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func drop_player_through_platforms(actor: PhysicsBody2D) -> void:
	for platform: StaticBody2D in platforms:
		actor.add_collision_exception_with(platform)

func restore_player_platforms(actor: PhysicsBody2D) -> void:
	for platform: StaticBody2D in platforms:
		if not _has_exclusion(actor, platform): actor.remove_collision_exception_with(platform)

func fire(from: Vector2, direction: Vector2, actor: PhysicsBody2D) -> void:
	if bullets.size() >= 128:
		bullets.pop_front()
	bullets.append({"position": from, "previous": from, "velocity": direction * Config.BULLET_SPEED,
		"life": Config.BULLET_LIFETIME, "exclude": [actor.get_rid()]})

func _physics_process(delta: float) -> void:
	if _paused: return
	_apply_platforms()
	_release_platform_exclusions()
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var start: Vector2 = bullet["position"]
		var end: Vector2 = start + bullet["velocity"] * delta
		var query := PhysicsRayQueryParameters2D.create(start, end, 1 | 4, bullet["exclude"])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		bullet["previous"] = start
		bullet["position"] = end
		bullet["life"] -= delta
		if not hit.is_empty():
			if hit["collider"] is RigidBody2D:
				hit["collider"].apply_central_impulse(bullet["velocity"].normalized() * 95)
			sparks.append({"position": hit["position"], "life": 0.2})
		if not hit.is_empty() or bullet["life"] <= 0 or not Rect2(Vector2.ZERO, world_size).has_point(end):
			bullets.remove_at(i)
	for item: RigidBody2D in props:
		if not item.held and item.position.y > world_size.y + 100:
			item.position = Vector2(world_size.x * 0.5, world_size.y - 40)
			item.linear_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	_hint_time = maxf(0, _hint_time - delta)
	hint.modulate.a = clampf(_hint_time, 0, 1)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i]["life"] -= delta
		if sparks[i]["life"] <= 0:
			sparks.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for rect: Rect2 in platform_rects:
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.35, 0.9, 1, 0.4), 1.5)
	for bullet: Dictionary in bullets:
		draw_line(bullet["previous"], bullet["position"], Color(0.65, 1.0, 1.0), 3.0)
	for spark: Dictionary in sparks:
		var radius := (0.2 - float(spark["life"])) * 75
		for ray in range(6):
			var direction := Vector2.from_angle(ray * TAU / 6.0)
			draw_line(spark["position"] + direction * radius * 0.5, spark["position"] + direction * (radius + 4), Color(0.5, 1, 1, float(spark["life"]) * 5), 2)
