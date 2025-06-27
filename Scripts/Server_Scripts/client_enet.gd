extends Node

var host_url = "localhost"
var port = 9000

func _ready():
	print("starting client e net server")
	
	await get_tree().process_frame
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(host_url, port)
	
	if result != OK:
		print("Client server failed")
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected():
	print("Connected to server!")

func _on_connection_failed():
	print("Connection failed.")

func _on_server_disconnected():
	print("Disconnected from server.")
	
#for sending player movement
@rpc("any_peer")
func send_client_data(data: Dictionary):
	if multiplayer.get_multiplayer_peer() and multiplayer.get_multiplayer_peer().get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print("Connected to the server enet client")
		#rpc("server_player_data", data)
	else:
		print("❌ Not connected to the server.")
