extends Sprite2D

enum StateMachine {
	Moving,
	Moved,
	None
}

@export var pieces: Node2D = null
@export var dots: Node2D = null
@export var turn: ColorRect = null
@export_category("Groups")
@export var white_team: CenterContainer = null
@export var black_team: CenterContainer = null

# 5 minutos en segundos (5 * 60)
var white_time: float = 300.0
var black_time: float = 300.0

# Modo Online Activado
var online_mode: bool = true

var flip_board: bool = false

var white_captured_pieces: Array[int] = []
var black_captured_pieces: Array[int] = []

# Variables para la captura de las piezas
@export var white_captured_container: GridContainer = null
@export var black_captured_container: GridContainer = null

# Referencias a las etiquetas de texto en tu interfaz
@export var white_time_label: Label = null
@export var black_time_label: Label = null

@onready var game_over_panel: Control = $"../GameOverCanvas/GameOverPanel"
@onready var result_label: Label = $"../GameOverCanvas/GameOverPanel/VBoxContainer/ResultLabel"
@onready var restart_button: Button = $"../GameOverCanvas/GameOverPanel/VBoxContainer/RestartButton"
@onready var board: Array = []
@onready var is_white: bool = true
@onready var state: StateMachine = StateMachine.None
@onready var moves = []
@onready var selected_pieces: Vector2i = Vector2i.ZERO
@onready var position_enemies: Array[Vector2i] = []
@onready var promotion_square = null

@onready var king_white := false
@onready var rook_white_left := false
@onready var rook_white_right := false

@onready var king_black := false
@onready var rook_black_left := false
@onready var rook_black_right := false

@onready var en_passant = null

@onready var king_white_position: Vector2i = Vector2i(0, 4)
@onready var king_black_position: Vector2i = Vector2i(7, 4)

@onready var fifty_move_rules = 0

@onready var unique_board_moves: Array = []
@onready var amount_same: Array = []

@onready var game_over: bool = false
@onready var game_result: String = ""


func can_play_local_turn() -> bool:
	if not online_mode:
		return true

	if NetworkManager.my_color == 0:
		return false

	if is_white and NetworkManager.my_color == 1:
		return true

	if not is_white and NetworkManager.my_color == -1:
		return true

	return false
	
func _process(delta: float) -> void:
	if game_over:
		return

	if online_mode and not multiplayer.is_server():
		update_time_labels()
		return

	if is_white:
		white_time -= delta
		if white_time <= 0:
			white_time = 0
			end_game_by_timeout(false)
	else:
		black_time -= delta
		if black_time <= 0:
			black_time = 0
			end_game_by_timeout(true)

	update_time_labels()

func update_time_labels() -> void:
	if white_time_label != null:
		white_time_label.text = format_time(white_time)
	if black_time_label != null:
		black_time_label.text = format_time(black_time)

func format_time(time_in_seconds: float) -> String:
	# Convertimos los segundos totales en minutos y segundos
	var minutes: int = int(time_in_seconds) / 60
	var seconds: int = int(time_in_seconds) % 60
	
	# Le damos formato de dos dígitos (ej. 05:09)
	return "%02d:%02d" % [minutes, seconds]

func end_game_by_timeout(winner_is_white: bool) -> void:
	if game_over:
		return

	game_over = true
	remove_dots()
	hide_canvas()
	state = StateMachine.None

	game_result = "Tiempo agotado.\nGanan las blancas." if winner_is_white else "Tiempo agotado.\nGanan las negras."
	show_game_over(game_result)

	if online_mode and multiplayer.is_server():
		sync_game_state.rpc(get_game_state())

func _ready() -> void:
	if NetworkManager.my_color == -1:
		flip_board = true
	else:
		flip_board = false
	if game_over_panel != null:
		game_over_panel.hide()

	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)

	white_team.hide()
	black_team.hide()

	# white
	board.append([
		Constants.ROOK_WHITE_ID,
		Constants.KNIGHT_WHITE_ID,
		Constants.BISHOP_WHITE_ID,
		Constants.QUEEN_WHITE_ID,
		Constants.KING_WHITE_ID,
		Constants.BISHOP_WHITE_ID,
		Constants.KNIGHT_WHITE_ID,
		Constants.ROOK_WHITE_ID
	])
	var pawns_white = []
	pawns_white.resize(Constants.BOARD_SIZE)
	pawns_white.fill(Constants.PAWN_WHITE_ID)
	board.append(pawns_white)

	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])

	# black
	var pawns_black = []
	pawns_black.resize(Constants.BOARD_SIZE)
	pawns_black.fill(Constants.PAWN_BLACK_ID)
	board.append(pawns_black)

	board.append([
		Constants.ROOK_BLACK_ID,
		Constants.KNIGHT_BLACK_ID,
		Constants.BISHOP_BLACK_ID,
		Constants.QUEEN_BLACK_ID,
		Constants.KING_BLACK_ID,
		Constants.BISHOP_BLACK_ID,
		Constants.KNIGHT_BLACK_ID,
		Constants.ROOK_BLACK_ID
	])
	
	display_board()
	

	if online_mode and multiplayer.is_server():
		await get_tree().create_timer(0.5).timeout
		sync_game_state.rpc(get_game_state())
	var buttons_white = get_tree().get_nodes_in_group("white_team")
	var buttons_black = get_tree().get_nodes_in_group("black_team")

	for button: Button in buttons_white:
		button.pressed.connect(func(): _handle_option(button))

	for button: Button in buttons_black:
		button.pressed.connect(func(): _handle_option(button))

