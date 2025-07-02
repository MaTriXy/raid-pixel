extends Node

var host = "localhost"
var server_port = 9000

#dictionaries for player datas
var rpc_player_connection_status: Dictionary
var rpc_player_spawn_dic: Dictionary
var rpc_player_attack_dic: Dictionary
var rpc_player_msg_dic: Dictionary
var rpc_player_active_dic: Dictionary

#collection for player spawn
var stored_players: Dictionary

#for connection
var enet_connection_status: String

#for ping
var enet_ping = 0
var enet_ping_time = 0

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
	if id == multiplayer.get_unique_id():
		enet_connection_status = "Connected"
	
	if not PlayerGlobalScript.player_game_id:
		PlayerGlobalScript.player_game_id = "GameID_%s" % [PlayerInfoStuff.string_generator(2)]
		
	print("Connected to server with ID: ", id)
	
func _on_peer_disconnected(id: int):
	if id == multiplayer.get_unique_id():
		enet_connection_status = "Disconnected"
	remove_player_scene(id)

func remove_player_scene(id: int):
	if not stored_players.has(id):
		return
		
	var joined_player_data = stored_players[id]
	var player_instance = joined_player_data["Player"]
	
	if is_instance_valid(player_instance):
		player_instance.queue_free()
		
	#check if account is guest so it will be deleted per logout or game exit
	var check_guest_acc = await ServerFetch.send_post_request(ServerFetch.backend_url + "accountRoute/check_account", { "username": joined_player_data["username"] })

	if check_guest_acc.has("status") and not check_guest_acc["status"] == "Success":
		return
	
	send_to_server("player_count", multiplayer.get_unique_id(), { "count": -1 })
	
	var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
	if ui_nodes_grp.size() > 0:
		var node_grp = ui_nodes_grp[0]
		node_grp.send_clients_notify_connection("Disconnected", joined_player_data["ign"], joined_player_data["gameID"])
		
	stored_players.erase(id)
		
func _on_connection_failed(id: int):
	if id == multiplayer.get_unique_id():
		enet_connection_status = "Disconnected"
	print("Failed to connect to server")

#sending data
@rpc("any_peer")
func send_to_server(rpc_name: String, peerID: int, data: Dictionary):
	rpc(rpc_name, peerID, data)
	
@rpc("any_peer")
func send_ping():
	enet_ping_time = Time.get_ticks_msec()
	print(enet_ping_time)
	rpc("server_ping", enet_ping_time)
	
#recieving ping pong
@rpc("any_peer", "reliable")
func server_ping(ping_time: int):
	var peer_id = multiplayer.get_remote_sender_id()
	rpc_id(peer_id, "output_pong", ping_time)
	
@rpc("any_peer", "reliable")
func output_pong(ping_time: int):
	var current_time = Time.get_ticks_msec()
	enet_ping = current_time - ping_time
	
#recieved data
@rpc("any_peer", "reliable")
func connection_notify(peerID: int, data: Dictionary):
	rpc_player_connection_status[peerID] = data
	
@rpc("any_peer", "reliable")
func player_count(peerID: int, data: Dictionary):
	var player_count_res = await ServerFetch.send_post_request(ServerFetch.backend_url + "gameData/modifyPlayerCount", { "count": data.count })
	var count = 0
	
	if player_count_res.has("status") and player_count_res["status"] == "Success":
		print(player_count_res["count"])
		count = int(player_count_res["count"])
		
	PlayerGlobalScript.player_count_active = count
	
@rpc("any_peer", "reliable")
func player_spawn_movement(peerID: int, data: Dictionary):
	rpc_player_spawn_dic[peerID] = data
	
@rpc("any_peer", "reliable")
func player_attack(peerID: int, data: Dictionary):
	rpc_player_attack_dic[peerID] = data
	
@rpc("any_peer", "reliable")
func global_message(peerID: int, data: Dictionary):
	rpc_player_msg_dic[peerID] = data
	
@rpc("any_peer", "reliable")
func list_active_player(peerID: int, data: Dictionary):
	rpc_player_active_dic[peerID] = data
	
@rpc("any_peer", "reliable")
func modify_profile(peerID: int, data: Dictionary):		
	var joined_player_data = stored_players[peerID]
	var joined_player = joined_player_data["Player"]
	
	joined_player.name = joined_player_data.gameID
	joined_player.playerIGN = joined_player_data.ign
	
	rpc_player_active_dic[peerID].ign = joined_player_data.ign
	
@rpc("any_peer", "reliable")
func player_left(peerID: int, _data: Dictionary):
	remove_player_scene(peerID)
