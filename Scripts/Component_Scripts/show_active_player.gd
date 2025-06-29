extends Node

@export var player_list_btn: Button

@export var player_info_panel: Panel
@export var player_name: RichTextLabel
@export var player_description: RichTextLabel
@export var player_profile: TextureRect
@export var player_gameID: RichTextLabel

@onready var player_list_panel = $"."
@onready var player_list_container = $"Content Panel/Player's list container"
@onready var player_name_button = $"Content Panel/Player Name Button"
@onready var animationPlayer = $"AnimationPlayer"
@onready var player_list_panel_close_button = $"Content Panel/Close Button"

var player_info_dic: Dictionary
var isOpen = false
var prev_player_info: Dictionary

func _ready() -> void:
	player_list_panel.visible = false
	player_info_panel.visible = false
	
	player_list_btn.focus_mode = Control.FOCUS_NONE
	player_list_btn.connect("pressed", load_player_list)
	player_list_panel_close_button.connect("pressed", close_panel)
	
func close_panel():
	#clear out the list of the player for refresh
	for child in player_list_container.get_children():
		child.queue_free()
		
	isOpen = false
	animationPlayer.play_backwards("pop_modal")
	
func load_player_list():
	for key in ClientEnet.rpc_player_active_dic.keys():
		var data = ClientEnet.rpc_player_active_dic[key]
		
		if prev_player_info != data and data.spawn_code == PlayerGlobalScript.spawn_player_code:
			player_info_dic[key] = data
			prev_player_info = data
		
		ClientEnet.rpc_player_active_dic.erase(key)

	if not PlayerGlobalScript.current_modal_open and not PlayerGlobalScript.isModalOpen:
		player_list_panel.visible = true
		isOpen = true
		animationPlayer.play("pop_modal")
		PlayerGlobalScript.current_modal_open = true
		PlayerGlobalScript.isModalOpen = true
		
		#iterate to all player list
		for gameID in player_info_dic.keys():
			var player_dic = player_info_dic[gameID]
			var ign = player_dic.ign
			var description = player_dic.description
			var profile = player_dic.profile
			
			
			if not player_list_container.has_node(gameID):
				var player_btn = player_name_button.duplicate()
				player_btn.name = gameID
				player_btn.text = "%s (%s)" % [ign, gameID]
				player_btn.visible = true
				
				player_btn.connect("mouse_entered", func(): get_player_data(gameID, description, profile, ign))
				player_btn.connect("mouse_exited", func(): player_info_panel.visible = false)
	
				player_list_container.add_child(player_btn)
				
			else:
				var player_btn = player_list_container.get_node(gameID)
				player_btn.text = "%s (%s)" % [ign, gameID]

func get_player_data(gameID: String, description: String, profile: Texture2D, ign: String):	
	player_info_panel.visible = true
	
	player_name.text = ign
	player_description.text = description
	player_gameID.text = gameID
	player_profile.texture = profile

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "pop_modal":
		player_list_panel.visible = isOpen
		PlayerGlobalScript.current_modal_open = isOpen
		PlayerGlobalScript.isModalOpen = isOpen
