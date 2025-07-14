class_name GameData

var prev_data: Dictionary
	
func player_logout(loading_modal: Control):
	if FileAccess.file_exists("user://login_data.json"):
		DirAccess.remove_absolute("user://login_data.json")
		
	PlayerGlobalScript.isLoggedOut = true
	PlayerGlobalScript.isModalOpen = false
	PlayerGlobalScript.isMainPlayerDead = false
	PlayerGlobalScript.current_modal_open = false
	PlayerGlobalScript.isLobby = false
	PlayerGlobalScript.player_in_game_name = ""
	PlayerGlobalScript.player_UUID = ""
	PlayerGlobalScript.player_account_type = ""
	PlayerGlobalScript.player_username = ""
	PlayerGlobalScript.player_diamond = 0
	PlayerGlobalScript.spawn_player_code = ""
	PlayerGlobalScript.player_health = 100
	PlayerGlobalScript.player_max_health = 100
	PlayerGlobalScript.isPlayerAttack = false
	PlayerGlobalScript.player_class_game_type = ""
	
	ClientEnet.is_player_full = false
	ClientEnet.stored_players.clear()
	ClientEnet.is_matching = false
	ClientEnet.match_player_dic.clear()
	ClientEnet.player_queue_match.clear()
	ClientEnet.matchID = ""
	GameClientEnet.game_client_dic_data.clear()
	
	loading_modal.visible = true
	loading_modal.load("res://Scenes/main_menu.tscn")