func _input(event: InputEvent) -> void:
	if game_over:
		return

	if online_mode and not can_play_local_turn():
		return

	if event is InputEventMouseButton and promotion_square == null:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_mouse_out_board():
				return

			var board_pos: Vector2i = mouse_to_board_position()

			var coord_y: int = board_pos.x
			var coord_x: int = board_pos.y

			var selected = board[coord_y][coord_x]

			if state == StateMachine.Moved or state == StateMachine.None:
				if is_current_player_piece(selected):
					selected_pieces = Vector2i(coord_y, coord_x)
					display_options()
					state = StateMachine.Moving
				return

			if state == StateMachine.Moving:
				if is_current_player_piece(selected):
					remove_dots()
					selected_pieces = Vector2i(coord_y, coord_x)
					display_options()
					state = StateMachine.Moving
					return

				var target := Vector2i(coord_y, coord_x)

				if moves.has(target):
					request_move(selected_pieces, target)
				else:
					remove_dots()
					state = StateMachine.Moved
func mouse_to_board_position() -> Vector2i:
	var mouse := get_global_mouse_position()

	var visual_col: int = int(floor(mouse.x / Constants.CELL_WIDTH))
	var visual_row: int = int(floor(abs(mouse.y) / Constants.CELL_WIDTH))

	var board_row: int = visual_row
	var board_col: int = visual_col

	if flip_board:
		board_row = Constants.BOARD_SIZE - 1 - visual_row
		board_col = Constants.BOARD_SIZE - 1 - visual_col

	return Vector2i(board_row, board_col)
	
func is_current_player_piece(piece_id: int) -> bool:
	if piece_id == 0:
		return false

	if is_white and piece_id > 0:
		return true

	if not is_white and piece_id < 0:
		return true

	return false
	
	
func board_to_screen_position(row: int, col: int) -> Vector2:
	var visual_row: int = row
	var visual_col: int = col

	if flip_board:
		visual_row = Constants.BOARD_SIZE - 1 - row
		visual_col = Constants.BOARD_SIZE - 1 - col

	return Vector2(
		visual_col * Constants.CELL_WIDTH + Constants.CELL_WIDTH / 2,
		-visual_row * Constants.CELL_WIDTH - Constants.CELL_WIDTH / 2
	)
	
func request_move(from: Vector2i, to: Vector2i) -> void:
	if not online_mode:
		selected_pieces = from
		set_move(to.x, to.y)
		return

	if multiplayer.is_server():
		server_receive_move(from.x, from.y, to.x, to.y)
	else:
		server_receive_move.rpc_id(1, from.x, from.y, to.x, to.y)
func remove_dots():
	position_enemies = []

	for child in dots.get_children():
		child.queue_free()

