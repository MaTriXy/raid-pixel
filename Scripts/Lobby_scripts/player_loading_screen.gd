extends Node

@onready var player_loading_panel = $"Player Loading Panel"
@onready var defender_container = $"Player Loading Panel/Defender Container"
@onready var raider_container = $"Player Loading Panel/Raider Container"
@onready var player_panel_scene = $"Player Loading Panel/Player Panel"
@onready var location_label = $"Player Loading Panel/Versus Label"

var no_profile = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

#for progress bar
var player_progress_instance_dic = {}
var finished_players = {}
var player_loading_value = 0.0
var prev_data: Dictionary
var max_players = 0

func _ready() -> void:
	player_loading_panel.visible = false

func go_to_the_player_loading():
	if ClientEnet.is_matching and not ClientEnet.player_queue_match.is_empty():
		player_loading_panel.visible = true
		
		ClientEnet.is_matching = false
		
		PlayerGlobalScript.isModalOpen = true
		PlayerGlobalScript.current_modal_open = true
		
		var match_data = ClientEnet.player_queue_match
		
		if not match_data.has("player_list"):
			return
			
		var player_list = match_data.player_list
		location_label.text = "Vs\nLocation: %s" % match_data.game_scene
		
		PlayerGlobalScript.game_scene_name = match_data.game_scene
		
		#for player list
		if max_players <= 0:
			for key in player_list.keys():
				var data = player_list[key]
				var player_ign = data.ign
				var player_profile = data.profile
				var player_class = data.class
				
				load_player_panel(key, player_ign, player_class, player_profile)
		
			max_players = player_list.size()

func _process(delta: float) -> void:
	#for all panel that load
	for key in player_progress_instance_dic.keys():
		var instantce = player_progress_instance_dic[key]
		
		if not is_instance_valid(instantce):
			break
			
		var progress_bar = instantce.get_node("Player Loading")
		
		if not progress_bar:
			break
		
		if key == multiplayer.get_unique_id():
			ClientEnet.send_to_server("player_progress_bar", multiplayer.get_unique_id(), { "value": progress_bar.value })
			load_game_scene_resource(progress_bar, delta)
			
			if progress_bar.value >= 100.0:
				finished_players[key] = true
				break
				
	#for player progress
	player_loading_progress()
			
func start_to_load():
	ResourceLoader.load_threaded_request("res://Scenes/game_scene.tscn")
			
func load_game_scene_resource(progress_bar: ProgressBar, delta: float):
	var progress = []
	var status = ResourceLoader.load_threaded_get_status("res://Scenes/game_scene.tscn", progress)

	if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
		player_loading_value = progress[0] * 100
		progress_bar.value = move_toward(progress_bar.value, player_loading_value, delta * 20)

	if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		# zip the progress bar to 100% so we don't get weird visuals
		progress_bar.value = move_toward(progress_bar.value, 100.0, delta * 150)

		# "done" loading :)
		if progress_bar.value >= 99 and finished_players.size() == max_players:
			PlayerGlobalScript.isModalOpen = false
			PlayerGlobalScript.current_modal_open = false
			
			get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")

func player_loading_progress():
	for key in ClientEnet.player_progress_bar_val.keys():
		if ClientEnet.player_progress_bar_val.has(key) and player_progress_instance_dic.has(key):
			var data = ClientEnet.player_progress_bar_val[key]
			var progress_bar = player_progress_instance_dic[key].get_node("Player Loading")
		
			if prev_data != data and progress_bar:
				progress_bar.value = data.value
				
				if data.value >= 100.0:
					finished_players[key] = true
			
		ClientEnet.player_progress_bar_val.erase(key)
						
func load_player_panel(id: int, ign: String, class_type: String, profile: String):
	var player_panel_instance = player_panel_scene.duplicate()
	player_panel_instance.visible = true
	player_panel_instance.name = "%s_instance" % id
	
	var label_text = " (You)" if id == multiplayer.get_unique_id() else ""
	player_panel_instance.get_node("Info Player Name").text = "%s%s" % [ign, label_text]
	
	player_progress_instance_dic[id] = player_panel_instance
	
	if id == multiplayer.get_unique_id():
		PlayerGlobalScript.player_class_game_type = class_type
		start_to_load()
	
	var instance_name = str(player_panel_instance.name)
	
	if not defender_container.has_node(instance_name) and not raider_container.has_node(instance_name):
		if class_type.to_upper() == "DEFENDER":
			defender_container.add_child(player_panel_instance)
		else:
			raider_container.add_child(player_panel_instance)
	
	var profile_req = await load_player_profile(id, profile)
	
	if profile_req:
		player_panel_instance.get_node("Info Profile").texture = profile_req
	else:
		player_panel_instance.get_node("Info Profile").texture = no_profile

func load_player_profile(id: int, profile_url: String):
	var player_http_req = HTTPRequest.new()
	player_http_req.name = "Player_info_%s" % [id]
	
	$".".add_child(player_http_req)
	
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
