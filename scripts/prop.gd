extends RigidBody2D

const Assets = preload("res://scripts/assets.gd")
const Config = preload("res://scripts/config.gd")
var art_scale := Config.ART_SCALE
var kind := "cyan"
var held := false
var sprite: Sprite2D
var _collider: CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 0.6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.25
	physics_material_override.friction = 0.8
	sprite = Sprite2D.new()
	sprite.texture = Assets.texture("projectiles/" + kind + ".png")
	sprite.scale = Vector2.ONE * art_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var collider := CollisionShape2D.new()
	_collider = collider
	var shape := CircleShape2D.new()
	shape.radius = {"cyan": 8.0, "amber": 10.0, "violet": 13.0}[kind] * art_scale / 2
	collider.shape = shape
	add_child(collider)

func world_bounds() -> Rect2:
	var radius: float = _collider.shape.radius
	return Rect2(global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2)

func apply_art_scale(value: float) -> void:
	art_scale = value
	sprite.scale = Vector2.ONE * value
	_collider.shape.radius = {"cyan": 8.0, "amber": 10.0, "violet": 13.0}[kind] * value / 2

func pickup() -> void:
	held = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	collision_layer = 0
	collision_mask = 0
	visible = false

func release(at: Vector2, speed: Vector2) -> void:
	global_position = at
	rotation = 0
	held = false
	visible = true
	collision_layer = 4
	collision_mask = 1 | 4
	freeze = false
	sleeping = false
	linear_velocity = speed
	angular_velocity = speed.x / 70.0
