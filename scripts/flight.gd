extends RefCounted

const Config = preload("res://scripts/config.gd")
var jumped := false
var held_time := 0.0
var jetting := false

func reset() -> void:
	jumped = false
	held_time = 0.0
	jetting = false

func step(grounded: bool, pressed: bool, held: bool, dropping: bool, delta: float) -> Dictionary:
	var jump := false
	var drop := false
	if grounded:
		reset()
		if pressed:
			if dropping:
				drop = true
			else:
				jump = true
				jumped = true
	elif pressed:
		jetting = true
	if not held:
		jetting = false
		held_time = 0.0
	elif jumped:
		held_time += delta
		if held_time >= Config.JET_HOLD_DELAY:
			jetting = true
	return {"jump": jump, "jet": jetting, "drop": drop}
