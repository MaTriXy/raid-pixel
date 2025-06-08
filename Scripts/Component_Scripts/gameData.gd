class_name GameData
extends Node

var prev_data: Dictionary
	
func player_logout(validation_modal: Control, loading_modal: Control, gameID: String, username: String):
	if FileAccess.file_exists("user://login_data.json"):
		DirAccess.remove_absolute("user://login_data.json")
		
	PlayerGlobalScript.isLoggedOut = true
	validation_modal.visible = true
	
	SocketClient.send_data({
		"Socket_Name": "Player_Logout",
		"GameID": gameID,
		"Player_username": username
	})

	WebsocketsConnection.socket_connection_status = ""
	WebsocketsConnection.socket_data = {}
	
	# Disconnect WebSocket
	WebsocketsConnection.disconnect_to_socket()

	PlayerGlobalScript.isModalOpen = false
	PlayerGlobalScript.isMainPlayerDead = false
	PlayerGlobalScript.current_modal_open = false
	PlayerGlobalScript.isLobby = false
	PlayerGlobalScript.player_in_game_name = ""
	PlayerGlobalScript.player_game_id = ""
	PlayerGlobalScript.player_UUID = ""
	PlayerGlobalScript.player_account_type = ""
	PlayerGlobalScript.player_username = ""
	PlayerGlobalScript.player_diamond = 0
	PlayerGlobalScript.current_scene = ""
	PlayerGlobalScript.spawn_player_code = ""
	PlayerGlobalScript.player_health = 100
	PlayerGlobalScript.player_max_health = 100
	PlayerGlobalScript.isPlayerAttack = false
	PlayerGlobalScript.match_roomID = ""
	PlayerGlobalScript.player_class_game_type = ""
	PlayerGlobalScript.isLobby = false
	
	loading_modal.visible = true
	loading_modal.load("res://Scenes/main_menu.tscn")
	
func get_player_count():
	if WebsocketsConnection.socket_connection_status == "Connected":
		var result = await ServerFetch.get_request(ServerFetch.backend_url + "gameData/getPlayerCount")

		if result.has("status") and result["status"] == "Success":
			return int(result["count"])
		else:
			return 0
	else:
		return 0
