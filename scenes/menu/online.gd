extends Control
class_name online

# --- CHAT STUFF ---
@onready var chat_root = $"../Chat"
@onready var chat_input = $"../Chat/chatinput"
@onready var chatlog: TextEdit = $"../Chat/chatlog"

var chat_enabled := true
static var is_chatting := false
var chat_tween: Tween

#network stuff
var ip := "127.0.0.1"
const port := 25565
var username := "dog"
var peer

@onready var ipinput: LineEdit = $game_options/ipinput
@onready var lvlinput: OptionButton = $game_options/lvlinput
@onready var igninput: LineEdit = $game_options2/igninput

@onready var mainmenu : menu = get_parent()


func _ready() -> void:
	chat_input.text_submitted.connect(_on_chat_submitted)
	chatlog.gui_input.connect(_on_chatlog_gui_input)
	chat_input.gui_input.connect(_on_chat_input_gui_input) # Add this
	chatlog.self_modulate.a = 0 
	_start_fade()

func _on_chatlog_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Scroll logic
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			chatlog.scroll_vertical -= 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			chatlog.scroll_vertical += 1
		# Focus logic: Click to highlight
		elif event.button_index == MOUSE_BUTTON_LEFT:
			chatlog.grab_focus()

func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			chat_input.grab_focus()
	
func _input(event: InputEvent) -> void:
	# ONLY handle and kill the wheel event if we are actually chatting
	if is_chatting:
		if event.is_action_pressed("mouse_wheel_up"):
			chatlog.scroll_vertical -= 1
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("mouse_wheel_down"):
			chatlog.scroll_vertical += 1
			get_viewport().set_input_as_handled()
			return
	
	# 1. HARD TOGGLE: Completely disable/enable visibility
	if event.is_action_pressed("toggle_chat"):
		chat_enabled = !chat_enabled
		chat_root.visible = chat_enabled
		if not chat_enabled:
			deactivate_chat()
	
	if not chat_enabled: return
	
	# 2. CHAT KEY: Open or Send
	if event.is_action_pressed("chat"):
		if not is_chatting:
			activate_chat()
		else:
			_on_chat_submitted(chat_input.text)
		
		# STOP INPUT BLEED: This prevents jumping/moving when pressing the chat key
		get_viewport().set_input_as_handled()


#options

# Updates the 'username' variable whenever you type in the IGN box
func _on_igninput_text_changed(new_text: String) -> void:
	username = new_text

# Updates the 'ip' variable whenever you type in the IP box
func _on_ipinput_text_changed(new_text: String) -> void:
	ip = new_text

# Updates the 'current_lvl' logic based on the dropdown selection
func _on_lvlinput_item_selected(index: int) -> void:
	# This mimics your old 'last_level' logic
	# We store the index so the host knows which level to 'open_new_world'
	Autoloader.worlds.current_lvl = index

#buttons

func _on_host_pressed() -> void:
	# If empty, keep "dog", otherwise use the text
	if igninput.text != "":
		username = igninput.text
	else:
		username = "dog"
	
	igninput.editable = false
	ipinput.editable = false
	host()

func _on_join_pressed() -> void:
	# Name default
	if igninput.text != "":
		username = igninput.text
	else:
		username = "dog"
		
	# IP default
	if ipinput.text != "":
		ip = ipinput.text
	else:
		ip = "127.0.0.1"

	igninput.editable = false
	ipinput.editable = false
	join()

#before single player was added
#func _on_start_pressed() -> void:
	#
	## Get the index directly from the OptionButton (lvlinput)
	#var selected_lvl = lvlinput.get_selected_id()
	#
	## Following reference: Utilities.world_manager.request_to_join_world.rpc_id(1,level_id)
	## This tells the server EXACTLY which level this specific player wants to enter.
	#Autoloader.worlds.request_to_join_world.rpc_id(1, selected_lvl)
	#showui()
		
func _on_start_pressed() -> void:
	# Get the index directly from the OptionButton
	var selected_lvl = lvlinput.get_selected_id()
	
	# CHECK: Are we actually connected to a network?
	if multiplayer.multiplayer_peer == null:
		# --- SINGLE PLAYER PATH ---
		update_chat_log("Starting Single Player...")
		
		# 1. Initialize local player data so the game knows who you are
		var my_id = 1 # In singleplayer/offline, Godot uses 1 as the default local ID
		PlayerManager.Players[my_id] = {"name": username, "id": my_id, "color": 0}
		
		# 2. Directly tell the world manager to load the level (no RPC needed)
		Autoloader.worlds.current_lvl = selected_lvl
		Autoloader.worlds.request_to_join_world(selected_lvl)
	else:
		# --- MULTIPLAYER PATH ---
		# Existing logic: Tell the server (ID 1) we want to join
		Autoloader.worlds.request_to_join_world.rpc_id(1, selected_lvl)
	
	# This UI management is usually handled inside the world manager, 
	# but we keep it here to match your current flow.
	showui()		
		
@rpc("any_peer", "call_local", "reliable")
func hideui():
	$"../Title/start".disabled = true
	# Reference: Utilities.switch_to_world_chooser()
	# This allows players to trigger the transition
	Autoloader.worlds.request_to_join_world(Autoloader.worlds.current_lvl)
		
#connection

func peer_con(id):
	# Simple text append to your @onready chatlog
	chatlog.text += "Player Connected: " + str(id) + "\n"
	chatlog.scroll_vertical = chatlog.get_line_count()

