extends Control

class_name menu                                

func _ready() -> void:
	# Keep this for clients when the host pulls the plug
	multiplayer.server_disconnected.connect(return_to_main_menu)
	# Set the Autoloader reference so the Player can find this script
	Autoloader.main_menu = self

func _input(event: InputEvent) -> void:
	# If the "menu" key is pressed anywhere, trigger the global cleanup
	if event.is_action_pressed("menu") and !online.is_chatting:
		return_to_main_menu()

func return_to_main_menu():
	print("Returning to main menu and cleaning up...")
	
	# 1. Unlock Mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 2. Despawn Players (If we are still connected)
	var w = Autoloader.worlds
	if w and w.current_lvl != -1:
		var active_svp = w.worldsvp[w.current_lvl]
		if active_svp.get_child_count() > 0:
			var current_world = active_svp.get_child(0)
			# Tell the network to despawn us before we kill the connection
			if multiplayer.multiplayer_peer != null:
				if multiplayer.is_server():
					current_world.despawn_player()
				else:
					current_world.despawn_player.rpc_id(1)
		
		# 3. Hide World Viewports
		w.worldsvc[w.current_lvl].hide()
		active_svp.audio_listener_enable_3d = false
		w.current_lvl = -1
	
	# 4. Nuke all World instances (Crucial for Host)
	if w:
		for svp in w.worldsvp:
			for child in svp.get_children():
				child.queue_free()
		w.active_lvl.fill(false)

	# 5. Kill the Network
	multiplayer.multiplayer_peer = null
	PlayerManager.LobbyMembers.clear()
	PlayerManager.Players.clear()

	# 6. Show the Menu and Kill Local Player Avatars
	self.show()
	for p in get_tree().get_nodes_in_group("player"):
		p.queue_free()
