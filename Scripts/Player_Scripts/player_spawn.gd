extends Node

@onready var spawner_animation = $Sprite/AnimationPlayer
var joined_player_scene = preload("res://Sprite_Nodes/joined_player.tscn")

@export var ySort: Control
var prev_data: Dictionary
var prev_player_mov_data: Dictionary
var prev_player_atk_data: Dictionary
var prev_player_hp_data: Dictionary
var prev_death_status = false
var isScene_loaded = false

#for player spawn
@onready var death_panel = $"UI/Death Screen Panel"
@onready var respawn_button = $"UI/Death Screen Panel/Panel/Respawn Button"
@export var spawn_coords: Vector2
@onready var spawn_timer = $"UI/Death Screen Panel/Spawn Timer"

var main_player_scene = preload("res://Sprite_Nodes/main_player.tscn")
var main_player = main_player_scene.instantiate()

var game_scene_spawn_coords = { 
	"Grassy Land": {
		"allied_spawn_coords": Vector2(3368.63, 791.32), 
		"enemy_spawn_coords": Vector2(-937.99, 764.66)
	} 
}

func spawn_player_on_scene():
	if not is_instance_valid(main_player):
		main_player = main_player_scene.instantiate()
		
	var spawn_coordinates = spawn_coords
	var scene_name = get_tree().current_scene.name
	
	if scene_name.to_upper() == "GAME SCENE" and PlayerGlobalScript.player_class_game_type:
		var game_dic = game_scene_spawn_coords.get(GameClientEnet.game_tilemap_name)
		spawn_coordinates = game_dic.allied_spawn_coords if PlayerGlobalScript.player_class_game_type.to_upper() == "DEFENDER" else game_dic.enemy_spawn_coords

	main_player.position = spawn_coordinates

	if is_instance_valid(ySort) and main_player.get_parent() != ySort:
		ySort.call_deferred("add_child", main_player)
		spawner_animation.play("spawner_spawn")

func _ready():
	call_deferred("_init_ui")
	call_deferred("spawn_player_on_scene")

func _init_ui():
	if not is_instance_valid(death_panel) or not is_instance_valid(respawn_button):
		push_warning("UI nodes not ready yet.")
		return

	death_panel.visible = false
	respawn_button.connect("pressed", respawn)
	isScene_loaded = true
	
func respawn():
	PlayerGlobalScript.isModalOpen = false
	PlayerGlobalScript.current_modal_open = false
	
	spawn_player_on_scene()
	
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
	
func player_hp_receive(player_data: Dictionary, peerID: int):
	if ClientEnet.stored_players.has(peerID):
		var joined_player_data = ClientEnet.stored_players[peerID]
		var joined_player = joined_player_data["Player"]
		
		if is_instance_valid(joined_player):
			joined_player.player_health = player_data.player_health
			
			if joined_player.player_health <= 0:
				joined_player.player_anim.play("death_anim")

				GameClientEnet.player_score_board_dictionary[peerID].death_score += 1
				GameClientEnet.player_score_board_dictionary[multiplayer.get_unique_id()].kill_score += 1
				
				var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
			
				if ui_nodes_grp.size() > 0:
					var message_append = ui_nodes_grp[0]
					message_append.append_msg_on_msg_container("System", peerID, "%s is killed by %s" % [joined_player.playerIGN, PlayerGlobalScript.player_in_game_name], Color("#004a04"))
				
				joined_player.queue_free()
	
func _process(_delta: float) -> void:
	var scene_parent = get_tree().get_current_scene()

	if isScene_loaded and scene_parent.tileMap and scene_parent.tileMap.tile_set and main_player and main_player.get_parent() == ySort:
		scene_parent.wrap_around(main_player)
		scene_parent.adjust_player_camera_limit(main_player)
		
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
	
	#health update
	for key in GameClientEnet.player_health_dictionary.keys():
		if GameClientEnet.player_health_dictionary.has(key):
			var data = GameClientEnet.player_health_dictionary[key]
			
			if data != prev_player_hp_data and data.spawn_code == PlayerGlobalScript.spawn_player_code:
				player_hp_receive(data, key)
				prev_player_hp_data = data
				
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
