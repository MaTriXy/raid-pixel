extends Node

@onready var game_label = $"Game Timer Label"

@onready var game_info_panel = $"Game Info Mechanics Panel"
@onready var game_info_anim = $"Game Info Mechanics Panel/AnimationPlayer"
@onready var game_info_button = $"Game Info Mechanics Panel/Panel/Lets go button"
@onready var game_instruction_label = $"Game Info Mechanics Panel/Panel/Player Label instruction"

@onready var sprite_core = $"Core HP"
@onready var core_hp_label = $"Core HP/Core HP Label"

var allied_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Ally.png")
var enemy_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Enemy.png")

@export var core: StaticBody2D

var prev_hp = 0
var prev_data = {}

var ui_core_hp = 0
var ui_core_max_hp = 0

func _ready() -> void:
	PlayerGlobalScript.is_game_scene_loaded = true
	ui_core_hp = core.core_hp
	ui_core_max_hp = core.core_max_hp
	
	sprite_core.value = ui_core_hp
	
	if PlayerGlobalScript.player_class_game_type == "Defender":
		sprite_core.texture_progress = allied_core_hp_render
		game_instruction_label.text = "Defend the core before the battle time runs out, or you lose."
	else:
		sprite_core.texture_progress = enemy_core_hp_render
		game_instruction_label.text = "Destroy the core before the battle time runs out, or you lose."

	game_info_panel.visible = true
	game_info_button.connect("pressed", func(): game_info_panel.visible = false)

	await get_tree().process_frame
	SocketClient.send_data({
		"Socket_Name": "start_game",
		"match_roomID": PlayerGlobalScript.match_roomID,
		"spawn_code": PlayerGlobalScript.spawn_player_code
	})

func game_end():
	print("Game ended")

func _process(_delta: float) -> void:
	game_scene_socket_data()
	
	if prev_hp != ui_core_hp:
		sprite_core.value = ui_core_hp
		core_hp_label.text = "%s/%s" % [ui_core_hp, ui_core_max_hp]
		
		prev_hp = core.core_hp
	
func game_scene_socket_data():
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status

	if connection_status == "Connected":
		if data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "core_health_%s" % PlayerGlobalScript.spawn_player_code:
			prev_data = data
		
			if data.has("health") and data.has("max_health"):
				ui_core_hp = int(data["health"])
				ui_core_max_hp = int(data["max_health"])
				
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "battle_time_%s" % PlayerGlobalScript.spawn_player_code:
			prev_data = data
			
			if data.has("minutes") and data.has("seconds"):
				var minutes = int(data.get("minutes"))
				var seconds = int(data.get("seconds"))
				game_label.text = "Battle time: %02d:%02d" % [minutes, seconds]
				
				if minutes <= 0 and seconds <= 0:
					game_end()
