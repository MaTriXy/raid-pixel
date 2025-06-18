extends Node

@onready var spawner_animation = $Sprite/AnimationPlayer
var joined_player_scene = preload("res://Sprite_Nodes/joined_player.tscn")

@export var ySort: Control
var prev_data: Dictionary
var spawn_code: String
var prev_death_status = false
var isRespawn = false

#for player spawn
@onready var death_panel = $"UI/Death Screen Panel"
@onready var respawn_button = $"UI/Death Screen Panel/Panel/Respawn Button"
@export var spawn_coords: Vector2
@onready var spawn_timer = $"UI/Death Screen Panel/Spawn Timer"

var game_scene_spawn_coords = { 
	"Grassy Land": { 
		"allied_spawn_coords": Vector2(5147.0, 867.0), 
		"enemy_spawn_coords": Vector2(-633.66, 867.0)
	} 
}

#for loading modal
@export var player_loading_modal: Control

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
	
	isRespawn = true
	
func start_timer():
	spawn_timer.wait_time = 1.0
	spawn_timer.timeout.connect(func(): respawn_button.disabled = false)
	spawn_timer.start()

func _process(_delta: float) -> void:
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status
	
	if connection_status == "Connected":		
		if data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "Player_Spawn_%s" % [spawn_code] and data.get("Player_GameID") != PlayerGlobalScript.player_game_id:

			prev_data = data
			
			if data.has("Player_inGameName"):
				if stored_players.has(data.get("Player_GameID")):
					var joined_player_data = stored_players[data.get("Player_GameID")]
					var joined_player = joined_player_data["Player"]
				
					if is_instance_valid(joined_player):
						joined_player.position = Vector2(data.get("Player_posX"), data.get("Player_posY"))
						joined_player.playerIGN = data.get("Player_inGameName")
						joined_player.direction_value = Vector2(data.get("direction_value")["x"], data.get("direction_value")["y"])
						joined_player.last_direction_value = Vector2(data.get("last_direction_value")["x"], data.get("last_direction_value")["y"])
						joined_player.isMoving = data.get("isMoving")
						joined_player.isAttacking = data.get("isAttacking")
						joined_player.player_health = float(data.get("player_health"))
					else:
						var newPlayer = joined_player_scene.instantiate()
						newPlayer.name = data.get("Player_GameID")
						newPlayer.playerIGN = data.get("Player_inGameName")
						newPlayer.player_type = "ally" if data.get("player_class_type").to_upper() == PlayerGlobalScript.player_class_game_type.to_upper() else "enemy"
						newPlayer.position = Vector2(data.get("Player_posX"), data.get("Player_posY"))
						
						if newPlayer.get_parent() != ySort and not bool(data.get("isDead")):
							spawner_animation.play("spawner_spawn")
							ySort.add_child(newPlayer)

						stored_players[data.get("Player_GameID")] = {
							"Player": newPlayer,
							"Position": newPlayer.position,
						}
					
				if not stored_players.has(data.get("Player_GameID")):
					var player = joined_player_scene.instantiate()
					GetPlayerInfo.active_player_dic[data.get("Player_GameID")] = {
						"Player_username": data.get("Player_username"),
						"Player_IGN": data.get("Player_inGameName"),
						"isFetched": false
					}
					
					if player.get_parent() != ySort and not bool(data.get("isDead")):
						spawner_animation.play("spawner_spawn")
				
						player.name = data.get("Player_GameID")
						player.position = Vector2(data.get("Player_posX"), data.get("Player_posY"))
						player.playerIGN = data.get("Player_inGameName")
						player.player_type = "ally" if data.get("player_class_type").to_upper() == PlayerGlobalScript.player_class_game_type.to_upper() else "enemy"

						ySort.add_child(player)
						
					stored_players[data.get("Player_GameID")] = {
						"Player": player,
						"Position": Vector2(spawn_coords.x, spawn_coords.y),
					}
		
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "populate_scene_%s" % [spawn_code]:
			prev_data = data
			
			for populate_data in data.get("player_data"):
				if bool(populate_data.get("isDead")):
					stored_players.erase(populate_data.get("Player_GameID"))
						
				if populate_data.get("Player_username") != PlayerGlobalScript.player_username and not stored_players.has(populate_data.get("Player_GameID")):
					var newPlayer = joined_player_scene.instantiate()
					newPlayer.name = populate_data.get("Player_GameID")
					newPlayer.position = Vector2(populate_data.get("Player_posX"), populate_data.get("Player_posY"))
					newPlayer.direction_value = Vector2(populate_data.get("direction_value")["x"], populate_data.get("direction_value")["y"])
					newPlayer.last_direction_value = Vector2(populate_data.get("last_direction_value")["x"], populate_data.get("last_direction_value")["y"])
					newPlayer.playerIGN = populate_data.get("Player_inGameName")
					newPlayer.player_health = float(populate_data.get("player_health"))
					newPlayer.player_type = "ally" if populate_data.get("player_class_type").to_upper() == PlayerGlobalScript.player_class_game_type.to_upper() else "enemy"
					
					if newPlayer.get_parent() != ySort and not bool(populate_data.get("isDead")):
						if str(populate_data.get("spawn_code")) == spawn_code:
							spawner_animation.play("spawner_spawn")
							ySort.add_child(newPlayer)
						
						stored_players[populate_data.get("Player_GameID")] = {
							"Player": newPlayer,
							"Position": newPlayer.position,
						}
						
						GetPlayerInfo.active_player_dic[populate_data.get("Player_GameID")] = {
							"Player_username": populate_data.get("Player_username"),
							"Player_IGN": populate_data.get("Player_inGameName"),
							"isFetched": false
						}
					
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") in ["Player_Disconnect", "leave_lobby"]:
			prev_data = data
			
			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")):
				var joined_player_data = stored_players[data.get("Player_GameID")]
				var joined_player = joined_player_data["Player"]
				
				if is_instance_valid(joined_player_scene):
					joined_player.queue_free()
					stored_players.erase(data.get("Player_GameID"))
					GetPlayerInfo.active_player_dic.erase(data.get("Player_GameID"))
					
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "ModifyProfile":
			prev_data = data
			
			if data.has("Player_GameID") and stored_players.has(data.get("Player_GameID")) and GetPlayerInfo.active_player_dic.has(data.get("Player_GameID")):
				
				var player_key_list = GetPlayerInfo.active_player_dic[data.get("Player_GameID")] 
				var joined_player_data = stored_players[data.get("Player_GameID")]
				var joined_player = joined_player_data["Player"]
				
				player_key_list.Player_IGN = data.get("Player_inGameName")
				joined_player.name = data.get("Player_GameID")
				joined_player.playerIGN = data.get("Player_inGameName")
		
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") in ["find_match", "start_match"]:
			prev_data = data

			await get_tree().process_frame
			if data.has("player_map") and data.has("Match_RoomID") and data.has("game_scene"):		
				player_loading_modal.player_map = data.get("player_map")
				player_loading_modal.match_roomID = data.get("Match_RoomID")
				player_loading_modal.game_scene = data.get("game_scene")
			
				for map in data.get("player_map"):
					if map.ign == PlayerGlobalScript.player_in_game_name:
						PlayerGlobalScript.player_class_game_type = map.class
					
					player_loading_modal.player_list[map.ign] = { "profile": map.profile, "class": map.class }
					
				PlayerGlobalScript.match_roomID = "_%s" % [data.get("Match_RoomID")]
				PlayerGlobalScript.game_scene_name = data.get("game_scene")
				
				if not player_loading_modal.visible:
					player_loading_modal.visible = true
					player_loading_modal.is_player_load = true
		
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name")  == "start_game":
			prev_data = data
			
			if data.has("match_roomID") and PlayerGlobalScript.match_roomID == data.get("match_roomID"):
				if not PlayerGlobalScript.is_game_scene_loaded:
					PlayerGlobalScript.isModalOpen = false
					PlayerGlobalScript.current_modal_open = false
					get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")
			
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
