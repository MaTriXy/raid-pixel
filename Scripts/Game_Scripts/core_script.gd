extends Node

var core_hp = 1000
var core_max_hp = 1000
var isInsideCore = false
var client_hp = 1000
var prev_hp = 0
var prev_data = {}

func _ready() -> void:
	var timer = Timer.new()
	timer.name = "core_checker"
	
	if not timer.is_inside_tree():
		add_child(timer)
		
	timer.wait_time = 1.0
	timer.timeout.connect(damage_core)
	timer.start()

#TODO: fix this one later on
func _process(_delta: float) -> void:
	var data = SocketClient.received_data()
	var connection_status = WebsocketsConnection.socket_connection_status
	
	if connection_status == "Connected":
		if data.get("Socket_Name") and prev_data != data and data.get("Socket_Name") == "core_health_%s" % [PlayerGlobalScript.spawn_player_code]:
			prev_data = data
			
			if data.has("health"):
				core_hp = int(data.get("health"))
			
		
func damage_core():
	if PlayerGlobalScript.isPlayerAttack and isInsideCore:
		client_hp -= 100
		
		if client_hp <= 0:
			client_hp = 0
			
		if client_hp != prev_hp:
			SocketClient.send_data({
				"Socket_Name": "core_health_%s" % [PlayerGlobalScript.spawn_player_code],
				"health": client_hp
			})
			prev_hp = client_hp

func _on_core_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isInsideCore = true

func _on_core_area_area_exited(area: Area2D) -> void:
	if area.name == "Main Player Area":
		isInsideCore = false
