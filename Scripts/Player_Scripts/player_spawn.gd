extends Node

@onready var spawner_animation = $Sprite/AnimationPlayer
var joined_player_scene = preload("res://Sprite_Nodes/joined_player.tscn")

@export var ySort: Control
var prev_data: Dictionary
var prev_player_mov_data: Dictionary
var prev_player_atk_data: Dictionary
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

func _ready() -> void:
	death_panel.visible = false
	spawner_animation.play("spawner_spawn")
	respawn_button.connect("pressed", respawn)
	
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
	var peerID = player.peerID
	var spawn_code = PlayerGlobalScript.spawn_player_code
	
	if spawn_code == scene_code:
		if not ClientEnet.stored_players.has(peerID) or not is_instance_valid(ClientEnet.stored_players[peerID]["Player"]):
			var player_ins = joined_player_scene.instantiate()
			player_ins.name = str(peerID)
			player_ins.position = pos
			player_ins.playerIGN = ign
			player_ins.last_direction_value = last_dir_val
			player_ins.direction_value = direction_value
			player_ins.isMoving = isMoving
			player_ins.player_class = player_class
			
			var new_player_ins = str(player_ins.name)
			
			if not ySort.has_node(new_player_ins):
				spawner_animation.play("spawner_spawn")
				ySort.add_child(player_ins)
				
				ClientEnet.stored_players[peerID] = {
					"Player": player_ins,
					"ign": ign,
					"peerID": peerID
				}
				
		else:
			var joined_player_data = ClientEnet.stored_players[peerID]
			var joined_player = joined_player_data["Player"]
			
			ClientEnet.stored_players[peerID].ign = ign
			
			joined_player.position = pos
			joined_player.playerIGN = ign
			joined_player.last_direction_value = last_dir_val
			joined_player.direction_value = direction_value
			joined_player.isMoving = isMoving
			joined_player.player_class = player_class
						
func player_attack_receive(player_data: Dictionary):
	if ClientEnet.stored_players.has(player_data.peerID):
		var joined_player_data = ClientEnet.stored_players[player_data.peerID]
		var joined_player = joined_player_data["Player"]
		
		if is_instance_valid(joined_player):
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
	
	#if player dead
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
