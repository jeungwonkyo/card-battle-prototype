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
var combo_drag_preview_cards: Array = []
var combo_drag_preview_outline: Panel = null
var combo_drag_preview_label: Label = null

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

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		return

	if is_combo_dragging and combo_drag_preview != null:
		var delta: Vector2 = get_global_mouse_position() - field_press_start_mouse_global
		_update_combo_drag_preview(delta)
		return

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

func set_current_slot(slot: FieldSlot) -> void:
	current_slot = slot

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		return

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
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_free()
		return

	_flip_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _end_drag() -> void:
	is_dragging = false

	var target_slot: FieldSlot = _find_target_slot()

	if target_slot != null and target_slot.card == null:
		var placed: bool = target_slot.place_card(self)
		if placed:
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
			_request_combo_refresh()
		return

	if source_pile_type != "" and card_state != null:
		pile_drag_finished.emit(card_state, source_pile_type, false)

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

	if combo_drag_preview == null:
		is_combo_dragging = false
		combo_drag_data = {}
		return false

	_set_combo_drag_source_cards_visible(false)
	return true

func _end_combo_drag() -> void:
	is_combo_dragging = false
	is_field_press_pending = false

	var used: bool = false
	var battle_scene = get_tree().current_scene

	if battle_scene != null and battle_scene.has_method("try_use_combo_by_leader"):
		used = battle_scene.try_use_combo_by_leader(self, get_global_mouse_position())

	if not used:
		_set_combo_drag_source_cards_visible(true)
		_destroy_combo_drag_preview()

	combo_drag_data = {}

func _create_combo_drag_preview() -> void:
	_destroy_combo_drag_preview()

	if not combo_drag_data.has("cards"):
		return

	var cards_value = combo_drag_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return

	var cards: Array = cards_value as Array
	if cards.is_empty():
		return

	combo_drag_preview = Panel.new()
	combo_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_drag_preview.global_position = Vector2.ZERO
	combo_drag_preview.size = get_viewport_rect().size
	combo_drag_preview.z_index = 500

	var root_style: StyleBoxFlat = StyleBoxFlat.new()
	root_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	combo_drag_preview.add_theme_stylebox_override("panel", root_style)

	combo_drag_preview_outline = Panel.new()
	combo_drag_preview_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_drag_preview.add_child(combo_drag_preview_outline)

	var outline_style: StyleBoxFlat = StyleBoxFlat.new()
	outline_style.bg_color = Color(1.0, 0.84, 0.0, 0.14)
	outline_style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	outline_style.border_width_left = 5
	outline_style.border_width_top = 5
	outline_style.border_width_right = 5
	outline_style.border_width_bottom = 5
	combo_drag_preview_outline.add_theme_stylebox_override("panel", outline_style)

	combo_drag_preview_label = Label.new()
	combo_drag_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_drag_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_drag_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_drag_preview_label.add_theme_font_size_override("font_size", 16)
	combo_drag_preview_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	combo_drag_preview_label.text = "HARMONY"
	if String(combo_drag_data.get("combo_type", "")) == "strike":
		combo_drag_preview_label.text = "STRIKE"
	combo_drag_preview.add_child(combo_drag_preview_label)

	combo_drag_preview_cards = []

	for combo_card_variant in cards:
		var typed_card: TestCard = combo_card_variant as TestCard
		if typed_card == null:
			continue
		if not is_instance_valid(typed_card):
			continue

		var preview_card: Control = _create_combo_drag_card_preview(typed_card)
		if preview_card == null:
			continue

		preview_card.set_meta("source_card_id", typed_card.get_instance_id())
		preview_card.set_meta("base_global_position", typed_card.get_global_rect().position)
		combo_drag_preview.add_child(preview_card)
		combo_drag_preview_cards.append(preview_card)

	var battle_scene = get_tree().current_scene
	if battle_scene != null:
		battle_scene.add_child(combo_drag_preview)

	_update_combo_drag_preview(Vector2.ZERO)

