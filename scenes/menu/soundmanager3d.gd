extends Node

# --- PUBLIC API ---

func play_id(id: int, pos: Vector3):
	_execute_play(id, pos)

func play_random(ids: Array[int], pos: Vector3):
	if ids.is_empty(): return
	_execute_play(ids[randi() % ids.size()], pos)

func play_alt(ids: Array[int], pos: Vector3):
	if ids.is_empty(): return
	var index = Autoloader._alt_index % ids.size()
	Autoloader._alt_index += 1
	_execute_play(ids[index], pos)

# --- INTERNAL LOGIC ---

func _execute_play(id: int, pos: Vector3):
	var w = Autoloader.worlds
	if not w or w.current_lvl == -1: return
	
	var my_world = w.current_lvl
	
	# 1. Play immediately for the local user (No lag)
	_local_playback(id, pos)
	
	# 2. Tell the server to tell others.
	if multiplayer.is_server():
		# If we are the host, broadcast to all clients
		# Use rpc_id(0, ...) but we'll filter the sender in the RPC function
		rpc("rpc_play_spatial", id, pos, my_world)
	else:
		# If we are a client, send only to server
		rpc_id(1, "rpc_play_spatial", id, pos, my_world)

func _local_playback(id: int, pos: Vector3):
	if id < 0 or id >= Autoloader.sfx_paths.size(): return
	var stream = load(Autoloader.sfx_paths[id])
	if not stream: return

	var p = AudioStreamPlayer3D.new()
	p.stream = stream
	
	# 1. ADD TO TREE FIRST (This makes it "inside_tree")
	add_child(p)
	
	# 2. SYNC TO WORLD (Reparenting)
	_sync_node_to_world(p)
	
	# 3. NOW SET POSITION (Now it has a global transform)
	p.global_position = pos
	
	# 4. Cleanup and Play
	p.finished.connect(p.queue_free)
	p.play()

func _sync_node_to_world(node: AudioStreamPlayer3D):
	var w = Autoloader.worlds
	if not (w and w.current_lvl != -1): return
	var active_svp = w.worldsvp[w.current_lvl]
	if active_svp.get_child_count() > 0:
		var target_world = active_svp.get_child(0)
		if node.get_parent() != target_world:
			if node.get_parent(): node.get_parent().remove_child(node)
			target_world.add_child(node)

# --- NETWORK ---

# Keep as call_remote so the sender doesn't trigger it twice via RPC
@rpc("any_peer", "call_remote", "reliable")
func rpc_play_spatial(id: int, pos: Vector3, origin_world: int):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# RELAY LOGIC
	if multiplayer.is_server():
		# The Server broadcasts to everyone EXCEPT the person who sent it
		for peer_id in multiplayer.get_peers():
			if peer_id != sender_id:
				rpc_id(peer_id, "rpc_play_spatial", id, pos, origin_world)

	# WORLD CHECK
	var w = Autoloader.worlds
	if not w or w.current_lvl != origin_world:
		return

	# If we got here, we are a peer who didn't start the sound, 
	# and we are in the right world. Play it.
	_local_playback(id, pos)
