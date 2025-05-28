extends Node

var socket = WebsocketsConnection.socket
var socket_data = WebsocketsConnection.socket_data
var ping = 0
var prev_data = {}
var gameID = ""

func _ready() -> void:
	var timer = Timer.new()
	timer.name = "Socket_Timer"
	
	timer.wait_time = 0.1
	timer.timeout.connect(send_connection)
	timer.autostart = true
	timer.one_shot = false
		
	add_child(timer)
		
func send_connection():
	if PlayerGlobalScript.player_game_id and not PlayerGlobalScript.player_game_id ==  gameID:
		send_data(
			{
				"Socket_Name": "Player_Connected" if WebsocketsConnection.socket_connection_status == "Connected" else "Player_Disconnected",
				"Player_GameID": PlayerGlobalScript.player_game_id,
				"Player_username": PlayerGlobalScript.player_username,
			}
		)
		
		gameID = PlayerGlobalScript.player_game_id

func send_data(data):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		socket.send_text(json_string)
		
func received_data():
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var raw = socket.get_packet().get_string_from_utf8()
			socket_data = JSON.parse_string(raw)

		return socket_data

func send_ping():
	var ping_sent_time = Time.get_ticks_msec()
	var data = {
		"Socket_Name": "ping",
		"timestamp": ping_sent_time
	}
	send_data(data)

func isConnected():
	return WebsocketsConnection.socket_connection_status == "Connected"
	
func output_ping():
	var data = received_data()
	
	if isConnected():
		if data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "ping":
			prev_data = data
			var sent_time = data.get("timestamp", 0)
			var current_time = Time.get_ticks_msec()
			ping = current_time - sent_time
		
	else:
		ping = 1000