func set_move(coord_y: int, coord_x: int):
	var just_now = false

	for i in moves:
		if i.x == coord_y and i.y == coord_x:
			fifty_move_rules += 1

			if is_enemy(Vector2i(coord_y, coord_x)):
				fifty_move_rules = 0

			match board[selected_pieces.x][selected_pieces.y]:
				Constants.PAWN_WHITE_ID:
					fifty_move_rules = 0

					if i.x == 7:
						upgade_pawn(i)

					if i.x == 3 and selected_pieces.x == 1:
						en_passant = i
						just_now = true
					elif en_passant != null:
						if en_passant.y == i.y and selected_pieces.y != i.y and en_passant.x == selected_pieces.x:
							# Lógica extra para registrar la captura al paso en el UI si es necesario
							var pieza_al_paso = board[en_passant.x][en_passant.y]
							if pieza_al_paso != 0:
								registrar_pieza_capturada(pieza_al_paso)
							board[en_passant.x][en_passant.y] = 0
							
				Constants.PAWN_BLACK_ID:
					fifty_move_rules = 0

					if i.x == 0:
						upgade_pawn(i)

					if i.x == 4 and selected_pieces.x == 6:
						en_passant = i
						just_now = true
					elif en_passant != null:
						if en_passant.y == i.y and selected_pieces.y != i.y and en_passant.x == selected_pieces.x:
							# Lógica extra para registrar la captura al paso en el UI si es necesario
							var pieza_al_paso = board[en_passant.x][en_passant.y]
							if pieza_al_paso != 0:
								registrar_pieza_capturada(pieza_al_paso)
							board[en_passant.x][en_passant.y] = 0
							
				Constants.ROOK_WHITE_ID:
					if selected_pieces.x == 0 and selected_pieces.y == 0:
						rook_white_left = true
					elif selected_pieces.x == 0 and selected_pieces.y == 7:
						rook_white_right = true
				Constants.ROOK_BLACK_ID:
					if selected_pieces.x == 7 and selected_pieces.y == 0:
						rook_black_left = true
					elif selected_pieces.x == 7 and selected_pieces.y == 7:
						rook_black_right = true
				Constants.KING_WHITE_ID:
					if selected_pieces.x == 0 and selected_pieces.y == 4:
						king_white = true
						
						if i.y == 2:
							rook_white_left = true
							rook_white_right = true
							board[0][0] = 0
							board[0][3] = Constants.ROOK_WHITE_ID
						elif i.y == 6:
							rook_white_left = true
							rook_white_right = true
							board[0][7] = 0
							board[0][5] = Constants.ROOK_WHITE_ID

					king_white_position = i

				Constants.KING_BLACK_ID:
					if selected_pieces.x == 7 and selected_pieces.y == 4:
						king_black = true
						
						if i.y == 2:
							rook_black_left = true
							rook_black_right = true
							board[7][0] = 0
							board[7][3] = Constants.ROOK_BLACK_ID
						elif i.y == 6:
							rook_black_left = true
							rook_black_right = true
							board[7][7] = 0
							board[7][5] = Constants.ROOK_BLACK_ID

					king_black_position = i

			if not just_now:
				en_passant = null

			# --- LÓGICA DE PIEZAS CAPTURADAS ---
			var pieza_en_destino = board[coord_y][coord_x]
			if pieza_en_destino != 0:
				registrar_pieza_capturada(pieza_en_destino)
			# -----------------------------------

			board[coord_y][coord_x] = board[selected_pieces.x][selected_pieces.y]
			board[selected_pieces.x][selected_pieces.y] = 0
			is_white = !is_white
			threefold_position(board)
			display_board()
			break

	remove_dots()
	state = StateMachine.Moved

	if online_mode:
		state = StateMachine.Moved
	elif (selected_pieces.x != coord_y or selected_pieces.y != coord_x) and (is_white and board[coord_y][coord_x] > 0 or not is_white and board[coord_y][coord_x] < 0):
		selected_pieces = Vector2i(coord_y, coord_x)
		display_options()
		state = StateMachine.Moving
	elif is_stalemate():
		if is_white and is_check_king_position(king_white_position):
			end_game(false) # negras ganan
		elif not is_white and is_check_king_position(king_black_position):
			end_game(true) # blancas ganan
		else:
			draw_game("Tablas por ahogado")

	if fifty_move_rules >= Constants.MAX_MOVES:
		draw_game("Tablas por regla de los 50 movimientos")
		return

	if insuficient_material():
		draw_game("Tablas por material insuficiente")
		return
	
func show_game_over(message: String) -> void:
	if game_over_panel != null:
		game_over_panel.show()

	if result_label != null:
		result_label.text = message

func end_game(winner_is_white: bool):
	if game_over:
		return

	game_over = true
	remove_dots()
	hide_canvas()
	state = StateMachine.None

	game_result = "Jaque mate.\nGanan las blancas." if winner_is_white else "Jaque mate.\nGanan las negras."
	show_game_over(game_result)

	if online_mode and multiplayer.is_server():
		sync_game_state.rpc(get_game_state())

func draw_game(reason: String = "Tablas"):
	if game_over:
		return

	game_over = true
	remove_dots()
	hide_canvas()
	state = StateMachine.None

	game_result = reason
	show_game_over(game_result)

	if online_mode and multiplayer.is_server():
		sync_game_state.rpc(get_game_state())

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func display_options() -> void:
	moves = get_moves(selected_pieces)

	if moves == []:
		state = StateMachine.Moved
		return

	display_dots()
func board_to_screen_square(row: int, col: int) -> Vector2:
	var visual_row: int = row
	var visual_col: int = col

	if flip_board:
		visual_row = Constants.BOARD_SIZE - 1 - row
		visual_col = Constants.BOARD_SIZE - 1 - col

	return Vector2(
		visual_col * Constants.CELL_WIDTH,
		-visual_row * Constants.CELL_WIDTH - Constants.CELL_WIDTH
	)
	
