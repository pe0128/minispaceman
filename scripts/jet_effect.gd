extends Node2D

const Assets = preload("res://scripts/assets.gd")
var emitting := false
var style := "small"
var facing := 1.0
var _previous := ""
var _clock := 0.0
var _timer := 0.0
var _puffs: Array[Dictionary] = []
var _variants: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Assets.BASE + "effects/manifest.json"))
	for entry: Dictionary in manifest.variants:
		_variants[entry.name.trim_prefix("jet-")] = entry

func _process(delta: float) -> void:
	if style != _previous:
		_puffs.clear()
		_timer = 0
		_previous = style
	_clock += delta
	var entry: Dictionary = _variants.get(style, _variants.small)
	if emitting and style != "small":
		var emitter: Dictionary = entry.emitter
		_timer -= delta
		while _timer <= 0:
			_timer += float(emitter.interval)
			for index in range(int(emitter.burst)):
				if _puffs.size() >= 64: _puffs.pop_front()
				var speed := Vector2(randf_range(-float(emitter.spreadSpeed), float(emitter.spreadSpeed)), float(emitter.speed))
				_puffs.append({"at": global_position, "speed": speed * global_scale.abs(), "age": 0.0,
					"life": float(emitter.life), "max_scale": float(emitter.maxScale)})
	else:
		_timer = 0
	for i in range(_puffs.size() - 1, -1, -1):
		_puffs[i].age += delta
		_puffs[i].at += _puffs[i].speed * delta
		if _puffs[i].age >= _puffs[i].life: _puffs.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if _variants.is_empty(): return
	var entry: Dictionary = _variants.get(style, _variants.small)
	var sheet := Assets.texture(entry.sheet)
	if style == "small":
		if emitting:
			draw_texture_rect_region(sheet, Rect2(-16, -2, 32, 32), Rect2((int(_clock * 12) % 6) * 32, 0, 32, 32))
		return
	for puff: Dictionary in _puffs:
		var progress: float = puff.age / puff.life
		var extent := Vector2.ONE * 32 * lerpf(0.4, puff.max_scale, progress)
		draw_texture_rect_region(sheet, Rect2(to_local(puff.at) - extent * 0.5, extent),
			Rect2(mini(5, int(progress * 6)) * 32, 0, 32, 32), Color(1, 1, 1, 1.0 - smoothstep(0.65, 1.0, progress)))
