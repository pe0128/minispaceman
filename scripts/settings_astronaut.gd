extends "res://scripts/settings_page.gd"

const Visual = preload("res://scripts/actor_visual.gd")
var actor: Node2D

func _ready() -> void:
	label("宇航员", 28)
	choice("大小", ["50%", "100%", "150%", "200%"],
		[50, 100, 150, 200].find(draft.astronaut.size), func(index: int):
			draft.astronaut.size = [50, 100, 150, 200][index]
			_refresh_preview()
			edited.emit())
	choice("喷气大小", ["小", "中", "大"],
		["small", "medium", "large"].find(draft.astronaut.smoke), func(index: int):
			draft.astronaut.smoke = ["small", "medium", "large"][index]
			_refresh_preview()
			edited.emit())
	label("预览", 17)
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(0, 310)
	preview.clip_contents = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	actor = Visual.new()
	actor.art_scale = float(draft.astronaut.size) / 50.0
	actor.smoke_style = draft.astronaut.smoke
	actor.jetting = true
	actor.play("jetpack")
	preview.add_child(actor)
	preview.resized.connect(func(): actor.position = Vector2(preview.size.x * 0.5, 130))

func _refresh_preview() -> void:
	if not is_instance_valid(actor): return
	actor.art_scale = float(draft.astronaut.size) / 50.0
	actor.scale = Vector2.ONE * actor.art_scale
	actor.smoke_style = draft.astronaut.smoke
