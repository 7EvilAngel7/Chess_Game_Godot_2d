extends Node

signal connected_ok
signal connection_failed
signal player_assigned

const PORT := 7000
const MAX_PLAYERS := 2

var peer := ENetMultiplayerPeer.new()

# 1 = blancas, -1 = negras
var my_color: int = 0

# Guarda colores por peer_id
var player_colors := {}

func host_game() -> void:
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(PORT, MAX_PLAYERS)

	if error != OK:
		print("Error al crear servidor: ", error)
		return

	multiplayer.multiplayer_peer = peer

	my_color = 1
	player_colors.clear()
	player_colors[1] = 1

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Servidor creado correctamente en puerto ", PORT)
	print("Eres blancas.")
	player_assigned.emit()


func join_game(ip: String) -> void:
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_client(ip, PORT)

	if error != OK:
		print("Error al crear cliente: ", error)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Intentando conectar a ", ip, ":", PORT)


func _on_peer_connected(id: int) -> void:
	print("Jugador conectado con ID: ", id)

	player_colors[id] = -1

	assign_color.rpc_id(id, -1)


func _on_peer_disconnected(id: int) -> void:
	print("Jugador desconectado: ", id)

	if player_colors.has(id):
		player_colors.erase(id)


func _on_connected_to_server() -> void:
	print("Conectado al servidor.")
	connected_ok.emit()


func _on_connection_failed() -> void:
	print("No se pudo conectar al servidor.")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("El servidor se desconectó.")


@rpc("authority", "reliable")
func assign_color(color: int) -> void:
	my_color = color

	if my_color == 1:
		print("Eres blancas.")
	else:
		print("Eres negras.")

	player_assigned.emit()
