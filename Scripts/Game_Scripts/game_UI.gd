extends Node

@onready var game_time_label = $"Game Timer Label"
@onready var game_timer = $"Game Timer"
@onready var game_info_panel = $"Game Info Mechanics Panel"
@onready var game_info_anim = $"Game Info Mechanics Panel/AnimationPlayer"
@onready var game_info_button = $"Game Info Mechanics Panel/Panel/Lets go button"
@onready var game_instruction_label = $"Game Info Mechanics Panel/Panel/Player Label instruction"
@onready var core_hp_status_label = $"Core HP name status"
@onready var loading_interface = $"Loading Interface"

@onready var sprite_core = $"Core HP"
@onready var core_hp_label = $"Core HP/Core HP Label"

var allied_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Ally.png")
var enemy_core_hp_render = preload("res://Assets/UI_Components/Core_Health_Enemy.png")

@export var core_object: Node2D

#for battle info
@export var battle_info_player_panel: Panel
@export var battle_info_defender_container: VBoxContainer
@export var battle_info_attacker_container: VBoxContainer
var no_profile_texture = preload("res://Assets/Sprite_Static/Bob_No_Img.png")
var instance_score_panel_dic: Dictionary
var player_score_panel: RichTextLabel

#for game win lose condition
@onready var win_lose_panel = $"Win Lose Panel"
@onready var win_lose_panel_battle_time_left = $"Win Lose Panel/Panel/Game time ended"
@onready var win_lose_panel_condition_label = $"Win Lose Panel/Panel/Condition Label"
@onready var win_lose_panel_score_result = $"Win Lose Panel/Panel/Score result"
@onready var win_lose_panel_back_to_lobby = $"Win Lose Panel/Panel/Back to lobby Button"
var defender_total_score = 0
var attacker_total_score = 0

var prev_data = {}
var prev_score_data = {}
var prev_time = 0
var prev_kill_score = 0
var prev_death_score = 0
var prev_hp = 0

func _ready() -> void:
	#for win lose contents
	win_lose_panel_back_to_lobby.connect("pressed", back_to_lobby)
	win_lose_panel.visible = false
	
	if GameClientEnet.game_tilemap_name == "Grassy Land":
		core_object.core_hp = 50
		core_object.core_max_hp = 500
	
	sprite_core.value = int(core_object.core_hp)
	sprite_core.max_value = int(core_object.core_max_hp)
	
	core_hp_label.text = "%s/%s" % [sprite_core.value, sprite_core.max_value]
	
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
	
	if not GameClientEnet.game_client_dic_data.is_empty():
		player_populate_battle_info()
	
	#this is for the timer at battle game timer
	game_timer.one_shot = true
	game_timer.wait_time = 500.0
	game_timer.timeout.connect(game_end)
	game_timer.start()

func back_to_lobby():
	PlayerGlobalScript.kill_count = 0
	PlayerGlobalScript.death_count = 0
	loading_interface.load("res://Scenes/lobby_scene.tscn")

func game_end():
	win_lose_condition()
	
func win_lose_condition():
	if sprite_core.value <= 0:
		win_lose_panel.visible = true
		game_timer.stop()
		win_lose_panel_battle_time_left.text = game_time_label.text
		win_lose_panel_score_result.text = "Defender: %s		Attacker: %s" % [defender_total_score, attacker_total_score]
		
		if PlayerGlobalScript.player_class_game_type.to_upper() == "DEFENDER":
			win_lose_panel_condition_label.text = "Defender Lose"
		else:
			win_lose_panel_condition_label.text = "Attacker Win"
	
	elif game_timer.time_left <= 0 and sprite_core.value >= 0:
		win_lose_panel.visible = true
		game_timer.stop()
		win_lose_panel_battle_time_left.text = game_time_label.text
		win_lose_panel_score_result.text = "Defender: %s		Attacker: %s" % [defender_total_score, attacker_total_score]
		
		if PlayerGlobalScript.player_class_game_type.to_upper() == "DEFENDER":
			win_lose_panel_condition_label.text = "Defender Win"
		else:
			win_lose_panel_condition_label.text = "Attacker Lose"

