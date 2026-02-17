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

func _ready() -> void:
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

	var buttons_white = get_tree().get_nodes_in_group("white_team")
	var buttons_black = get_tree().get_nodes_in_group("black_team")

	for button: Button in buttons_white:
		button.pressed.connect(func(): _handle_option(button))

	for button: Button in buttons_black:
		button.pressed.connect(func(): _handle_option(button))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and promotion_square == null:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_mouse_out_board():
				return

			var mouse = get_global_mouse_position()
			var coord_x = snapped(mouse.x, 0) / Constants.CELL_WIDTH
			var coord_y = abs(snapped(mouse.y, 0)) / Constants.CELL_WIDTH
			var selected = board[coord_y][coord_x]

			if (state == StateMachine.Moved or state == StateMachine.None) and (is_white && selected > 0 or !is_white && selected < 0):
				selected_pieces = Vector2i(coord_y, coord_x)
				display_options()
				state = StateMachine.Moving
			elif state == StateMachine.Moving:
				set_move(coord_y, coord_x)

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
							board[en_passant.x][en_passant.y] = 0
				Constants.ROOK_WHITE_ID:
					if selected_pieces.x == 0 and selected_pieces.y == 0:
						rook_white_left = true
					elif selected_pieces.x == 0 and selected_pieces.y == 7:
						rook_white_right = true
				Constants.ROOK_BLACK_ID:
					if selected_pieces.x == 0 and selected_pieces.y == 0:
						rook_black_left = true
					elif selected_pieces.x == 0 and selected_pieces.y == 7:
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

			board[coord_y][coord_x] = board[selected_pieces.x][selected_pieces.y]
			board[selected_pieces.x][selected_pieces.y] = 0
			is_white = !is_white
			threefold_position(board)
			display_board()
			break

	remove_dots()
	state = StateMachine.Moved

	if (selected_pieces.x != coord_y or selected_pieces.y != coord_x) and (is_white and board[coord_y][coord_x] > 0 or not is_white and board[coord_y][coord_x] < 0):
		selected_pieces = Vector2i(coord_y, coord_x)
		display_options()
		state = StateMachine.Moving
	elif is_stalemate():
		if is_white and is_check_king_position(king_white_position) or not is_white and is_check_king_position(king_black_position):
			end_game()
		else:
			draw_game()

	if fifty_move_rules == Constants.MAX_MOVES:
		draw_game()
	
	if insuficient_material():
		draw_game()

func end_game():
	print("checkmate -> stalemate")

func draw_game():
	print("draw")

func display_options() -> void:
	moves = get_moves(selected_pieces)

	if moves == []:
		state = StateMachine.Moved
		return

	display_dots()

func display_dots() -> void:
	for i in moves:
		var holder: DotPlaceholder = Constants.DOT_PLACEHOLDER.instantiate()

		if position_enemies.any(func(vec): return vec == i):
			holder.can_destory = true

		dots.add_child(holder)
		holder.global_position = Vector2(
			i.y * Constants.CELL_WIDTH,
			-i.x * Constants.CELL_WIDTH - Constants.CELL_WIDTH
		)

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
	if get_rect().has_point(to_local(get_global_mouse_position())):
		return false

	return true

func display_board() -> void:
	for child in pieces.get_children():
		child.queue_free()

	for row in Constants.BOARD_SIZE:
		for col in Constants.BOARD_SIZE:
			var holder: Sprite2D = Constants.TEXUTE_PLACEHOLDER.instantiate()

			pieces.add_child(holder)
			@warning_ignore("integer_division")
			holder.global_position = Vector2(
				col * Constants.CELL_WIDTH + (Constants.CELL_WIDTH / 2),
				-row * Constants.CELL_WIDTH - (Constants.CELL_WIDTH / 2)
			)

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

func insuficient_material():
	var white_pieces = 0
	var black_pieces = 0
	
	for i in Constants.BOARD_SIZE:
		for j in Constants.BOARD_SIZE:
			match board[i][j]:
				Constants.KNIGHT_WHITE_ID, Constants.BISHOP_WHITE_ID:
					if white_pieces == 0:
						white_pieces += 1
					else:
						return false
				Constants.KNIGHT_BLACK_ID, Constants.BISHOP_BLACK_ID:
					if black_pieces == 0:
						black_pieces += 1
					else:
						return false
				Constants.KING_WHITE_ID, Constants.KING_BLACK_ID, 0:
					pass
				_:
					return false

	return true

func threefold_position(_board: Array):
	for i in unique_board_moves.size():
		if _board == unique_board_moves[i]:
			amount_same[i] += 1

			if amount_same[i] >= 3:
				draw_game()
				return

	unique_board_moves.append(_board.duplicate_deep())
	amount_same.append(1)
