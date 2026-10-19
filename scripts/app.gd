extends Node

const Config = preload("res://scripts/config.gd")
const Visual = preload("res://scripts/actor_visual.gd")
const World = preload("res://scripts/world.gd")
const Desktop = preload("res://scripts/desktop_service.gd")
const Assets = preload("res://scripts/assets.gd")
const PET_ANCHOR := Vector2(96, 120)
enum Mode { PET, ENTERING, WORLD, PAUSED, EXITING }
var mode := Mode.PET
var pet: Window
var visual: Node2D
var world_window: Window
var world: Node2D
var desktop := Desktop.new()
var screen_id := 0
var screen_origin := Vector2.ZERO
var screen_size := Vector2.ZERO
var _portal_time := 0.0
var _drag_candidate := false
var _dragging := false
var _drag_start := Vector2.ZERO
var _window_start := Vector2.ZERO
var _check_time := 0.0
var _menu: PopupMenu
var _dialog: AcceptDialog
var _quitting := false
var _test_mode := false
var _last_size := Vector2i.ZERO

func _ready() -> void:
	Config.setup_input()
	Engine.max_fps = 30
	# Godot's main window cannot be hidden. Keep a transparent 1px host,
	# and use two independently hideable native child windows instead.
	var host := get_window()
	host.title = "minispaceman host"
	host.transparent_bg = true
	host.transparent = true
	host.unfocusable = true
	host.always_on_top = false
	host.mouse_passthrough = true
	host.exclude_from_capture = true
	host.size = Vector2i.ONE
	host.position = Vector2i(-32000, -32000)
	host.close_requested.connect(_quit)
	pet = Window.new()
	pet.visible = false
	pet.force_native = true
	pet.title = "minispaceman"
	pet.transparent_bg = true
	pet.transparent = true
	pet.borderless = true
	pet.always_on_top = true
	pet.unresizable = true
	pet.unfocusable = true
	pet.exclude_from_capture = true
	pet.size = Config.PET_SIZE
	add_child(pet)
	visual = Visual.new()
	visual.assembled = true
	visual.position = PET_ANCHOR
	pet.add_child(visual)
	_set_hit_region()
	_restore_position()
	pet.show()
	pet.window_input.connect(_pet_input)
	pet.close_requested.connect(_quit)
	_menu = PopupMenu.new()
	_menu.add_item("进入桌宠世界", 0)
	_menu.add_separator()
	_menu.add_item("退出程序", 1)
	_menu.id_pressed.connect(func(id: int):
		if id == 0: enter_world()
		else: _quit())
	pet.add_child(_menu)
	_dialog = AcceptDialog.new()
	_dialog.title = "minispaceman"
	pet.add_child(_dialog)
	if "--smoke-test" in OS.get_cmdline_user_args():
		_test_mode = true
		call_deferred("_smoke_test")
	elif "--integration-test" in OS.get_cmdline_user_args():
		_test_mode = true
		call_deferred("_integration_test")
	elif "--ui-test" in OS.get_cmdline_user_args():
		_test_mode = true

func _set_hit_region() -> void:
	var image := Assets.texture("assembled/sheets/idle.png").get_image()
	var bounds := Rect2i()
	for frame in range(6):
		var used := image.get_region(Rect2i(frame * 96, 0, 96, 96)).get_used_rect()
		bounds = used if frame == 0 else bounds.merge(used)
	bounds = bounds.merge(Rect2i(96 - bounds.end.x, bounds.position.y, bounds.size.x, bounds.size.y))
	var rect := Rect2(Vector2(bounds.position) * 2, Vector2(bounds.size) * 2).grow(2)
	pet.mouse_passthrough_polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _pet_input(event: InputEvent) -> void:
	if mode != Mode.PET:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_menu.position = DisplayServer.mouse_get_position()
			_menu.popup()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				_drag_candidate = false
				_dragging = false
				enter_world()
			elif event.pressed:
				_drag_candidate = true
				_drag_start = DisplayServer.mouse_get_position()
				_window_start = pet.position
			else:
				_drag_candidate = false
				if _dragging:
					_dragging = false
					_save_position()

