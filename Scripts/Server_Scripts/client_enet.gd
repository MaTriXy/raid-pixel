extends Node

var host = "localhost"
var server_port = 9000

#dictionaries for player datas
var rpc_player_connection_status: Dictionary
var rpc_player_spawn_dic: Dictionary
var rpc_player_attack_dic: Dictionary
var rpc_player_msg_dic: Dictionary
var rpc_player_active_dic: Dictionary
var rpc_player_modify_profile: Dictionary

#collection for player spawn
var stored_players: Dictionary

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
	
func _on_peer_disconnected(id: int):
	for key in stored_players.keys():
		if stored_players.has(key):
			var joined_player_data = stored_players[key]
			var joined_player = joined_player_data["Player"]
			
			if is_instance_valid(joined_player):
				joined_player.queue_free()
				stored_players.erase(key)
				
				var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
		
				if ui_nodes_grp.size() > 0:
					var message_append = ui_nodes_grp[0]
					message_append.send_clients_notify_connection("Disconnected", joined_player_data["ign"], joined_player_data["gameID"])
					
				var check_guest_acc = await ServerFetch.send_post_request(ServerFetch.backend_url + "accountGuestCheck/check_account", { "username": joined_player_data["username"] })
	
				if check_guest_acc.has("status") and not check_guest_acc["status"] == "Success":
					return
	
	var player_count_res = await ServerFetch.send_post_request(ServerFetch.backend_url + "gameData/modifyPlayerCount", { "count": -1 })
	
	if player_count_res.has("status") and not player_count_res["status"] == "Success":
		return
		
func _on_connection_failed():
	print("Failed to connect to server")

#sending data
@rpc("any_peer")
func send_to_server(rpc_name: String, gameID: String, data: Dictionary):
	rpc(rpc_name, gameID, data)
	
#recieving data
@rpc("any_peer", "reliable")
func connection_notify(gameID, data):
	rpc_player_connection_status[gameID] = data
	
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
func modify_profile(gameID, data):
	rpc_player_modify_profile[gameID] = data
