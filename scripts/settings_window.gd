extends Window

const Store = preload("res://scripts/settings_store.gd")
const Style = preload("res://scripts/settings_theme.gd")
# Add a category here and a page script to extend the settings surface.
const CATEGORIES := [
	{"id": "astronaut", "title": "宇航员", "page": preload("res://scripts/settings_astronaut.gd")},
	{"id": "app", "title": "应用", "page": preload("res://scripts/settings_app.gd")}]
var store: RefCounted
var initial_screen := -1
var draft: Dictionary
var _category := 0
var _root: PanelContainer
var _sidebar: PanelContainer
var _pages: VBoxContainer
var _page: VBoxContainer
var _status: Label
var _apply: Button
var _nav: Array[Button] = []
var _confirm: ConfirmationDialog
var _close_after_apply := false

func _ready() -> void:
	title = "设置"
	min_size = Vector2i(760, 540)
	size = Vector2i(960, 680)
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if initial_screen < 0: initial_screen = DisplayServer.get_primary_screen()
	content_scale_factor = maxf(1, DisplayServer.screen_get_scale(initial_screen))
	if OS.get_name() == "Windows":
		content_scale_factor = maxf(1, DisplayServer.screen_get_dpi(initial_screen) / 96.0)
	# Fit the available display while keeping the scrollable page usable.
	var available := DisplayServer.screen_get_usable_rect(initial_screen).size - Vector2i(48, 80)
	content_scale_factor = minf(content_scale_factor, maxf(1, minf(available.x / 760.0, available.y / 540.0)))
	size = Vector2i(Vector2(size) * content_scale_factor)
	min_size = Vector2i(Vector2(min_size) * content_scale_factor)
	size = size.min(available.max(min_size))
	draft = store.values.duplicate(true)
	_root = PanelContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var column := VBoxContainer.new()
	_root.add_child(column)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_sidebar = PanelContainer.new()
	_sidebar.custom_minimum_size.x = 180
	body.add_child(_sidebar)
	var nav := VBoxContainer.new()
	_sidebar.add_child(nav)
	var brand := Label.new()
	brand.text = "minispaceman"
	brand.add_theme_font_size_override("font_size", 14)
	brand.custom_minimum_size.y = 84
	nav.add_child(brand)
	var group := ButtonGroup.new()
	for index in range(CATEGORIES.size()):
		var button := Button.new()
		button.text = CATEGORIES[index].title
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 46
		button.pressed.connect(_show_page.bind(index))
		nav.add_child(button)
		_nav.append(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(margin)
	_pages = VBoxContainer.new()
	margin.add_child(_pages)
	var footer := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]: footer.add_theme_constant_override("margin_" + edge, 14)
	column.add_child(footer)
	var actions := HBoxContainer.new()
	footer.add_child(actions)
	var reset := Button.new()
	reset.text = "重置本页"
	reset.pressed.connect(_reset_page)
	actions.add_child(reset)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 80
	_status.add_theme_font_size_override("font_size", 13)
	actions.add_child(_status)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	_apply = Button.new()
	_apply.text = "应用"
	_apply.custom_minimum_size.x = 90
	_apply.pressed.connect(_apply_changes)
	actions.add_child(_apply)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "保存设置？"
	_confirm.dialog_text = "你还有尚未应用的修改。"
	_confirm.ok_button_text = "应用并关闭"
	_confirm.cancel_button_text = "继续编辑"
	_confirm.add_button("放弃修改", false, "discard")
	_confirm.confirmed.connect(func(): _close_after_apply = true; _apply_changes())
	_confirm.custom_action.connect(func(_action: StringName): queue_free())
	add_child(_confirm)
	close_requested.connect(_request_close)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _confirm.visible: _request_close())
	focus_entered.connect(func():
		if is_instance_valid(_page) and _page.has_method("refresh_status"): _page.refresh_status())
	DisplayServer.set_system_theme_change_callback(_theme_changed)
	_show_page(0)
	call_deferred("_present")

func _present() -> void:
	var area := DisplayServer.screen_get_usable_rect(initial_screen)
	position = area.position + (area.size - size) / 2
	show()
	grab_focus()

func _exit_tree() -> void:
	DisplayServer.set_system_theme_change_callback(Callable())

func _theme_changed() -> void:
	if draft.app.theme == "system": _update_theme()

func _show_page(index: int) -> void:
	_category = index
	if is_instance_valid(_page):
		_pages.remove_child(_page)
		_page.queue_free()
	_page = CATEGORIES[index].page.new()
	_page.draft = draft
	if CATEGORIES[index].id == "app": _page.store = store
	_page.edited.connect(_edited)
	_pages.add_child(_page)
	_nav[index].button_pressed = true
	_edited()

func _edited() -> void:
	_apply.disabled = draft == store.values
	_status.text = "有未应用的修改" if not _apply.disabled else "设置已保存"
	_update_theme()

func _update_theme() -> void:
	theme = Style.build(draft.app.theme)
	var p := Style.palette(draft.app.theme)
	_root.add_theme_stylebox_override("panel", Style.box(p.bg))
	_sidebar.add_theme_stylebox_override("panel", Style.box(p.panel))
	_status.add_theme_color_override("font_color", p.muted)
	_apply.add_theme_stylebox_override("normal", Style.box(p.accent))
	_apply.add_theme_color_override("font_color", p.bg)

func _reset_page() -> void:
	var key: String = CATEGORIES[_category].id
	draft[key] = Store.DEFAULTS[key].duplicate(true)
	_show_page(_category)

func _apply_changes() -> void:
	var error: String = store.apply(draft)
	if not error.is_empty():
		_status.text = error
		_status.add_theme_color_override("font_color", Style.palette(draft.app.theme).error)
		_close_after_apply = false
		return
	_edited()
	if _page.has_method("refresh_status"): _page.refresh_status()
	if _close_after_apply: queue_free()

func _request_close() -> void:
	if draft == store.values: queue_free()
	else: _confirm.popup_centered(Vector2i(470, 150))
