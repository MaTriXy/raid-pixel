extends Node

var socket = WebsocketsConnection.socket
var socket_data = WebsocketsConnection.socket_data
var ping = 0
var prev_data = {}

var enet_client_node: Node

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
	if WebsocketsConnection.socket_connection_status == "Connected":
		var ping_sent_time = Time.get_ticks_msec()
		var data = {
			"Socket_Name": "ping",
			"timestamp": ping_sent_time
		}
		send_data(data)
	
func output_ping():
	var data = received_data()
	
	if WebsocketsConnection.socket_connection_status == "Connected":
		if data.has("Socket_Name") and prev_data != data and data.get("Socket_Name") == "ping":
			prev_data = data
			var sent_time = data.get("timestamp", 0)
			var current_time = Time.get_ticks_msec()
			ping = current_time - sent_time
		
	else:
		ping = 1000
