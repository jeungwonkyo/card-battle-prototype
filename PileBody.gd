extends Control
class_name PileBody

signal drag_requested(pile_type: String)

# deck / grave
@export var pile_type: String = "deck"

# 드래그 시작 최소 이동 거리
const DRAG_START_DISTANCE: float = 10.0

var is_mouse_down: bool = false
var has_drag_started: bool = false
var drag_start_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 내부 ColorRect가 클릭을 먹지 않게 함
	if has_node("ColorRect"):
		$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_mouse_down = true
			has_drag_started = false
			drag_start_mouse_position = get_global_mouse_position()
		else:
			is_mouse_down = false
			has_drag_started = false

	elif event is InputEventMouseMotion:
		if not is_mouse_down:
			return

		if has_drag_started:
			return

		var distance := drag_start_mouse_position.distance_to(get_global_mouse_position())
		if distance >= DRAG_START_DISTANCE:
			has_drag_started = true
			is_mouse_down = false

			print("드래그 요청:", pile_type)
			drag_requested.emit(pile_type)
