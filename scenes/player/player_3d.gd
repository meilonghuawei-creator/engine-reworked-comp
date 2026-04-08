class_name Player
extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.66
var current_portal: Portal = null

# shaders
@export var shaders: Array[ColorRect] = []
var shaders_enabled := false
var active_shader := 0
# Persistence Memory
static var saved_shaders_enabled := false
static var saved_active_shader := 0

# sounds
@onready var audio_listener_3d: AudioListener3D = $AudioListener3D

# game
@onready var hotbar: ItemList = $Hotbar

# appearance
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var player_cube: MeshInstance3D = $player_cube
@onready var collision: CollisionShape3D = $CollisionShape3D

@export var sprite_height_offset := 0.0
@export var front_texture: Texture2D
@export var left_texture: Texture2D
@export var back_texture: Texture2D
@export var right_texture: Texture2D

# cameras assign
@onready var cam : Camera3D = $Camera3D
@onready var cam3 : Camera3D = $SpringArm3D/ThirdPersonCamera
@onready var spring: SpringArm3D = $SpringArm3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D


var using_first_person := true
var mouse_sensitivity := 0.002

var camera_touch_index := -1
var touch_sensitivity := 0.005

var player_id : int = -1
var player_name : String

#setup

func _ready():
	pass
	
func _on_timer_timeout() -> void:
	initialize_player()

func initialize_player():
	
	#singleplayer support
	if multiplayer.multiplayer_peer == null:
		set_multiplayer_authority(1) # Default to 1
		player_id = 1
		_update_camera_state(true)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	
	# Only run the early authority/camera path if this peer is actually the host (unique id 1)
	if player_id == 1 and multiplayer.get_unique_id() == 1:
		set_multiplayer_authority(1)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_update_camera_state(true)
	else:
		request_information.rpc_id(1)

@rpc("any_peer","call_local","reliable")
func request_information():
	send_information.rpc_id(multiplayer.get_remote_sender_id(), player_id)
	set_multiplayer_authority(player_id)
	
@rpc("any_peer","call_local","reliable")
func send_information(p_id : int):
	player_id = p_id
	set_multiplayer_authority(player_id)    
	if player_id == multiplayer.get_unique_id():
		cam.make_current()
		cam.current = true
		cam3.current = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_update_camera_state(true)
	
func leave_game():
	# Free the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Clean up the Viewports & Despawn
	var w = Autoloader.worlds
	if w and w.current_lvl != -1:
		var active_svp = w.worldsvp[w.current_lvl]
		
		if active_svp.get_child_count() > 0:
			var current_world = active_svp.get_child(0)
			if multiplayer.is_server():
				current_world.despawn_player()
			else:
				current_world.despawn_player.rpc_id(1)
				
		w.worldsvc[w.current_lvl].hide()
		active_svp.audio_listener_enable_3d = false
		w.current_lvl = -1
		
		if multiplayer.is_server():
			for svp in w.worldsvp:
				for child in svp.get_children():
					child.queue_free()
			w.active_lvl.fill(false)

	await get_tree().process_frame

	# Disconnect & Clear Data
	multiplayer.multiplayer_peer = null
	PlayerManager.LobbyMembers.clear()
	PlayerManager.Players.clear()


	# Despawn self
	queue_free()
		
#gameplay
		
func _physics_process(delta: float) -> void:
	_update_sprite_texture()
	
	if !is_multiplayer_authority():
		return
	
	testmusic()
	
	if not is_on_floor():
		velocity += get_gravity() * delta

