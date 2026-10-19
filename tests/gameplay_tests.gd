extends SceneTree

const World = preload("res://scripts/world.gd")
const Config = preload("res://scripts/config.gd")
var failures := 0
var checks := 0
var world: Node2D

func _initialize() -> void:
	Config.setup_input()
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	var image := Image.create(800, 600, false, Image.FORMAT_RGB8)
	world = World.new()
	root.add_child(world)
	world.build({"size": Vector2(800, 600), "image": image, "platforms": [Rect2(100, 280, 600, 4)]}, Vector2(200, 180))
	world.set_portal_progress(1)
	world.player.enabled = true
	await ticks(65)
	check(world.player.is_on_floor(), "Player lands on a one-way window platform")
	check(absf(world.player.position.y - 248) < 2, "Feet align to window top at the authored ground line")
	var before: float = world.player.position.x
	Input.action_press("move_right")
	await ticks(20)
	Input.action_release("move_right")
	check(world.player.position.x > before + 40, "Movement affects real physics body")
	Input.action_press("jump")
	await ticks(1)
	check(world.player.velocity.y < 0, "Space initiates upward jump velocity")
	await ticks(20)
	check(world.player.flight.jetting, "Held space starts jet in actual player loop")
	Input.action_release("jump")
	await ticks(2)
	check(not world.player.flight.jetting, "Release stops thrust in actual player loop")
	world.player.enabled = false
	world.player.position = Vector2(200, 550)
	world.player.velocity = Vector2.ZERO
	await ticks(5)
	world.player._pickup()
	check(is_instance_valid(world.player.held_item), "Q pickup selects nearby floor prop")
	check(world.props[0].held and world.props[0].freeze and not world.props[0].visible, "Held prop leaves physics and renders through actor")
	world.player.visual.aim = Vector2.RIGHT
	world.player._throw_elapsed = 0.0
	world.player.visual.play("throw")
	world.player.visual.throwing = true
	world.player._update_throw(0.32)
	check(is_instance_valid(world.player.held_item), "Prop remains held before fourth throw frame")
	world.player._update_throw(0.02)
	check(not is_instance_valid(world.player.held_item) and not world.props[0].held, "Fourth throw frame releases prop")
	check(world.props[0].linear_velocity.x > 500, "Thrown prop receives aimed velocity")
	var target: RigidBody2D = world.props[1]
	target.position = Vector2(400, 520)
	target.linear_velocity = Vector2.ZERO
	await ticks(2)
	world.fire(Vector2(350, target.position.y), Vector2.RIGHT, world.player)
	await ticks(8)
	check(target.linear_velocity.x > 10, "Swept bullet hit imparts impulse to prop")
	world.set_paused(true)
	var paused_position: Vector2 = target.position
	await ticks(8)
	check(target.position.is_equal_approx(paused_position), "Losing focus pauses rigid-body simulation too")
	world.set_paused(false)
	await ticks(5)
	check(not target.position.is_equal_approx(paused_position), "Rigid bodies resume after focus returns")
	world.player.clear_controls()
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "Pause clears movement/jump actions")
	world.queue_free()
	await process_frame
	print("GAMEPLAY ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
