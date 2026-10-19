extends VBoxContainer

signal edited
var draft: Dictionary

func label(text: String, font_size: int = 15) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	if font_size <= 13: node.theme_type_variation = "SettingsDescription"
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(node)
	return node

func choice(title: String, description: String, options: Array, selected: int, callback: Callable) -> OptionButton:
	label(title, 17)
	label(description, 13)
	var select := OptionButton.new()
	select.custom_minimum_size.y = 42
	for text: String in options: select.add_item(text)
	select.select(selected)
	select.item_selected.connect(callback)
	add_child(select)
	return select

func toggle(title: String, description: String, value: bool, callback: Callable) -> CheckButton:
	var control := CheckButton.new()
	control.text = title
	control.button_pressed = value
	control.custom_minimum_size.y = 44
	control.toggled.connect(callback)
	add_child(control)
	label(description, 13)
	return control
