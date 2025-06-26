extends Node

var player_populate_dic = {}
var player_populate_size = 0
var player_score_info_dic = {}
var update_render = false

#TODO: do something on this one bruh
func update_score_board(player_ID: String, player_class: String):
	update_render = true
	player_score_info_dic[player_ID] = {
		"game_id": player_ID,
		"class": player_class,
	}

func render_score_board(container: VBoxContainer, player_ID: String):
	for child in container.get_children():
		if child.name == player_ID:
			if player_ID == PlayerGlobalScript.player_game_id:
				player_populate_dic[player_ID]["deaths"]+=1
			else:
				player_populate_dic[player_ID]["kills"]+=1
			
			await get_tree().process_frame
			child.get_node("Player status").text = "Kill/s: %s		Death/s: %s" % [player_populate_dic[player_ID]["kills"], player_populate_dic[player_ID]["deaths"]]
