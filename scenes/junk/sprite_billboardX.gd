extends Sprite3D
class_name Billboardx

@onready var current_camera : Camera3D
@onready var node_y_axis : Node3D = $Rotate_y
@onready var node_x_axis : Node3D = $Rotate_y/Rotate_x
@onready var sprite : Sprite3D = $Rotate_y/Rotate_x/Sprite3D

@export var distance_factor : float = 5
@export var min_angle : float = 0
@export var max_angle : float = 20

func _process(_delta: float) -> void:
	current_camera = get_viewport().get_camera_3d()
	if current_camera != null:
		tip_based_on_distance()
		rotate_toward_player()

func tip_based_on_distance():
	var distance_to_player : float = global_position.distance_to(current_camera.global_position)
	node_x_axis.rotation.x = deg_to_rad(clampf(distance_to_player*5,0,20))

func rotate_toward_player():
	#find angle toward player
	var angle_to_player : float = Vector2(0,-1).angle_to(Vector2(to_local(current_camera.global_position).x,to_local(current_camera.global_position).z)) + 3*PI/4
	#rotate first node around y axis 3D by that angle
	node_y_axis.rotation.y = -angle_to_player
	#rotate sprite around y axis in opposite direction
	sprite.rotation.y = angle_to_player
