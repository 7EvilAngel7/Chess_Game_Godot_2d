class_name DotPlaceholder extends ColorRect

const BLUE_COLOR = Color(0.04, 0.39, 1, 0.27)
const RED_COLOR = Color(1, 0.04, 0.04, 0.27)

@export var can_destory = false

func _ready() -> void:
	if can_destory:
		color = RED_COLOR
		return

	color = BLUE_COLOR

func set_dot_color(is_red: bool) -> void:
	color = RED_COLOR if is_red else BLUE_COLOR
