extends "res://scripts/settings_page.gd"

var store: RefCounted
var _status: Label
var _login_button: Button

func _ready() -> void:
	label("应用", 28)
	label("管理启动、桌面行为与界面外观。")
	var startup := toggle("登录后自动启动", "仅对当前系统用户生效，无需管理员权限。", draft.app.autostart,
		func(value: bool): draft.app.autostart = value; edited.emit())
	startup.disabled = OS.has_feature("editor") or store.bridge == null
	_status = label("", 13)
	_login_button = Button.new()
	_login_button.text = "打开系统登录项设置…"
	_login_button.pressed.connect(func(): store.bridge.open_login_settings())
	add_child(_login_button)
	refresh_status()
	toggle("桌宠始终置顶", "控制普通桌宠；桌宠世界仍需覆盖当前显示器。", draft.app.always_on_top,
		func(value: bool): draft.app.always_on_top = value; edited.emit())
	toggle("记住上次位置", "下次启动时恢复桌宠的位置与朝向。", draft.app.remember_position,
		func(value: bool): draft.app.remember_position = value; edited.emit())
	choice("界面主题", "跟随系统，或为设置窗口固定一种外观。", ["跟随系统", "浅色", "深色"],
		["system", "light", "dark"].find(draft.app.theme), func(index: int):
			draft.app.theme = ["system", "light", "dark"][index]
			edited.emit())

func refresh_status() -> void:
	var status: Dictionary = store.login_status()
	var names := {"enabled": "系统状态：已启用", "notRegistered": "系统状态：未注册",
		"requiresApproval": "系统状态：等待你在系统设置中允许", "notFound": "系统找不到应用，请将应用移至固定位置后重试。"}
	_status.text = names.get(status.state, status.get("message", "无法读取系统状态。"))
	_login_button.visible = status.state == "requiresApproval"
