class_name Global_Message
extends Node

@onready var global_message_input = $"Global Messages/LineEdit"
@onready var message_label = $"Global Messages/Display Messages/HBoxContainer/Message label"
@onready var message_container = $"Global Messages/Display Messages/HBoxContainer"
@onready var scroll_message_container = $"Global Messages/Display Messages"

#for rendering message that will disappear after sometime
@onready var display_message_panel = $"Display Message Panel/Display Container Box"

#a timer and label to wait for input
@onready var timer_label = $"Global Messages/Wait for input Label"
@onready var timer = $"Global Messages/Timer"

#for game data
var gameData = GameData.new()

var isSend = false
var prev_connection_status = ""

#this is for prev data to avoid receiving a bunch
var prev_data: Dictionary

#this will notify player for connection, a heartbeat
func connection_notify_main_player():
	if prev_connection_status != WebsocketsConnection.socket_connection_status and WebsocketsConnection.socket_connection_status == "Connected":
		prev_connection_status = WebsocketsConnection.socket_connection_status
		append_connection_notify(PlayerGlobalScript.player_game_id, "Player_Connected")
		
		await get_tree().create_timer(0.5).timeout
		SocketClient.send_data(
			{
				"Socket_Name": "Player_Connected",
				"Player_GameID": PlayerGlobalScript.player_game_id,
				"Player_username": PlayerGlobalScript.player_username
			}
		)
		
	else:
		if WebsocketsConnection.socket_connection_status == "Disconnected":
			prev_connection_status = ""
			SocketClient.send_data(
				{
					"Socket_Name": "Player_Disconnected",
					"Player_GameID": PlayerGlobalScript.player_game_id,
					"Player_username": PlayerGlobalScript.player_username
				}
			)

func message_append_on_container():
	if global_message_input.text:		
		SocketClient.send_data({
			"Socket_Name": "GlobalMessage",
			"Sender": PlayerGlobalScript.player_in_game_name,
			"GameID": PlayerGlobalScript.player_game_id,
			"Message": global_message_input.text
		})
		isSend = true
		
func message_render_display():	
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status

	if connection_status == "Connected":
		#sending global messages
		if data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") in ["GlobalMessage", "kill_notify_%s" % PlayerGlobalScript.spawn_player_code]:
			prev_data = data
			
			var receiver = ""
			
			if data.has("Receiver"):
				receiver = data.get("Receiver") + "(You)" if data.get("Receiver") == PlayerGlobalScript.player_in_game_name else data.get("Receiver")
			
			var message_clone = message_label.duplicate()
			message_clone.visible = true
			message_clone.add_theme_color_override("default_color", Color("#ffffff"))
			
			if data.get("Socket_Name") == "kill_notify_%s" % PlayerGlobalScript.spawn_player_code:
				receiver = "System"
				message_clone.add_theme_color_override("default_color", Color("#004a04"))
			
			message_clone.text = receiver + ": " + data.get("Message")
			message_container.add_child(message_clone)
			
			#remove old messages
			if display_message_panel.get_child_count() >= 5:
				var oldest = display_message_panel.get_child(0)
				oldest.queue_free()
			
			#add a new one
			var display_msg = message_clone.duplicate()
			display_message_panel.add_child(display_msg)
		
		#for player connected and disconnected
		elif data.has("Socket_Name") and prev_data != data and (data.get("Socket_Name") == "Player_Connected" or data.get("Socket_Name") == "Player_Disconnect") and data.get("Player_GameID") != PlayerGlobalScript.player_game_id:
			prev_data = data
			append_connection_notify(data.get("Player_GameID"), data.get("Socket_Name"))
				
func append_connection_notify(gameID, status):
	#remove old messages
	if display_message_panel.get_child_count() >= 5:
		var oldest = display_message_panel.get_child(0)
		oldest.queue_free()
	
	#add a new one
	var display_msg = message_label.duplicate()
	display_msg.visible = true
	
	display_msg.text = "%s %s" % [gameID, "connected" if status == "Player_Connected" else "disconnected"]
	display_msg.add_theme_color_override("default_color", Color("#ffff00") if status == "Player_Connected" else Color("#ff0000"))
	display_message_panel.add_child(display_msg)
