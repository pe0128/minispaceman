extends Node

const Config = preload("res://scripts/config.gd")
const Visual = preload("res://scripts/actor_visual.gd")
const World = preload("res://scripts/world.gd")
const Desktop = preload("res://scripts/desktop_service.gd")
const Assets = preload("res://scripts/assets.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")
const Fonts = preload("res://scripts/ui_fonts.gd")
const Style = preload("res://scripts/settings_theme.gd")
const Resident = preload("res://scripts/resident_service.gd")
const PetMenu = preload("res://scripts/pet_menu.gd")
const APP_ICON = preload("res://assets/icons/app.png")
const TRAY_ICON = preload("res://assets/icons/tray.png")
const TRAY_DISABLED = preload("res://assets/icons/tray_disabled.png")
var pet_anchor := Vector2(96, 120)
var settings: RefCounted
var settings_window: Window
enum Mode { PET, ENTERING, WORLD, PAUSED, EXITING, INACTIVE }
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
var _menu: Window
var _dialog: AcceptDialog
var _quitting := false
var _last_size := Vector2i.ZERO
var _tray_id := -1
var _tray_menu: Window
var _resident: Node
var _enabled := true
var _startup := false
var _font_warning_shown := false
var _entry_generation := 0

func _ready() -> void:
	# Configure the default before any child native windows are created.
	DisplayServer.set_icon(APP_ICON.get_image())
	get_window().size = Vector2i.ONE
	get_window().position = Vector2i(-32000, -32000)
	_startup = "--startup" in OS.get_cmdline_user_args()
	if desktop.bridge != null and OS.get_name() == "macOS":
		_startup = desktop.bridge.launched_at_login()
	_resident = Resident.new()
	add_child(_resident)
	if desktop.bridge != null and not desktop.bridge.claim_instance():
		if not _startup: await _resident.wake_existing()
		set_process(false)
		get_tree().quit()
		return
	var ipc_error: int = _resident.start()
	_resident.activated.connect(func(): _set_enabled(true))
	settings = SettingsStore.new(desktop.bridge)
	settings.ensure_resident_login()
	settings.changed.connect(_settings_changed)
	pet_anchor = Config.ROOT * settings.art_scale()
	Config.setup_input()
	Engine.max_fps = 30
	# Godot's main window cannot be hidden. Keep a transparent 1px host,
	# and use two independently hideable native child windows instead.
	var host := get_window()
	host.theme = Fonts.theme()
	host.title = "minispaceman"
	host.transparent_bg = true
	host.transparent = true
	host.unfocusable = true
	host.always_on_top = false
	host.mouse_passthrough = true
	host.exclude_from_capture = true
	host.size = Vector2i.ONE
	host.position = Vector2i(-32000, -32000)
	host.close_requested.connect(_quit)
	_set_window_taskbar(host, false)
	_sync_dock()
	pet = Window.new()
	pet.visible = false
	pet.force_native = true
	pet.title = "minispaceman"
	pet.transparent_bg = true
	pet.transparent = true
	pet.borderless = true
	pet.always_on_top = settings.values.app.always_on_top
	pet.unresizable = true
	pet.unfocusable = true
	pet.exclude_from_capture = true
	pet.size = Vector2i(Vector2(96, 96) * settings.art_scale())
	add_child(pet)
	visual = Visual.new()
	visual.art_scale = settings.art_scale()
	visual.smoke_style = settings.values.astronaut.smoke
	visual.assembled = true
	visual.position = pet_anchor
	pet.add_child(visual)
	_set_hit_region()
	_restore_position()
	_enabled = not _startup or settings.values.app.autostart
	if _enabled: pet.show()
	else:
		mode = Mode.INACTIVE
		pet.process_mode = Node.PROCESS_MODE_DISABLED
	_set_window_taskbar(pet, false)
	pet.window_input.connect(_pet_input)
	pet.close_requested.connect(func(): _set_enabled(false))
	_menu = PetMenu.new()
	_menu.bridge = desktop.bridge
	add_child(_menu)
	_menu.add_item("设置", 2)
	_menu.add_separator()
	_menu.add_item("退出桌宠", 1)
	_menu.id_pressed.connect(func(id: int):
		if id == 2: _open_settings()
		else: _set_enabled(false))
	_menu.visibility_changed.connect(_update_refresh_rate)
	_tray_menu = PetMenu.new()
	_tray_menu.bridge = desktop.bridge
	add_child(_tray_menu)
	_tray_menu.add_item("退出桌宠", 0)
	_tray_menu.add_item("设置", 2)
	_tray_menu.add_separator()
	_tray_menu.add_item("退出程序", 1)
	_tray_menu.id_pressed.connect(func(id: int):
		if id == 0: _set_enabled(not _enabled)
		elif id == 2: _open_settings()
		else: _quit())
	_tray_menu.visibility_changed.connect(_update_refresh_rate)
	_dialog = AcceptDialog.new()
	_dialog.title = "minispaceman"
	add_child(_dialog)
	_refresh_ui_theme()
	_tray_id = DisplayServer.create_status_indicator(_tray_icon(), "minispaceman", _tray_pressed)
	if _tray_id < 0 or ipc_error != OK:
		_open_settings()
		_show_error("无法创建系统托盘。" if _tray_id < 0 else "无法建立本机唤醒通道。")
	_update_refresh_rate()

