extends CharacterBody2D

@onready var player_anim = $"Player Sprite/AnimationPlayer"
@onready var player_sprite = $"Player Sprite"
@onready var player_ign = $"Player ign"
@onready var player_health_bar = $"Health Bar"
@onready var player_health_label = $"Health Bar/label"
@onready var player_area = $"Player Area"
var player_max_health = 100

var direction_value = Vector2.ZERO
var last_direction_value = Vector2.ZERO
var isAttacking = false
var isMoving = false
var isDead = false

var isMainPlayerInArea = false

var playerIGN = ""

var prev_pos = Vector2.ZERO
var prev_ign = ""

var player_type = ""

var player_ally_asset = preload("res://Assets/UI_Components/Sprite_Health_Ally_player.png")
var player_enemy_asset = preload("res://Assets/UI_Components/Sprite_Health_Enemy_player.png")

func _ready() -> void:
	player_health_bar.value = 100
	player_health_bar.texture_progress = player_enemy_asset if player_type.to_upper() == "ENEMY" else player_ally_asset
	
	player_anim.play("side_idle_anim")
	player_area.name = $".".name
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
	
func _process(_delta: float) -> void:
	if prev_ign != playerIGN:
		prev_ign = playerIGN
		player_ign.text = playerIGN

	if isAttacking:
		if not isDead:
			play_punch_animation()
			
			if isMainPlayerInArea:
				PlayerGlobalScript.player_health -= 5
	else:
		if not isDead:
			play_movement_animation()
		
func play_movement_animation():
	var x = direction_value.x
	var y = direction_value.y
	
	if isMoving:
		if abs(x) > abs(y) or ((x < 0 and y < 0) or (x > 0 and y < 0) or (x < 0 and y > 0) or (x > 0 and y > 0)):
			play_anim("side_walk_anim")
			player_sprite.flip_h = x < 0
			
		elif y <= -1:
			play_anim("back_walk_anim")
		
		elif y >= 1:
			play_anim("front_walk_anim")
	else:
		var last_dirX = last_direction_value.x
		var last_dirY = last_direction_value.y
		
		if abs(last_dirX) > abs(last_dirY):
			play_anim("side_idle_anim")
			
		elif last_dirY <= -1:
			play_anim("back_idle_anim")
		
		elif last_dirY >= -1:
			play_anim("front_idle_anim")

func play_anim(anim_name):
	if player_anim.current_animation != anim_name:
		player_anim.play(anim_name)

func player_health_bar_status(status: float):
	player_health_bar.value += status
	player_health_label.text = str(player_health_bar.value) + "/" + str(player_max_health)
	
	if player_health_bar.value <= 0.0:
		isDead = true
		player_anim.play("death_anim")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "death_anim":
		SocketClient.send_data({
			"Socket_Name": "player_death",
			"Player_GameID": player_area.name
		})

func _on_player_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isMainPlayerInArea = true

func _on_player_area_area_exited(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isMainPlayerInArea = false
