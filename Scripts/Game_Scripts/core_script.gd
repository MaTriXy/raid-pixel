extends Node

var core_hp = 1000
var core_max_hp = 1000
var isInsideCore = false
var prev_hp = 0

func _process(_delta: float) -> void:
	damage_core()
		
func damage_core():
	if PlayerGlobalScript.isPlayerAttack and isInsideCore:
		core_hp -= 10
		
		if core_hp <= 0:
			core_hp = 0
			
		if core_hp != prev_hp:
			SocketClient.send_data({
				"Socket_Name": "core_health_%s" % [PlayerGlobalScript.spawn_player_code],
				"health": core_hp,
				"Player_IGN": PlayerGlobalScript.player_in_game_name
			})
			prev_hp = core_hp

func _on_core_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isInsideCore = true

func _on_core_area_area_exited(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isInsideCore = false
