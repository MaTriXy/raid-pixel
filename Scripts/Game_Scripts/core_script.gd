extends Node

signal send_damage_to_server(new_health)

@export var damage_per_tick = 10
@export var damage_cooldown = 0.5

var core_hp = 1000
var core_max_hp = 1000
var is_inside_core = false

var prev_hp = 0
var damage_timer = 0.0

func _ready() -> void:
	connect("send_damage_to_server", Callable(self, "_on_send_damage_to_server"))

func _process(delta: float) -> void:
	if PlayerGlobalScript.player_class_game_type == "Attacker":
		if PlayerGlobalScript.isPlayerAttack and is_inside_core:
			damage_timer -= delta
			if damage_timer <= 0:
				damage_core()
				damage_timer = damage_cooldown

func damage_core():
	core_hp = max(core_hp - damage_per_tick, 0)
	
	if prev_hp != core_hp:
		emit_signal("send_damage_to_server", core_hp)
		prev_hp = core_hp
	
func _on_send_damage_to_server(new_health: float):
	SocketClient.send_data({
		"Socket_Name": "core_health_%s" % PlayerGlobalScript.spawn_player_code,
		"health": new_health,
		"max_health": core_max_hp
	})

func _on_core_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		is_inside_core = true

func _on_core_area_area_exited(area: Area2D) -> void:
	if area.name == "Main Player Area":
		is_inside_core = false
