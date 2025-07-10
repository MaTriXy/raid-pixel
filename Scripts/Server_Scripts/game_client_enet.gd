extends Node

@rpc("any_peer")
func game_send_to_server(rpc_name: String, peerID: int, data: Dictionary):
	rpc(rpc_name, data)

#for recieve game
