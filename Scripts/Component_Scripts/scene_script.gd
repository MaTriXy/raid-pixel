extends Node

@export var scene_particle: CPUParticles2D
@export var ySort: Control
@export var tileMap: TileMapLayer
@export var scene_name: String
@onready var spawn_machine = $"Y Sort/Spawner"

var main_player_scene = preload("res://Sprite_Nodes/main_player.tscn")
var main_player = main_player_scene.instantiate()

var max_scene_width_left: float
var max_scene_width_right: float
var max_scene_height_top: float
var max_scene_height_bottom: float

var world_rect: Rect2

var prev_data = {}

func _ready() -> void:	
	PlayerGlobalScript.current_scene = scene_name
	PlayerGlobalScript.spawn_player_code = scene_name + PlayerGlobalScript.match_roomID
	
	spawn_player_on_scene()
	
	var timer = Timer.new()
	
	if not timer.is_inside_tree():
		add_child(timer)
		
	timer.wait_time = 1.0
	timer.timeout.connect(send_scene_data)
	timer.start()
	
	if scene_particle:
		scene_particle.emitting = true
	
	#convert tile map layer into local world
	if tileMap and tileMap.tile_set:
		var tile_size = tileMap.tile_set.tile_size
		var used_rect = tileMap.get_used_rect()
		
		world_rect = Rect2(
			tileMap.map_to_local(used_rect.position),
			used_rect.size * tile_size
		)
		
		max_scene_width_left = world_rect.position.x + world_rect.size.x
		max_scene_width_right = world_rect.position.x
		max_scene_height_bottom = world_rect.position.y + world_rect.size.y
		max_scene_height_top = world_rect.position.y
		
func spawn_player_on_scene():
	if not is_instance_valid(main_player):
		main_player = main_player_scene.instantiate()
		
	var spawn_coordinates = spawn_machine.spawn_coords
	if PlayerGlobalScript.game_scene_name != "Lobby" and PlayerGlobalScript.player_class_game_type:
		spawn_coordinates = spawn_machine.game_scene_spawn_coords.get(PlayerGlobalScript.game_scene_name).allied_spawn_coords if PlayerGlobalScript.player_class_game_type.to_upper() == "DEFENDER" else spawn_machine.game_scene_spawn_coords.get(PlayerGlobalScript.game_scene_name).enemy_spawn_coords
	
	main_player.position = spawn_coordinates
	ySort.add_child(main_player)
	spawn_machine.spawner_animation.play("spawner_spawn")
		
func send_scene_data():
	PlayerGlobalScript.isLobby = true if WebsocketsConnection.socket_connection_status == "Connected" else false
	
	var state = {
			"Socket_Name": "scene_code",
			"Spawn_Player_Code": PlayerGlobalScript.spawn_player_code
		}
		
	if WebsocketsConnection.socket_connection_status == "Connected" and prev_data != state:
		SocketClient.send_data(state)
		prev_data = state

	elif WebsocketsConnection.socket_connection_status == "Disconnected":
		prev_data = {}
	
func _process(_delta: float):
	if spawn_machine.isRespawn:
		spawn_player_on_scene()
		spawn_machine.isRespawn = false
		
	if tileMap and tileMap.tile_set and main_player and main_player.get_parent() == ySort:
		wrap_around()
		adjust_player_camera_limit()
	
func adjust_player_camera_limit():
	var playerCamera = main_player.player_camera
	var map_limits = tileMap.get_used_rect()
	var map_cellsize = tileMap.tile_set.tile_size
	
	playerCamera.limit_left = map_limits.position.x * map_cellsize.x
	playerCamera.limit_right = map_limits.end.x * map_cellsize.x
	playerCamera.limit_top = map_limits.position.y * map_cellsize.y
	playerCamera.limit_bottom = map_limits.end.y * map_cellsize.y
	
func wrap_around():
	#going left
	if main_player.position.x >= max_scene_width_left:
		main_player.position.x = max_scene_width_right
	
	#going right
	elif main_player.position.x <= max_scene_width_right:
		main_player.position.x = max_scene_width_left
	
	#going down
	if main_player.position.y >= max_scene_height_bottom:
		main_player.position.y = max_scene_height_top
	
	#going up
	elif main_player.position.y <= max_scene_height_top:
		main_player.position.y = max_scene_height_bottom
