extends Node

var main_menu : menu
var ingame_menu : Node
var session_id : int
var is_dragging : bool = false
var ingame : bool = false
var late_join : bool = false

var worlds : Worlds
var p_spawn_name : String = ""
var p_spawn_pos : Variant = null

# Sound Collections
@export_group("Sound Collections")
@export var sfx_paths: Array[String] = []
@export var music_paths: Array[String] = []

var music_library = {} 
var _alt_index: int = 0 

func get_random_id(min_id: int, max_id: int) -> int:
	var range_size = (max_id - min_id) + 1
	if range_size <= 0: return min_id
	return min_id + (randi() % range_size)

func get_alt_id(min_id: int, max_id: int) -> int:
	var range_size = (max_id - min_id) + 1
	if range_size <= 0: return min_id
	var selected_id = min_id + (_alt_index % range_size)
	_alt_index += 1
	return selected_id

# --- Music Folder Scanner ---
func scan_folder(album_name: String, path: String):
	var dir = DirAccess.open(path)
	if dir:
		var tracks: Array[String] = []
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if !dir.current_is_dir() and (file.ends_with(".mp3") or file.ends_with(".wav")):
				tracks.append(path + "/" + file)
			file = dir.get_next()
		music_library[album_name] = tracks

func toggle_visibility(node : Node):
	node.visible = !node.visible
