extends Node

@onready var game_label = $"Game Timer Label"

@onready var game_info_panel = $"Game Info Mechanics Panel"
@onready var game_info_anim = $"Game Info Mechanics Panel/AnimationPlayer"
@onready var game_info_button = $"Game Info Mechanics Panel/Panel/Lets go button"
@onready var game_instruction_label = $"Game Info Mechanics Panel/Panel/Player Label instruction"
@onready var core_hp_status_label = $"Core HP name status"

@onready var sprite_core = $"Core HP"
@onready var core_hp_label = $"Core HP/Core HP Label"

var allied_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Ally.png")
var enemy_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Enemy.png")

@export var core: StaticBody2D

#for battle info
@export var battle_info_player_panel: Panel
@export var battle_info_defender_container: VBoxContainer
@export var battle_info_attacker_container: VBoxContainer
var no_profile_texture = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

var prev_hp = 0
var prev_data = {}

var ui_core_hp = 0
var ui_core_max_hp = 0

var player_score_dic = {}

var isPlayerScore_populate = false

func _ready() -> void:
	PlayerGlobalScript.is_game_scene_loaded = true
	
	if PlayerGlobalScript.game_scene_name == "Grassy Land":
		core.core_hp = 500
		core.core_max_hp = 500
	
	ui_core_hp = int(core.core_hp)
	ui_core_max_hp = int(core.core_max_hp)
	
	sprite_core.value = ui_core_hp
	sprite_core.max_value = ui_core_max_hp
	
	if PlayerGlobalScript.player_class_game_type == "Defender":
		sprite_core.texture_progress = allied_core_hp_render
		game_instruction_label.text = "Defend the core before the battle time runs out, or you lose."
		core_hp_status_label.text = "Core HP (Protect this)"
		core_hp_status_label.add_theme_color_override("default_color", Color("#007cb5"))
	else:
		sprite_core.texture_progress = enemy_core_hp_render
		game_instruction_label.text = "Destroy the core before the battle time runs out, or you lose."
		core_hp_status_label.text = "Core HP (Destroy this)"
		core_hp_status_label.add_theme_color_override("default_color", Color("#ad0202"))

	game_info_panel.visible = true
	game_info_button.connect("pressed", func(): game_info_panel.visible = false)
	
	var start_game_notify = Timer.new()
	start_game_notify.name = "start game timer"
	
	if not start_game_notify.is_inside_tree():
		add_child(start_game_notify)
	
	start_game_notify.wait_time = 1.0
	start_game_notify.timeout.connect(start_game)
	start_game_notify.start()
	
	#this is for the timer at battle game timer
	var battle_timer = Timer.new()
	battle_timer.name = "Battle Timer"
	
	if not battle_timer.is_inside_tree():
		add_child(battle_timer)
	
	battle_timer.wait_time = 1.0
	battle_timer.timeout.connect(start_timer)
	battle_timer.start()
	
func start_game():
	if not isPlayerScore_populate:
		SocketClient.send_data({
			"Socket_Name": "start_game_%s" % PlayerGlobalScript.spawn_player_code,
			"match_roomID": PlayerGlobalScript.match_roomID,
			"spawn_code": PlayerGlobalScript.spawn_player_code
		})
		
		SocketClient.send_data({
			"Socket_Name": "battle_info_%s" % PlayerGlobalScript.spawn_player_code
		})
	
func start_timer():
	SocketClient.send_data({
		"Socket_Name": "game_is_start_%s" % PlayerGlobalScript.spawn_player_code,
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
				
		#TODO: fix this not working properly
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "battle_time_%s" % PlayerGlobalScript.spawn_player_code:
			prev_data = data
			
			if data.has("minutes") and data.has("seconds"):
				var minutes = int(data.get("minutes"))
				var seconds = int(data.get("seconds"))
				game_label.text = "Battle time: %02d:%02d" % [minutes, seconds]
				
				if minutes <= 0 and seconds <= 0:
					game_end()
		
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "battle_info_%s" % PlayerGlobalScript.spawn_player_code:
			isPlayerScore_populate = true
			prev_data = data
			
			if data.has("players"):
				for entry in data.get("players"):
					var player_panel_instance = battle_info_player_panel.duplicate()
					player_panel_instance.name = entry.id
					player_panel_instance.visible = true
					
					if not player_score_dic.has(entry.id):
						player_score_dic[entry.id] = {
							"kills": 0,
							"deaths": 0
						}
					
					var player_panel_instantce_profile = player_panel_instance.get_node("Player Profile")
					var player_panel_instance_ign = player_panel_instance.get_node("Player IGN")
					
					player_panel_instance_ign.text = entry.ign
					
					if entry.ign == PlayerGlobalScript.player_in_game_name:
						player_panel_instance_ign.text = "%s (You)" % entry.ign
					
					if not player_panel_instance.is_inside_tree():
						if entry.class == "Defender":
							battle_info_defender_container.add_child(player_panel_instance)
						else:
							battle_info_attacker_container.add_child(player_panel_instance)
					
					var player_profile_texture = await load_player_profile_battle_info(entry.ign, entry.profile)
					
					if player_profile_texture:
						player_panel_instantce_profile.texture = player_profile_texture
					else:
						player_panel_instantce_profile.texture = no_profile_texture
						
		#TODO: fix this not working properly
		elif data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "battle_info_player_score_status_%s" % PlayerGlobalScript.spawn_player_code:
			prev_data = data
			
			print(data)
			if data.has_all(["killer_game_id", "killer_class", "dead_game_id", "dead_class"]):
				var killer_container = battle_info_defender_container if data.get("killer_class") == "Defender" else battle_info_attacker_container
				var dead_container = battle_info_defender_container if data.get("dead_class") == "Defender" else battle_info_attacker_container
	
				update_score_board(killer_container, data.get("killer_game_id"), true)
				update_score_board(dead_container, data.get("dead_game_id"), false)
				
func update_score_board(container: VBoxContainer, player_ID: String, isKill: bool):
	for child in container.get_children():
		if child.name == player_ID:
			if isKill:
				player_score_dic[player_ID]["kills"]+=1
			else:
				player_score_dic[player_ID]["deaths"]+=1
			
			await get_tree().process_frame
			child.get_node("Player status").text = "Kill/s: %s		Death/s: %s" % [player_score_dic[player_ID]["kills"], player_score_dic[player_ID]["deaths"]]
			
func load_player_profile_battle_info(ign: String, profile_url: String):
	var player_http_req = HTTPRequest.new()
	player_http_req.name = "Player_info_%s" % [ign]
	
	add_child(player_http_req)
	
	var request_status = player_http_req.request(profile_url)
	if request_status != OK:
		player_http_req.queue_free()
		return null
	
	var result = await player_http_req.request_completed
	var response_code = result[1]
	var body = result[3]

	if response_code == 200:
		var image = Image.new()
		var err = image.load_png_from_buffer(body)
		if err == OK:
			return ImageTexture.create_from_image(image)
	else:
		return null
		
	player_http_req.queue_free()
