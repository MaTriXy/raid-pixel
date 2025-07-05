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
			
func string_generator(size: int):
	var letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
	"m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
	var nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	
	var randomNum = RandomNumberGenerator.new()
	var result : String = ""
	
	for i in range(size):
		var char_index = randomNum.randi_range(0, len(letters) - 1)
		var num_index = randomNum.randi_range(0, len(nums) - 1)
		
		var temp_name = "%s%s" % [letters[char_index], nums[num_index]]
		result += temp_name
	
	return result
		
func cancel_match():
	"""
	SocketClient.send_data({
		"Socket_Name": "find_match",
		"player_id": PlayerGlobalScript.player_game_id,
		"status": "leave"
	})
	"""
		
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
		
		var match_info = {
			"peerID": multiplayer.get_unique_id(),
			"ign": PlayerGlobalScript.player_in_game_name,
			"profile": PlayerGlobalScript.player_profile,
			"match_ID": "match_%s" % string_generator(5),
			"status": "joined"
		}
		
		ClientEnet.send_to_server("find_match", match_info.peerID, match_info)
	
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