func _update_combo_drag_preview(delta: Vector2) -> void:
	if combo_drag_preview == null:
		return
	if combo_drag_preview_cards.is_empty():
		return

	var leader_card: TestCard = combo_drag_data.get("leader_card", null) as TestCard
	if leader_card == null:
		return

	var leader_index: int = -1
	var leader_base_global: Vector2 = Vector2.ZERO
	var leader_size: Vector2 = Vector2.ZERO
	var adjusted_positions: Array = []

	for i in range(combo_drag_preview_cards.size()):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			adjusted_positions.append(Vector2.ZERO)
			continue

		var source_card_id: int = int(preview_card.get_meta("source_card_id", 0))
		var base_global: Vector2 = preview_card.get_meta("base_global_position", Vector2.ZERO)

		if source_card_id == leader_card.get_instance_id():
			leader_index = i
			leader_base_global = base_global
			leader_size = preview_card.size

		adjusted_positions.append(base_global)

	if leader_index == -1:
		return

	var applied_delta: Vector2 = delta
	var move_bounds: Rect2 = _get_combo_drag_move_bounds()

	if move_bounds.size.x > 0.0 and move_bounds.size.y > 0.0:
		var desired_leader_global: Vector2 = leader_base_global + delta

		var min_x: float = move_bounds.position.x
		var max_x: float = move_bounds.position.x + move_bounds.size.x - leader_size.x
		if max_x < min_x:
			max_x = min_x

		var min_y: float = move_bounds.position.y
		var max_y: float = move_bounds.position.y + move_bounds.size.y - leader_size.y
		if max_y < min_y:
			max_y = min_y

		var clamped_leader_global := Vector2(
			clampf(desired_leader_global.x, min_x, max_x),
			clampf(desired_leader_global.y, min_y, max_y)
		)

		applied_delta = clamped_leader_global - leader_base_global

	for i in range(combo_drag_preview_cards.size()):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			continue

		var base_global: Vector2 = preview_card.get_meta("base_global_position", Vector2.ZERO)
		adjusted_positions[i] = base_global + applied_delta

	var viewport_rect: Rect2 = get_viewport_rect()
	var viewport_left: float = viewport_rect.position.x
	var viewport_right: float = viewport_rect.position.x + viewport_rect.size.x

	var combo_left_x: float = INF
	var combo_right_x: float = -INF

	for i in range(combo_drag_preview_cards.size()):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			continue

		var pos: Vector2 = adjusted_positions[i]
		combo_left_x = min(combo_left_x, pos.x)
		combo_right_x = max(combo_right_x, pos.x + preview_card.size.x)

	var left_overflow: float = maxf(0.0, viewport_left - combo_left_x)
	var right_overflow: float = maxf(0.0, combo_right_x - viewport_right)

	var left_count: int = leader_index
	var right_count: int = combo_drag_preview_cards.size() - leader_index - 1

	if left_overflow > 0.0 and left_count > 0:
		for i in range(leader_index):
			var ratio: float = float(left_count - i) / float(left_count)
			var pos: Vector2 = adjusted_positions[i]
			pos.x += left_overflow * ratio
			adjusted_positions[i] = pos

	if right_overflow > 0.0 and right_count > 0:
		for i in range(leader_index + 1, combo_drag_preview_cards.size()):
			var ratio: float = float(i - leader_index) / float(right_count)
			var pos: Vector2 = adjusted_positions[i]
			pos.x -= right_overflow * ratio
			adjusted_positions[i] = pos

	var left_x: float = INF
	var right_x: float = -INF
	var top_y: float = INF
	var bottom_y: float = -INF

	for i in range(combo_drag_preview_cards.size()):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			continue

		var pos: Vector2 = adjusted_positions[i]
		preview_card.global_position = pos

		left_x = min(left_x, pos.x)
		right_x = max(right_x, pos.x + preview_card.size.x)
		top_y = min(top_y, pos.y)
		bottom_y = max(bottom_y, pos.y + preview_card.size.y)

	if combo_drag_preview_outline != null and left_x != INF:
		combo_drag_preview_outline.global_position = Vector2(left_x, top_y)
		combo_drag_preview_outline.size = Vector2(right_x - left_x, bottom_y - top_y)

	if combo_drag_preview_label != null and left_x != INF:
		combo_drag_preview_label.global_position = Vector2(left_x, top_y - 24.0)
		combo_drag_preview_label.size = Vector2(right_x - left_x, 22.0)

	var battle_scene = get_tree().current_scene
	if battle_scene != null and battle_scene.has_method("update_combo_drag_target_highlight_by_point"):
		var leader_pos: Vector2 = adjusted_positions[leader_index]
		var target_point: Vector2 = _get_combo_drag_target_point(leader_pos, leader_size)
		battle_scene.update_combo_drag_target_highlight_by_point(target_point)

	if battle_scene != null and battle_scene.has_method("update_combo_drag_snapped_overlap_preview"):
		var snapped_card_rect_datas: Array = []

		if battle_scene.has_method("get_combo_drag_highlighted_monster_slot_for_preview"):
			var target_slot: FieldSlot = battle_scene.get_combo_drag_highlighted_monster_slot_for_preview()
			if target_slot != null:
				snapped_card_rect_datas = _get_snapped_combo_drag_preview_card_rect_datas(target_slot)

		battle_scene.update_combo_drag_snapped_overlap_preview(snapped_card_rect_datas)

