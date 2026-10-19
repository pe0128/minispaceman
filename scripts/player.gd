extends CharacterBody2D

const Config = preload("res://scripts/config.gd")
const Visual = preload("res://scripts/actor_visual.gd")
const Flight = preload("res://scripts/flight.gd")
const Assets = preload("res://scripts/assets.gd")
var visual: Node2D
var flight := Flight.new()
var enabled := false
var held_item: RigidBody2D
var world: Node2D
var _throw_elapsed := -1.0
var _throw_released := false
var _drop_time := 0.0
var _shoot_cooldown := 0.0
var _landing_time := 0.0
var _was_grounded := false
var _collider: CollisionShape2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 5
	_collider = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 82)
	_collider.shape = shape
	_collider.position = Vector2(0, -9)
	add_child(_collider)
	visual = Visual.new()
	add_child(visual)

func clear_controls() -> void:
	Config.clear_input()
	flight.reset()
	visual.jetting = false

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_shoot_cooldown = maxf(0, _shoot_cooldown - delta)
	var cursor := get_global_mouse_position()
	visual.aim = (cursor - (global_position + Vector2(0, -12))).normalized()
	if visual.aim.length_squared() < 0.01:
		visual.aim = Vector2.RIGHT
	visual.facing = -1.0 if visual.aim.x < 0 else 1.0
	var grounded := is_on_floor()
	var down := Input.is_action_pressed("crouch")
	var result: Dictionary = flight.step(grounded, Input.is_action_just_pressed("jump"), Input.is_action_pressed("jump"), down, delta)
	if result["drop"]:
		_drop_time = 0.2
		world.drop_player_through_platforms(self)
		position.y += 5
		velocity.y = 100
	_drop_time = maxf(0, _drop_time - delta)
	if _drop_time <= 0:
		world.restore_player_platforms(self)
	if result["jump"]:
		velocity.y = -Config.JUMP_SPEED
		_landing_time = 0
	velocity.y = minf(velocity.y + Config.GRAVITY * delta, Config.FALL_MAX_SPEED)
	if result["jet"]:
		velocity.y = maxf(velocity.y - Config.JET_ACCELERATION * delta, -Config.JET_MAX_SPEED)
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, axis * (Config.CROUCH_SPEED if down and grounded else Config.MOVE_SPEED), 1600.0 * delta)
	var box := _collider.shape as RectangleShape2D
	box.size.y = 54.0 if down and grounded else 82.0
	_collider.position.y = 32.0 - box.size.y * 0.5
	move_and_slide()
	position.x = clampf(position.x, 34, world.world_size.x - 34)
	position.y = maxf(position.y, 54)
	if position.y <= 54 and velocity.y < 0:
		velocity.y = 0
	if position.y > world.world_size.y + 100:
		position.y = world.world_size.y - 40
		velocity = Vector2.ZERO
	if is_on_floor() and not _was_grounded:
		_landing_time = 0.1
	_landing_time = maxf(0, _landing_time - delta)
	_was_grounded = is_on_floor()
	visual.jetting = result["jet"]
	_update_throw(delta)
	if _throw_elapsed >= 0:
		visual.play("throw")
		visual.throwing = true
	else:
		visual.throwing = false
		if not is_on_floor():
			visual.play("jetpack" if result["jet"] else "jump")
			if not result["jet"]:
				visual.frame = 1 if velocity.y < -80 else (2 if velocity.y < 60 else 3)
		elif _landing_time > 0:
			visual.play("jump")
			visual.frame = 4
		elif down:
			visual.play("crouch_walk" if absf(velocity.x) > 10 else "crouch_idle")
		else:
			visual.play("run" if absf(velocity.x) > 10 else "idle")
	if Input.is_action_just_pressed("pickup") and _throw_elapsed < 0:
		_pickup()
	if Input.is_action_just_pressed("throw_item") and is_instance_valid(held_item) and _throw_elapsed < 0:
		_throw_elapsed = 0
		_throw_released = false
		visual.play("throw")
	if Input.is_action_just_pressed("shoot") and _shoot_cooldown <= 0:
		_shoot_cooldown = 0.12
		visual.recoil = 2.0
		world.fire(visual.muzzle_global(), visual.aim, self)

func _pickup() -> void:
	if is_instance_valid(held_item):
		return
	var nearest: RigidBody2D
	var best := Config.PICKUP_RADIUS * Config.PICKUP_RADIUS
	for item: RigidBody2D in world.props:
		if not is_instance_valid(item) or item.held:
			continue
		var distance := global_position.distance_squared_to(item.global_position)
		if distance < best:
			best = distance
			nearest = item
	if nearest != null:
		held_item = nearest
		held_item.pickup()
		visual.carrying = held_item.kind

func _update_throw(delta: float) -> void:
	if _throw_elapsed < 0:
		return
	_throw_elapsed += delta
	if _throw_elapsed >= 3.0 / 9.0 and not _throw_released and is_instance_valid(held_item):
		_throw_released = true
		visual.frame = 3
		var palm: Vector2 = visual.to_global(visual.palm_local())
		var anchor: Vector2 = Assets.prop_anchor(held_item.kind) - held_item.sprite.texture.get_size() * 0.5
		var center: Vector2 = palm - anchor * Config.ART_SCALE * Vector2(visual.facing, 1)
		held_item.release(center, visual.aim * Config.THROW_SPEED + velocity)
		held_item = null
		visual.carrying = ""
	if _throw_elapsed >= 6.0 / 9.0:
		_throw_elapsed = -1
		visual.throwing = false
