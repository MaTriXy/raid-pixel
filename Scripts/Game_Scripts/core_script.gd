extends Node

@export var damage_per_tick = 10
@export var damage_cooldown = 0.5

var core_hp: float
var core_max_hp: float
var is_inside_core = false

var prev_hp = 0
var damage_timer = 0.0

func _process(delta: float) -> void:
	if PlayerGlobalScript.player_class_game_type == "Attacker":
		if PlayerGlobalScript.isPlayerAttack and is_inside_core:
			damage_timer -= delta
			if damage_timer <= 0:
				damage_core()
				damage_timer = damage_cooldown

func damage_core():
	core_hp = max(core_hp - damage_per_tick, 0)
	GameClientEnet.game_send_to_server("core_health_update", multiplayer.get_unique_id(), { "health": core_hp, "spawn_code": PlayerGlobalScript.spawn_player_code })

func _on_core_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		is_inside_core = true

func _on_core_area_area_exited(area: Area2D) -> void:
	if area.name == "Main Player Area":
		is_inside_core = false