func display_dots() -> void:
	for i in moves:
		var holder: DotPlaceholder = Constants.DOT_PLACEHOLDER.instantiate()

		if position_enemies.any(func(vec): return vec == i):
			holder.can_destory = true

		dots.add_child(holder)

		# Misma alineación de antes, pero con soporte para tablero invertido
		holder.global_position = board_to_screen_square(i.x, i.y)
func get_moves(selected: Vector2i) -> Array:
	var _moves = []

	match abs(board[selected.x][selected.y]):
		Constants.PAWN_WHITE_ID:
			_moves = get_pawn_moves(selected)
		Constants.ROOK_WHITE_ID:
			_moves = get_rook_moves(selected)
		Constants.KNIGHT_WHITE_ID:
			_moves = get_knight_moves(selected)
		Constants.BISHOP_WHITE_ID:
			_moves = get_bishop_moves(selected)
		Constants.QUEEN_WHITE_ID:
			_moves = get_queen_moves(selected)
		Constants.KING_WHITE_ID:
			_moves = get_king_moves(selected)

	return _moves

func get_rook_moves(selected: Vector2i):
	var _moves = []
	var directions = Constants.ROOK_DIRECTIONS

	for i in directions:
		var pos = selected
		pos += i

		while is_valid_moves(pos):
			if is_empty(pos):
				board[pos.x][pos.y] = Constants.ROOK_WHITE_ID if is_white else Constants.ROOK_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = 0
				board[selected.x][selected.y] = Constants.ROOK_WHITE_ID if is_white else Constants.ROOK_BLACK_ID
			elif is_enemy(pos):
				var tmp_piece = board[pos.x][pos.y]

				position_enemies.append(pos)
				board[pos.x][pos.y] = Constants.ROOK_WHITE_ID if is_white else Constants.ROOK_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = tmp_piece
				board[selected.x][selected.y] = Constants.ROOK_WHITE_ID if is_white else Constants.ROOK_BLACK_ID
				break
			else:
				break

			pos += i

	return _moves

func get_bishop_moves(selected: Vector2i):
	var _moves = []
	var directions = Constants.BISHOP_DIRECTIONS

	for i in directions:
		var pos = selected
		pos += i

		while is_valid_moves(pos):
			if is_empty(pos):
				board[pos.x][pos.y] = Constants.BISHOP_WHITE_ID if is_white else Constants.BISHOP_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = 0
				board[selected.x][selected.y] = Constants.BISHOP_WHITE_ID if is_white else Constants.BISHOP_BLACK_ID
			elif is_enemy(pos):
				var tmp_piece = board[pos.x][pos.y]

				board[pos.x][pos.y] = Constants.BISHOP_WHITE_ID if is_white else Constants.BISHOP_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = tmp_piece
				board[selected.x][selected.y] = Constants.BISHOP_WHITE_ID if is_white else Constants.BISHOP_BLACK_ID
				break
			else:
				break

			pos += i

	return _moves

func get_queen_moves(selected: Vector2i):
	var _moves = []
	var directions = Constants.QUEEN_DIRECTIONS

	for i in directions:
		var pos = selected
		pos += i

		while is_valid_moves(pos):
			if is_empty(pos):
				board[pos.x][pos.y] = Constants.QUEEN_WHITE_ID if is_white else Constants.QUEEN_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = 0
				board[selected.x][selected.y] = Constants.QUEEN_WHITE_ID if is_white else Constants.QUEEN_BLACK_ID
			elif is_enemy(pos):
				var tmp_piece = board[pos.x][pos.y]

				board[pos.x][pos.y] = Constants.QUEEN_WHITE_ID if is_white else Constants.QUEEN_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = tmp_piece
				board[selected.x][selected.y] = Constants.QUEEN_WHITE_ID if is_white else Constants.QUEEN_BLACK_ID
				break
			else:
				break

			pos += i

	return _moves

