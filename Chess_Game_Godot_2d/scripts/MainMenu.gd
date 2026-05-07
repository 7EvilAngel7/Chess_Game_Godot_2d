extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_input: LineEdit = $VBoxContainer/IpInput

func _ready() -> void:
	host_button.text = "Crear partida"
	join_button.text = "Unirse"
	ip_input.placeholder_text = "IP del host"

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	NetworkManager.player_assigned.connect(_on_player_assigned)


func _on_host_pressed() -> void:
	NetworkManager.host_game()


func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()

	if ip == "":
		ip = "127.0.0.1"

	NetworkManager.join_game(ip)


func _on_player_assigned() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Game.tscn")
