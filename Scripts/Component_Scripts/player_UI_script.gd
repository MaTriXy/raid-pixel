extends Global_Message

@onready var coordinate_label = $Coordinates
@onready var global_message_modal = $"Global Messages"
@onready var playerCount = $"Player Count"
@onready var loading_modal = $"Loading Modal"
@onready var validation_modal = $"Validation Modal"
@onready var diamond_count_label = $"Diamond Panel/Diamond Count"
@onready var player_profile = $"Profile"
@onready var http_request = $"HTTPRequest"
@onready var current_player_scene_button = $"Show Players button"
@onready var fps_counter = $"FPS Counter"
@onready var ping_timer = $"Ping Timer"
@onready var ping_label = $"Signal Strength/Signal Label"
@onready var ping_render = $"Signal Strength"
@onready var playerCount_timer = $"Player Count Timer"
@onready var view_profile_btn = $"Profile button"

#for player hp
@onready var player_hp = $"Player Health Bar"
@onready var player_hp_label = $"Player Health Bar/label"

#setting modal contents
@onready var logout_btn = $"Setting Modal/Panel/Log out Button"
@onready var surrender_btn = $"Setting Modal/Panel/Surrender Button"

#for guest stuff
@onready var guestAccountButton = $"Guest Account connect button"
@onready var guest_warning_panel = $"Guest Warning Panel"
@onready var guest_warning_panel_button = $"Guest Warning Panel/Panel/Understand button"
@onready var guest_connect_account_panel = $"Guest Connect Account Panel"
@onready var guest_connect_success_panel = $"Connect Account Success Panel"
@onready var guest_connect_success_panel_btn = $"Connect Account Success Panel/Panel/Ok button"

#inputs for account guest connect
@onready var guest_password_input = $"Guest Connect Account Panel/Panel/Password Input"
@onready var guest_confirm_password_input = $"Guest Connect Account Panel/Panel/Retype Password Input"
@onready var guest_confirm_button = $"Guest Connect Account Panel/Panel/Confirm button"
@onready var guest_back_button = $"Guest Connect Account Panel/Panel/Cancel Button"
@onready var guest_warning_text = $"Guest Connect Account Panel/Panel/Warning text"
@onready var guest_animation = $"Guest Connect Account Panel/Guest Animation Player"

#profile panel contents
@onready var player_in_game_name_label = $"Profile Modal/Panel/In Game Name Label"
@onready var player_gameID_label = $"Profile Modal/Panel/Game ID Label"
@onready var player_description_label = $"Profile Modal/Panel/Description Label"
@onready var player_profile_view = $"Profile Modal/Panel/Profile View"
@onready var IGN_last_date_change = $"Profile Modal/Panel/IGN last date change"
@onready var profile_last_date_change = $"Profile Modal/Panel/Profile last date change"
@onready var description_last_date_change = $"Profile Modal/Panel/Description last date change"

@onready var warning_text = $"Profile Modal/Panel/Warning Text"

@onready var profile_preview = $"Profile Modal/Panel/Profile Preview"
@onready var in_game_name_input =  $"Profile Modal/Panel/In Game Name Input"
@onready var description_input =  $"Profile Modal/Panel/Description Input"
@onready var change_profile_button = $"Profile Modal/Panel/Change Profile Button"
@onready var fileDialog_panel = $"Profile Modal/File Panel"
@onready var fileDialog = $"Profile Modal/File Panel/FileDialog"

@onready var edit_profile_button = $"Profile Modal/Panel/Edit Button"
@onready var cancel_edit_profile_button = $"Profile Modal/Panel/Cancel Edit Button"
@onready var save_edit_profile_button =  $"Profile Modal/Panel/Save Edit Button"

#for warning panel when saving edit profile
@onready var profile_confirmation_panel = $"Profile Confirmation Panel"
@onready var profile_confirmation_panel_proceed = $"Profile Confirmation Panel/Panel/Confirm Button"
@onready var profile_confirmation_panel_cancel = $"Profile Confirmation Panel/Panel/Cancel Button"

#for passing data
var prev_count = ""
var prev_coordinates = Vector2.ZERO
var prev_diamond = 0
var prev_FPS = 0
var prev_status: String
var prev_health = 0

var profile_base64: String

#for components classes
var player_profile_class = PlayerProfile.new()
var game_data_class = GameData.new()

