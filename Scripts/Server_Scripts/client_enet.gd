extends Node

var host = "localhost"
var server_port = 9000

#dictionaries for player datas
var rpc_player_data_dic: Dictionary

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
	
func _on_peer_connected(id: int):
	print("Connected to server with ID: ", id)

func _on_connection_failed():
	print("Failed to connect to server")

@rpc("any_peer")
func send_to_server(rpc_name: String, spawn_code: String, player_pos: Vector2, isMoving: bool, last_direction_value: Vector2, direction_value: Vector2, ign: String, gameID: String):
	rpc(rpc_name, spawn_code, player_pos, isMoving, last_direction_value, direction_value, ign, gameID)
	

@rpc("any_peer", "reliable")
func player_spawn_movement(spawn_code: String, player_pos: Vector2, isMoving: bool, last_direction_value: Vector2, direction_value: Vector2, ign: String, gameID: String):
	rpc_player_data_dic[gameID] = {
		"spawn_code": spawn_code,
		"player_pos": player_pos,
		"isMoving": isMoving,
		"last_direction_value": last_direction_value,
		"direction_value": direction_value,
		"ign": ign,
		"gameID": gameID
	}
