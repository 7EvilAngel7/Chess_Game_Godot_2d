class_name Constants

const BOARD_SIZE = 8
const CELL_WIDTH = 60

const BISHOP_WHITE = preload("res://assets/pieces/bishop/bishop_00.png")
const BISHOP_BLACK = preload("res://assets/pieces/bishop/bishop_01.png")

const KING_WHITE = preload("res://assets/pieces/king/king_00.png")
const KING_BLACK = preload("res://assets/pieces/king/king_01.png")

const KNIGHT_WHITE = preload("res://assets/pieces/knight/knight_00.png")
const KNIGHT_BLACK = preload("res://assets/pieces/knight/knight_01.png")

const QUEEN_WHITE = preload("res://assets/pieces/queen/queen_00.png")
const QUEEN_BLACK = preload("res://assets/pieces/queen/queen_01.png")

const PAWN_WHITE = preload("res://assets/pieces/pawn/pawn_00.png")
const PAWN_BLACK = preload("res://assets/pieces/pawn/pawn_01.png")

const ROOK_WHITE = preload("res://assets/pieces/rook/rook_00.png")
const ROOK_BLACK = preload("res://assets/pieces/rook/rook_01.png")

# pieces
# [max: 6]
# pawn white = 1
# rook white = 2
# knight white = 3
# bishop white = 4
# queen white = 5
# king white = 6

# ids
const PAWN_WHITE_ID = 1
const ROOK_WHITE_ID = 2
const KNIGHT_WHITE_ID = 3
const BISHOP_WHITE_ID = 4
const QUEEN_WHITE_ID = 5
const KING_WHITE_ID = 6

const PAWN_BLACK_ID = -1
const ROOK_BLACK_ID = -2
const KNIGHT_BLACK_ID = -3
const BISHOP_BLACK_ID = -4
const QUEEN_BLACK_ID = -5
const KING_BLACK_ID = -6

const TEXUTE_PLACEHOLDER = preload("res://scenes/texture_placeholder.tscn")
const DOT_PLACEHOLDER = preload("res://scenes/dot_placeholder.tscn")

const BLACK_COLOR = Color(0, 0, 0)
const WHITE_COLOR = Color(255, 255, 255)

const ROOK_DIRECTIONS = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const BISHOP_DIRECTIONS = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const QUEEN_DIRECTIONS = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]
const KING_DIRECTIONS = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]
const KNIGHT_DIRECTIONS = [
	Vector2i(2, 1),
	Vector2i(2, -1),
	Vector2i(1, 2),
	Vector2i(1, -2),
	Vector2i(-2, 1),
	Vector2i(-2, -1),
	Vector2i(-1, 2),
	Vector2i(-1, -2)
]

const MAX_MOVES = 50
