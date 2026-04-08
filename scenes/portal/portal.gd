extends Node3D
class_name Portal

@export_group("Destination")
@export var to_world: String = "" # Path/Name matching available_lvl in Worlds
@export var to_portal: String = "" # Name of the portal node in the next world
@export var pos_override: Variant  # Manual Vector2/3 if not using portal-to-portal

var player_in_range: bool = false

func _ready() -> void:
	add_to_group("portals")

# We only use this to tell the PLAYER they can interact
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		body.current_portal = self 

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		if body.current_portal == self:
			body.current_portal = null

func _teleport():
	var worlds_node = Autoloader.worlds
	var level_id = worlds_node.available_lvl.find(to_world)
	
	if level_id != -1:
		# Call the new dedicated portal RPC
		worlds_node.portal_request_to_join.rpc_id(1, level_id, to_portal, pos_override)
	else:
		print("Portal Error: '", to_world, "' not found in available_lvl")
