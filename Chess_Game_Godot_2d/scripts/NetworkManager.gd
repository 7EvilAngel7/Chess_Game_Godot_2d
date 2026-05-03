extends Node

signal connected_ok
signal connection_failed
signal player_assigned

const PORT := 7000
const MAX_PLAYERS := 2

var peer := ENetMultiplayerPeer.new()

# 1 = blancas, -1 = negras
var my_color: int = 0

# Guarda qué color tiene cada jugador según su peer_id
var player_colors := {}

func host_game() -> void:
	var error = peer.create_server(PORT, MAX_PLAYERS - 1)

	if error != OK:
		print("Error al crear servidor: ", error)
		return

	multiplayer.multiplayer_peer = peer

	# El host siempre será blancas
	my_color = 1
	player_colors[1] = 1

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Servidor creado. Eres blancas.")
	player_assigned.emit()


func join_game(ip: String) -> void:
	var error = peer.create_client(ip, PORT)

	if error != OK:
		print("Error al conectar: ", error)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Intentando conectar a: ", ip)


func _on_peer_connected(id: int) -> void:
	print("Jugador conectado: ", id)

	# Primer cliente será negras
	player_colors[id] = -1

	# Avisamos al cliente que es negras
	assign_color.rpc_id(id, -1)


func _on_peer_disconnected(id: int) -> void:
	print("Jugador desconectado: ", id)


func _on_connected_to_server() -> void:
	print("Conectado al servidor.")
	connected_ok.emit()


func _on_connection_failed() -> void:
	print("No se pudo conectar.")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("Servidor desconectado.")


@rpc("authority", "reliable")
func assign_color(color: int) -> void:
	my_color = color

	if my_color == 1:
		print("Eres blancas.")
	else:
		print("Eres negras.")

	player_assigned.emit()
