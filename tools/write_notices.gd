extends SceneTree

func _initialize() -> void:
	var text := "minispaceman — third-party engine and binding notices\n\n"
	text += "Godot Engine 4.7.2\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text()
	text += "\n\nGodot third-party component attributions\n\n"
	text += JSON.stringify(Engine.get_copyright_info(), "\t")
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		text += "\n\n===== " + name + " =====\n" + String(licenses[name])
	text += "\n\n===== godot-cpp =====\n"
	text += FileAccess.get_file_as_string("res://native/godot-cpp/LICENSE.md")
	var file := FileAccess.open("res://docs/THIRD_PARTY_NOTICES.txt", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write third-party notices")
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("Wrote docs/THIRD_PARTY_NOTICES.txt")
	quit()
