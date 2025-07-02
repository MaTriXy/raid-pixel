extends Node

@onready var spawner_animation = $Sprite/AnimationPlayer
var joined_player_scene = preload("res://Sprite_Nodes/joined_player.tscn")

@export var ySort: Control
var prev_data: Dictionary
var prev_player_mov_data: Dictionary
var prev_player_atk_data: Dictionary
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
		"allied_spawn_coords": Vector2(5733.66, 440.33), 
		"enemy_spawn_coords": Vector2(-879.60, 267.33)
	} 
}

#for loading modal
@export var player_loading_modal: Control

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
	
func player_move_receieve(player_data: Dictionary):
	var player = player_data
	var scene_code = player.spawn_code
	var pos = player.player_pos
	var last_dir_val = Vector2(player.last_direction_value.x, player.last_direction_value.y)
	var ign = player.ign
	var direction_value = Vector2(player.direction_value.x, player.direction_value.y)
	var isMoving = player.isMoving
	var player_class = player.player_class
	var username = player.username
	var peerID = player.peerID
	
	if spawn_code == scene_code:
		if ClientEnet.stored_players.has(peerID):
			var joined_player_data = ClientEnet.stored_players[peerID]
			var joined_player = joined_player_data["Player"]
			
			ClientEnet.stored_players[peerID].ign = ign
				
			if is_instance_valid(joined_player):
				joined_player.position = pos
				joined_player.playerIGN = ign
				joined_player.last_direction_value = last_dir_val
				joined_player.direction_value = direction_value
				joined_player.isMoving = isMoving
				joined_player.player_class = player_class
			else:
				var newPlayer = joined_player_scene.instantiate()
				newPlayer.name = str(peerID)
				newPlayer.playerIGN = ign
				newPlayer.last_direction_value = last_dir_val
				newPlayer.direction_value = direction_value
				newPlayer.position = pos
				newPlayer.isMoving = isMoving
				newPlayer.player_class = player_class
				
				if newPlayer.get_parent() != ySort and not newPlayer.is_inside_tree():
					spawner_animation.play("spawner_spawn")
					ySort.add_child(newPlayer)

		if not ClientEnet.stored_players.has(peerID):
			var player_ins = joined_player_scene.instantiate()
			player_ins.name = str(peerID)
			player_ins.position = pos
			player_ins.playerIGN = ign
			player_ins.last_direction_value = last_dir_val
			player_ins.direction_value = direction_value
			player_ins.isMoving = isMoving
			player_ins.player_class = player_class
			
			if player_ins.get_parent() != ySort and not player_ins.is_inside_tree():
				spawner_animation.play("spawner_spawn")
				ySort.add_child(player_ins)
				
				ClientEnet.stored_players[peerID] = {
					"Player": player_ins,
					"ign": ign,
					"username": username,
					"peerID": peerID
				}
						
func player_attack_receive(player_data: Dictionary):
	if ClientEnet.stored_players.has(player_data.peerID):
		var joined_player_data = ClientEnet.stored_players[player_data.peerID]
		var joined_player = joined_player_data["Player"]
		
		if is_instance_valid(joined_player_scene):
			joined_player.isAttacking = player_data.isAttacking
	
func _process(_delta: float) -> void:
	#spawn
	for key in ClientEnet.rpc_player_spawn_dic.keys():
		var player_data = ClientEnet.rpc_player_spawn_dic[key]
		
		if player_data != prev_player_mov_data:
			player_move_receieve(player_data)
			prev_player_mov_data = player_data
		
		ClientEnet.rpc_player_spawn_dic.erase(key)
	
	#attack
	for key in ClientEnet.rpc_player_attack_dic.keys():
		var player_data = ClientEnet.rpc_player_attack_dic[key]
		
		if player_data != prev_player_atk_data:
			player_attack_receive(player_data)
			prev_player_atk_data = player_data
		
		ClientEnet.rpc_player_attack_dic.erase(key)
	
	var data = {}
	var connection_status = "Connected"
	
	if connection_status == "Connected":		
		if data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") in ["find_match", "start_match"]:
			prev_data = data

			await get_tree().process_frame
			if data.has("player_map") and data.has("Match_RoomID") and data.has("game_scene"):		
				player_loading_modal.player_map = data.get("player_map")
				player_loading_modal.match_roomID = data.get("Match_RoomID")
				player_loading_modal.game_scene = data.get("game_scene")
			
				for map in data.get("player_map"):
					if map.id == PlayerGlobalScript.player_game_id:
						PlayerGlobalScript.player_class_game_type = map.class
					
					player_loading_modal.player_list[map.id] = { "ign": map.ign, "profile": map.profile, "class": map.class }
					
					GameBattleInfo.player_populate_dic[map.id] = {
						"ign": map.ign,
						"profile": map.profile,
						"class": map.class,
						"kills": 0,
						"deaths": 0
					}
					GameBattleInfo.player_populate_size = GameBattleInfo.player_populate_dic.size()
					
				PlayerGlobalScript.match_roomID = "_%s" % [data.get("Match_RoomID")]
				PlayerGlobalScript.game_scene_name = data.get("game_scene")
				
				if not player_loading_modal.visible:
					player_loading_modal.visible = true
					player_loading_modal.is_player_load = true
		
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name")  == "start_game_%s" % PlayerGlobalScript.spawn_player_code:
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
