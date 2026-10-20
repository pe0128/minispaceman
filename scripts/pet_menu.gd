extends Window

signal id_pressed(id: int)

const Style = preload("res://scripts/settings_theme.gd")
var bridge: Object
var _items: Array[Button] = []
var _column: VBoxContainer

func _init() -> void:
	visible = false
	force_native = true
	transient = false
	borderless = true
	unresizable = true
	unfocusable = false
	mouse_passthrough = false
	always_on_top = true
	transparent = true
	transparent_bg = true
	title = "minispaceman"
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PetMenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	panel.add_child(_column)
	close_requested.connect(hide)
	focus_exited.connect(func(): call_deferred("_dismiss_if_unfocused"))
	window_input.connect(_menu_input)

func add_item(text: String, id: int) -> void:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = "PetMenuItem"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(180, 34)
	button.pressed.connect(func(): hide(); id_pressed.emit(id))
	_column.add_child(button)
	_items.append(button)
	for index in _items.size():
		_items[index].focus_neighbor_top = _items[posmod(index - 1, _items.size())].get_path()
		_items[index].focus_neighbor_bottom = _items[(index + 1) % _items.size()].get_path()

func add_separator() -> void:
	_column.add_child(HSeparator.new())

func set_item_text(index: int, text: String) -> void:
	_items[index].text = text

func present(anchor: Vector2i, theme_mode: String) -> void:
	theme = Style.build(theme_mode)
	var screen := DisplayServer.get_primary_screen()
	for index in DisplayServer.get_screen_count():
		if Rect2i(DisplayServer.screen_get_position(index), DisplayServer.screen_get_size(index)).has_point(anchor):
			screen = index
			break
	content_scale_factor = maxf(1, DisplayServer.screen_get_scale(screen))
	if OS.get_name() == "Windows": content_scale_factor = maxf(1, DisplayServer.screen_get_dpi(screen) / 96.0)
	var logical_size := _column.get_combined_minimum_size() + Vector2(16, 16)
	size = Vector2i((logical_size * content_scale_factor).ceil())
	var usable := DisplayServer.screen_get_usable_rect(screen)
	position = anchor.clamp(usable.position, (usable.end - size).max(usable.position))
	show()
	# This is a regular focusable native window. Godot Popup windows deliberately
	# skip foreground activation, which fails when the owner is our background host.
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_window_id())
	if bridge != null and not bridge.present_menu_window(handle):
		push_warning("无法激活菜单窗口。")
	grab_focus()
	if not _items.is_empty(): _items[0].grab_focus()

func _dismiss_if_unfocused() -> void:
	if visible and not has_focus(): hide()

func _menu_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed: return
	if event.keycode == KEY_ESCAPE:
		hide()
		set_input_as_handled()
