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
	var theme := preload("res://scripts/ui_fonts.gd").theme()
	for type: String in ["Label", "Button", "OptionButton", "CheckButton", "PopupMenu"]:
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(key, type, p.text)
		theme.set_color("font_disabled_color", type, p.muted)
	for type: String in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", type, box(p.panel, p.line, 1))
		theme.set_stylebox("hover", type, box(p.panel.lerp(p.accent, 0.10), p.accent, 1))
		theme.set_stylebox("pressed", type, box(p.panel.lerp(p.accent, 0.16), p.accent, 1))
		theme.set_stylebox("hover_pressed", type, box(p.panel.lerp(p.accent, 0.24), p.accent, 1))
		theme.set_stylebox("disabled", type, box(p.bg, p.line, 1))
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, p.accent, 2))
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			theme.set_color(key, type, p.accent)
		theme.set_color("icon_disabled_color", type, p.muted)
	theme.set_type_variation("SettingsNavigation", "Button")
	theme.set_stylebox("pressed", "SettingsNavigation", box(p.panel.lerp(p.accent, 0.18), p.accent, 1))
	theme.set_stylebox("hover_pressed", "SettingsNavigation", box(p.panel.lerp(p.accent, 0.26), p.accent, 1))
	theme.set_type_variation("SettingsApply", "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var strength := 0.0 if state == "normal" else (0.12 if state == "hover" else 0.22)
		var fill: Color = p.accent.lerp(p.text, strength)
		theme.set_stylebox(state, "SettingsApply", box(fill, fill, 1))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(key, "SettingsApply", p.bg)
	theme.set_color("font_disabled_color", "SettingsApply", p.muted)
	theme.set_stylebox("disabled", "SettingsApply", box(p.bg, p.line, 1))
	theme.set_stylebox("focus", "SettingsApply", box(Color.TRANSPARENT, p.text, 2))
	theme.set_stylebox("panel", "PopupMenu", box(p.panel, p.line, 1))
	theme.set_stylebox("hover", "PopupMenu", box(p.panel.lerp(p.accent, 0.16)))
	theme.set_stylebox("panel", "Panel", box(p.panel.lerp(p.accent, 0.08), p.line, 1))
	theme.set_stylebox("panel", "AcceptDialog", box(p.bg, p.line, 1))
	theme.set_constant("separation", "VBoxContainer", 16)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme
