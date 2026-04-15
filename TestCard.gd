extends Control
class_name TestCard

signal pile_drag_finished(card_state, pile_type: String, placed: bool)

@export var card_name: String = "테스트 카드"
@export var card_side: String = "player"

var card_state = null
var current_slot: FieldSlot = null

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_slot: FieldSlot = null
var source_pile_type: String = ""
var is_face_up: bool = true

# 필드 카드 입력 대기
var is_field_press_pending: bool = false
var field_press_start_mouse_global: Vector2 = Vector2.ZERO

# 조합 드래그
var is_combo_dragging: bool = false
var combo_drag_data: Dictionary = {}
var combo_drag_preview: Panel = null
var combo_drag_start_top_left_global: Vector2 = Vector2.ZERO

# 위쪽 드래그 시작 최소 거리
const COMBO_DRAG_START_Y_DISTANCE: float = 18.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if has_node("ColorRect"):
		var card_body: ColorRect = $ColorRect
		size = card_body.size
		card_body.position = Vector2.ZERO
		card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ensure_card_labels()
	_ensure_selection_outline()

	_show_front_face()

	print("테스트 카드 준비 완료:", card_name)
	print("테스트 카드 루트 크기:", size)

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		return

	if is_combo_dragging and combo_drag_preview != null:
		var delta: Vector2 = get_global_mouse_position() - field_press_start_mouse_global
		combo_drag_preview.global_position = combo_drag_start_top_left_global + delta
		return

	# 누르고 있는 동안 계속 위쪽 드래그 감시
	if is_field_press_pending and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var delta: Vector2 = get_global_mouse_position() - field_press_start_mouse_global

		if delta.y <= -COMBO_DRAG_START_Y_DISTANCE:
			var started: bool = _start_combo_drag_from_field()
			if started:
				is_field_press_pending = false

func _input(event: InputEvent) -> void:
	if is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()
		return

	if is_combo_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_combo_drag()
		return

	# 드래그 시작이 안 됐으면 클릭으로 처리
	if is_field_press_pending:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_field_press_pending = false

			var battle_scene = get_tree().current_scene
			if battle_scene != null and battle_scene.has_method("on_field_card_clicked"):
				battle_scene.on_field_card_clicked(self)
			return

func setup_from_card_state(new_card_state) -> void:
	card_state = new_card_state
	card_side = new_card_state.owner_side
	card_name = _make_card_name_from_state(new_card_state)

	_update_card_labels()

	if is_face_up:
		_show_front_face()

	print("카드 데이터 연결 완료:", card_state.to_log_string(), "/ 이름:", card_name)

func set_current_slot(slot: FieldSlot) -> void:
	current_slot = slot

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return

	print("카드 클릭 감지")

	# 필드 위 카드일 때만 클릭/드래그 분기
	if current_slot != null and source_pile_type == "":
		is_field_press_pending = true
		field_press_start_mouse_global = get_global_mouse_position()
		return

func start_drag_from_pile(pile_type: String, mouse_global_position: Vector2) -> void:
	source_pile_type = pile_type
	original_slot = null
	current_slot = null
	is_dragging = true

	_show_back_face()

	drag_offset = size * 0.5
	global_position = mouse_global_position - drag_offset

	print("파일 더미 카드 드래그 시작:", pile_type)

func deal_from_pile_to_slot(start_global_position: Vector2, target_slot: FieldSlot) -> void:
	source_pile_type = ""
	original_slot = null
	current_slot = null
	is_dragging = false
	scale = Vector2.ONE

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_show_back_face()
	global_position = start_global_position

	var target_global_position: Vector2 = target_slot.get_global_rect().position

	var move_tween = create_tween()
	move_tween.tween_property(self, "global_position", target_global_position, 0.18)
	await move_tween.finished

	var placed: bool = target_slot.place_card(self)
	if not placed:
		print("오프닝 배치 실패 / 슬롯:", target_slot.slot_no)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_free()
		return

	_flip_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP

	print("오프닝 배치 완료 / 슬롯:", target_slot.slot_no)

