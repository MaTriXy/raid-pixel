extends Node

@onready var defender_container = $"Defender Container"
@onready var raider_container = $"Raider Container"
@onready var player_panel_scene = $"Player Panel"
@onready var location_label = $"Versus Label"

var no_profile = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

var player_list = {}
var is_player_load = false
var is_start_loading = false

var prev_value = 0
var prev_data = {}

#for progress bar
var player_progress_instance_dic = {}
var finished_players = {}
var max_players = 0
var player_loading_value = 0.0
var began_to_load = false

#this is for the fallback
var player_map: Array
var match_roomID: String
var game_scene: String

func _ready() -> void:
	$".".visible = false

func _process(delta: float) -> void:
	if is_player_load and not is_start_loading:
		PlayerGlobalScript.isModalOpen = true
		PlayerGlobalScript.current_modal_open = true
		
		location_label.text = "Vs\nLocation: %s" % [game_scene]
		
		"""
		SocketClient.send_data({
			"Socket_Name": "start_match",
			"player_map": player_map,
			"Match_RoomID": match_roomID,
			"game_scene": game_scene
		})
		"""
		
		for key in player_list:
			max_players += 1
			load_player_panel(key, player_list[key].get("ign"), player_list[key].get("class"), player_list[key].get("profile"))
		is_start_loading = true
		
	if began_to_load:	
		if prev_value != player_loading_value:
			"""
			SocketClient.send_data({
				"Socket_Name": "player_progress_interface",
				"Player_ID": PlayerGlobalScript.player_game_id,
				"loading_value": player_loading_value
			})
			"""
			prev_value = player_loading_value
			
		player_loading_progress()
		
		for key in player_progress_instance_dic:
			var progress_bar = player_progress_instance_dic[key].get_node("Player Loading")
			
			if key == PlayerGlobalScript.player_game_id:
				load_game_scene_resource(progress_bar, delta)
				
			if progress_bar.value >= 100.0:
				finished_players[key] = true
				
		if finished_players.size() == max_players:
			"""
			SocketClient.send_data({
				"Socket_Name": "leave_lobby",
				"Player_GameID": PlayerGlobalScript.player_game_id
			})
			"""
			PlayerGlobalScript.isModalOpen = false
			PlayerGlobalScript.current_modal_open = false
			get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")
			
func start_to_load():
	began_to_load = true
	ResourceLoader.load_threaded_request("res://Scenes/game_scene.tscn")
			
func load_game_scene_resource(progress_bar: Control, delta: float):
	var progress = []
	var status = ResourceLoader.load_threaded_get_status("res://Scenes/game_scene.tscn", progress)

	if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
		player_loading_value = progress[0] * 100
		progress_bar.value = move_toward(progress_bar.value, player_loading_value, delta * 20)

	if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		# zip the progress bar to 100% so we don't get weird visuals
		progress_bar.value = move_toward(progress_bar.value, 100.0, delta * 150)

		# "done" loading :)
		if progress_bar.value >= 99:
			is_player_load = false

func player_loading_progress():
	"""
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status
	
	if connection_status == "Connected":
		if data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "player_progress_interface":
			prev_data = data
	
			if data.has("Player_ID") and data.has("loading_value"):
				for key in player_progress_instance_dic:
					if key == data.get("Player_ID") and not key == PlayerGlobalScript.player_game_id:
						player_progress_instance_dic[key].get_node("Player Loading").value = float(data.get("loading_value"))
	"""
	pass
						
func load_player_panel(id: String, ign: String, class_type: String, profile: String):
	var player_panel_instance = player_panel_scene.duplicate()
	player_panel_instance.visible = true
	player_panel_instance.name = "%s_instance" % [id]
	
	var label_text = " (You)" if id == PlayerGlobalScript.player_game_id else ""
	player_panel_instance.get_node("Info Player Name").text = "%s%s" % [ign, label_text]
	
	player_progress_instance_dic[id] = player_panel_instance
	
	if id == PlayerGlobalScript.player_game_id:
		start_to_load()
	
	if not player_panel_instance.is_inside_tree():
		if class_type.to_upper() == "DEFENDER":
			defender_container.add_child(player_panel_instance)
		else:
			raider_container.add_child(player_panel_instance)
	
	var profile_req = await load_player_profile(id, profile)
	
	if profile_req:
		player_panel_instance.get_node("Info Profile").texture = profile_req
	else:
		player_panel_instance.get_node("Info Profile").texture = no_profile

func load_player_profile(id: String, profile_url: String):
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
