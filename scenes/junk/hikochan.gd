extends Sprite3D

## Total distance the plane travels (Forward/Backward)
@export var patrol_distance: float = 10.0
## Movement speed
@export var speed: float = 4.0
## Vertical bobbing height
@export var hover_amplitude: float = 0.2

var _time: float = 0.0
var _direction: float = -1.0 # -1.0 is Forward (-Z), 1.0 is Backward (+Z)
@onready var _origin: Vector3 = position

func _process(delta: float) -> void:
	_time += delta
	
	# 1. Move along the Z axis (Forward/Backward)
	position.z += speed * _direction * delta
	
	# 2. Check distance from the starting Z position
	var current_offset = position.z - _origin.z
	
	if abs(current_offset) >= patrol_distance:
		# Snap to the exact limit to prevent drifting
		position.z = _origin.z + (patrol_distance * _direction)
		
		# Reverse direction
		_direction *= -1.0
		
		# Flip the image so it looks like it's heading the other way
		flip_h = !flip_h

	# 3. Keep the slight hover on the Y axis
	position.y = _origin.y + (sin(_time * 3.0) * hover_amplitude)
