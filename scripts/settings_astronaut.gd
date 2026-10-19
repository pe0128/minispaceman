extends "res://scripts/settings_page.gd"

const Visual = preload("res://scripts/actor_visual.gd")
var actor: Node2D

func _ready() -> void:
	label("宇航员", 28)
	label("调整你的太空伙伴，让它更贴合你的桌面。")
	choice("宇航员大小", "普通桌宠与桌宠世界共用尺寸；应用时保持脚下位置。", ["50% · 迷你", "100% · 标准", "150% · 大", "200% · 特大"],
		[50, 100, 150, 200].find(draft.astronaut.size), func(index: int):
			draft.astronaut.size = [50, 100, 150, 200][index]
			_refresh_preview()
			edited.emit())
	choice("喷气烟雾", "三套独立素材，仅改变视觉效果，飞行推力相同。", ["小 · 紧凑火焰", "中 · 轻盈烟雾", "大 · 扩散烟云"],
		["small", "medium", "large"].find(draft.astronaut.smoke), func(index: int):
			draft.astronaut.smoke = ["small", "medium", "large"][index]
			_refresh_preview()
			edited.emit())
	label("实时预览", 17)
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
	label("预览独立于桌宠；点击「应用」后才生效。", 13)

func _refresh_preview() -> void:
	if not is_instance_valid(actor): return
	actor.art_scale = float(draft.astronaut.size) / 50.0
	actor.scale = Vector2.ONE * actor.art_scale
	actor.smoke_style = draft.astronaut.smoke