func _tray_pressed(button: int, position: Vector2i) -> void:
	if button not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	_menu.hide()
	_tray_menu.set_item_text(0, "退出桌宠" if _enabled else "启用桌宠")
	_tray_menu.present(position, settings.values.app.theme)
	_update_refresh_rate()

func _set_enabled(enabled: bool) -> void:
	if _quitting or not is_instance_valid(pet): return
	if enabled == _enabled:
		_sync_tray()
		return
	_enabled = enabled
	_drag_candidate = false
	_dragging = false
	if not enabled:
		_entry_generation += 1
		if is_instance_valid(world): leave_world()
		_save_position()
		pet.hide()
		pet.process_mode = Node.PROCESS_MODE_DISABLED
		mode = Mode.INACTIVE
	else:
		mode = Mode.PET
		pet.process_mode = Node.PROCESS_MODE_INHERIT
		_clamp_pet()
		pet.show()
		_set_window_taskbar(pet, false)
	_sync_tray()
	_update_refresh_rate()

func _sync_tray() -> void:
	if _tray_id >= 0: DisplayServer.status_indicator_set_icon(_tray_id, _tray_icon())
	if is_instance_valid(_tray_menu): _tray_menu.set_item_text(0, "退出桌宠" if _enabled else "启用桌宠")

func _tray_icon() -> Texture2D:
	var screen := DisplayServer.get_primary_screen()
	var target := 20.0 * maxf(1, DisplayServer.screen_get_scale(screen))
	if OS.get_name() == "Windows": target = 16.0 * maxf(1, DisplayServer.screen_get_dpi(screen) / 96.0)
	var best := 16
	for size: int in [20, 24, 32, 40, 48, 64]:
		if absf(size - target) < absf(best - target): best = size
	var path := "res://assets/icons/%s_%d.png" % ["tray" if _enabled else "tray_disabled", best]
	return load(path) if ResourceLoader.exists(path) else (TRAY_ICON if _enabled else TRAY_DISABLED)

func _update_refresh_rate() -> void:
	var settings_visible := is_instance_valid(settings_window) and not settings_window.is_queued_for_deletion() and settings_window.visible
	var menu_visible := (is_instance_valid(_tray_menu) and _tray_menu.visible) or (is_instance_valid(_menu) and _menu.visible)
	Engine.max_fps = 60 if is_instance_valid(world) else (30 if _enabled or settings_visible or menu_visible else 5)

