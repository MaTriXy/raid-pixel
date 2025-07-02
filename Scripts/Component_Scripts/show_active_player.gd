extends Node

@export var player_list_btn: Button

@export var player_info_panel: Panel
@export var player_name: RichTextLabel
@export var player_description: RichTextLabel
@export var player_profile: TextureRect
@export var player_peerID: RichTextLabel

@onready var player_list_panel = $"."
@onready var player_list_container = $"Content Panel/Player's list container"
@onready var player_name_button = $"Content Panel/Player Name Button"
@onready var animationPlayer = $"AnimationPlayer"
@onready var player_list_panel_close_button = $"Content Panel/Close Button"
@onready var player_http_req = $"Player List Request"

@onready var no_profile = preload("res://Assets/Sprite_Static/Bob_No_Img.png")

var current_username: String

var hover_timer = null

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
		
	current_username = ""
		
	isOpen = false
	animationPlayer.play_backwards("pop_modal")
	
func load_player_list():
	for key in ClientEnet.rpc_player_active_dic.keys():
		var data = ClientEnet.rpc_player_active_dic[key]
		
		if prev_player_info != data and data.spawn_code == PlayerGlobalScript.spawn_player_code:
			player_info_dic[key] = data
			prev_player_info = data

	if not PlayerGlobalScript.current_modal_open and not PlayerGlobalScript.isModalOpen:
		player_list_panel.visible = true
		isOpen = true
		animationPlayer.play("pop_modal")
		PlayerGlobalScript.current_modal_open = true
		PlayerGlobalScript.isModalOpen = true
		
		#iterate to all player list
		for peerID in player_info_dic.keys():
			var player_dic = player_info_dic[peerID]
			var username = player_dic.username
			var ign = player_dic.ign
			
			var player_btn = player_name_button.duplicate()
			player_btn.name = str(peerID)
			player_btn.text = "%s (%s)" % [ign, peerID]
			player_btn.visible = true
			
			if not player_list_container.has_node(str(peerID)):
				player_list_container.add_child(player_btn)
			
			player_btn.connect("mouse_entered", func(): mouse_over(peerID, username))
			player_btn.connect("mouse_exited", mouse_out)
			
func mouse_out():
	current_username = ""
	player_info_panel.visible = false
				
func mouse_over(peerID: int, username: String):
	current_username = username
	
	player_info_panel.visible = true
	
	player_name.text = "Fetching..."
	player_description.text = "Fetching..."
	player_peerID.text = "Fetching..."
	player_profile.texture = no_profile
	
	if hover_timer != null:
		return

	hover_timer = get_tree().create_timer(1.0).timeout
	await hover_timer
	
	if current_username == username:
		await get_player_data(peerID, username)
		
	hover_timer = null

func get_player_data(peerID: int, username: String):
	var result = await ServerFetch.send_post_request(ServerFetch.backend_url + "playerInformation/playerData", { "username": username })
	
	if result.has("status") and result["status"] == "Success":
		player_name.text = result["inGameName"]
		player_description.text = result["description"]
		player_peerID.text = str(peerID)
	
		player_http_req.request(result["profile"])

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "pop_modal":
		player_list_panel.visible = isOpen
		PlayerGlobalScript.current_modal_open = isOpen
		PlayerGlobalScript.isModalOpen = isOpen


func _on_player_list_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var image = Image.new()
		var err = image.load_png_from_buffer(body)
		
		if err == OK:
			var texture = ImageTexture.create_from_image(image)
			player_profile.texture = texture
		else:
			print("Failed to load image from buffer:", err)
	else:
		print("HTTP request failed with code:", response_code)
