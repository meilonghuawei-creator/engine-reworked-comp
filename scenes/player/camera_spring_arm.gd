extends SpringArm3D

@export var touch_sensitivity := 0.005
var camera_touch_index := -1

@export var tpsmouse_sensitivity := 0.002
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = -PI/4

const ZOOM_SPEED := 1.0
const ZOOM_MIN := 1.8
const ZOOM_MAX := 5.0

func _ready() -> void:
	# Only the local player who owns this instance should lock the mouse
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	
func _unhandled_input(event: InputEvent) -> void:
	# Ignore input if we don't own this player or if the mouse isn't captured
	if !is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * tpsmouse_sensitivity
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= event.relative.y * tpsmouse_sensitivity
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

# --- FIXED MOBILE TOUCH ROTATION ---
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x / 2.0:
			camera_touch_index = event.index
		elif not event.pressed and event.index == camera_touch_index:
			camera_touch_index = -1

	elif event is InputEventScreenDrag:
		if event.index == camera_touch_index:
			rotation.y -= event.relative.x * touch_sensitivity
			rotation.y = wrapf(rotation.y, 0.0, TAU)
			
			rotation.x -= event.relative.y * touch_sensitivity
			rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

	if event.is_action_pressed("mouse_wheel_up"):
		spring_length = clamp(spring_length - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
	if event.is_action_pressed("mouse_wheel_down"):
		spring_length = clamp(spring_length + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
