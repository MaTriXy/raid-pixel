extends Node

@onready var connection_panel = $"."
@onready var connection_label = $"Background Panel/Panel/Status Label"
@onready var sprite_anim = $"Background Panel/Panel/Sprite/AnimationPlayer"
@onready var retry_button = $"Background Panel/Panel/Reconnect Button"

var isDisconnect = false

func _ready() -> void:
	connection_panel.visible = true
	sprite_anim.play("Connecting_Anim")
	retry_button.visible = false
	
	retry_button.connect("button_down", retry_socket)
	
func retry_socket():
	PlayerGlobalScript.current_modal_open = false
	PlayerGlobalScript.isModalOpen = false
	
	ClientEnet.join_server(ClientEnet.host, ClientEnet.server_port)
	
func _process(_delta: float) -> void:
	if ClientEnet.enet_connection_status == "Disconnected" and isDisconnect == false:
		sprite_anim.play("Disconnected_Anim")
		isDisconnect = true
	
	connection_label.text = ClientEnet.enet_connection_status if ClientEnet.enet_connection_status == "Connected" else ClientEnet.enet_connection_status + "..."
	
	retry_button.visible = ClientEnet.enet_connection_status == "Connected"
	connection_panel.visible = ClientEnet.enet_connection_status == "Connected"

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Disconnected_Anim":
		sprite_anim.play("Disconnected_Anim_con")
