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

	if not NetworkManager.player_assigned.is_connected(_on_player_assigned):
		NetworkManager.player_assigned.connect(_on_player_assigned)

	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)


func _on_host_pressed() -> void:
	NetworkManager.host_game()


func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()

	if ip == "":
		ip = "127.0.0.1"

	NetworkManager.join_game(ip)


func _on_player_assigned() -> void:
	print("Entrando a la escena del juego...")
	get_tree().change_scene_to_file("res://scenes/main_scene.tscn")


func _on_connection_failed() -> void:
	print("No se pudo conectar. Revisa la IP o el firewall.")