func _get_combo_drag_move_bounds() -> Rect2:
	var battle_scene = get_tree().current_scene
	if battle_scene == null:
		return Rect2()

	if not battle_scene.has_node("Layer1_PlayerField/P_SlotStation"):
		return Rect2()

	if not battle_scene.has_node("Layer2_MonsterField/M_SlotStation"):
		return Rect2()

	var p_station: Control = battle_scene.get_node("Layer1_PlayerField/P_SlotStation") as Control
	var m_station: Control = battle_scene.get_node("Layer2_MonsterField/M_SlotStation") as Control

	if p_station == null or m_station == null:
		return Rect2()

	var p_rect: Rect2 = p_station.get_global_rect()
	var m_rect: Rect2 = m_station.get_global_rect()

	var left_x: float = min(p_rect.position.x, m_rect.position.x)
	var right_x: float = max(p_rect.position.x + p_rect.size.x, m_rect.position.x + m_rect.size.x)
	var bottom_y: float = max(p_rect.position.y + p_rect.size.y, m_rect.position.y + m_rect.size.y)
	var monster_mid_y: float = m_rect.position.y + (m_rect.size.y * 0.5)
	var top_y: float = monster_mid_y

	return Rect2(
		Vector2(left_x, top_y),
		Vector2(right_x - left_x, bottom_y - top_y)
	)

func _set_combo_drag_source_cards_visible(visible_state: bool) -> void:
	if not combo_drag_data.has("cards"):
		return

	var cards_value = combo_drag_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return

	var cards: Array = cards_value as Array

	for combo_card_variant in cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue

		combo_card.visible = visible_state

func _create_combo_drag_card_preview(source_card: TestCard) -> Control:
	if source_card == null:
		return null

	var preview_root: Control = Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.size = source_card.size

	var bg: ColorRect = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2.ZERO
	bg.size = source_card.size
	bg.color = Color(0.7, 0.7, 0.7, 1.0)

	if source_card.has_node("ColorRect"):
		var source_bg: ColorRect = source_card.get_node("ColorRect") as ColorRect
		if source_bg != null:
			bg.color = source_bg.color

	preview_root.add_child(bg)

	if source_card.is_face_up:
		var name_label: Label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(0, 8)
		name_label.size = Vector2(source_card.size.x, 24)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		name_label.text = source_card.card_name
		preview_root.add_child(name_label)

		var number_label: Label = Label.new()
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_label.position = Vector2(0, 60)
		number_label.size = Vector2(source_card.size.x, 90)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 34)
		number_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		number_label.text = source_card._get_number_text_from_card_name()
		preview_root.add_child(number_label)

	return preview_root

func _get_combo_drag_target_point(card_global_position: Vector2, card_size: Vector2) -> Vector2:
	return Vector2(
		card_global_position.x + (card_size.x * 0.5),
		card_global_position.y + (card_size.y * 0.25)
	)

func _get_combo_drag_preview_leader_index() -> int:
	if combo_drag_preview_cards.is_empty():
		return -1

	var leader_card: TestCard = combo_drag_data.get("leader_card", null) as TestCard
	if leader_card == null:
		return -1

	var leader_id: int = leader_card.get_instance_id()

	for i in range(combo_drag_preview_cards.size()):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		var source_card_id: int = int(preview_card.get_meta("source_card_id", 0))
		if source_card_id == leader_id:
			return i

	return -1

func _refresh_combo_drag_preview_layout_from_current_positions() -> void:
	if combo_drag_preview == null:
		return

	var left_x: float = INF
	var right_x: float = -INF
	var top_y: float = INF
	var bottom_y: float = -INF

	for preview_card_variant in combo_drag_preview_cards:
		var preview_card: Control = preview_card_variant as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		var pos: Vector2 = preview_card.global_position
		left_x = min(left_x, pos.x)
		right_x = max(right_x, pos.x + preview_card.size.x)
		top_y = min(top_y, pos.y)
		bottom_y = max(bottom_y, pos.y + preview_card.size.y)

	if left_x == INF:
		return

	if combo_drag_preview_outline != null:
		combo_drag_preview_outline.global_position = Vector2(left_x, top_y)
		combo_drag_preview_outline.size = Vector2(right_x - left_x, bottom_y - top_y)

	if combo_drag_preview_label != null:
		combo_drag_preview_label.global_position = Vector2(left_x, top_y - 24.0)
		combo_drag_preview_label.size = Vector2(right_x - left_x, 22.0)

