extends SceneTree

# Run with Godot --headless --path . --script tools/generate_icons.gd.
# Only the copied project sprite is used; no external imaging dependency.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/spaceman/assembled/sheets/idle.png")
	var frame := source.get_region(Rect2i(0, 0, 96, 96))
	var sprite := frame.get_region(frame.get_used_rect())
	var disabled := Image.load_from_file("res://assets/icons/tray_disabled_source.png")
	disabled = disabled.get_region(disabled.get_used_rect())
	# Normalize the approved drawing for small tray sizes; keep opaque pixels,
	# strong grayscale steps and a genuinely transparent background.
	for y in disabled.get_height():
		for x in disabled.get_width():
			var color := disabled.get_pixel(x, y)
			var gray := snappedf(color.r * 0.299 + color.g * 0.587 + color.b * 0.114, 0.2)
			disabled.set_pixel(x, y, Color(gray, gray, gray, 1.0 if color.a >= 0.5 else 0.0))
	DirAccess.make_dir_recursive_absolute("res://assets/icons")
	for size: int in [16, 20, 24, 32, 40, 48, 64]:
		for inactive: bool in [false, true]:
			var input: Image = disabled if inactive else sprite
			var scaled := input.duplicate()
			var factor := float(size) * 0.9 / maxi(input.get_width(), input.get_height())
			scaled.resize(maxi(1, roundi(input.get_width() * factor)), maxi(1, roundi(input.get_height() * factor)), Image.INTERPOLATE_NEAREST)
			var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), (Vector2i(size, size) - scaled.get_size()) / 2)
			var stem := "tray_disabled" if inactive else "tray"
			canvas.save_png("res://assets/icons/%s_%d.png" % [stem, size])
			if size == 32: canvas.save_png("res://assets/icons/%s.png" % stem)
	var pngs: Dictionary = {}
	for size: int in [16, 24, 32, 48, 64, 128, 256, 512, 1024]:
		var scaled := sprite.duplicate()
		var factor := float(size) * 0.9 / maxi(sprite.get_width(), sprite.get_height())
		scaled.resize(maxi(1, roundi(sprite.get_width() * factor)), maxi(1, roundi(sprite.get_height() * factor)), Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), (Vector2i(size, size) - scaled.get_size()) / 2)
		pngs[size] = canvas.save_png_to_buffer()
		if size == 256: canvas.save_png("res://assets/icons/app.png")
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
