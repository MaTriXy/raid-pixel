extends PlayerMovement

@onready var player_anim = $"Player Sprite/AnimationPlayer"
@onready var player_sprite = $"Player Sprite"
@onready var player_ign = $"Player ign"
@onready var player_camera = $"Camera2D"
@onready var player_health_bar = $"Health Bar"
@onready var player_health_label = $"Health Bar/label"
@onready var attack_timer = $"Attack Timer"
var player_max_health = 100
var can_attack = true

var prev_state = {}
var prev_ign = ""
var prev_coordinates = Vector2.ZERO
var isDead = false
var prev_health = 0

func _ready() -> void:
	PlayerGlobalScript.isMainPlayerDead = false
	PlayerGlobalScript.player_health = 100
	player_health_bar.value = PlayerGlobalScript.player_health
	player_anim.play("side_idle_anim")
	
	await get_tree().process_frame
	PlayerGlobalScript.player_type = "Ally" if PlayerGlobalScript.current_scene.to_upper() == "LOBBY" else "Enemy"
	player_health_label.text = str(player_health_bar.value) + "/" + str(player_max_health)
		
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
	player_health_bar_status(PlayerGlobalScript.player_health)
	
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
			"player_type": PlayerGlobalScript.player_type,
			"isAttacking": isAttacking
		}
	
	if (isMoving or isAttacking or prev_state != current_state) and not PlayerGlobalScript.isModalOpen and not PlayerGlobalScript.current_modal_open:

		SocketClient.send_data(current_state)
		prev_state = current_state.duplicate()
		

func player_health_bar_status(status: float):
	player_health_bar.value = status
	player_health_label.text = str(player_health_bar.value) + "/" + str(player_max_health)
	
	if player_health_bar.value <= 0.0:
		isDead = true
		PlayerGlobalScript.isModalOpen = true
		PlayerGlobalScript.current_modal_open = true
		play_anim("death_anim")
		
	var attack_state = {
		"Socket_Name": "player_health",
		"Player_GameID": PlayerGlobalScript.player_game_id,
		"Player_Health": player_health_bar.value
	}
	
	if prev_health != player_health_bar.value:
		SocketClient.send_data(attack_state)
		prev_health = player_health_bar.value

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "death_anim":
		PlayerGlobalScript.isMainPlayerDead = true
		queue_free()

func _on_attack_timer_timeout() -> void:
	can_attack = true
	isAttacking = false
