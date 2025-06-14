extends Node

@onready var defender_container = $"Defender Container"
@onready var raider_container = $"Raider Container"
@onready var player_panel_scene = $"Player Panel"

var no_profile = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

@export var loading_modal: Control

var player_list = {}
var is_player_load = false
var is_loading = false

func _ready() -> void:
	$".".visible = false

func _process(_delta: float) -> void:
	if is_player_load and not is_loading:
		for key in player_list:
			await load_player_panel(key, player_list[key])
			
		is_loading = true

"""
						SocketClient.send_data({
							"Socket_Name": "leave_lobby",
							"Player_GameID": playerID
						})
						PlayerGlobalScript.isModalOpen = true
						PlayerGlobalScript.current_modal_open = true
						
						loading_modal.load("res://Scenes/game_scene.tscn")
						"""
						
func load_player_panel(username: String, class_type):
	var player_panel_instance = player_panel_scene.duplicate()
	player_panel_instance.visible = true
	player_panel_instance.name = "%s_instance" % [username]
	
	var player_data = await get_player_data(username)
	
	if player_data["status"] == "Success":
		player_panel_instance.get_node("Info Player Name").text = player_data["player_IGN"]
		
		var profile = await load_player_profile(username, player_data["player_profile"])
		
		if profile:
			player_panel_instance.get_node("Info Profile").texture = profile
		else:
			player_panel_instance.get_node("Info Profile").texture = no_profile
	

	if class_type.to_upper() == "DEFENDER":
		defender_container.add_child(player_panel_instance)
	else:
		raider_container.add_child(player_panel_instance)	

func load_player_profile(username: String, profile_url: String):
	var player_http_req = HTTPRequest.new()
	player_http_req.name = "Player_info_%s" % [username]
	
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
		

func get_player_data(username: String):
	var result = await ServerFetch.send_post_request(ServerFetch.backend_url + "playerInformation/playerData", { "username": username })
	
	if result.has("status") and result["status"] == "Success":
		return {
			"status": result["status"],
			"player_IGN": result["inGameName"],
			"player_profile": result["profile"]
		}
	else:
		return {
			"status": "Failed"
		}