# If mouse is visible, we are in a menu/pause. Stop all gameplay inputs.
	var is_paused = Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE
	
	if online.is_chatting:
		move_and_slide()
		return
		
	#if is_paused:
		#move_and_slide()
		#return
		
	if Input.is_action_just_pressed("chatter"):
		# You pass an ARRAY [0, 10]
		Soundmanager3d.play_random([0, 1], global_position)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	
	var direction := Vector3.ZERO
	
	if using_first_person:
		# FPS: Movement is relative to the Player Root (which rotates with mouse)
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		# TPS: FLATTENED MOVEMENT
		var cam_basis := spring.global_transform.basis
		
		# Create horizontal-only vectors from the camera basis
		var forward := Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
		var right := Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
		
		# Apply input to the flattened vectors
		direction = (forward * input_dir.y + right * input_dir.x).normalized()
	
	direction.y = 0

	if direction.length() > 0.001:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		if !using_first_person:
			# Calculate the angle in World Space
			var target_angle := atan2(-direction.x, -direction.z)
			
			# Use global_rotation to bypass the Root's "South/East/West" offset
			player_cube.global_rotation.y = lerp_angle(player_cube.global_rotation.y, target_angle, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	
# 1. While chatting, force mouse visible and enable UI interaction
	if online.is_chatting:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			# ENABLE SCROLLING
			if $Chat/chatlog:
				$Chat/chatlog.mouse_filter = Control.MOUSE_FILTER_STOP
		return 

	# 2. When closing chat, SNAP BACK and DISABLE UI SCROLLING
	if event.is_action_released("chat") and !online.is_chatting:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# KILL SCROLLING (Makes chat "click-through" so wheel hits SpringArm)
		if $Chat/chatlog:
			$Chat/chatlog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var focused_node = get_viewport().gui_get_focus_owner()
		if focused_node:
			focused_node.release_focus()
	
	if !is_multiplayer_authority() or online.is_chatting: return
	
	if is_multiplayer_authority() and current_portal != null:
		if event.is_action_pressed("interact"):
			_trigger_portal()
	
	if event.is_action_pressed("menu"):
		leave_game()
	
	if event.is_action_pressed("mute"):
		var bus_idx = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus_idx, !AudioServer.is_bus_mute(bus_idx))
	
	# Optional: Change button icon/text based on state
		if AudioServer.is_bus_mute(bus_idx):
			print("Game Muted")
		else:
			print("Game Unmuted")

	# Only handle FPS rotation here. TPS rotation is in SpringArm script.
	if using_first_person and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		cam.rotate_x(-event.relative.y * mouse_sensitivity)
		cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)
		
	# --- FIXED MOBILE TOUCH ROTATION ---
	# 1. Detect when a finger touches or leaves the screen
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x / 2.0:
			# Finger pressed down on the right side, lock onto this finger ID
			camera_touch_index = event.index
		elif not event.pressed and event.index == camera_touch_index:
			# The finger we were tracking lifted off the screen, reset
			camera_touch_index = -1

	# 2. Rotate if the dragging finger matches our locked ID
	elif using_first_person and event is InputEventScreenDrag:
		if event.index == camera_touch_index:
			rotate_y(-event.relative.x * touch_sensitivity)
			cam.rotate_x(-event.relative.y * touch_sensitivity)
			cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)

	if event.is_action_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("toggle_camera"):
		_update_camera_state(!using_first_person)			
		
		# UI & Shader Toggles
	if event.is_action_pressed("toggle_hotbar"):
		if hotbar:
			hotbar.visible = !hotbar.visible
			
	if event.is_action_pressed("toggle_shader"):
		toggle_shaders()
	elif event.is_action_pressed("next_shader"):
		next_shader()
	elif event.is_action_pressed("prev_shader"):
		prev_shader()
		

#camera/sprite logic

func _update_camera_state(fps_mode: bool):
	using_first_person = fps_mode

	if using_first_person:
		cam.make_current()
		cam.current = true
		cam3.current = false
	else:
		cam3.make_current()
		cam3.current = true
		cam.current = false

	if spring:
		spring.set_process_unhandled_input(!using_first_person)

	# …rest of your rotation/sync logic unchanged…

	
	if using_first_person:
		# 1. Sync the Player Root to the Cube's current world-facing direction
		global_rotation.y = player_cube.global_rotation.y
		
		# 2. Reset the Cube's local rotation so it's 'Forward' relative to the root
		player_cube.rotation.y = 0
		
		# 3. Force the FPS camera and Spring to face perfectly forward (0,0,0)
		cam.rotation = Vector3.ZERO
		spring.rotation = Vector3.ZERO
	else:
		# Entering TPS: Just reset the spring so it starts behind the player
		spring.rotation = Vector3.ZERO
		player_cube.rotation.y = 0

	sprite_3d.visible = !using_first_person
	
	# LOAD PERSISTENT SHADERS
	if is_multiplayer_authority():
		shaders_enabled = Player.saved_shaders_enabled
		active_shader = Player.saved_active_shader
		_update_shader_visibility()

