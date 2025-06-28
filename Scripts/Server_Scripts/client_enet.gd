extends Node

var host = "localhost"
var server_port = 9000

#dictionaries for player datas
var rpc_player_disconnect: Dictionary
var rpc_player_spawn_dic: Dictionary
var rpc_player_attack_dic: Dictionary
var rpc_player_msg_dic: Dictionary
var rpc_player_active_dic: Dictionary
var rpc_player_modify_profile: Dictionary

func _ready():
	join_server(host, server_port)

func join_server(ip: String, port: int):
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, port)
	
	if result != OK:
		print("server is not connected")
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
func _on_peer_connected(id: int):
	print("Connected to server with ID: ", id)
	
func _on_peer_disconnected(_id: int):
	print("Disconnected")
	send_to_server("player_disconnect", PlayerGlobalScript.player_game_id, { "gameID": PlayerGlobalScript.player_game_id })

func _on_connection_failed():
	print("Failed to connect to server")

@rpc("any_peer")
func send_to_server(rpc_name: String, gameID: String, data: Dictionary):
	rpc(rpc_name, gameID, data)
	
#recieving data
@rpc("any_peer", "reliable")
func player_spawn_movement(gameID, data):
	rpc_player_spawn_dic[gameID] = data
	
@rpc("any_peer", "reliable")
func player_attack(gameID, data):
	rpc_player_attack_dic[gameID] = data
	
@rpc("any_peer", "reliable")
func global_message(gameID, data):
	rpc_player_msg_dic[gameID] = data
	
@rpc("any_peer", "reliable")
func list_active_player(gameID, data):
	rpc_player_active_dic[gameID] = data
	
@rpc("any_peer", "reliable")
func player_disconnect(gameID, data):
	rpc_player_disconnect[gameID] = data
	
@rpc("any_peer", "reliable")
func modify_profile(gameID, data):
	rpc_player_modify_profile[gameID] = data