func peer_dc(id):
	# If it's a client leaving
	if id != 1:
		chatlog.text += "Player Disconnected: " + str(id) + "\n"
		chatlog.scroll_vertical = chatlog.get_line_count()
		PlayerManager.LobbyMembers.erase(id)
		PlayerManager.Players.erase(id)
		
		# Clean up their physical character node
		for i in get_tree().get_nodes_in_group("player"):
			if i.name == str(id):
				i.queue_free()
	# If the host leaves/closes
	else:
		multiplayer.multiplayer_peer = null
		PlayerManager.LobbyMembers.clear()
		PlayerManager.Players.clear()
		chatlog.text += "Host has closed the lobby\n"
		chatlog.scroll_vertical = chatlog.get_line_count()
		# Add button resets here if you want them clickable again
	

func host():
	#connect signals for join/leave
	multiplayer.peer_connected.connect(peer_con)
	multiplayer.peer_disconnected.connect(peer_dc)
	
	#host game
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 32)
	if error != OK: 
		update_chat_log("Error: Cannot host server.")
		chatlog.scroll_vertical = chatlog.get_line_count()
		return
		
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	#send chat
	update_chat_log("Hosting Lobby as " + username)
	chatlog.scroll_vertical = chatlog.get_line_count()
	senddata(username, 1)

func join():
	#connect signals for join/leave
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_fail)
	
	#game join
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK: return
	update_chat_log("Failed to join")
	showui()
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_connection_success():
	update_chat_log("Connection successful!")
	chatlog.scroll_vertical = chatlog.get_line_count()
	senddata.rpc(username, multiplayer.get_unique_id())

func _on_connection_fail():
	update_chat_log("Failed to connect to " + ip)
	chatlog.scroll_vertical = chatlog.get_line_count()
	
@rpc("any_peer", "reliable")
func senddata(pname: String, id: int, col: int = 0):
	# Match reference logic for "SendPlayerInformation"
	if Autoloader.worlds.current_lvl == -1:
		if !PlayerManager.LobbyMembers.has(id):
			PlayerManager.LobbyMembers[id] = {"name": pname, "id": id, "color": col}
		
		if multiplayer.is_server():
			for i in PlayerManager.LobbyMembers:
				var p = PlayerManager.LobbyMembers[i]
				senddata.rpc(p.name, i, p.color)
	else:
		# In-game / Late join logic
		if !PlayerManager.Players.has(id):
			PlayerManager.Players[id] = {"name": pname, "id": id, "color": col}
		
		if multiplayer.is_server():
			# If you have a spawn function for late joins, call it here
			# Example: Utilities.active_battlemap.spawn_late_player(id)
			for i in PlayerManager.Players:
				var p = PlayerManager.Players[i]
				senddata.rpc(p.name, i, p.color)
	
# --- CHAT SYSTEM ---

func activate_chat() -> void:
	online.is_chatting = true
	chat_input.show()
	chat_input.grab_focus()
	
	# Enable clicking on the container and log
	chat_root.mouse_filter = Control.MOUSE_FILTER_PASS
	chatlog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	chatlog.selecting_enabled = true
	chatlog.context_menu_enabled = true 
	chatlog.focus_mode = Control.FOCUS_CLICK 
	
	if chat_tween: chat_tween.kill()
	chatlog.modulate.a = 1.0
	chatlog.self_modulate.a = 1.0
	
func deactivate_chat() -> void:
	online.is_chatting = false
	chat_input.release_focus()
	chat_input.hide()
	chat_input.text = ""
	
	# --- Disable Interaction so you can aim/shoot through it ---
	chatlog.selecting_enabled = false
	chatlog.deselect() # Clears any blue highlight when closing
	chatlog.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	chatlog.focus_mode = Control.FOCUS_NONE
	
	chatlog.self_modulate.a = 0.0 
	_start_fade()
	
	
func _start_fade() -> void:
	if chat_tween: chat_tween.kill()
	chat_tween = create_tween()
	chat_tween.tween_interval(4.0)
	# This fades BOTH the text and the box together
	chat_tween.tween_property(chatlog, "modulate:a", 0.0, 1.0)

func _on_chat_submitted(new_text: String) -> void:
	if new_text.strip_edges() != "":
		if igninput.text != "": username = igninput.text 
		update_chat_log.rpc(username + ": " + new_text)
	deactivate_chat()

func _on_chat_send_pressed() -> void:
	_on_chat_submitted(chat_input.text)

@rpc("any_peer", "call_local", "reliable")
func update_chat_log(message: String) -> void:
	chatlog.text += message + "\n"
	chatlog.scroll_vertical = chatlog.get_line_count()
	
	# Wake up text transparency on new message
	chatlog.modulate.a = 1.0
	
	# If we aren't currently typing, start/restart the fade
	if not is_chatting:
		_start_fade()

@rpc("any_peer", "call_local", "reliable")
func showui():
	igninput.release_focus()
	ipinput.release_focus()
	lvlinput.release_focus()
	$"../Title/start".disabled = false
	igninput.editable = true
	ipinput.editable = true
	lvlinput.disabled = false

func leave_lobby():
	# 1. Kill the connection
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.set_multiplayer_peer(null)
	
	# 2. Clean up local data (Mirroring your peer_dc logic)
	PlayerManager.LobbyMembers.clear()
	PlayerManager.Players.clear()
	
	# 3. Reset UI so you can host/join again
	showui()
	
	# 4. Log it locally
	update_chat_log("Left the lobby.")

func _on_leave_pressed() -> void:
	leave_lobby()


func _on_touch_screen_button_pressed() -> void:
	_on_chat_submitted(chat_input.text)