func enter_world() -> void:
	if mode != Mode.PET:
		return
	mode = Mode.ENTERING
	_drag_candidate = false
	_dragging = false
	screen_id = _screen_for_anchor(Vector2(pet.position) + PET_ANCHOR)
	screen_origin = DisplayServer.screen_get_position(screen_id)
	screen_size = DisplayServer.screen_get_size(screen_id)
	var anchor := Vector2(pet.position) + PET_ANCHOR - screen_origin
	# Hidden capture is deliberate: capture exclusions are compositor-dependent.
	pet.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = desktop.capture_desktop(screen_id)
	if snapshot.has("error"):
		pet.show()
		mode = Mode.PET
		_show_error(snapshot["error"])
		return
	_start_world(snapshot, anchor)

func _start_world(snapshot: Dictionary, anchor: Vector2) -> void:
	Engine.max_fps = 60
	screen_origin = snapshot["origin"]
	screen_size = snapshot["size"]
	world_window = Window.new()
	world_window.visible = false
	world_window.title = "桌宠世界 · Esc 返回"
	world_window.force_native = true
	world_window.borderless = true
	world_window.unresizable = true
	world_window.always_on_top = true
	world_window.transparent_bg = false
	world_window.size = Vector2i(screen_size)
	world_window.position = Vector2i(screen_origin)
	world_window.world_2d = World2D.new()
	add_child(world_window)
	world = World.new()
	world_window.add_child(world)
	world.build(snapshot, anchor)
	world_window.close_requested.connect(leave_world)
	world_window.window_input.connect(_world_input)
	world_window.focus_exited.connect(_world_blurred)
	world_window.focus_entered.connect(_world_focused)
	world_window.show()
	world_window.grab_focus()
	_portal_time = 0
	mode = Mode.ENTERING
	Config.clear_input()
	_last_size = DisplayServer.screen_get_size(screen_id)

func _world_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave_world"):
		leave_world()

func _world_blurred() -> void:
	if mode != Mode.WORLD or _test_mode:
		return
	mode = Mode.PAUSED
	world.player.clear_controls()
	world.set_paused(true)

func _world_focused() -> void:
	if mode != Mode.PAUSED:
		return
	world.set_paused(false)
	world.player.clear_controls()
	mode = Mode.WORLD

func leave_world() -> void:
	if mode in [Mode.PET, Mode.EXITING]:
		return
	if not is_instance_valid(world):
		return
	mode = Mode.EXITING
	var anchor: Vector2 = screen_origin + world.player.position
	visual.facing = world.player.visual.facing
	world.player.clear_controls()
	world_window.hide()
	world_window.queue_free()
	world = null
	world_window = null
	pet.position = Vector2i((anchor - PET_ANCHOR).round())
	visual.play("idle")
	pet.show()
	Engine.max_fps = 30
	mode = Mode.PET
	_save_position()

func _process(delta: float) -> void:
	if mode == Mode.PET and _drag_candidate:
		var distance := Vector2(DisplayServer.mouse_get_position()) - _drag_start
		if distance.length() > 6:
			_dragging = true
		if _dragging:
			pet.position = Vector2i(_window_start + distance)
			_clamp_pet()
	if mode == Mode.ENTERING and is_instance_valid(world):
		_portal_time += delta
		world.set_portal_progress(minf(_portal_time / Config.ENTER_DURATION, 1))
		if _portal_time >= Config.ENTER_DURATION:
			Config.clear_input()
			world.player.enabled = true
			mode = Mode.WORLD
			if not world_window.has_focus():
				_world_blurred()
	_check_time += delta
	if _check_time >= 0.5:
		_check_time = 0
		if mode in [Mode.WORLD, Mode.PAUSED, Mode.ENTERING] and is_instance_valid(world) and not _test_mode:
			if screen_id >= DisplayServer.get_screen_count() or DisplayServer.screen_get_size(screen_id) != _last_size or Vector2(DisplayServer.screen_get_position(screen_id)) != screen_origin:
				leave_world()
				_clamp_pet()
		elif mode == Mode.PET:
			_clamp_pet()

func _clamp_pet() -> void:
	var monitor := _screen_for_anchor(Vector2(pet.position) + PET_ANCHOR)
	var rect := Rect2(DisplayServer.screen_get_position(monitor), DisplayServer.screen_get_size(monitor))
	# Retain the root anchor, even when a small transparent margin is offscreen.
	var root_position := Vector2(pet.position) + PET_ANCHOR
	root_position = root_position.clamp(rect.position + Vector2(34, 54), rect.end - Vector2(34, 34))
	pet.position = Vector2i(root_position - PET_ANCHOR)

