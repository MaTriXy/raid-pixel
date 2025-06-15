extends Node

@onready var defender_container = $"Defender Container"
@onready var raider_container = $"Raider Container"
@onready var player_panel_scene = $"Player Panel"

var no_profile = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

@export var loading_modal: Control
var player_loading_value = 0.0
var player_panel_reference: Control

var player_list = {}
var is_player_load = false
var is_start_loading = false

var player_progress_instance_dic = {}

var prev_value = 0
var prev_data = {}

#this is for the fallback
var player_map: Array
var match_roomID: String
var game_scene: String

func _ready() -> void:
	$".".visible = false

func _process(_delta: float) -> void:
	if is_player_load and not is_start_loading:
		SocketClient.send_data({
			"Socket_Name": "start_match",
			"player_map": player_map,
			"Match_RoomID": match_roomID,
			"game_scene": game_scene
		})
		print("Fall back send on other player")
		for key in player_list:
			load_player_panel(key, player_list[key].get("class"), player_list[key].get("profile"))
		is_start_loading = true
		
	if player_panel_reference:
		player_loading_value += _delta
		
		if player_loading_value >= 100:
			is_player_load = false
		
		if prev_value != player_loading_value:
			SocketClient.send_data({
				"Socket_Name": "player_progress_interface",
				"Player_IGN": PlayerGlobalScript.player_in_game_name,
				"loading_value": player_loading_value
			})
			prev_value = player_loading_value
			
		player_panel_reference.get_node("Player Loading").value = player_loading_value
		player_loading_progress()

"""
						SocketClient.send_data({
							"Socket_Name": "leave_lobby",
							"Player_GameID": playerID
						})
						PlayerGlobalScript.isModalOpen = true
						PlayerGlobalScript.current_modal_open = true
						
						loading_modal.load("res://Scenes/game_scene.tscn")
						"""
func player_loading_progress():
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status
	
	if connection_status == "Connected":
		if data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "player_progress_interface":
			prev_data = data
	
			if data.has("Player_IGN") and data.has("loading_value"):
				for key in player_progress_instance_dic:
					if key == data.get("Player_IGN") and not key == PlayerGlobalScript.player_in_game_name:
						player_progress_instance_dic[key].value = data.get("loading_value")
						
func load_player_panel(ign: String, class_type: String, profile: String):
	var player_panel_instance = player_panel_scene.duplicate()
	player_panel_instance.visible = true
	player_panel_instance.name = "%s_instance" % [ign]
	player_panel_instance.get_node("Info Player Name").text = ign
	
	player_progress_instance_dic[ign] = player_panel_instance
	
	if ign == PlayerGlobalScript.player_in_game_name:
		player_panel_reference = player_panel_instance
	
	if not player_panel_instance.is_inside_tree():
		if class_type.to_upper() == "DEFENDER":
			defender_container.add_child(player_panel_instance)
		else:
			raider_container.add_child(player_panel_instance)
	
	var profile_req = await load_player_profile(ign, profile)
	
	if profile_req:
		player_panel_instance.get_node("Info Profile").texture = profile_req
	else:
		player_panel_instance.get_node("Info Profile").texture = no_profile

func load_player_profile(ign: String, profile_url: String):
	var player_http_req = HTTPRequest.new()
	player_http_req.name = "Player_info_%s" % [ign]
	
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