func get_king_moves(selected: Vector2i):
	var _moves = []
	var directions = Constants.KING_DIRECTIONS

	if is_white:
		board[king_white_position.x][king_white_position.y] = 0
	else:
		board[king_black_position.x][king_black_position.y] = 0

	for i in directions:
		var pos = selected + i

		if is_valid_moves(pos):
			if not is_check_king_position(pos):
				if is_empty(pos):
					_moves.append(pos)
				elif is_enemy(pos):
					_moves.append(pos)

	if is_white and not king_white:
		if not rook_white_left and is_empty(Vector2i(0, 1)) and is_empty(Vector2i(0, 2)) and not is_check_king_position(Vector2i(0, 2)) and is_empty(Vector2i(0, 3)) and not is_check_king_position(Vector2i(0, 3)) and not is_check_king_position(Vector2i(0, 4)):
			_moves.append(Vector2i(0, 2))

		if not rook_white_right and not is_check_king_position(Vector2i(0, 4)) and is_empty(Vector2i(0, 5)) and not is_check_king_position(Vector2i(0, 5)) and is_empty(Vector2i(0, 6)) and not is_check_king_position(Vector2i(0, 6)):
			_moves.append(Vector2i(0, 6))
	elif not is_white and !king_black:
		if not rook_black_left and is_empty(Vector2i(7, 1)) and is_empty(Vector2i(7, 2)) and not is_check_king_position(Vector2i(7, 2)) and is_empty(Vector2i(7, 3)) and not is_check_king_position(Vector2i(7, 3)) and not is_check_king_position(Vector2i(7, 4)):
			_moves.append(Vector2i(7, 2))

		if not rook_black_right and not is_check_king_position(Vector2i(7, 4)) and is_empty(Vector2i(7, 5)) and not is_check_king_position(Vector2i(7, 5)) and is_empty(Vector2i(7, 6)) and not is_check_king_position(Vector2i(7, 6)):
			_moves.append(Vector2i(7, 6))

	if is_white:
		board[king_white_position.x][king_white_position.y] = Constants.KING_WHITE_ID
	else:
		board[king_black_position.x][king_black_position.y] = Constants.KING_BLACK_ID

	return _moves

func get_knight_moves(selected: Vector2i):
	var _moves = []
	var directions = Constants.KNIGHT_DIRECTIONS

	for i in directions:
		var pos = selected + i

		if is_valid_moves(pos):
			if is_empty(pos):
				board[pos.x][pos.y] = Constants.KNIGHT_WHITE_ID if is_white else Constants.KNIGHT_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = 0
				board[selected.x][selected.y] = Constants.KNIGHT_WHITE_ID if is_white else Constants.KNIGHT_BLACK_ID
			elif is_enemy(pos):
				var tmp_piece = board[pos.x][pos.y]

				board[pos.x][pos.y] = Constants.KNIGHT_WHITE_ID if is_white else Constants.KNIGHT_BLACK_ID
				board[selected.x][selected.y] = 0
				if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
					_moves.append(pos)
				board[pos.x][pos.y] = tmp_piece
				board[selected.x][selected.y] = Constants.KNIGHT_WHITE_ID if is_white else Constants.KNIGHT_BLACK_ID

	return _moves

