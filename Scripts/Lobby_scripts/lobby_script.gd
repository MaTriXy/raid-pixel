extends Node

@onready var player_loading_panel = $"Player Loading Panel"

func _ready() -> void:
	player_loading_panel.visible = false
	
func _process(_delta: float) -> void:
	if ClientEnet.is_player_full and ClientEnet.is_matching and not ClientEnet.player_queue_match.is_empty():
		player_loading_panel.visible = true
