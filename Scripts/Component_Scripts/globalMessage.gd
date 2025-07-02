class_name Global_Message
extends Node

@onready var global_message_input = $"Global Messages/LineEdit"
@onready var message_label = $"Global Messages/Display Messages/HBoxContainer/Message label"
@onready var message_container = $"Global Messages/Display Messages/HBoxContainer"
@onready var scroll_message_container = $"Global Messages/Display Messages"

#for rendering message that will disappear after sometime
@onready var display_message_panel = $"Display Message Panel/Display Container Box"

#for game data
var gameData = GameData.new()

var prev_connection_status = ""

#this is for prev data to avoid receiving a bunch
var prev_data: Dictionary
var prev_msg: Dictionary

func send_clients_notify_connection(status: String, ign: String, peerID: int):
	var info = {
		"spawn_code": PlayerGlobalScript.spawn_player_code,
		"ign": ign,
		"status": status
	}
	ClientEnet.send_to_server("connection_notify", multiplayer.get_unique_id(), info)
	append_connection_notify(info.ign, peerID, info.status)
	
func connection_notify_main_player():
	for peerID in ClientEnet.rpc_player_connection_status.keys():
		var dic = ClientEnet.rpc_player_connection_status[peerID]
		var spawn_code = dic.spawn_code
		var ign = dic.ign
		var status = dic.status
		
		if PlayerGlobalScript.spawn_player_code == spawn_code and dic != prev_data:
			append_connection_notify(ign, peerID, status)
			prev_data = dic
			
		ClientEnet.rpc_player_connection_status.erase(peerID)

func message_append_on_container():
	if global_message_input.text:
		await get_tree().process_frame
		var message_data = {
			"spawn_code": PlayerGlobalScript.spawn_player_code,
			"sender": PlayerGlobalScript.player_in_game_name,
			"message": global_message_input.text
		}
		ClientEnet.send_to_server("global_message", multiplayer.get_unique_id(), message_data)
	
		var receiver = PlayerGlobalScript.player_in_game_name + "(You)"
		append_msg_on_msg_container(receiver, multiplayer.get_unique_id(), global_message_input.text, Color("#ffffff"))
	global_message_input.text = ""
	
func message_render_display():
	#sending scene messages
	for key in ClientEnet.rpc_player_msg_dic.keys():
		var msg_data = ClientEnet.rpc_player_msg_dic[key]

		if msg_data != prev_msg and msg_data.spawn_code == PlayerGlobalScript.spawn_player_code:
			append_msg_on_msg_container(msg_data.sender, key, msg_data.message, Color("#ffffff"))
			prev_msg = msg_data
		ClientEnet.rpc_player_msg_dic.erase(key)
			
func append_msg_on_msg_container(receiver: String, peerID: int, msg: String, color: Color):
	var message_clone = message_label.duplicate()
	message_clone.visible = true
	message_clone.add_theme_color_override("default_color", color)
	message_clone.text = "%s (%s): %s" % [receiver, peerID, msg]
	message_container.add_child(message_clone)
	
	#remove old messages
	if display_message_panel.get_child_count() >= 5:
		var oldest = display_message_panel.get_child(0)
		oldest.queue_free()
	
	#add a new one
	var display_msg = message_clone.duplicate()
	display_message_panel.add_child(display_msg)
				
func append_connection_notify(ign, peerID, status):
	#remove old messages
	if display_message_panel.get_child_count() >= 5:
		var oldest = display_message_panel.get_child(0)
		oldest.queue_free()
	
	#add a new one
	var display_msg = message_label.duplicate()
	display_msg.visible = true
	
	var notify =  "connected" if status == "Connected" else "disconnected"
	
	display_msg.text = "%s (%s) %s" % [ign, peerID, notify]
	display_msg.add_theme_color_override("default_color", Color("#ffff00") if status == "Connected" else Color("#ff0000"))
	display_message_panel.add_child(display_msg)