func get_pawn_moves(selected: Vector2i):
	var _moves = []
	var direction: Vector2i
	var is_first_move = false

	if is_white:
		direction = Vector2i(1, 0)
	else:
		direction = Vector2i(-1, 0)

	if is_white and selected.x == 1 or not is_white and selected.x == 6:
		is_first_move = true

	if en_passant != null and (is_white and selected.x == 4 or not is_white and selected.x == 3) and abs(en_passant.y - selected.y) == 1:
		var _pos = en_passant + direction

		board[_pos.x][_pos.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
		board[selected.x][selected.y] = 0
		board[en_passant.x][en_passant.y] = 0
		if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
			_moves.append(_pos)
		board[_pos.x][_pos.y] = 0
		board[selected.x][selected.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
		board[en_passant.x][en_passant.y] = Constants.PAWN_BLACK_ID if is_white else Constants.PAWN_WHITE_ID

	var pos = selected + direction

	if is_empty(pos):
		board[pos.x][pos.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
		board[selected.x][selected.y] = 0
		if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
			_moves.append(pos)
		board[pos.x][pos.y] = 0
		board[selected.x][selected.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID

	pos = selected + Vector2i(direction.x, 1)

	if is_valid_moves(pos):
		if is_enemy(pos):
			var tmp_piece = board[pos.x][pos.y]

			board[pos.x][pos.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
			board[selected.x][selected.y] = 0
			if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
				_moves.append(pos)
			board[pos.x][pos.y] = tmp_piece
			board[selected.x][selected.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID

	pos = selected + Vector2i(direction.x, -1)

	if is_valid_moves(pos):
		if is_enemy(pos):
			var tmp_piece = board[pos.x][pos.y]

			board[pos.x][pos.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
			board[selected.x][selected.y] = 0
			if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
				_moves.append(pos)
			board[pos.x][pos.y] = tmp_piece
			board[selected.x][selected.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
	
	pos = selected + direction * 2
	
	if is_first_move and is_empty(pos) and is_empty(selected + direction):
		board[pos.x][pos.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID
		board[selected.x][selected.y] = 0
		if is_white and not is_check_king_position(king_white_position) or not is_white and not is_check_king_position(king_black_position):
			_moves.append(pos)
		board[pos.x][pos.y] = 0
		board[selected.x][selected.y] = Constants.PAWN_WHITE_ID if is_white else Constants.PAWN_BLACK_ID

	return _moves

func is_valid_moves(pos: Vector2i):
	if pos.x >= 0 and pos.x < Constants.BOARD_SIZE and pos.y >= 0 and pos.y < Constants.BOARD_SIZE:
		return true

	return false

func is_empty(pos: Vector2i):
	if board[pos.x][pos.y] == 0:
		return true

	return false

func is_enemy(pos: Vector2i):
	if is_white and board[pos.x][pos.y] < 0 or !is_white and board[pos.x][pos.y] > 0:
		position_enemies.append(pos)
		return true

	return false

func upgade_pawn(pos: Vector2i):
	if online_mode:
		if is_white:
			board[pos.x][pos.y] = Constants.QUEEN_WHITE_ID
		else:
			board[pos.x][pos.y] = Constants.QUEEN_BLACK_ID

		promotion_square = null
		return

	promotion_square = pos
	show_canvas()

func _handle_option(button: Button) -> void:
	var local_name = button.name
	var id: int

	match local_name:
		"Rook":
			id = Constants.ROOK_WHITE_ID
		"Queen":
			id = Constants.QUEEN_WHITE_ID
		"Bishop":
			id = Constants.BISHOP_WHITE_ID
		"Knight":
			id = Constants.KNIGHT_WHITE_ID

	board[promotion_square.x][promotion_square.y] = id if !is_white else -id
	hide_canvas()
	promotion_square = null
	display_board()

func show_canvas():
	if is_white:
		white_team.show()
	else:
		black_team.show()

func hide_canvas():
	white_team.hide()
	black_team.hide()

func is_mouse_out_board() -> bool:
	var mouse := get_global_mouse_position()

	var min_x := 0.0
	var max_x := Constants.BOARD_SIZE * Constants.CELL_WIDTH

	var min_y := -Constants.BOARD_SIZE * Constants.CELL_WIDTH
	var max_y := 0.0

	if mouse.x < min_x or mouse.x >= max_x:
		return true

	if mouse.y < min_y or mouse.y >= max_y:
		return true

	return false
func display_board() -> void:
	for child in pieces.get_children():
		child.queue_free()

	var tamano_objetivo := Vector2(60.0, 60.0)

	for row in Constants.BOARD_SIZE:
		for col in Constants.BOARD_SIZE:
			var holder: Sprite2D = Constants.TEXUTE_PLACEHOLDER.instantiate()

			pieces.add_child(holder)

			# Posición visual según el color del jugador
			holder.global_position = board_to_screen_position(row, col)

			match board[row][col]:
				Constants.PAWN_WHITE_ID:
					holder.texture = Constants.PAWN_WHITE
				Constants.ROOK_WHITE_ID:
					holder.texture = Constants.ROOK_WHITE
				Constants.KNIGHT_WHITE_ID:
					holder.texture = Constants.KNIGHT_WHITE
				Constants.BISHOP_WHITE_ID:
					holder.texture = Constants.BISHOP_WHITE
				Constants.QUEEN_WHITE_ID:
					holder.texture = Constants.QUEEN_WHITE
				Constants.KING_WHITE_ID:
					holder.texture = Constants.KING_WHITE
				0:
					holder.texture = null
				Constants.PAWN_BLACK_ID:
					holder.texture = Constants.PAWN_BLACK
				Constants.ROOK_BLACK_ID:
					holder.texture = Constants.ROOK_BLACK
				Constants.KNIGHT_BLACK_ID:
					holder.texture = Constants.KNIGHT_BLACK
				Constants.BISHOP_BLACK_ID:
					holder.texture = Constants.BISHOP_BLACK
				Constants.QUEEN_BLACK_ID:
					holder.texture = Constants.QUEEN_BLACK
				Constants.KING_BLACK_ID:
					holder.texture = Constants.KING_BLACK

			if holder.texture != null:
				var tamano_textura := holder.texture.get_size()

				holder.centered = true
				holder.offset = Vector2.ZERO
				holder.scale = tamano_objetivo / tamano_textura

				# Gira visualmente las piezas para el jugador negro
				holder.rotation_degrees = 180 if flip_board else 0

	turn.color = Constants.WHITE_COLOR if is_white else Constants.BLACK_COLOR
func is_check_king_position(king_position: Vector2i) -> bool:
	# TODO: refactor here -> move direction vectors to constant file
	var directions = Constants.KING_DIRECTIONS
	
	var pawn_direction = 1 if is_white else -1
	var pawn_attacks = [
		king_position + Vector2i(pawn_direction, 1),
		king_position + Vector2i(pawn_direction, -1)
	]
	
	for i in pawn_attacks:
		if is_valid_moves(i):
			var current_piece = board[i.x][i.y]

			if is_white and current_piece == Constants.PAWN_BLACK_ID or not is_white and current_piece == Constants.PAWN_WHITE_ID:
				return true

	for i in directions:
		var pos = king_position + i

		if is_valid_moves(pos):
			var current_piece = board[pos.x][pos.y]
			if is_white and current_piece == Constants.KING_BLACK_ID or not is_white and current_piece == Constants.KING_WHITE_ID:
				return true

	for i in directions:
		var pos = king_position + i

		while is_valid_moves(pos):
			if !is_empty(pos):
				var piece = board[pos.x][pos.y]
				
				if (i.x == 0 or i.y == 0) and (is_white and piece in [Constants.ROOK_BLACK_ID, Constants.QUEEN_BLACK_ID] or not is_white and piece in [Constants.ROOK_WHITE_ID, Constants.QUEEN_WHITE_ID]):
					return true
				elif (i.x != 0 and i.y != 0) and (is_white and piece in [Constants.BISHOP_BLACK_ID, Constants.QUEEN_BLACK_ID] or not is_white and piece in [Constants.BISHOP_WHITE_ID, Constants.QUEEN_WHITE_ID]):
					return true

				break
			pos += i

	var knight_directions = Constants.KNIGHT_DIRECTIONS
	
	for i in knight_directions:
		var pos = king_position + i

		if is_valid_moves(pos):
			var piece = board[pos.x][pos.y]

			if is_white and piece == Constants.KNIGHT_BLACK_ID or not is_white and piece == Constants.KNIGHT_WHITE_ID:
				return true

	return false

func is_stalemate():
	if is_white:
		for i in Constants.BOARD_SIZE:
			for j in Constants.BOARD_SIZE:
				if board[i][j] > 0:
					if get_moves(Vector2i(i, j)) != []:
						return false
	else:
		for i in Constants.BOARD_SIZE:
			for j in Constants.BOARD_SIZE:
				if board[i][j] < 0:
					if get_moves(Vector2i(i, j)) != []:
						return false

	return true

func insuficient_material() -> bool:
	var white_minor: Array = []
	var black_minor: Array = []

	for row in Constants.BOARD_SIZE:
		for col in Constants.BOARD_SIZE:
			var piece = board[row][col]

			match piece:
				0, Constants.KING_WHITE_ID, Constants.KING_BLACK_ID:
					pass

				Constants.BISHOP_WHITE_ID:
					white_minor.append({
						"type": "bishop",
						"square_color": get_square_color(Vector2i(row, col))
					})

				Constants.KNIGHT_WHITE_ID:
					white_minor.append({
						"type": "knight"
					})

				Constants.BISHOP_BLACK_ID:
					black_minor.append({
						"type": "bishop",
						"square_color": get_square_color(Vector2i(row, col))
					})

				Constants.KNIGHT_BLACK_ID:
					black_minor.append({
						"type": "knight"
					})

				_:
					# Si hay peones, torres o damas, no es material insuficiente
					return false

	# Rey vs Rey
	if white_minor.is_empty() and black_minor.is_empty():
		return true

	# Rey + pieza menor vs Rey
	if white_minor.size() == 1 and black_minor.is_empty():
		return true

	if black_minor.size() == 1 and white_minor.is_empty():
		return true

	# Rey + alfil vs Rey + alfil, con ambos alfiles en el mismo color de casilla
	if white_minor.size() == 1 and black_minor.size() == 1:
		if white_minor[0]["type"] == "bishop" and black_minor[0]["type"] == "bishop":
			return white_minor[0]["square_color"] == black_minor[0]["square_color"]

	return false

func get_square_color(pos: Vector2i) -> int:
	# 0 = clara, 1 = oscura
	return (pos.x + pos.y) % 2

func threefold_position(_board: Array):
	for i in unique_board_moves.size():
		if _board == unique_board_moves[i]:
			amount_same[i] += 1

			if amount_same[i] >= 3:
				draw_game("Tablas por triple repetición")
			return

	unique_board_moves.append(_board.duplicate_deep())
	amount_same.append(1)

# --- NUEVAS FUNCIONES PARA EL REGISTRO DE PIEZAS CAPTURADAS ---
func crear_icono_captura(id_pieza: int, container: GridContainer) -> void:
	if container == null:
		return

	var icono := TextureRect.new()
	icono.texture = obtener_textura_por_id(id_pieza)

	if icono.texture == null:
		return

	icono.custom_minimum_size = Vector2(60, 60)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	container.add_child(icono)
	
func actualizar_piezas_capturadas() -> void:
	if white_captured_container != null:
		for child in white_captured_container.get_children():
			child.queue_free()

	if black_captured_container != null:
		for child in black_captured_container.get_children():
			child.queue_free()

	for id_pieza in white_captured_pieces:
		crear_icono_captura(id_pieza, white_captured_container)

	for id_pieza in black_captured_pieces:
		crear_icono_captura(id_pieza, black_captured_container)
		
func registrar_pieza_capturada(id_pieza: int):
	if id_pieza == 0:
		return

	# Guardamos la pieza capturada en arrays sincronizables
	if id_pieza > 0:
		# Pieza blanca capturada
		white_captured_pieces.append(id_pieza)
	else:
		# Pieza negra capturada
		black_captured_pieces.append(id_pieza)

	actualizar_piezas_capturadas()
	
func obtener_textura_por_id(id: int) -> Texture2D:
	match id:
		Constants.PAWN_WHITE_ID: return Constants.PAWN_WHITE
		Constants.ROOK_WHITE_ID: return Constants.ROOK_WHITE
		Constants.KNIGHT_WHITE_ID: return Constants.KNIGHT_WHITE
		Constants.BISHOP_WHITE_ID: return Constants.BISHOP_WHITE
		Constants.QUEEN_WHITE_ID: return Constants.QUEEN_WHITE
		Constants.KING_WHITE_ID: return Constants.KING_WHITE
		Constants.PAWN_BLACK_ID: return Constants.PAWN_BLACK
		Constants.ROOK_BLACK_ID: return Constants.ROOK_BLACK
		Constants.KNIGHT_BLACK_ID: return Constants.KNIGHT_BLACK
		Constants.BISHOP_BLACK_ID: return Constants.BISHOP_BLACK
		Constants.QUEEN_BLACK_ID: return Constants.QUEEN_BLACK
		Constants.KING_BLACK_ID: return Constants.KING_BLACK
	return null

func get_game_state() -> Dictionary:
	return {
		"board": board.duplicate_deep(),
		"is_white": is_white,
		"white_time": white_time,
		"black_time": black_time,
		"king_white_position": king_white_position,
		"king_black_position": king_black_position,
		"king_white": king_white,
		"king_black": king_black,
		"rook_white_left": rook_white_left,
		"rook_white_right": rook_white_right,
		"rook_black_left": rook_black_left,
		"rook_black_right": rook_black_right,
		"en_passant": en_passant,
		"fifty_move_rules": fifty_move_rules,
		"game_over": game_over,
		"game_result": game_result,
		"white_captured_pieces": white_captured_pieces.duplicate(),
		"black_captured_pieces": black_captured_pieces.duplicate()
	}
	
@rpc("any_peer", "reliable")
func server_receive_move(from_y: int, from_x: int, to_y: int, to_x: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	if sender_id == 0:
		sender_id = 1

	var from := Vector2i(from_y, from_x)
	var to := Vector2i(to_y, to_x)

	var expected_color := 1 if is_white else -1

	if not NetworkManager.player_colors.has(sender_id):
		print("Movimiento rechazado: jugador no registrado. ID: ", sender_id)
		sync_game_state.rpc(get_game_state())
		return

	if NetworkManager.player_colors[sender_id] != expected_color:
		print("Movimiento rechazado: no es el turno de ese jugador.")
		sync_game_state.rpc(get_game_state())
		return

	var piece = board[from.x][from.y]

	if expected_color == 1 and piece <= 0:
		print("Movimiento rechazado: no es pieza blanca.")
		sync_game_state.rpc(get_game_state())
		return

	if expected_color == -1 and piece >= 0:
		print("Movimiento rechazado: no es pieza negra.")
		sync_game_state.rpc(get_game_state())
		return

	selected_pieces = from
	moves = get_moves(selected_pieces)

	var valid := false

	for move in moves:
		if move == to:
			valid = true
			break

	if not valid:
		print("Movimiento ilegal rechazado.")
		sync_game_state.rpc(get_game_state())
		return

	selected_pieces = from
	set_move(to.x, to.y)

	sync_game_state.rpc(get_game_state())

@rpc("authority", "call_local", "reliable")
func sync_game_state(state_data: Dictionary) -> void:
	board = state_data["board"].duplicate_deep()

	is_white = state_data["is_white"]
	white_time = state_data["white_time"]
	black_time = state_data["black_time"]

	king_white_position = state_data["king_white_position"]
	king_black_position = state_data["king_black_position"]

	king_white = state_data["king_white"]
	king_black = state_data["king_black"]

	rook_white_left = state_data["rook_white_left"]
	rook_white_right = state_data["rook_white_right"]
	rook_black_left = state_data["rook_black_left"]
	rook_black_right = state_data["rook_black_right"]

	en_passant = state_data["en_passant"]
	fifty_move_rules = state_data["fifty_move_rules"]

	game_over = state_data["game_over"]
	game_result = state_data["game_result"]

	white_captured_pieces = state_data["white_captured_pieces"].duplicate()
	black_captured_pieces = state_data["black_captured_pieces"].duplicate()
	remove_dots()
	moves.clear()
	position_enemies.clear()
	promotion_square = null

	state = StateMachine.Moved

	display_board()
	update_time_labels()
	actualizar_piezas_capturadas()
	if game_over:
		show_game_over(game_result)
	else:
		if game_over_panel != null:
			game_over_panel.hide()