func _set_hit_region() -> void:
	var image := Assets.texture("assembled/sheets/idle.png").get_image()
	var bounds := Rect2i()
	for frame in range(6):
		var used := image.get_region(Rect2i(frame * 96, 0, 96, 96)).get_used_rect()
		bounds = used if frame == 0 else bounds.merge(used)
	bounds = bounds.merge(Rect2i(96 - bounds.end.x, bounds.position.y, bounds.size.x, bounds.size.y))
	var rect := Rect2(Vector2(bounds.position) * settings.art_scale(), Vector2(bounds.size) * settings.art_scale()).grow(2)
	pet.mouse_passthrough_polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _pet_input(event: InputEvent) -> void:
	if mode != Mode.PET:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_tray_menu.hide()
			_menu.present(DisplayServer.mouse_get_position(), settings.values.app.theme)
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
	_entry_generation += 1
	var generation := _entry_generation
	if is_instance_valid(settings_window):
		settings_window.suspend()
	mode = Mode.ENTERING
	_drag_candidate = false
	_dragging = false
	screen_id = _screen_for_anchor(Vector2(pet.position) + pet_anchor)
	screen_origin = DisplayServer.screen_get_position(screen_id)
	screen_size = DisplayServer.screen_get_size(screen_id)
	var anchor := Vector2(pet.position) + pet_anchor - screen_origin
	# Hidden capture is deliberate: capture exclusions are compositor-dependent.
	pet.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _enabled or _quitting or generation != _entry_generation: return
	var snapshot: Dictionary = desktop.capture_desktop(screen_id)
	if snapshot.has("error"):
		pet.show()
		_set_window_taskbar(pet, false)
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
	world_window.title = "桌宠世界"
	world_window.force_native = true
	world_window.borderless = true
	world_window.unresizable = true
	world_window.always_on_top = true
	world_window.transparent_bg = false
	world_window.size = Vector2i(screen_size)
	world_window.position = Vector2i(screen_origin)
	world_window.theme = Fonts.theme()
	world_window.world_2d = World2D.new()
	add_child(world_window)
	world = World.new()
	world_window.add_child(world)
	world.build(snapshot, anchor, settings.art_scale(), settings.values.astronaut.smoke)
	world_window.close_requested.connect(leave_world)
	world_window.window_input.connect(_world_input)
	world_window.focus_exited.connect(_world_blurred)
	world_window.focus_entered.connect(_world_focused)
	world_window.show()
	_set_window_taskbar(world_window, false)
	world_window.grab_focus()
	_portal_time = 0
	mode = Mode.ENTERING
	Config.clear_input()
	_last_size = DisplayServer.screen_get_size(screen_id)

func _world_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave_world"):
		leave_world()

func _world_blurred() -> void:
	if mode != Mode.WORLD:
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
	pet.position = Vector2i((anchor - pet_anchor).round())
	visual.play("idle")
	pet.show()
	_set_window_taskbar(pet, false)
	Engine.max_fps = 30
	mode = Mode.PET
	_save_position()

func _process(delta: float) -> void:
	if desktop.bridge != null and OS.get_name() == "macOS" and desktop.bridge.consume_reopen():
		_set_enabled(true)
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
		if mode in [Mode.WORLD, Mode.PAUSED, Mode.ENTERING] and is_instance_valid(world):
			if screen_id >= DisplayServer.get_screen_count() or DisplayServer.screen_get_size(screen_id) != _last_size or Vector2(DisplayServer.screen_get_position(screen_id)) != screen_origin:
				leave_world()
				_clamp_pet()
		elif mode == Mode.PET:
			_clamp_pet()

func _clamp_pet() -> void:
	var monitor := _screen_for_anchor(Vector2(pet.position) + pet_anchor)
	var rect := Rect2(DisplayServer.screen_get_position(monitor), DisplayServer.screen_get_size(monitor))
	# Retain the root anchor, even when a small transparent margin is offscreen.
	var root_position := Vector2(pet.position) + pet_anchor
	root_position = root_position.clamp(rect.position + Vector2(34, 54) * settings.art_scale() / 2, rect.end - Vector2(34, 34) * settings.art_scale() / 2)
	pet.position = Vector2i(root_position - pet_anchor)

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
	if self.settings.values.app.remember_position and settings.load("user://position.cfg") == OK:
		var saved_screen: int = settings.get_value("pet", "screen", monitor)
		if saved_screen < DisplayServer.get_screen_count() and saved_screen >= 0:
			monitor = saved_screen
			anchor = Vector2(DisplayServer.screen_get_position(monitor)) + Vector2(settings.get_value("pet", "local_position", Vector2(150, 150)))
		visual.facing = settings.get_value("pet", "facing", 1.0)
	pet.position = Vector2i(anchor - pet_anchor)
	_clamp_pet()