func _screen_for_anchor(anchor: Vector2) -> int:
	var nearest := DisplayServer.get_primary_screen()
	var best := INF
	for index in range(DisplayServer.get_screen_count()):
		var rect := Rect2(DisplayServer.screen_get_position(index), DisplayServer.screen_get_size(index))
		if rect.has_point(anchor):
			return index
		var distance := anchor.distance_squared_to(anchor.clamp(rect.position, rect.end))
		if distance < best:
			best = distance
			nearest = index
	return nearest

func _restore_position() -> void:
	var settings := ConfigFile.new()
	var monitor := DisplayServer.get_primary_screen()
	var rect := Rect2(DisplayServer.screen_get_position(monitor), DisplayServer.screen_get_size(monitor))
	var anchor := rect.end - Vector2(140, 100)
	if settings.load("user://position.cfg") == OK:
		var saved_screen: int = settings.get_value("pet", "screen", monitor)
		if saved_screen < DisplayServer.get_screen_count() and saved_screen >= 0:
			monitor = saved_screen
			anchor = Vector2(DisplayServer.screen_get_position(monitor)) + Vector2(settings.get_value("pet", "local_position", Vector2(150, 150)))
		visual.facing = settings.get_value("pet", "facing", 1.0)
	pet.position = Vector2i(anchor - PET_ANCHOR)
	_clamp_pet()

func _save_position() -> void:
	if _test_mode:
		return
	var settings := ConfigFile.new()
	var monitor := _screen_for_anchor(Vector2(pet.position) + PET_ANCHOR)
	settings.set_value("pet", "screen", monitor)
	settings.set_value("pet", "local_position", Vector2(pet.position) + PET_ANCHOR - Vector2(DisplayServer.screen_get_position(monitor)))
	settings.set_value("pet", "facing", visual.facing)
	settings.save("user://position.cfg")

func _show_error(message: String) -> void:
	push_warning(message)
	_dialog.dialog_text = message
	_dialog.popup_centered(Vector2i(480, 140))

func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	if is_instance_valid(world):
		leave_world()
	_save_position()
	get_tree().quit()

func _synthetic_snapshot() -> Dictionary:
	var image := Image.create(1100, 740, false, Image.FORMAT_RGB8)
	image.fill(Color("172433"))
	image.fill_rect(Rect2i(60, 110, 470, 280), Color("263c50"))
	image.fill_rect(Rect2i(600, 300, 400, 250), Color("31495b"))
	return {"origin": Vector2(60, 60), "size": Vector2(1100, 740), "image": image,
		"platforms": [Rect2(60, 110, 470, 4), Rect2(600, 300, 400, 4)]}

func _smoke_test() -> void:
	pet.hide()
	_start_world(_synthetic_snapshot(), Vector2(320, 240))
	await get_tree().create_timer(1.1).timeout
	world.player.position = Vector2(275, 690)
	world.player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.2).timeout
	world.player._pickup()
	world.player.visual.aim = Vector2(1, -0.4).normalized()
	world.fire(world.player.visual.muzzle_global(), Vector2.RIGHT, world.player)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	world_window.get_texture().get_image().save_png("res://artifacts/smoke.png")
	var last_position: Vector2 = screen_origin + world.player.position
	leave_world()
	var error := (Vector2(pet.position) + PET_ANCHOR).distance_to(last_position)
	print("SMOKE position_error=", error)
	await get_tree().process_frame
	get_tree().quit(0 if error <= 1.5 else 1)

func _integration_test() -> void:
	await get_tree().create_timer(0.3).timeout
	enter_world()
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(world):
		get_tree().quit(1)
		return
	print("NATIVE_CAPTURE platforms=", world.platforms.size(), " screen=", screen_size)
	leave_world()
	await get_tree().process_frame
	var baseline := get_tree().get_node_count()
	for iteration in range(50):
		_start_world(_synthetic_snapshot(), Vector2(180 + iteration, 200))
		world.set_portal_progress(1.0)
		leave_world()
		await get_tree().process_frame
	await get_tree().process_frame
	var final_nodes := get_tree().get_node_count()
	print("INTEGRATION 50 mode transitions passed; nodes ", baseline, " -> ", final_nodes)
	get_tree().quit(0 if baseline == final_nodes else 1)