func _update_sprite_texture() -> void:
	var current_cam := get_viewport().get_camera_3d()
	if !current_cam or !sprite_3d or !player_cube:
		return

	var to_cam := current_cam.global_transform.origin - player_cube.global_transform.origin
	to_cam.y = 0
	to_cam = to_cam.normalized()

	var forward := -player_cube.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var angle := fposmod(rad_to_deg(atan2(to_cam.x, to_cam.z) - atan2(forward.x, forward.z)) + 360.0, 360.0)

# 5. Texture Swap based on 90-degree slices
	# 0 = Front, 90 = Left, 180 = Back, 270 = Right
	if angle >= 315.0 or angle < 45.0:
		sprite_3d.texture = front_texture
	elif angle >= 45.0 and angle < 135.0:
		sprite_3d.texture = left_texture
	elif angle >= 135.0 and angle < 225.0:
		sprite_3d.texture = back_texture
	else:
		sprite_3d.texture = right_texture
	
	sprite_3d.position.y = sprite_height_offset
	
#sounds
		
func testmusic():
	
	if not is_multiplayer_authority():
		return
	
	print("--- MUSIC DEBUG START ---")
	
	# 1. Look for the world root (Go up until we find the theme)
	var current_node = get_parent()
	var world_root = null
	
	# Keep looking up the tree for a node that actually HAS the theme variable
	while current_node != null:
		if "level_theme" in current_node:
			world_root = current_node
			break
		current_node = current_node.get_parent()

	if world_root:
		print("1. World Root found: ", world_root.name)
	else:
		print("1. ERROR: Could not find any parent node with 'level_theme'!")
		return

	# 2. Check the Music Node
	var music_player = Autoloader.main_menu.get_node_or_null("Music")
	
	# 3. Handle the theme assignment
	var theme = world_root.level_theme
	if theme:
		print("3. Theme detected: ", theme.resource_path)
		if music_player.stream != theme:
			music_player.stream = theme
			music_player.play()
			print("4. SUCCESS: Music playing.")
	else:
		print("3. ERROR: level_theme is empty in the Inspector for ", world_root.name)
	
	print("--- MUSIC DEBUG END ---")
		
func toggle_mute():
	var master_bus_index = AudioServer.get_bus_index("Master")
	var is_muted = AudioServer.is_bus_mute(master_bus_index)
	
	# Flip the current state
	AudioServer.set_bus_mute(master_bus_index, !is_muted)

#shaders

#shaders

func toggle_shaders() -> void:
	shaders_enabled = !shaders_enabled
	Player.saved_shaders_enabled = shaders_enabled # SAVE
	_update_shader_visibility()

func next_shader() -> void:
	if not shaders_enabled or shaders.is_empty():
		return
	active_shader = (active_shader + 1) % shaders.size()
	Player.saved_active_shader = active_shader # SAVE
	_update_shader_visibility()

func prev_shader() -> void:
	if not shaders_enabled or shaders.is_empty():
		return
	active_shader = (active_shader - 1 + shaders.size()) % shaders.size()
	Player.saved_active_shader = active_shader # SAVE
	_update_shader_visibility()

func _update_shader_visibility() -> void:
	# If the array is empty, there's nothing to loop through
	if shaders.is_empty():
		return
		
	for i in shaders.size():
		var shader_rect: ColorRect = shaders[i]
		if shader_rect:
			# Only show if system is ON and this index is the ACTIVE one
			shader_rect.visible = (shaders_enabled and i == active_shader)

#features

func _trigger_portal():
	var worlds_node = Autoloader.worlds
	var target_to_world = current_portal.to_world
	var target_to_portal = current_portal.to_portal
	var target_pos = current_portal.pos_override
	
	var level_id = worlds_node.available_lvl.find(target_to_world)
	
	if level_id != -1:
		# Sending the request to the server using the LOCAL data 
		# grabbed at the exact moment of interaction
		worlds_node.portal_request_to_join.rpc_id(1, level_id, target_to_portal, target_pos)
		
	
		


	
