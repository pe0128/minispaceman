extends "res://scripts/settings_page.gd"

var store: RefCounted
var _status: Label
var _login_button: Button

func _ready() -> void:
	label("应用", 28)
	var startup := toggle("开机自启动", draft.app.autostart,
		func(value: bool): draft.app.autostart = value; edited.emit())
	startup.disabled = OS.has_feature("editor") or store.bridge == null
	_status = label("", 13)
	_login_button = Button.new()
	_login_button.text = "打开系统登录项设置…"
	_login_button.pressed.connect(func(): store.bridge.open_login_settings())
	add_child(_login_button)
	refresh_status()
	toggle("始终置顶", draft.app.always_on_top,
		func(value: bool): draft.app.always_on_top = value; edited.emit())
	toggle("记住位置", draft.app.remember_position,
		func(value: bool): draft.app.remember_position = value; edited.emit())
	choice("主题", ["跟随系统", "浅色", "深色"],
		["system", "light", "dark"].find(draft.app.theme), func(index: int):
			draft.app.theme = ["system", "light", "dark"][index]
			edited.emit())

func refresh_status() -> void:
	var status: Dictionary = store.login_status()
	_status.visible = status.state in ["requiresApproval", "notFound", "unavailable"]
	match status.state:
		"requiresApproval": _status.text = "需要在系统设置中允许自启动。"
		"notFound": _status.text = "找不到登录项中的应用，请重新设置自启动。"
		"unavailable": _status.text = status.get("message", "无法读取登录项。")
		_: _status.text = ""
	_login_button.visible = status.state == "requiresApproval"
