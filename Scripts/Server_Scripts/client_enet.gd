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
	if id == multiplayer.get_remote_sender_id():
		enet_connection_status = "Connected"
		
	print("Connected to server with ID: ", id)
	
func _on_peer_disconnected(id: int):
	remove_player_scene(id)
	
	if id == multiplayer.get_remote_sender_id() and not PlayerGlobalScript.isLoggedOut:
		print("is disconnect through game exit")
		print("Removing player now with ID: %s " % id)
		update_player_count(-1)
	
		enet_connection_status = "Disconnected"
		
		remove_player_guest_acc()

#check if account is guest so it will be deleted per logout or game exit
func remove_player_guest_acc():
	var check_guest_acc = await ServerFetch.send_post_request(ServerFetch.backend_url + "accountRoute/check_account", { "username": PlayerGlobalScript.player_username })

	if check_guest_acc.has("status") and not check_guest_acc["status"] == "Success":
		return

func remove_player_scene(id: int):
	if not stored_players.has(id):
		return
	
	var joined_player_data = stored_players[id]
	var player_instance = joined_player_data["Player"]
	
	if is_instance_valid(player_instance):
		player_instance.queue_free()
	
	var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
	if ui_nodes_grp.size() > 0:
		var node_grp = ui_nodes_grp[0]
		node_grp.send_clients_notify_connection("Disconnected", joined_player_data["ign"], joined_player_data["peerID"])
		
	stored_players.erase(id)
		
func _on_connection_failed(id: int):
	if id == multiplayer.get_remote_sender_id():
		enet_connection_status = "Disconnected"
	print("Failed to connect to server")

#sending data
@rpc("any_peer")
func send_to_server(rpc_name: String, peerID: int, data: Dictionary):
	rpc(rpc_name, peerID, data)
	
@rpc("any_peer")
func send_ping():
	enet_ping_time = Time.get_ticks_msec()
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
	
#getting and updating player count
@rpc("any_peer")
func update_player_count(count: int):
	var player_count_res = await ServerFetch.send_post_request(ServerFetch.backend_url + "gameData/modifyPlayerCount", { "count": count })

	if player_count_res.has("status") and player_count_res["status"] == "Success":
		PlayerGlobalScript.player_count_active = int(player_count_res["count"])
		
	if count < 0:
		send_player_count_to_clients()
		
@rpc("any_peer")
func send_player_count_to_clients():
	rpc("player_count", PlayerGlobalScript.player_count_active)

@rpc("any_peer", "reliable")
func player_count(count: int):
	PlayerGlobalScript.player_count_active = count
	
#recieved data
@rpc("any_peer", "reliable")
func connection_notify(peerID: int, data: Dictionary):
	rpc_player_connection_status[peerID] = data
	
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
#TODO: fixthis, not updating on active player
func modify_profile(peerID: int, data: Dictionary):		
	var joined_player_data = stored_players[peerID]
	var joined_player = joined_player_data["Player"]
	
	joined_player.name = str(peerID)
	joined_player.playerIGN = joined_player_data.ign
	
	stored_players[peerID].ign = joined_player_data.ign
	rpc_player_active_dic[peerID].ign = joined_player_data.ign
	
@rpc("any_peer", "reliable")
func player_left(peerID: int, _data: Dictionary):
	remove_player_scene(peerID)
	
	if peerID == multiplayer.get_remote_sender_id():
		print("is disconnect through logout")
		print("Removing player now with ID: %s " % peerID)
		update_player_count(-1)
		remove_player_guest_acc()
