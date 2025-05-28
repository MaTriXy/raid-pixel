extends Node

@onready var game_timer = $"Game Timer"
@onready var game_label = $"Game Timer Label"

@onready var game_info_panel = $"Game Mechanics Info Panel"
@onready var game_info_anim = $"Game Mechanics Info Panel/AnimationPlayer"
@onready var game_info_button = $"Game Mechanics Info Panel/Panel/Lets go button"

func _ready() -> void:
	game_timer.wait_time = 99
	game_timer.one_shot = true
	game_timer.timeout.connect(game_end)
	game_timer.start()
	
	game_info_panel.visible = true
	game_info_button.connect("pressed", func(): game_info_panel.visible = false)
	
func game_end():
	print("Game ended")
	
func _process(_delta: float) -> void:
	var seconds = int(game_timer.time_left) % 60
	var minutes = int(game_timer.time_left) / 60
	game_label.text = "Battle time: %02d:%02d" % [minutes, seconds]
