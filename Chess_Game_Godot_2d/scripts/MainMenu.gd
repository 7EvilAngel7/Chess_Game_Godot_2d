extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_input: LineEdit = $VBoxContainer/IpInput

const GAME_SCENE_PATH := "res://scenes/main_scene.tscn"

func _ready() -> void:
	host_button.text = "Crear partida"
	join_button.text = "Unirse"
	ip_input.placeholder_text = "IP del host"

	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)

	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)

	if not NetworkManager.start_match.is_connected(_on_start_match):
		NetworkManager.start_match.connect(_on_start_match)

	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)


func _on_host_pressed() -> void:
	print("Creando partida...")
	NetworkManager.host_game()

	host_button.disabled = true
	join_button.disabled = true
	host_button.text = "Esperando jugador..."


func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()

	if ip == "":
		ip = "127.0.0.1"

	print("Uniéndose a partida...")
	print("IP: ", ip)

	NetworkManager.join_game(ip)

	host_button.disabled = true
	join_button.disabled = true
	join_button.text = "Conectando..."


func _on_start_match() -> void:
	print("Iniciando escena del juego...")
	print("Mi color es: ", NetworkManager.my_color)

	if not ResourceLoader.exists(GAME_SCENE_PATH):
		print("ERROR: No existe la escena: ", GAME_SCENE_PATH)
		return

	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_connection_failed() -> void:
	print("No se pudo conectar.")

	host_button.disabled = false
	join_button.disabled = false
	host_button.text = "Crear partida"
	join_button.text = "Unirse"
