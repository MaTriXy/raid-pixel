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

var player_populate_size = 0

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
		player_populate_battle_info()
	
func start_timer():
	pass

func game_end():
	print("Game ended")

func _process(_delta: float) -> void:
	game_scene_socket_data()
	
	if GameBattleInfo.update_render:
		update_score_board()
		GameBattleInfo.update_render = false
	
	if prev_hp != ui_core_hp:
		sprite_core.value = ui_core_hp
		core_hp_label.text = "%s/%s" % [ui_core_hp, ui_core_max_hp]
		
		prev_hp = core.core_hp
		
func update_score_board():
	for key in GameBattleInfo.player_score_info_dic:
		var player = GameBattleInfo.player_score_info_dic[key]
		var container = battle_info_defender_container if player.class == "Defender" else battle_info_attacker_container
	
		GameBattleInfo.render_score_board(container, player.game_id)
		
func player_populate_battle_info():
	if player_populate_size < GameBattleInfo.player_populate_size:
		for key in GameBattleInfo.player_populate_dic:
			var player = GameBattleInfo.player_populate_dic[key]
			
			var player_panel_instance = battle_info_player_panel.duplicate()
			player_panel_instance.name = key
			player_panel_instance.visible = true
						
			var player_panel_instantce_profile = player_panel_instance.get_node("Player Profile")
			var player_panel_instance_ign = player_panel_instance.get_node("Player IGN")
						
			player_panel_instance_ign.text = player.ign
						
			if player.ign == PlayerGlobalScript.player_in_game_name:
				player_panel_instance_ign.text = "%s (You)" % player.ign
						
			if not player_panel_instance.is_inside_tree():
				if player.class == "Defender":
					battle_info_defender_container.add_child(player_panel_instance)
				else:
					battle_info_attacker_container.add_child(player_panel_instance)
				player_populate_size+=1
			
			var player_profile_texture = await load_player_profile_battle_info(player.ign, player.profile)
			
			if player_profile_texture:
				player_panel_instantce_profile.texture = player_profile_texture
			else:
				player_panel_instantce_profile.texture = no_profile_texture		
	else:
		isPlayerScore_populate = true
	
func game_scene_socket_data():
	"""
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
	"""
			
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
