extends Node

func _ready():
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(9000)
	
	if result != OK:
		print("Server connection failed")
		return
	else:
		print("Connected to the server with port 9000")

	multiplayer.multiplayer_peer = peer

@rpc("any_peer")
func server_player_data(data: Dictionary):
	print(data)
