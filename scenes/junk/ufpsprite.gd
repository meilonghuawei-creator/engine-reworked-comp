extends Sprite3D

## Horizontal loop distance from origin
@export var orbit_radius: float = 3.0
## How fast it completes a full circle
@export var orbit_speed: float = 1.5
## Vertical bobbing height
@export var hover_amplitude: float = 0.5
## How fast it bobs up and down
@export var hover_speed: float = 3.0

var _time: float = 0.0
@onready var _origin: Vector3 = position

func _process(delta: float) -> void:
	_time += delta
	
	# Horizontal Orbit (X and Z coordinates)
	# We use cosine and sine to create a perfect circle
	var x_pos = cos(_time * orbit_speed) * orbit_radius
	var z_pos = sin(_time * orbit_speed) * orbit_radius
	
	# Vertical Hover (Y coordinate)
	# We use a separate sine wave for independent vertical bobbing
	var y_pos = sin(_time * hover_speed) * hover_amplitude
	
	# Apply the combined offset to the starting origin
	position = _origin + Vector3(x_pos, y_pos, z_pos)
