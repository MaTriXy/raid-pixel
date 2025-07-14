extends Node

#for game scene
var game_client_dic_data: Dictionary
var game_tilemap_name: String

@rpc("any_peer")
func game_send_to_server(rpc_name: String, peerID: int, data: Dictionary):
	rpc(rpc_name, peerID, data)

#for recieve game
