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

#for storing player connected
var player_connected_dic: Dictionary

#for find match player
var player_queue_match: Dictionary
var match_player_arr: Array

#for ping
var enet_ping = 0
var enet_ping_time = 0

#for player count
var client_player_count = 0

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
	client_player_count += 1
	if id == multiplayer.get_remote_sender_id():
		enet_connection_status = "Connected"
		
	print("Connected to server with ID: ", id)
	
func _on_peer_disconnected(id: int):
	client_player_count -= 1
	remove_player_scene(id)
	
	if player_connected_dic.has(id):
		var ui_nodes_grp = get_tree().get_nodes_in_group("player_UI")
		
		if ui_nodes_grp.size() > 0:
			var node_grp = ui_nodes_grp[0]
			node_grp.send_clients_notify_connection("Disconnected", player_connected_dic[id].ign, id)
		
		remove_player_guest_acc(player_connected_dic[id].username)
		player_connected_dic.erase(id)
	
	if id == multiplayer.get_remote_sender_id() and not PlayerGlobalScript.isLoggedOut:
		enet_connection_status = "Disconnected"

#check if account is guest so it will be deleted per logout or game exit
func remove_player_guest_acc(username: String):
	var check_guest_acc = await ServerFetch.send_post_request(ServerFetch.backend_url + "accountRoute/check_account", { "username": username })

	if check_guest_acc.has("status") and not check_guest_acc["status"] == "Success":
		return

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
	player_connected_dic[id] = { "username": data.username, "ign": data.ign }
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

#TODO: fix this later on
#for find match only
func string_generator(size: int):
	var letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
	"m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
	var nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	
	var randomNum = RandomNumberGenerator.new()
	var result : String = ""
	
	for i in range(size):
		var char_index = randomNum.randi_range(0, len(letters) - 1)
		var num_index = randomNum.randi_range(0, len(nums) - 1)
		
		var temp_name = "%s%s" % [letters[char_index], nums[num_index]]
		result += temp_name
	
	return result
	
@rpc("any_peer", "reliable")
func find_match(data: Dictionary):
	print("Calling queue now")
	#if multiplayer.is_server():
	print(data)
	queue_match(data)

func queue_match(data: Dictionary):
	var match_max_player = 2
	var already_in_list = false
	
	#check if players are already on temp array
	if not match_player_arr.has(data.peerID):
		match_player_arr.append(data.peerID)
		
	#check if player cancel the queue
	if data.status == "leave":
		match_player_arr.erase(data.peerID)
		
	print(match_player_arr)
	
	#chec if the temp array is full
	if match_player_arr.size() >= match_max_player:
		var game_scene = ["Grassy Land"]
		var match_ID = "match_%s" % string_generator(5)
		
		#add player to the player queue match
		player_queue_match[match_ID] = {
			"match_ID": match_ID,
			"game_scene": game_scene[0],
			"player_list": [] 
		}
	
		#add player data to the player list
		var player_list = player_queue_match[match_ID]["player_list"]
		
		for pid in match_player_arr:
			var arr_data = match_player_arr[pid]
			var player_data = { "ign": arr_data["ign"], "profile": arr_data["profile"], "peerID": pid }
			player_list.append(player_data)
		
		#for player class
		if player_list.size() >= match_max_player:
			for arr_key in range(player_list.size()):
				player_list[arr_key]["class"] = "Defender" if arr_key % 2 == 0 else "Attacker"
			
			for id in player_list:
				pass
				#rpc_id(id, "start_match", match_ID)
	
	#clear the temporary array
	match_player_arr.clear()

@rpc("any_peer", "reliable")
func start_match(match_dic_key: String):
	if player_queue_match.has(match_dic_key):
		print("Removing match now")
		print(player_queue_match)

		player_queue_match.erase(match_dic_key)
		