func _end_drag() -> void:
	is_dragging = false

	var target_slot: FieldSlot = _find_target_slot()

	if target_slot != null and target_slot.card == null:
		var placed: bool = target_slot.place_card(self)
		if placed:
			print("드래그 종료 / 새 슬롯 배치 성공:", target_slot.slot_no)

			if source_pile_type != "":
				_flip_to_front()

				if card_state != null:
					pile_drag_finished.emit(card_state, source_pile_type, true)

			source_pile_type = ""
			_request_combo_refresh()
			return

	_return_after_failed_drop()

func _find_target_slot() -> FieldSlot:
	var mouse_position: Vector2 = get_global_mouse_position()

	for slot in get_tree().get_nodes_in_group("field_slots"):
		if slot is FieldSlot:
			var field_slot: FieldSlot = slot as FieldSlot

			if field_slot.side != card_side:
				continue

			if field_slot.get_global_rect().has_point(mouse_position):
				return field_slot

	return null

func _return_after_failed_drop() -> void:
	if original_slot != null:
		var returned: bool = original_slot.place_card(self)

		if returned:
			print("원래 슬롯으로 복귀:", original_slot.slot_no)
			_request_combo_refresh()
		return

	if source_pile_type != "" and card_state != null:
		pile_drag_finished.emit(card_state, source_pile_type, false)

	print("배치 실패 / 더미 카드 제거")
	queue_free()

func _start_combo_drag_from_field() -> bool:
	if current_slot == null:
		return false

	var battle_scene = get_tree().current_scene
	if battle_scene == null:
		return false

	if not battle_scene.has_method("get_combo_data_for_card"):
		return false

	var found_combo: Dictionary = battle_scene.get_combo_data_for_card(self)
	if found_combo.is_empty():
		return false

	var cards_value = found_combo.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return false

	var slot_nos_value = found_combo.get("slot_nos", [])
	if typeof(slot_nos_value) != TYPE_ARRAY:
		return false

	# 핵심 수정:
	# 원본 combo 딕셔너리를 직접 잡지 말고 복사본으로 저장
	combo_drag_data = {
		"combo_type": String(found_combo.get("combo_type", "")),
		"slot_nos": (slot_nos_value as Array).duplicate(),
		"cards": (cards_value as Array).duplicate(),
		"leader_card": self
	}

	if battle_scene.has_method("clear_selected_field_card"):
		battle_scene.clear_selected_field_card()

	is_combo_dragging = true
	_create_combo_drag_preview()

	print("조합 드래그 시작 / 리더:", card_name, "/ 타입:", String(combo_drag_data.get("combo_type", "")))
	return true

func _end_combo_drag() -> void:
	is_combo_dragging = false
	is_field_press_pending = false
	_destroy_combo_drag_preview()

	var battle_scene = get_tree().current_scene
	if battle_scene == null:
		combo_drag_data = {}
		return

	if not battle_scene.has_method("try_use_combo_by_leader"):
		combo_drag_data = {}
		return

	var used: bool = battle_scene.try_use_combo_by_leader(self, get_global_mouse_position())

	if used:
		print("조합 드래그 종료 / 사용 성공")
	else:
		print("조합 드래그 종료 / 사용 취소")

	# 핵심 수정:
	# clear() 대신 새 딕셔너리로 교체해서 원본 조합 데이터 오염 방지
	combo_drag_data = {}

func _create_combo_drag_preview() -> void:
	_destroy_combo_drag_preview()

	if not combo_drag_data.has("cards"):
		return

	var cards_value = combo_drag_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return

	var cards: Array = cards_value as Array

	var left_x: float = INF
	var right_x: float = -INF
	var top_y: float = INF
	var bottom_y: float = -INF

	for combo_card_variant in cards:
		var typed_card: TestCard = combo_card_variant as TestCard
		if typed_card == null:
			continue
		if typed_card.current_slot == null:
			continue

		var rect: Rect2 = typed_card.current_slot.get_global_rect()

		left_x = min(left_x, rect.position.x)
		right_x = max(right_x, rect.position.x + rect.size.x)
		top_y = min(top_y, rect.position.y)
		bottom_y = max(bottom_y, rect.position.y + rect.size.y)

	if left_x == INF:
		return

	combo_drag_start_top_left_global = Vector2(left_x, top_y)

	combo_drag_preview = Panel.new()
	combo_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_drag_preview.global_position = combo_drag_start_top_left_global
	combo_drag_preview.size = Vector2(right_x - left_x, bottom_y - top_y)
	combo_drag_preview.z_index = 500

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.0, 0.14)
	style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	combo_drag_preview.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, -24)
	label.size = Vector2(combo_drag_preview.size.x, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))

	if String(combo_drag_data.get("combo_type", "")) == "strike":
		label.text = "STRIKE"
	else:
		label.text = "HARMONY"

	combo_drag_preview.add_child(label)

	var battle_scene = get_tree().current_scene
	if battle_scene != null:
		battle_scene.add_child(combo_drag_preview)

