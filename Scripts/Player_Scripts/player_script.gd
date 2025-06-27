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

var prev_state = {}
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
		
	send_player_data()
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

func send_player_data():
	var current_state = {
			"Socket_Name": "Player_Spawn_%s" % [PlayerGlobalScript.spawn_player_code],
			"Player_username": PlayerGlobalScript.player_username,
			"Player_inGameName": PlayerGlobalScript.player_in_game_name,
			"Player_GameID": PlayerGlobalScript.player_game_id,
			"Player_posX": PlayerGlobalScript.player_pos_X,
			"Player_posY": PlayerGlobalScript.player_pos_Y,
			"direction_value": { "x": direction_value.x, "y": direction_value.y },
			"last_direction_value": { "x": last_direction_value.x, "y": last_direction_value.y },
			"isMoving": isMoving,
			"player_class": PlayerGlobalScript.player_class_game_type,
			"isAttacking": isAttacking,
			"isDead": PlayerGlobalScript.isMainPlayerDead,
			"spawn_code": PlayerGlobalScript.spawn_player_code,
			"player_health": PlayerGlobalScript.player_health,
		}
	
	if WebsocketsConnection.socket_connection_status == "Connected":
		if not isDataSend:
			await get_tree().create_timer(1.0).timeout
			if  SocketClient.enet_client_node:
				SocketClient.enet_client_node.send_client_data(current_state)
			#SocketClient.send_data(current_state)
			
			prev_state = current_state.duplicate()
			prev_health = PlayerGlobalScript.player_health
			isDataSend = true
			
		if (isMoving or isAttacking or prev_state != current_state or prev_health != PlayerGlobalScript.player_health) and PlayerGlobalScript.player_in_game_name and not PlayerGlobalScript.isModalOpen and not PlayerGlobalScript.current_modal_open and not isDead:
			if SocketClient.enet_client_node:
				SocketClient.enet_client_node.send_client_data(current_state)
			#SocketClient.send_data(current_state)
			
			prev_state = current_state.duplicate()
			prev_health = PlayerGlobalScript.player_health
	else:
		isDataSend = false
		prev_state = {}

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
		send_player_data()
		
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