func _get_snapped_combo_drag_preview_card_rect_datas(target_slot: FieldSlot) -> Array:
	var result: Array = []

	if combo_drag_preview == null:
		return result
	if target_slot == null:
		return result

	var leader_index: int = _get_combo_drag_preview_leader_index()
	if leader_index == -1:
		return result

	var leader_preview: Control = combo_drag_preview_cards[leader_index] as Control
	if leader_preview == null:
		return result
	if not is_instance_valid(leader_preview):
		return result

	var leader_pos: Vector2 = leader_preview.global_position
	var leader_size: Vector2 = leader_preview.size
	var target_rect: Rect2 = target_slot.get_global_rect()

	var target_x: float = target_rect.position.x + ((target_rect.size.x - leader_size.x) * 0.5)
	var target_y: float = leader_pos.y

	var move_bounds: Rect2 = _get_combo_drag_move_bounds()
	if move_bounds.size.y > 0.0:
		var max_drag_top_y: float = move_bounds.position.y
		if target_y > max_drag_top_y:
			target_y = max_drag_top_y

	var snap_delta: Vector2 = Vector2(
		target_x - leader_pos.x,
		target_y - leader_pos.y
	)

	for preview_card_variant in combo_drag_preview_cards:
		var preview_card: Control = preview_card_variant as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		result.append({
			"source_card_id": int(preview_card.get_meta("source_card_id", 0)),
			"rect": Rect2(preview_card.global_position + snap_delta, preview_card.size)
		})

	return result

func snap_combo_drag_preview_to_monster_slot(target_slot: FieldSlot) -> void:
	var snapped_card_rect_datas: Array = _get_snapped_combo_drag_preview_card_rect_datas(target_slot)
	if snapped_card_rect_datas.is_empty():
		return

	var rect_index: int = 0
	for preview_card_variant in combo_drag_preview_cards:
		var preview_card: Control = preview_card_variant as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue
		if rect_index >= snapped_card_rect_datas.size():
			break

		var rect_data: Dictionary = snapped_card_rect_datas[rect_index] as Dictionary
		var snapped_rect: Rect2 = rect_data.get("rect", Rect2())
		preview_card.global_position = snapped_rect.position
		rect_index += 1

	_refresh_combo_drag_preview_layout_from_current_positions()

	var battle_scene = get_tree().current_scene
	if battle_scene != null and battle_scene.has_method("update_combo_drag_snapped_overlap_preview"):
		battle_scene.update_combo_drag_snapped_overlap_preview(snapped_card_rect_datas)

	if battle_scene != null and battle_scene.has_method("update_combo_drag_target_highlight_by_point"):
		var leader_index: int = _get_combo_drag_preview_leader_index()
		if leader_index != -1:
			var leader_preview: Control = combo_drag_preview_cards[leader_index] as Control
			if leader_preview != null and is_instance_valid(leader_preview):
				var snapped_target_point: Vector2 = _get_combo_drag_target_point(
					leader_preview.global_position,
					leader_preview.size
				)
				battle_scene.update_combo_drag_target_highlight_by_point(snapped_target_point)

func _find_combo_drag_preview_card_by_source_card(source_card: TestCard) -> Control:
	if combo_drag_preview == null:
		return null
	if source_card == null:
		return null

	var source_card_id: int = source_card.get_instance_id()

	for preview_card_variant in combo_drag_preview_cards:
		var preview_card: Control = preview_card_variant as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		var preview_source_id: int = int(preview_card.get_meta("source_card_id", 0))
		if preview_source_id == source_card_id:
			return preview_card

	return null

