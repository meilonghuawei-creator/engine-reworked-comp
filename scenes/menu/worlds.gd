class_name Worlds
extends Control

@onready var worldsvc : Array[SubViewportContainer] = [$"3D/svc0",$"3D/svc1",$"2D/svc0a"]
@onready var worldsvp : Array[SubViewport] = [$"3D/svc0/svp0",$"3D/svc1/svp1",$"2D/svc0a/svp0a"]
@export var available_lvl : Array[String]
var active_lvl : Array[bool]
var current_lvl := -1

func _ready() -> void:
	
	Autoloader.worlds = self
	
	active_lvl.resize(available_lvl.size())
	active_lvl.fill(false)
	
	# Automatically add all available scenes to all spawners
	for i in worldsvc:
		for j in i.get_children():
			if j is MultiplayerSpawner:
				for k in available_lvl:
					j.add_spawnable_scene(k)

@rpc("any_peer","call_local","reliable")
func request_to_join_world(level_id : int):
	# if world exists tell player to spawn into that world
	if active_lvl[level_id] == true:
		print("sending client to existing world")
		for i in worldsvp:
			if i.get_child_count() > 0:
				if i.get_child(0).level_id == level_id:
					enter_world.rpc_id(multiplayer.get_remote_sender_id(), i.get_child(0).world_index)
	# otherwise spin up new world for player
	else:
		print("spinning up new world for client ", multiplayer.get_remote_sender_id())
		open_new_world(level_id, multiplayer.get_remote_sender_id())
		
@rpc("any_peer", "call_local", "reliable")
func portal_request_to_join(level_id: int, s_name: String, s_pos: Variant, is_response: bool = false):
	# --- 1. THE RESPONSE (Client Logic) ---
	if is_response:
		# Update variables so the Player script finds them during _ready()
		Autoloader.p_spawn_name = s_name
		Autoloader.p_spawn_pos = s_pos
		
		# Only run the 'Switch' logic if the server actually sent a valid world_index
		if level_id != -1:
			if current_lvl != -1:
				worldsvc[current_lvl].hide()
				if worldsvp[current_lvl].get_child_count() > 0:
					worldsvp[current_lvl].get_child(0).leave_world()
					worldsvp[current_lvl].audio_listener_enable_3d = false
			
			current_lvl = level_id 
			worldsvc[current_lvl].show()
			
			if worldsvp[current_lvl].get_child_count() > 0:
				worldsvp[current_lvl].get_child(0).join_world()
				worldsvp[current_lvl].audio_listener_enable_3d = true
		return

	# --- 2. THE REQUEST (Server Logic) ---
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = 1
		
		# Server-side update for the host's own logic
		Autoloader.p_spawn_name = s_name
		Autoloader.p_spawn_pos = s_pos

		if active_lvl[level_id] == true:
			# World exists: Find it and tell client to go there
			for i in worldsvp:
				if i.get_child_count() > 0:
					var world_node = i.get_child(0)
					if world_node.level_id == level_id:
						portal_request_to_join.rpc_id(sender_id, world_node.world_index, s_name, s_pos, true)
						return
		else:
			# World doesn't exist: Tell client to update variables, then spin up
			portal_request_to_join.rpc_id(sender_id, -1, s_name, s_pos, true)
			open_new_world(level_id, sender_id)

@rpc("any_peer","call_local","reliable")
func enter_world(world_index : int):
	# If the game thinks we are in a world
	if current_lvl != -1:
		worldsvc[current_lvl].hide()
		# ONLY try to leave if there is actually a world node there
		if worldsvp[current_lvl].get_child_count() > 0:
			worldsvp[current_lvl].get_child(0).leave_world()
			worldsvp[world_index].audio_listener_enable_3d = false
		else:
			# This catches the "ghost world" state your friend mentioned
			print("Warning: current_lvl was not -1, but no world node found to leave.")
	
	current_lvl = world_index
	worldsvc[world_index].show()
	
	# Same check for joining
	if worldsvp[world_index].get_child_count() > 0:
		worldsvp[world_index].get_child(0).join_world()
		worldsvp[current_lvl].audio_listener_enable_3d = true

func open_new_world(level_id : int, client_id : int):
	var new_world : World = load(available_lvl[level_id]).instantiate()
	var world_index : int = 0
	
	for i in worldsvp:
		if i.get_child_count() == 0:
			new_world.world_index = world_index
			i.add_child(new_world, true)
			break
		world_index += 1
	
	active_lvl[level_id] = true
	enter_world.rpc_id(client_id, world_index)

#func close_empty_world(world_id : int, level_id : int):
	#worldsvp[world_id].get_child(0).queue_free()
	#active_lvl[level_id] = false
	#print("deleting world ", world_id)
	
func close_empty_world(world_id : int, level_id : int):
	# We don't need to check for player_3d anymore because 
	# the new manager creates/destroys nodes automatically.
	
	if worldsvp[world_id].get_child_count() > 0:
		var world_node = worldsvp[world_id].get_child(0)
		world_node.queue_free()
		
	active_lvl[level_id] = false
	print("deleting world ", world_id)