func _ready() -> void:
	ping_timer.wait_time = 4.0
	ping_timer.timeout.connect(SocketClient.send_ping)
	ping_timer.start()
	
	playerCount_timer.wait_time = 2.0
	playerCount_timer.timeout.connect(renderCount)
	playerCount_timer.start()
	
	var connection_timer = Timer.new()
	connection_timer.name = "Connection Timer"
	
	if not connection_timer.is_inside_tree():
		add_child(connection_timer)
	
	connection_timer.wait_time = 1.0
	connection_timer.timeout.connect(connection_notify_main_player)
	connection_timer.start()
	
	guest_connect_success_panel_btn.connect("pressed", func(): status_panel(false, guest_connect_success_panel))
	
	global_message_modal.visible = false
	validation_modal.visible = false
	guest_connect_account_panel.visible = false
	guest_connect_success_panel.visible = false
	profile_confirmation_panel.visible = false
	
	timer_label.visible = false
	loading_modal.visible = false
	guest_warning_text.visible = false
	
	if PlayerGlobalScript.game_scene_name == "Lobby" and PlayerGlobalScript.player_account_type == "Guest":
		guest_warning_panel.visible = true
		guestAccountButton.visible =  true
	else:
		guest_warning_panel.visible = false
		guestAccountButton.visible = false
		
	view_profile_btn.visible = PlayerGlobalScript.game_scene_name == "Lobby"
	
	guestAccountButton.focus_mode = Control.FOCUS_NONE
	guestAccountButton.connect("pressed", func(): status_panel(true, guest_connect_account_panel))
	guest_warning_panel_button.connect("pressed", func(): guest_warning_panel.visible = false)
	guest_back_button.connect("pressed", func(): status_panel(false, guest_connect_account_panel))
	guest_confirm_button.connect("pressed", upgrade_account)
	
	#hide all inputs stuff on player profile
	in_game_name_input.visible = false
	description_input.visible = false
	warning_text.visible = false
	
	#for profile picture inputs
	fileDialog_panel.visible = false
	fileDialog.visible = false
	fileDialog.add_theme_icon_override("close", ImageTexture.new())
	fileDialog.filters = ["*.png", "*.jpg", "*.jpeg"]
	
	save_edit_profile_button.visible = false
	cancel_edit_profile_button.visible = false
	edit_profile_button.visible = true
	change_profile_button.visible = false
	
	change_profile_button.connect("pressed", open_file_Dialog)
	cancel_edit_profile_button.connect("pressed", func(): player_profile_class.edit_profile_status(false, in_game_name_input, description_input, cancel_edit_profile_button, save_edit_profile_button, edit_profile_button, player_in_game_name_label, player_description_label, change_profile_button, profile_preview, player_profile_view, IGN_last_date_change, profile_last_date_change, description_last_date_change))
	edit_profile_button.connect("pressed", func(): player_profile_class.edit_profile_status(true, in_game_name_input, description_input, cancel_edit_profile_button, save_edit_profile_button, edit_profile_button, player_in_game_name_label, player_description_label, change_profile_button, profile_preview, player_profile_view, IGN_last_date_change, profile_last_date_change, description_last_date_change))
	save_edit_profile_button.connect("pressed", func(): profile_confirmation_panel.visible = true)
	
	profile_confirmation_panel_cancel.connect("pressed", func(): profile_confirmation_panel.visible = false)
	profile_confirmation_panel_proceed.connect("pressed", save_profile_edit)
	
	#for setting modal, to check if player is in game.
	await get_tree().process_frame
	var current_scene = PlayerGlobalScript.current_scene
	
	logout_btn.connect("pressed", log_out_action)
	logout_btn.visible = current_scene.to_upper() == "LOBBY"
	surrender_btn.visible = not current_scene.to_upper() == "LOBBY"
		
	var data = await player_profile_class.get_player_data(http_request)
	if data["status"] == "Finished":
		in_game_name_input.text = data["inGameName"]
		description_input.text = data["description"]
		IGN_last_date_change.text = "(Change again in: %s)" % [data["IGN_last_date_change"]]
		profile_last_date_change.text = "(Change again ine: %s)" % [data["profile_last_date_change"]]
		description_last_date_change.text = "(Change again in: %s)" % [data["desc_last_date_change"]]
		
		#for ign input field
		var today = Time.get_datetime_dict_from_system()
		var today_date = "%04d-%02d-%02d" % [today.year, today.month, today.day]

		in_game_name_input.editable = today_date >= data["IGN_last_date_change"]
		description_input.editable = today_date >= data["desc_last_date_change"]
		change_profile_button.disabled = today_date < data["profile_last_date_change"]
	
func renderCount():
	var count = await game_data_class.get_player_count()
	playerCount.text = "Active player/s: %s" % [count]
		
func log_out_action():
	game_data_class.player_logout(validation_modal, loading_modal, PlayerGlobalScript.player_game_id, PlayerGlobalScript.player_username)
	
func open_file_Dialog():
	fileDialog.visible = true
	fileDialog_panel.visible = true
	
