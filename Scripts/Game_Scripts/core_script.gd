extends Node

var core_hp = 1000
var core_max_hp = 1000

func _on_core_area_area_entered(area: Area2D) -> void:
	if area.name == "Main Player Area":
		print("is main player attack")
		if PlayerGlobalScript.isPlayerAttack:
			print("is main player damage core")
			core_hp -= 100
