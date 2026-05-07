extends Node

signal connection_failed
signal start_match

const PORT := 8910
const MAX_CLIENTS := 1

var peer: ENetMultiplayerPeer

# 1 = blancas, -1 = negras
var my_color: int = 0
var player_colors := {}

func host_game() -> void:
	peer = ENetMultiplayerPeer.new()

	var error := peer.create_server(PORT, MAX_CLIENTS)

	if error != OK:
		print("ERROR al crear servidor. Código: ", error)
		print("Puede que el puerto esté ocupado: ", PORT)
		return

	multiplayer.multiplayer_peer = peer

	my_color = 1
	player_colors.clear()
	player_colors[1] = 1

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Servidor creado correctamente.")
	print("Eres blancas. Esperando jugador negro...")


func join_game(ip: String) -> void:
	peer = ENetMultiplayerPeer.new()

	var error := peer.create_client(ip, PORT)

	if error != OK:
		print("ERROR al crear cliente. Código: ", error)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Intentando conectar a: ", ip, ":", PORT)


func _on_peer_connected(id: int) -> void:
	print("Cliente conectado con ID: ", id)

	player_colors[id] = -1

	print("Asignando negras al cliente...")
	assign_color.rpc_id(id, -1)

	print("Iniciando partida para ambos jugadores...")
	start_game.rpc()


func _on_peer_disconnected(id: int) -> void:
	print("Jugador desconectado: ", id)

	if player_colors.has(id):
		player_colors.erase(id)


func _on_connected_to_server() -> void:
	print("Cliente conectado al servidor. Esperando asignación de color...")


func _on_connection_failed() -> void:
	print("Falló la conexión.")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("Servidor desconectado.")


@rpc("authority", "reliable")
func assign_color(color: int) -> void:
	my_color = color

	if my_color == 1:
		print("Soy blancas.")
	elif my_color == -1:
		print("Soy negras.")


@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	print("START GAME recibido. Color: ", my_color)
	start_match.emit()
