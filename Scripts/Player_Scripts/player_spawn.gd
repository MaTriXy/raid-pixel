extends Node

@onready var spawner_animation = $Sprite/AnimationPlayer

var main_player = preload("res://Sprite_Nodes/main_player.tscn")
var joined_Player = preload("res://Sprite_Nodes/joined_player.tscn")
@export var ySort: Control
var prev_data: Dictionary
var spawn_code: String
var prev_death_status = false

#for player spawn
@onready var death_panel = $"UI/Death Screen Panel"
@onready var respawn_button = $"UI/Death Screen Panel/Panel/Respawn Button"
@export var spawn_coords: Vector2

@onready var spawn_timer = $"UI/Death Screen Panel/Spawn Timer"

#store player here
var stored_players = {}

func _ready() -> void:
	death_panel.visible = false
	spawner_animation.play("spawner_spawn")
	respawn_button.connect("pressed", respawn)
	
	await get_tree().process_frame
	spawn_code = PlayerGlobalScript.spawn_player_code
	
func respawn():
	PlayerGlobalScript.isModalOpen = false
	PlayerGlobalScript.current_modal_open = false
	
	await get_tree().process_frame
	var player = main_player.instantiate()
	player.position = spawn_coords
	ySort.add_child(player)
	spawner_animation.play("spawner_spawn")
	
func start_timer():
	spawn_timer.wait_time = 1.0
	spawn_timer.timeout.connect(func(): respawn_button.disabled = false)
	spawn_timer.start()

func _process(_delta: float) -> void:
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status
	
	if connection_status == "Connected":		
		if data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "Player_Spawn_%s" % [spawn_code] and data.get("Player_GameID") != PlayerGlobalScript.player_game_id:
			prev_data = data
			
			if data.has("Player_inGameName"):
				var player = joined_Player.instantiate()
				
				if stored_players.has(data.get("Player_GameID")):
					var joined_player_data = stored_players[data.get("Player_GameID")]
					var joined_player = joined_player_data["Player"]
				
					if is_instance_valid(joined_player):
						joined_player.position = Vector2(data.get("Player_posX"), data.get("Player_posY"))
						joined_player.playerIGN = data.get("Player_inGameName")
						joined_player.direction_value = Vector2(data.get("direction_value")["x"], data.get("direction_value")["y"])
						joined_player.last_direction_value = Vector2(data.get("last_direction_value")["x"], data.get("last_direction_value")["y"])
						joined_player.isMoving = data.get("isMoving")
						joined_player.player_type = data.get("player_type")
						joined_player.isAttacking = data.get("isAttacking")
					else:
						var newPlayer = joined_Player.instantiate()
						newPlayer.position = Vector2(spawn_coords.x, spawn_coords.y)
						newPlayer.name = data.get("Player_GameID")
						newPlayer.playerIGN = data.get("Player_inGameName")
						newPlayer.player_type = data.get("player_type")
						
						if newPlayer.get_parent() != ySort:
							spawner_animation.play("spawner_spawn")
							ySort.add_child(newPlayer)

						stored_players[data.get("Player_GameID")] = {
							"Player": newPlayer,
							"Position": newPlayer.position,
						}
					
				else:
					GetPlayerInfo.active_player_dic[data.get("Player_GameID")] = {
						"Player_username": data.get("Player_username"),
						"Player_IGN": data.get("Player_inGameName"),
						"isFetched": false
					}
				
					stored_players[data.get("Player_GameID")] = {
						"Player": player,
						"Position": Vector2(spawn_coords.x, spawn_coords.y),
					}
					
					spawner_animation.play("spawner_spawn")
					player.name = data.get("Player_GameID")
					player.playerIGN = data.get("Player_inGameName")
					player.player_type = data.get("player_type")
					ySort.add_child(player)
				
		elif data.get("Socket_Name") and prev_data != data and (data.get("Socket_Name") == "Player_Disconnect" or data.get("Socket_Name") == "leave_lobby"):
			prev_data = data
			
			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")):
				var joined_player_data = stored_players[data.get("Player_GameID")]
				var joined_player = joined_player_data["Player"]
				
				if joined_player:
					joined_player.queue_free()
					stored_players.erase(data.get("Player_GameID"))
					GetPlayerInfo.active_player_dic.erase(data.get("Player_GameID"))
					
		elif data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "player_death":
			prev_data = data

			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")):
				stored_players.erase(data.get("Player_GameID"))
					
		elif data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "ModifyProfile":
			prev_data = data
			
			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")) and GetPlayerInfo.active_player_dic.has(data.get("Player_GameID")):
				
				var player_key_list = GetPlayerInfo.active_player_dic[data.get("Player_GameID")] 
				var joined_player_data = stored_players[data.get("Player_GameID")]
				var joined_player = joined_player_data["Player"]
				
				player_key_list.Player_IGN = data.get("Player_inGameName")
				joined_Player.name = data.get("Player_GameID")
				joined_player.playerIGN = data.get("Player_inGameName")
				
		elif data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "player_health":
			prev_data = data
			
			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")) and GetPlayerInfo.active_player_dic.has(data.get("Player_GameID")):
				var joined_player_data = stored_players[data.get("Player_GameID")]
				var joined_player = joined_player_data["Player"]
		
				if joined_player:
					joined_player.player_health_bar_status(int(data.get("Player_Health")))

	if prev_death_status != PlayerGlobalScript.isMainPlayerDead:
		if PlayerGlobalScript.isMainPlayerDead:
			respawn_button.disabled = true
			start_timer()
			
		death_panel.visible = PlayerGlobalScript.isMainPlayerDead
		prev_death_status = PlayerGlobalScript.isMainPlayerDead
		
		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "spawner_spawn":
		PlayerGlobalScript.main_player_spawned = true
		spawner_animation.play("spawner_idle")