func save_profile_edit():
	var regex = RegEx.new()
	regex.compile("\\s")
	
	validation_modal.visible = true
	
	var inGameName_input_style = in_game_name_input.get_theme_stylebox("normal")
	var description_input_style = description_input.get_theme_stylebox("normal")
	
	if not in_game_name_input.text:
		inGameName_input_style.border_color = "red"
		
		warning_text.visible = true
		warning_text.text = "In Game Name must be inputted."
		validation_modal.visible = false
		
	elif len(in_game_name_input.text) <= 4:
		inGameName_input_style.border_color = "red"
		description_input_style.border_color = "black"
		
		warning_text.visible = true
		warning_text.text = "In Game Name too short, five characters minimum."
		validation_modal.visible = false
		
	elif regex.search(in_game_name_input.text):
		inGameName_input_style.border_color = "red"
		
		warning_text.visible = true
		warning_text.text = "In Game Name cannot contain spaces."
		validation_modal.visible = false

	else:
		profile_confirmation_panel.visible = false
		warning_text.visible = false
		
		var result = await ServerFetch.send_post_request(ServerFetch.backend_url + "playerInformation/modifyPlayerData", { "username": PlayerGlobalScript.player_username, "inGameName": in_game_name_input.text, "description": description_input.text, "profile": profile_base64 })
		
		if result.has("status") and result["status"] == "Success":
			validation_modal.visible = false
			
			PlayerGlobalScript.player_in_game_name = result["inGameName"]
			player_profile_class.description_profile = result["description"]
			
			IGN_last_date_change.text = "(Change again in: %s)" % [result["ign_change_date"]]
			profile_last_date_change.text = "(Change again in: %s)" % [result["profile_change_date"]]
			description_last_date_change.text = "(Change again in: %s)" % [result["desc_change_date"]]
			
			#for ign input field
			var today = Time.get_datetime_dict_from_system()
			var today_date = "%04d-%02d-%02d" % [today.year, today.month, today.day]

			in_game_name_input.editable = today_date >= result["ign_change_date"]
			description_input.editable = today_date >= result["desc_change_date"]
			change_profile_button.disabled = today_date < result["profile_change_date"]
			
			if result["profile"]:
				PlayerGlobalScript.player_profile = result["profile"]
				
				var url = PlayerGlobalScript.player_profile
				http_request.request(url)
			
			profile_base64 = ""
			
			player_profile_class.edit_profile_status(false, in_game_name_input, description_input, cancel_edit_profile_button, save_edit_profile_button, edit_profile_button, player_in_game_name_label, player_description_label, change_profile_button, profile_preview, player_profile_view, IGN_last_date_change, profile_last_date_change, description_last_date_change)
			
			SocketClient.send_data({
				"Socket_Name": "ModifyProfile",
				"Player_GameID": PlayerGlobalScript.player_game_id,
				"Player_inGameName": PlayerGlobalScript.player_in_game_name
			})
	
func status_panel(status: bool, panel: Panel):
	if status:
		if not PlayerGlobalScript.current_modal_open and not PlayerGlobalScript.isModalOpen:
			panel.visible = status
			guest_animation.play("pop")
	else:
		guest_animation.play_backwards("pop")
	PlayerGlobalScript.isModalOpen = status
	PlayerGlobalScript.current_modal_open = status
	
func upgrade_account():
	if not PlayerGlobalScript.current_modal_open and not PlayerGlobalScript.isModalOpen:
		PlayerGlobalScript.current_modal_open = true
		PlayerGlobalScript.isModalOpen = true
		validation_modal.visible = true
		
		#for inputs
		if not guest_password_input.text or not guest_confirm_password_input.text:
			guest_warning_text.visible = true
			guest_warning_text.text = "Fields cannot be empty!."
			
			guest_password_input.get_theme_stylebox("normal").border_color = "red"
			guest_confirm_password_input.get_theme_stylebox("normal").border_color = "red"
		
		elif len(guest_password_input.text) <= 4:
			guest_warning_text.visible = true
			guest_warning_text.text = "Password should be 5 characters above."
			
			guest_password_input.get_theme_stylebox("normal").border_color = "red"
			
		elif guest_password_input.text != guest_confirm_password_input.text:
			guest_warning_text.visible = true
			guest_warning_text.text = "Password should match."
			
			guest_password_input.get_theme_stylebox("normal").border_color = "red"
			guest_confirm_password_input.get_theme_stylebox("normal").border_color = "red"
			
		else:
			var result = await ServerFetch.send_post_request(ServerFetch.backend_url + "accountRoute/connectAccount", { "username": PlayerGlobalScript.player_username, "password": guest_password_input.text })
			
			if result["status"] == "Success":
				guest_connect_account_panel.visible = false
				guest_connect_success_panel.visible = true
				
				PlayerGlobalScript.player_account_type = result["accountType"]
			else:
				guest_warning_text.text = result["status"]
				
			guest_password_input.get_theme_stylebox("normal").border_color = "black"
			guest_confirm_password_input.get_theme_stylebox("normal").border_color = "black"
			
		validation_modal.visible = false
		guestAccountButton.visible =  true if PlayerGlobalScript.player_account_type == "Guest" else false
		