func _save_position() -> void:
	if not settings.values.app.remember_position:
		return
	var settings := ConfigFile.new()
	var monitor := _screen_for_anchor(Vector2(pet.position) + pet_anchor)
	settings.set_value("pet", "screen", monitor)
	settings.set_value("pet", "local_position", Vector2(pet.position) + pet_anchor - Vector2(DisplayServer.screen_get_position(monitor)))
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
	if _tray_id >= 0:
		DisplayServer.delete_status_indicator(_tray_id)
		_tray_id = -1
	_resident.stop()
	get_tree().quit()

func _open_settings() -> void:
	if not _font_warning_shown:
		_font_warning_shown = true
		var missing := Fonts.missing_fonts()
		if not missing.is_empty(): call_deferred("_show_error", "请安装字体：" + "、".join(missing))
	if is_instance_valid(settings_window):
		settings_window.show()
		_set_window_taskbar(settings_window, true)
		settings_window.grab_focus()
		return
	_drag_candidate = false
	_dragging = false
	settings_window = SettingsWindow.new()
	settings_window.visible = false
	settings_window.force_native = true
	settings_window.store = settings
	settings_window.initial_screen = _screen_for_anchor(Vector2(pet.position) + pet_anchor)
	settings_window.visibility_changed.connect(_settings_visibility_changed)
	settings_window.tree_exiting.connect(_sync_dock)
	settings_window.tree_exited.connect(func():
		_update_refresh_rate()
		if _tray_id < 0 and not _quitting: call_deferred("_quit"))
	add_child(settings_window)

func _settings_changed(_previous: Dictionary) -> void:
	var feet := Vector2(pet.position) + pet_anchor + Vector2(0, 16 * visual.art_scale)
	var art_scale: float = settings.art_scale()
	pet_anchor = Config.ROOT * art_scale
	visual.art_scale = art_scale
	visual.scale = Vector2.ONE * art_scale
	visual.position = pet_anchor
	visual.smoke_style = settings.values.astronaut.smoke
	pet.size = Vector2i(Vector2(96, 96) * art_scale)
	pet.position = Vector2i((feet - pet_anchor - Vector2(0, 16 * art_scale)).round())
	pet.always_on_top = settings.values.app.always_on_top
	_set_hit_region()
	_set_window_taskbar(pet, false)
	_refresh_ui_theme()
	_clamp_pet()
	_save_position()

func _refresh_ui_theme() -> void:
	pet.theme = Style.build(settings.values.app.theme)
	if is_instance_valid(_tray_menu): _tray_menu.theme = pet.theme
	if is_instance_valid(_dialog): _dialog.theme = pet.theme
	if is_instance_valid(world_window): world_window.theme = Fonts.theme()

func _set_window_taskbar(window: Window, show_in_taskbar: bool) -> void:
	if not is_instance_valid(window) or window.is_queued_for_deletion() or not window.visible: return
	DisplayServer.window_set_icon(APP_ICON.get_image(), window.get_window_id())
	if OS.get_name() == "macOS":
		_sync_dock()
		return
	if OS.get_name() != "Windows" or desktop.bridge == null: return
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window.get_window_id())
	if handle != 0 and not desktop.bridge.set_window_taskbar_visible(handle, show_in_taskbar):
		push_warning("无法更新窗口任务栏状态。")

func _settings_visibility_changed() -> void:
	if is_instance_valid(settings_window) and not settings_window.is_queued_for_deletion():
		settings_window.process_mode = Node.PROCESS_MODE_INHERIT if settings_window.visible else Node.PROCESS_MODE_DISABLED
		if settings_window.visible: call_deferred("_set_window_taskbar", settings_window, true)
	_sync_dock()
	_update_refresh_rate()

func _sync_dock() -> void:
	if OS.get_name() != "macOS" or desktop.bridge == null: return
	var show_icon := is_instance_valid(settings_window) and not settings_window.is_queued_for_deletion() and settings_window.visible
	if not desktop.bridge.set_app_dock_visible(show_icon): push_warning("无法更新 Dock 状态。")
