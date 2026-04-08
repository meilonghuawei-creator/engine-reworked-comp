class_name World
extends Node

#this is world class script for all worlds to use
#extends World 
#at the top

# We use Variant (no type hint) so it can hold Vector2 OR Vector3
@export var spawn_pos: Variant = Vector3(0, 1, 0)
@export var is3d := true
@export var level_id : int
@export var player_override : PackedScene
@export var level_theme : AudioStream

var world_index : int
var world_lifetime : float

@onready var players : Node = $players
@onready var mobs : Node = $mobs
@onready var items : Node = $items
@onready var furnitures : Node = $furnitures
@onready var gridmap : GridMap = $GridMap

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if !multiplayer.is_server():
		return
	#remove this world if there are no players left
	world_lifetime += delta
	if world_lifetime > 10 and players.get_children().size() == 0:
		Autoloader.worlds.close_empty_world(world_index,level_id)

func join_world():
	# Pull from Autoloader and send to server
	request_player_spawn.rpc_id(1, Autoloader.p_spawn_name, Autoloader.p_spawn_pos)
	
	# Reset Autoloader so the next random spawn doesn't use old portal data
	Autoloader.p_spawn_name = ""
	Autoloader.p_spawn_pos = null

@rpc("any_peer", "call_local", "reliable")
func request_player_spawn(p_name: String = "", p_pos: Variant = null):
	spawn_player(multiplayer.get_remote_sender_id(), p_name, p_pos)

func spawn_player(player_id: int, p_name: String = "", p_pos: Variant = null):
	# 1. Load the player
	var path = "res://scenes/player/player_3d.tscn" if is3d else "res://scenes/player/player_2d.tscn"
	var new_player = (player_override if player_override else load(path)).instantiate()
	new_player.player_id = player_id
	
	# 2. Set default position
	new_player.position = p_pos if p_pos != null else spawn_pos
	
	# 3. Override if using a Portal
	if p_name != "":
		for p in get_tree().get_nodes_in_group("portals"):
			if p.name == p_name and is_ancestor_of(p):
				var sp = p.get_node("SpawnPoint")
				new_player.position = sp.global_position
				new_player.rotation = sp.global_rotation
				break
				
	players.add_child(new_player, true)

func leave_world():
	#print("player ", multiplayer.get_unique_id()," leaving world ",world_index)
	#$AudioStreamPlayer3D.stop()
	despawn_player.rpc_id(1)
	
@rpc("any_peer", "call_local", "reliable")
func despawn_player():
	var sender_id = multiplayer.get_remote_sender_id()
	for i in players.get_children():
		# Removed strict ": Player" hint so it works for 2D/Override scenes
		if i.get("player_id") == sender_id:
			i.queue_free()
			
#despawn function backup before 2d support
#@rpc("any_peer","call_local","reliable")
#func despawn_player():
	#for i : Player in players.get_children():
		#if i.player_id == multiplayer.get_remote_sender_id():
			#i.queue_free()
	##print("player ",multiplayer.get_remote_sender_id()," despawned, remaining players in the world: ",player_container.get_children().size())
