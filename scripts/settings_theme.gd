extends RefCounted

static func palette(mode: String) -> Dictionary:
	var dark := mode == "dark" or (mode == "system" and DisplayServer.is_dark_mode())
	return {"bg": Color("111923" if dark else "F6F8FB"), "panel": Color("1B2735" if dark else "FFFFFF"),
		"text": Color("E6EDF6" if dark else "182330"), "muted": Color("A8B8CB" if dark else "607286"),
		"accent": Color("63D9E8" if dark else "087E94"), "line": Color("34465A" if dark else "DCE4ED"),
		"error": Color("FFABAB" if dark else "B32632")}

static func box(color: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func build(mode: String) -> Theme:
	var p := palette(mode)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_type_variation("SettingsDescription", "Label")
	theme.set_color("font_color", "SettingsDescription", p.muted)
	for type: String in ["Label", "Button", "OptionButton", "CheckButton", "PopupMenu"]:
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(key, type, p.text)
		theme.set_color("font_disabled_color", type, p.muted)
	for type: String in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", type, box(p.panel, p.line, 1))
		theme.set_stylebox("hover", type, box(p.panel.lerp(p.accent, 0.12), p.accent, 1))
		theme.set_stylebox("pressed", type, box(p.panel.lerp(p.accent, 0.23), p.accent, 1))
		theme.set_stylebox("disabled", type, box(p.bg, p.line, 1))
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, p.accent, 2))
	theme.set_stylebox("panel", "PopupMenu", box(p.panel, p.line, 1))
	theme.set_stylebox("panel", "Panel", box(p.panel.lerp(p.accent, 0.08), p.line, 1))
	theme.set_stylebox("panel", "AcceptDialog", box(p.bg, p.line, 1))
	theme.set_constant("separation", "VBoxContainer", 14)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme
