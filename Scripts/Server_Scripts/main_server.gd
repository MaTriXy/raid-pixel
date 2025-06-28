extends Node

var server_port = 9000

func _ready():
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(server_port)
	
	if result != OK:
		print("Server connection failed")
		return
	else:
		print("Connected to the server with port 9000")

	multiplayer.multiplayer_peer = peer
