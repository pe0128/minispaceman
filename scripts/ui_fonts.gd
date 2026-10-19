extends RefCounted

static var _font: SystemFont

static func font() -> SystemFont:
	if _font == null:
		var chinese := SystemFont.new()
		chinese.font_names = PackedStringArray(["SimSun", "宋体", "Songti SC"])
		chinese.allow_system_fallback = false
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Times New Roman"])
		_font.allow_system_fallback = false
		_font.fallbacks = [chinese]
	return _font

static func missing_fonts() -> PackedStringArray:
	var available := OS.get_system_fonts()
	var missing := PackedStringArray()
	if not "Times New Roman" in available: missing.append("Times New Roman")
	if not ("SimSun" in available or "宋体" in available or "Songti SC" in available): missing.append("宋体")
	return missing

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 16
	return result
