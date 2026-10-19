extends RefCounted

const ART_SCALE := 2.0
const ROOT := Vector2(48, 60)
const FEET := Vector2(0, 32)
const PET_SIZE := Vector2i(192, 192)
const GRAVITY := 1100.0
const MOVE_SPEED := 240.0
const CROUCH_SPEED := 105.0
const JUMP_SPEED := 410.0
const JET_ACCELERATION := 1750.0
const JET_MAX_SPEED := 330.0
const FALL_MAX_SPEED := 700.0
const JET_HOLD_DELAY := 0.25
const PICKUP_RADIUS := 90.0
const THROW_SPEED := 580.0
const BULLET_SPEED := 1150.0
const BULLET_LIFETIME := 2.0
const ENTER_DURATION := 0.6
const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"crouch": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"pickup": [KEY_Q],
	"throw_item": [KEY_E],
	"leave_world": [KEY_ESCAPE],
}

static func setup_input() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in ACTIONS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", click)

static func clear_input() -> void:
	for action: StringName in InputMap.get_actions():
		if ACTIONS.has(String(action)) or action == &"shoot":
			Input.action_release(action)
