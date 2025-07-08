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
	PlayerGlobalScript.current_scene = ""
	PlayerGlobalScript.spawn_player_code = ""
	PlayerGlobalScript.player_health = 100
	PlayerGlobalScript.player_max_health = 100
	PlayerGlobalScript.isPlayerAttack = false
	PlayerGlobalScript.match_roomID = ""
	PlayerGlobalScript.player_class_game_type = ""
	PlayerGlobalScript.game_scene_name = ""
	PlayerGlobalScript.is_game_scene_loaded = false
	
	ClientEnet.isMatching = false
	ClientEnet.is_player_full = false
	ClientEnet.stored_players.clear()
	
	loading_modal.visible = true
	loading_modal.load("res://Scenes/main_menu.tscn")
