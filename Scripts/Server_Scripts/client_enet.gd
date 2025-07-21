extends Node

var host = "localhost"
var server_port = 9000
var isConnected = false

#dictionaries for player datas
var rpc_player_connection_status: Dictionary
var rpc_player_spawn_dic: Dictionary
var rpc_player_attack_dic: Dictionary
var rpc_player_msg_dic: Dictionary
var rpc_player_active_dic: Dictionary

#for find match player
var player_queue_match: Dictionary
var match_player_dic: Dictionary
var player_progress_bar_val: Dictionary
var is_matching = false
var player_match_count = 0

#collection for player spawn
var stored_players: Dictionary

#for connection
var enet_connection_status: String

#for storing player connected
var player_connected_dic: Dictionary

#for ping
var enet_ping = 0
var enet_ping_time = 0

#for player count
var client_player_count = 0

func join_server(ip: String, port: int):
	var peer = ENetMultiplayerPeer.new()
	
	if not isConnected:
		var result = peer.create_client(ip, port)
		
		if result != OK:
			print("server is not connected")
			return
			
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		isConnected = true
	
func _on_peer_connected(id: int):
	client_player_count += 1
	if id == multiplayer.get_remote_sender_id():
		enet_connection_status = "Connected"
		
	print("Connected to server with ID: ", id)
	
func _on_peer_disconnected(id: int):
	client_player_count -= 1
	remove_player_scene(id)
	
	if match_player_dic.has(id):
		match_player_dic.erase(id)
	
	if player_connected_dic.has(id):
		var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
		
		if ui_nodes_grp.size() > 0:
			var node_grp = ui_nodes_grp[0]
			
			if player_connected_dic[id].spawn_code == PlayerGlobalScript.spawn_player_code:
				node_grp.append_status_notify(player_connected_dic[id].ign, id, "disconnected", Color("#ff0000"))
		
		player_connected_dic.erase(id)
	
	if id == multiplayer.get_unique_id() and not PlayerGlobalScript.isLoggedOut:
		enet_connection_status = "Disconnected"

func remove_player_scene(id: int):
	if not stored_players.has(id):
		return
	
	var joined_player_data = stored_players[id]
	var player_instance = joined_player_data["Player"]
	
	if is_instance_valid(player_instance):
		player_instance.queue_free()
	
	stored_players.erase(id)

#getting and updating player count
@rpc("any_peer")
func update_player_count():
	rpc("player_count", client_player_count)
	
@rpc("any_peer", "reliable")
func player_count(count: int):
	client_player_count = count
	
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
func player_connected(id: int, data: Dictionary):
	player_connected_dic[id] = { "ign": data.ign, "spawn_code": data.spawn_code }
	rpc("player_count", client_player_count)
	
@rpc("any_peer", "reliable")
#TODO: fixthis, not updating on active player
func modify_profile(peerID: int, data: Dictionary):		
	var joined_player_data = stored_players[peerID]
	var joined_player = joined_player_data["Player"]
	
	joined_player.name = str(peerID)
	joined_player.playerIGN = joined_player_data.ign
	
	stored_players[peerID].ign = joined_player_data.ign
	player_connected_dic[peerID].ign = joined_player_data.ign
	rpc_player_active_dic[peerID].ign = joined_player_data.ign

@rpc("any_peer", "reliable")
func player_left(peerID: int, _data: Dictionary):
	if player_connected_dic.has(peerID):
		var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
		
		if ui_nodes_grp.size() > 0:
			var node_grp = ui_nodes_grp[0]
			
			if player_connected_dic[peerID].has("spawn_code") and player_connected_dic[peerID]["spawn_code"] == PlayerGlobalScript.spawn_player_code:
				node_grp.append_status_notify(player_connected_dic.ign, peerID, "disconnected", Color("#ff0000"))
		
		player_connected_dic.erase(peerID)
		
	remove_player_scene(peerID)
	
#for find match only
@rpc("any_peer", "reliable")
func find_match(peerID: int, data: Dictionary):
	queue_match(peerID, data)
	
@rpc("any_peer", "reliable")
func player_progress_bar(peerID: int, data: Dictionary):
	player_progress_bar_val[peerID] = data

func queue_match(peerID: int, data: Dictionary):
	var matchID: String
	var match_max_player = 2
	
	if not match_player_dic.has(peerID):
		player_match_count += 1
		var player_class = "Defender" if player_match_count % 2 == 0 else "Attacker"
		match_player_dic[peerID] = { "ign": data.ign, "profile": data.profile, "peerID": peerID, "class": player_class }
		
	if data.status == "leave":
		player_match_count -= 1
		
		if player_match_count <= 0:
			player_match_count = 0
			
		match_player_dic.erase(peerID)
	
	#check if the temp array is full
	if match_player_dic.size() >= match_max_player:
		var player_in_match = match_player_dic.duplicate()
		match_player_dic.clear()
		
		for id in player_in_match.keys():
			if id != multiplayer.get_unique_id():
				remove_player_scene(id)
				
				#add player to the player queue match
				if not matchID:
					matchID = "match_%s" % match_ID_generator(5)
				
				var match_data = { "match_ID": matchID, "player_list": player_in_match }
				rpc_id(id, "start_match", id, match_data)

func match_ID_generator(string_length: int):
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var random_string = ""
	
	for i in range(string_length):
		var random_index = randi() % chars.length()
		random_string += chars[random_index]
		
	return random_string

@rpc("any_peer", "reliable")
func start_match(_peerID: int, data: Dictionary):
	player_queue_match.clear()
	match_player_dic.clear()
	
	if is_matching:
		var game_scene = ["Grassy Land"]

		player_queue_match = {
			"match_ID": data.match_ID,
			"game_scene": game_scene[0],
			"player_list": data.player_list
		}
		
		var lobby_scene = get_tree().get_root().get_node("Lobby Scene")
		if lobby_scene:
			var ui_node = lobby_scene.get_node("UI")
			if ui_node:
				ui_node.go_to_the_player_loading()
