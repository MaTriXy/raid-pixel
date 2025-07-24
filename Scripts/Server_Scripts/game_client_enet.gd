extends Node

#for game scene
var game_client_dic_data: Dictionary
var game_tilemap_name: String

#game receive dictionary
var core_health_dictionary: Dictionary
var player_health_dictionary: Dictionary
var player_score_board_dictionary: Dictionary

@rpc("any_peer")
func game_send_to_server(rpc_name: String, peerID: int, data: Dictionary):
	rpc(rpc_name, peerID, data)

#for recieve game
@rpc("any_peer", "reliable")
func core_health_update(peerID: int, data: Dictionary):
	core_health_dictionary[peerID] = data
	
@rpc("any_peer", "reliable")
func update_player_hp(peerID: int, data: Dictionary):
	player_health_dictionary[peerID] = data
	
@rpc("any_peer", "reliable")
func update_player_score_board(peerID: int, data: Dictionary):
	player_score_board_dictionary[peerID] = data
