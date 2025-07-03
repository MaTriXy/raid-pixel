extends PlayerMovement

@onready var player_anim = $"Player Sprite/AnimationPlayer"
@onready var player_sprite = $"Player Sprite"
@onready var player_ign = $"Player ign"
@onready var player_camera = $"Camera2D"
@onready var player_health_bar = $"Health Bar"
@onready var player_health_label = $"Health Bar/label"
@onready var attack_timer = $"Attack Timer"
var can_attack = true
var isDataSend = false

var last_data_mov_send = false
var last_data_atk_send = false
var prev_ign = ""
var prev_health = 0
var prev_coordinates = Vector2.ZERO
var isDead = false

func _ready() -> void:
	PlayerGlobalScript.isMainPlayerDead = false
	PlayerGlobalScript.player_health = 100
	PlayerGlobalScript.player_max_health = 100
	player_health_bar.value = PlayerGlobalScript.player_health
	player_anim.play("side_idle_anim")
	
	await get_tree().process_frame
	player_health_label.text = str(player_health_bar.value) + "/" + str(PlayerGlobalScript.player_max_health)
		
func play_punch_animation():
	var x = last_direction_value.x
	var y = last_direction_value.y
	
	if isAttacking:
		if abs(x) > abs(y):
			play_anim("side_punch_anim")
		
		elif y <= -1:
			play_anim("back_punch_anim")
		
		elif y >= 1:
			play_anim("front_punch_anim")
			
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("punch") and PlayerGlobalScript.isModalOpen == false and can_attack:
		can_attack = false
		isAttacking = true
		PlayerGlobalScript.isPlayerAttack = true
		
		play_punch_animation()
		attack_timer.start(0.5)
	
func _process(_delta: float) -> void:
	if prev_ign != PlayerGlobalScript.player_in_game_name:
		prev_ign = PlayerGlobalScript.player_in_game_name
		player_ign.text = PlayerGlobalScript.player_in_game_name
	
	if not isAttacking:
		if not isDead:
			move_player_animation()
	
	player_sprite.visible = PlayerGlobalScript.main_player_spawned
		
	send_player_mov()
	send_player_atk()
	player_health_bar_status()
	
	if prev_coordinates != Vector2($".".position.x, $".".position.y):
		PlayerGlobalScript.player_pos_X = $".".position.x
		PlayerGlobalScript.player_pos_Y = $".".position.y

		prev_coordinates = Vector2($".".position.x, $".".position.y)
	
func move_player_animation():
	var dir_value = direction_value
	var x = dir_value.x
	var y = dir_value.y
	
	if isMoving:
		if abs(x) > abs(y) or ((x < 0 and y < 0) or (x > 0 and y < 0) or (x < 0 and y > 0) or (x > 0 and y > 0)):
			play_anim("side_walk_anim")
			player_sprite.flip_h = last_direction_value.x < 0
			
		elif y <= -1:
			play_anim("back_walk_anim")
		
		elif y >= 1:
			play_anim("front_walk_anim")
	else:
		var last_dir_x = last_direction_value.x
		var last_dir_y = last_direction_value.y
		
		if abs(last_dir_x) > abs(last_dir_y):
			play_anim("side_idle_anim")
			
		elif last_dir_y <= -1:
			play_anim("back_idle_anim")
		
		elif last_dir_y >= -1:
			play_anim("front_idle_anim")
	
func play_anim(anim_name):
	if player_anim.current_animation != anim_name:
		player_anim.play(anim_name)

func send_player_atk():
	var player_data = {
		"last_direction": last_direction_value,
		"isAttacking": isAttacking,
		"peerID": multiplayer.get_unique_id()
	}
	
	if isAttacking:
		last_data_atk_send = false
		ClientEnet.send_to_server("player_attack", multiplayer.get_unique_id(), player_data)
	else:
		if not last_data_atk_send:
			last_data_atk_send = true
			ClientEnet.send_to_server("player_attack", multiplayer.get_unique_id(), player_data)

func send_player_mov():
	var player_pos = Vector2(PlayerGlobalScript.player_pos_X, PlayerGlobalScript.player_pos_Y)
	
	var player_data = {
		"spawn_code": PlayerGlobalScript.spawn_player_code,
		"player_pos": player_pos,
		"isMoving": isMoving,
		"last_direction_value": last_direction_value,
		"direction_value": direction_value,
		"ign": PlayerGlobalScript.player_in_game_name,
		"player_class": PlayerGlobalScript.player_class_game_type,
		"peerID": multiplayer.get_unique_id()
	}

	if not isDataSend:
		await get_tree().create_timer(0.5).timeout
		ClientEnet.send_to_server("player_spawn_movement", player_data.peerID, player_data)
		isDataSend = true
		
	if not isMoving and not last_data_mov_send:
		last_data_mov_send = true
		ClientEnet.send_to_server("player_spawn_movement", player_data.peerID, player_data)
		
	if isMoving and not PlayerGlobalScript.isModalOpen and not PlayerGlobalScript.current_modal_open and not isDead:
		last_data_mov_send = false
		ClientEnet.send_to_server("player_spawn_movement", player_data.peerID, player_data)

func player_health_bar_status():
	if  PlayerGlobalScript.player_health <= 0.0:
		isDead = true
		PlayerGlobalScript.isMainPlayerDead = true
		PlayerGlobalScript.isModalOpen = true
		PlayerGlobalScript.current_modal_open = true
		play_anim("death_anim")
		
		PlayerGlobalScript.player_health = 0
	
	player_health_bar.value = PlayerGlobalScript.player_health
	player_health_label.text = str(PlayerGlobalScript.player_health) + "/" + str(PlayerGlobalScript.player_max_health)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "death_anim":
		await get_tree().create_timer(0.5).timeout
		GameBattleInfo.update_score_board(PlayerGlobalScript.player_game_id, PlayerGlobalScript.player_class_game_type)
		
		var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
		
		if ui_nodes_grp.size() > 0:
			var message_append = ui_nodes_grp[0]
			message_append.append_msg_on_msg_container("System", "You have been killed", Color("#004a04"))
		
		await get_tree().process_frame
		queue_free()

func _on_attack_timer_timeout() -> void:
	can_attack = true
	isAttacking = false
	PlayerGlobalScript.isPlayerAttack = false