func play_combo_dash_hit_preview(source_card: TestCard, target_slot_no: int) -> void:
	var preview_card: Control = _find_combo_drag_preview_card_by_source_card(source_card)
	if preview_card == null:
		return
	if not is_instance_valid(preview_card):
		return
	if target_slot_no <= 0:
		return
	if combo_drag_preview == null:
		return
	if not is_instance_valid(combo_drag_preview):
		return

	var battle_scene: Node = combo_drag_preview.get_parent()
	if battle_scene == null:
		return

	var slot_path: String = "Layer2_MonsterField/M_SlotStation/MonsterSlot%d" % target_slot_no
	if not battle_scene.has_node(slot_path):
		return

	var target_slot: FieldSlot = battle_scene.get_node(slot_path) as FieldSlot
	if target_slot == null:
		return

	var target_rect: Rect2 = target_slot.get_global_rect()
	var start_pos: Vector2 = preview_card.global_position
	var target_x: float = target_rect.position.x + ((target_rect.size.x - preview_card.size.x) * 0.5)

	if absf(target_x - start_pos.x) < 1.0:
		return

	var step_count: int = 5

	for step in range(1, step_count + 1):
		if not is_instance_valid(preview_card):
			return
		if combo_drag_preview == null:
			return
		if not is_instance_valid(combo_drag_preview):
			return

		var t: float = float(step) / float(step_count)
		var next_x: float = lerpf(start_pos.x, target_x, t)

		preview_card.global_position = Vector2(next_x, start_pos.y)
		_refresh_combo_drag_preview_layout_from_current_positions()

		var tree := combo_drag_preview.get_tree()
		if tree != null:
			await tree.create_timer(0.02).timeout

func play_combo_contact_hit_preview(source_card: TestCard) -> void:
	var preview_card: Control = _find_combo_drag_preview_card_by_source_card(source_card)
	if preview_card == null:
		return
	if not is_instance_valid(preview_card):
		return

	var start_pos: Vector2 = preview_card.global_position
	var hit_pos: Vector2 = start_pos + Vector2(0, 8)
	var start_scale: Vector2 = preview_card.scale
	var hit_scale: Vector2 = Vector2(start_scale.x * 1.04, start_scale.y * 0.96)

	preview_card.global_position = hit_pos
	preview_card.scale = hit_scale
	_refresh_combo_drag_preview_layout_from_current_positions()

	if is_inside_tree():
		await get_tree().create_timer(0.04).timeout

	if not is_instance_valid(preview_card):
		return

	preview_card.global_position = start_pos
	preview_card.scale = start_scale
	_refresh_combo_drag_preview_layout_from_current_positions()

	if is_inside_tree():
		await get_tree().create_timer(0.05).timeout

func consume_combo_drag_preview_card(source_card: TestCard) -> void:
	if combo_drag_preview == null:
		return
	if source_card == null:
		return

	var source_card_id: int = source_card.get_instance_id()

	for i in range(combo_drag_preview_cards.size() - 1, -1, -1):
		var preview_card: Control = combo_drag_preview_cards[i] as Control
		if preview_card == null:
			combo_drag_preview_cards.remove_at(i)
			continue
		if not is_instance_valid(preview_card):
			combo_drag_preview_cards.remove_at(i)
			continue

		var preview_source_id: int = int(preview_card.get_meta("source_card_id", 0))
		if preview_source_id == source_card_id:
			combo_drag_preview_cards.remove_at(i)
			preview_card.queue_free()
			break

	_refresh_combo_drag_preview_layout_after_consume()

func finish_combo_drag_attack_preview() -> void:
	_destroy_combo_drag_preview()

func _refresh_combo_drag_preview_layout_after_consume() -> void:
	if combo_drag_preview == null:
		return

	var left_x: float = INF
	var right_x: float = -INF
	var top_y: float = INF
	var bottom_y: float = -INF

	for preview_card_variant in combo_drag_preview_cards:
		var preview_card: Control = preview_card_variant as Control
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		var pos: Vector2 = preview_card.global_position
		left_x = min(left_x, pos.x)
		right_x = max(right_x, pos.x + preview_card.size.x)
		top_y = min(top_y, pos.y)
		bottom_y = max(bottom_y, pos.y + preview_card.size.y)

	if left_x == INF:
		_destroy_combo_drag_preview()
		return

	if combo_drag_preview_outline != null:
		combo_drag_preview_outline.global_position = Vector2(left_x, top_y)
		combo_drag_preview_outline.size = Vector2(right_x - left_x, bottom_y - top_y)

	if combo_drag_preview_label != null:
		combo_drag_preview_label.global_position = Vector2(left_x, top_y - 24.0)
		combo_drag_preview_label.size = Vector2(right_x - left_x, 22.0)

func _destroy_combo_drag_preview() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var battle_scene = tree.current_scene
			if battle_scene != null and battle_scene.has_method("clear_combo_drag_target_highlight"):
				battle_scene.clear_combo_drag_target_highlight()

	if combo_drag_preview != null and is_instance_valid(combo_drag_preview):
		combo_drag_preview.queue_free()

	combo_drag_preview = null
	combo_drag_preview_cards = []
	combo_drag_preview_outline = null
	combo_drag_preview_label = null

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