func _process(_delta: float) -> void:
	player_profile_class.render_player_profile_data(player_in_game_name_label, player_gameID_label, player_description_label)
	
	if prev_diamond != PlayerGlobalScript.player_diamond:
		prev_diamond = PlayerGlobalScript.player_diamond
		diamond_count_label.text = str(PlayerGlobalScript.player_diamond)
	
	if prev_coordinates != Vector2(PlayerGlobalScript.player_pos_X, PlayerGlobalScript.player_pos_Y):
		prev_coordinates = Vector2(PlayerGlobalScript.player_pos_X, PlayerGlobalScript.player_pos_Y)
		coordinate_label.text = "Player posX: " + str("%.2f" % PlayerGlobalScript.player_pos_X) + "\nPlayer posY: " + str("%.2f" % PlayerGlobalScript.player_pos_Y)
		
	if str(prev_FPS) != fps_counter.text:
		fps_counter.text = "FPS: " + str(Engine.get_frames_per_second())
		prev_FPS = Engine.get_frames_per_second()
		
	if prev_health != PlayerGlobalScript.player_health:
		player_hp.value = PlayerGlobalScript.player_health
		
		player_hp_label.text = "%s/%s" % [str(PlayerGlobalScript.player_health), str(PlayerGlobalScript.player_max_health)]
		prev_health = PlayerGlobalScript.player_health
		
	if WebsocketsConnection.socket_connection_status and prev_status != WebsocketsConnection.socket_connection_status:
		prev_status = WebsocketsConnection.socket_connection_status
		
		if prev_status == "Disconnected":
			append_connection_notify(PlayerGlobalScript.player_game_id, prev_status)
	
	message_render_display()
	
	SocketClient.output_ping()
	var color = "green"
	var frame = 0
	
	if SocketClient.ping > 80:
		frame = 2
		color = "red"
		
	elif SocketClient.ping <= 80 and SocketClient.ping >= 30:
		frame = 1 
		color = "yellow"
		
	else:
		frame = 0
		color = "green"
		
	ping_render.frame = frame
	ping_label.add_theme_color_override("default_color", color)
	ping_label.text = str(SocketClient.ping) + "ms"
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("global_message"): #pressing enter
		if global_message_modal.visible:
			message_append_on_container()

			PlayerGlobalScript.isModalOpen = false
			PlayerGlobalScript.current_modal_open = false
			global_message_modal.visible = false
			global_message_input.text = ""
			timer.wait_time = 1.0
		else:
			if PlayerGlobalScript.current_modal_open == false:
				global_message_modal.visible = true
				PlayerGlobalScript.isModalOpen = true
				PlayerGlobalScript.current_modal_open = true
				
				await get_tree().process_frame
				scroll_message_container.scroll_vertical = scroll_message_container.get_v_scroll_bar().max_value
				
				if isSend:
					timer.start()
					timer_label.visible = true
				else:
					timer_label.visible = false
					await get_tree().process_frame
					global_message_input.grab_focus()
					
				global_message_input.editable = !timer_label.visible

func _on_timer_timeout() -> void:
	timer_label.visible = false
	global_message_input.editable = true
	
	await get_tree().process_frame
	global_message_input.grab_focus()
	
func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var image = Image.new()
		var err = image.load_png_from_buffer(body)
		
		if err == OK:
			var texture = ImageTexture.create_from_image(image)
			player_profile.texture = texture
			player_profile_view.texture = texture
			profile_preview.texture = texture
		else:
			print("Failed to load image from buffer:", err)
	else:
		print("HTTP request failed with code:", response_code)

func _on_guest_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "pop":
		if PlayerGlobalScript.isModalOpen == false:
			guest_connect_account_panel.visible = false

func _on_file_dialog_file_selected(path: String) -> void:
	var image = Image.new()
	var error = image.load(path)
	
	if error == OK:
		var texture = ImageTexture.create_from_image(image)
		profile_preview.texture = texture
		
		var byte_array = image.save_png_to_buffer()
		var base64_string = Marshalls.raw_to_base64(byte_array)

		profile_base64 = base64_string
	else:
		push_error("Failed to load image.")

func _on_file_dialog_canceled() -> void:
	fileDialog_panel.visible = false

func _on_file_dialog_confirmed() -> void:
	fileDialog_panel.visible = false