func _destroy_combo_drag_preview() -> void:
	if combo_drag_preview != null and is_instance_valid(combo_drag_preview):
		combo_drag_preview.queue_free()

	combo_drag_preview = null

func _show_front_face() -> void:
	is_face_up = true

	if has_node("ColorRect"):
		$ColorRect.color = _get_front_color_by_combo_id()

	_update_card_labels()

	if has_node("CardNameLabel"):
		$CardNameLabel.visible = true

	if has_node("CardNumberLabel"):
		$CardNumberLabel.visible = true

func _show_back_face() -> void:
	is_face_up = false

	if has_node("ColorRect"):
		$ColorRect.color = Color(0.75, 0.1, 0.75, 1.0)

	if has_node("CardNameLabel"):
		$CardNameLabel.visible = false

	if has_node("CardNumberLabel"):
		$CardNumberLabel.visible = false

func _flip_to_front() -> void:
	if is_face_up:
		return

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.0, 1.0), 0.08)
	tween.tween_callback(Callable(self, "_show_front_face"))
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

func _ensure_card_labels() -> void:
	if not has_node("CardNameLabel"):
		var name_label := Label.new()
		name_label.name = "CardNameLabel"
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(0, 8)
		name_label.size = Vector2(size.x, 24)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		add_child(name_label)

	if not has_node("CardNumberLabel"):
		var number_label := Label.new()
		number_label.name = "CardNumberLabel"
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_label.position = Vector2(0, 60)
		number_label.size = Vector2(size.x, 90)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 34)
		number_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		add_child(number_label)

func _ensure_selection_outline() -> void:
	if has_node("SelectionOutline"):
		return

	var outline := Panel.new()
	outline.name = "SelectionOutline"
	outline.position = Vector2(4, 4)
	outline.size = size - Vector2(8, 8)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

	outline.add_theme_stylebox_override("panel", style)
	add_child(outline)

func _update_card_labels() -> void:
	if has_node("CardNameLabel"):
		$CardNameLabel.text = card_name

	if has_node("CardNumberLabel"):
		$CardNumberLabel.text = _get_number_text_from_card_name()

func _make_card_name_from_state(state) -> String:
	if state == null:
		return "테스트 카드"

	if "card_name" in state and String(state.card_name) != "":
		return String(state.card_name)

	var color_name := ""

	match int(state.combo_id):
		1001:
			color_name = "빨강"
		1002:
			color_name = "파랑"
		1003:
			color_name = "초록"
		1004:
			color_name = "노랑"
		_:
			color_name = "기타"

	var number := ((int(state.data_id) - 101) % 3) + 1
	return "%s_%02d" % [color_name, number]

func _get_number_text_from_card_name() -> String:
	if card_name == "":
		return ""

	var parts := card_name.split("_")
	if parts.size() < 2:
		return ""

	return parts[1]

func _get_front_color_by_combo_id() -> Color:
	if card_state == null:
		return Color(0.95, 0.85, 0.35, 1.0)

	match int(card_state.combo_id):
		1001:
			return Color(0.90, 0.30, 0.30, 1.0)
		1002:
			return Color(0.30, 0.55, 0.90, 1.0)
		1003:
			return Color(0.30, 0.80, 0.40, 1.0)
		1004:
			return Color(0.95, 0.85, 0.35, 1.0)
		_:
			return Color(0.70, 0.70, 0.70, 1.0)

func set_selected_visual(is_selected: bool) -> void:
	if not has_node("SelectionOutline"):
		return

	$SelectionOutline.visible = is_selected

func _request_combo_refresh() -> void:
	var battle_scene = get_tree().current_scene
	if battle_scene != null and battle_scene.has_method("refresh_player_combos"):
		battle_scene.refresh_player_combos()
