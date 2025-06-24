extends Node

@onready var animation = $"Sprite/AnimationPlayer"

@export var ready_panel: Panel
@export var go_to_scene_button: Button

@export var find_match_panel: Panel
@export var find_match_cancel_button: Button
@export var find_match_timer_label: RichTextLabel
var isFindMatchStart = false
var find_match_timer = 0.0

var prev_status = false

func _ready() -> void:
	find_match_panel.visible = false
	find_match_cancel_button.visible = false
	ready_panel.visible = false
	go_to_scene_button.connect("pressed", head_to_game)
	find_match_cancel_button.connect("pressed", cancel_match)
	
	PlayerGlobalScript.game_scene_name = "Lobby"
	PlayerGlobalScript.player_class_game_type = "Defender"
	PlayerGlobalScript.is_game_scene_loaded = false
	
func _process(delta: float) -> void:
	if isFindMatchStart:
		find_match_timer += delta
		
		var seconds = int(find_match_timer) % 60
		var minutes = int(find_match_timer) / 60
		find_match_timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		if seconds >= 10.0:
			find_match_cancel_button.visible = true
		
func cancel_match():
	SocketClient.send_data({
		"Socket_Name": "find_match",
		"player_id": PlayerGlobalScript.player_game_id,
		"status": "leave"
	})
		
	isFindMatchStart = false
	find_match_timer = 0
	
	ready_panel.visible = true
	find_match_panel.visible = false
	
	PlayerGlobalScript.isModalOpen = false
	PlayerGlobalScript.current_modal_open = false
		
func head_to_game():
	if not PlayerGlobalScript.isModalOpen and not PlayerGlobalScript.current_modal_open:
		find_match_cancel_button.visible = false
		ready_panel.visible = false
		find_match_panel.visible = true
		isFindMatchStart = true
		
		PlayerGlobalScript.isModalOpen = true
		PlayerGlobalScript.current_modal_open = true
		
		SocketClient.send_data({
			"Socket_Name": "find_match",
			"player_id": PlayerGlobalScript.player_game_id,
			"player_ign": PlayerGlobalScript.player_in_game_name,
			"player_profile": PlayerGlobalScript.player_profile,
			"match_ID": "match_%s" % [PlayerInfoStuff.string_generator(5)],
			"status": "joined"
		})
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "door_anim":
		animation.pause()

func _on_player_door_area_area_entered(area: Area2D) -> void:
	if area.name:
		if area.name == "Main Player Area":
			ready_panel.visible = true
			
		animation.play("door_anim")

func _on_player_door_area_area_exited(area: Area2D) -> void:
	if area.name:
		if area.name == "Main Player Area":
			ready_panel.visible = false
		
		animation.play_backwards("door_anim")