func _process(_delta: float) -> void:
	sync_damage_in_server()
	update_battle_score_board()
	win_lose_condition()
	
	if prev_hp != int(core_object.core_hp):
		sprite_core.value = int(core_object.core_hp)
		sprite_core.max_value = int(core_object.core_max_hp)
	
		core_hp_label.text = "%s/%s" % [sprite_core.value, sprite_core.max_value]
	
		prev_hp = int(core_object.core_hp)
	
	if prev_time != game_timer.time_left:
		game_time_label.text = "Battle time: %03d" % int(game_timer.time_left)
		
func update_battle_score_board():
	if prev_kill_score != PlayerGlobalScript.kill_count or prev_death_score != PlayerGlobalScript.death_count and player_score_panel:
		player_score_panel.text = "Kill/s: %s		Death/s: %s" % [PlayerGlobalScript.kill_count, PlayerGlobalScript.death_count]
		
		if PlayerGlobalScript.player_class_game_type.to_upper() == "DEFENDER":
			defender_total_score = PlayerGlobalScript.kill_count
		else:
			attacker_total_score = PlayerGlobalScript.kill_count
		
	for key in GameClientEnet.player_score_board_dictionary.keys():
		if GameClientEnet.player_score_board_dictionary.has(key):
			var data = GameClientEnet.player_score_board_dictionary[key]
			
			if data != prev_score_data and data.spawn_code == PlayerGlobalScript.spawn_player_code:
				var kill_score = data.kill_score
				var death_score = data.death_score
				
				instance_score_panel_dic[key]["status_panel"].text = "Kill/s: %s		Death/s: %s" % [kill_score, death_score]
				
				if instance_score_panel_dic[key]["class"].to_upper() == "DEFENDER":
					defender_total_score = kill_score
				else:
					attacker_total_score = kill_score
					
				prev_score_data = data
				
			GameClientEnet.player_score_board_dictionary.erase(key)
		
func player_populate_battle_info():
	var player_list = GameClientEnet.game_client_dic_data.player_list
	var spawn_code = "game_scene_%s" % GameClientEnet.game_client_dic_data.match_ID
	
	for key in player_list.keys():
		var player = player_list[key]
		
		var player_panel_instance = battle_info_player_panel.duplicate()
		player_panel_instance.name = str(key)
		player_panel_instance.visible = true
						
		var player_panel_instance_profile = player_panel_instance.get_node("Player Profile")
		var player_panel_instance_ign = player_panel_instance.get_node("Player IGN")
		var player_panel_instance_status = player_panel_instance.get_node("Player status")
		
		instance_score_panel_dic[key] = { "status_panel": player_panel_instance_status, "class": player.class }
						
		player_panel_instance_ign.text = player.ign
						
		if key == multiplayer.get_unique_id():
			player_score_panel = player_panel_instance_status
			player_panel_instance_ign.text = "%s (You)" % player.ign
					
		if not player_panel_instance.is_inside_tree():
			if player.class == "Defender":
				battle_info_defender_container.add_child(player_panel_instance)
			else:
				battle_info_attacker_container.add_child(player_panel_instance)
		
		var player_profile_texture = await load_player_profile_battle_info(player.ign, player.profile)
		
		if player_profile_texture:
			player_panel_instance_profile.texture = player_profile_texture
		else:
			player_panel_instance_profile.texture = no_profile_texture
	
func sync_damage_in_server():
	for key in GameClientEnet.core_health_dictionary.keys():
		if GameClientEnet.core_health_dictionary.has(key):
			var data = GameClientEnet.core_health_dictionary[key]
			
			if data != prev_data and data.spawn_code == PlayerGlobalScript.spawn_player_code:
				var updated_hp = data.health
				core_object.core_hp = updated_hp
				prev_data = data
			
			GameClientEnet.core_health_dictionary.erase(key)
			
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
