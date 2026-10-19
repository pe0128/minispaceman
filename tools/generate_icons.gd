extends SceneTree

# Run with Godot --headless --path . --script tools/generate_icons.gd.
# Only the copied project sprite is used; no external imaging dependency.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/spaceman/assembled/sheets/idle.png")
	var frame := source.get_region(Rect2i(0, 0, 96, 96))
	var sprite := frame.get_region(frame.get_used_rect())
	DirAccess.make_dir_recursive_absolute("res://assets/icons")
	var pngs: Dictionary = {}
	for size: int in [16, 24, 32, 48, 64, 128, 256, 512, 1024]:
		var scaled := sprite.duplicate()
		var factor := float(size) * 0.9 / maxi(sprite.get_width(), sprite.get_height())
		scaled.resize(maxi(1, roundi(sprite.get_width() * factor)), maxi(1, roundi(sprite.get_height() * factor)), Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), (Vector2i(size, size) - scaled.get_size()) / 2)
		pngs[size] = canvas.save_png_to_buffer()
		if size == 256: canvas.save_png("res://assets/icons/app.png")
		if size == 32:
			canvas.save_png("res://assets/icons/tray.png")
			for y in size:
				for x in size:
					var color := canvas.get_pixel(x, y)
					var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
					canvas.set_pixel(x, y, Color(gray, gray, gray, color.a * 0.7))
			canvas.save_png("res://assets/icons/tray_disabled.png")
	var ico := StreamPeerBuffer.new()
	ico.put_u16(0)
	ico.put_u16(1)
	ico.put_u16(7)
	var offset := 6 + 16 * 7
	for size: int in [16, 24, 32, 48, 64, 128, 256]:
		ico.put_u8(size if size < 256 else 0)
		ico.put_u8(size if size < 256 else 0)
		ico.put_u16(0)
		ico.put_u16(1)
		ico.put_u16(32)
		ico.put_u32(pngs[size].size())
		ico.put_u32(offset)
		offset += pngs[size].size()
	for size: int in [16, 24, 32, 48, 64, 128, 256]: ico.put_data(pngs[size])
	FileAccess.open("res://assets/icons/app.ico", FileAccess.WRITE).store_buffer(ico.data_array)
	var chunks := StreamPeerBuffer.new()
	chunks.big_endian = true
	var types := {16: "icp4", 32: "icp5", 64: "icp6", 128: "ic07", 256: "ic08", 512: "ic09", 1024: "ic10"}
	for size: int in types:
		chunks.put_data(types[size].to_ascii_buffer())
		chunks.put_u32(pngs[size].size() + 8)
		chunks.put_data(pngs[size])
	var icns := StreamPeerBuffer.new()
	icns.big_endian = true
	icns.put_data("icns".to_ascii_buffer())
	icns.put_u32(chunks.data_array.size() + 8)
	icns.put_data(chunks.data_array)
	FileAccess.open("res://assets/icons/app.icns", FileAccess.WRITE).store_buffer(icns.data_array)
	quit()
