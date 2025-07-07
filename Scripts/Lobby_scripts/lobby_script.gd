extends Node

@onready var player_loading_panel = $"Player Loading Panel"

func _ready() -> void:
	player_loading_panel.visible = false
	
func _process(_delta: float) -> void:
	if ClientEnet.is_player_full:
		player_loading_panel.visible = true
