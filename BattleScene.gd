extends Node2D

const TEST_CARD_SCENE = preload("res://test_card.tscn")
const CardStateScript = preload("res://CardState.gd")

@onready var player_field_layer: Control = $Layer1_PlayerField
@onready var deck_body: PileBody = $Layer1_PlayerField/Deck
@onready var grave_body: PileBody = $Layer1_PlayerField/Grave
@onready var deck_info_button: Button = $Layer1_PlayerField/DeckInfoButton
@onready var end_turn_button: Button = $Layer0_UI/EndTurnButton
@onready var grave_info_button: Button = $Layer1_PlayerField/GraveInfoButton


var deck_cards: Array = []
var grave_cards: Array = []
var next_instance_id: int = 1

var is_opening_deal_in_progress: bool = false
var is_refill_draw_in_progress: bool = false
var selected_field_card: TestCard = null

var player_combos: Array = []
var combo_overlay_nodes: Array = []

var pile_popup_layer: CanvasLayer = null
var pile_popup_overlay: ColorRect = null
var pile_popup_panel: Panel = null
var pile_popup_title_label: Label = null
var pile_popup_count_label: Label = null
var pile_popup_scroll: ScrollContainer = null
var pile_popup_cards_grid: GridContainer = null
var current_popup_pile_type: String = ""

func _ready() -> void:
	_fix_scene_input_layers()
	_connect_pile_signals()
	_connect_ui_signals()
	_build_start_deck()
	_create_pile_popup()
	_print_pile_counts("초기화 완료")

	await get_tree().process_frame
	await _deal_opening_player_field()
	refresh_player_combos()

func _fix_scene_input_layers() -> void:
	var ignore_paths: Array[String] = [
		"Layer1_PlayerField/ColorRect",
		"Layer2_MonsterField",
		"Layer2_MonsterField/ColorRect"
	]

	for node_path in ignore_paths:
		if not has_node(node_path):
			continue

		var node: Node = get_node(node_path)
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_pile_signals() -> void:
	if deck_body != null:
		deck_body.drag_requested.connect(_on_pile_drag_requested)

	if grave_body != null:
		grave_body.drag_requested.connect(_on_pile_drag_requested)

func _connect_ui_signals() -> void:
	if deck_info_button != null:
		deck_info_button.pressed.connect(_on_deck_info_button_pressed)

	if grave_info_button != null:
		grave_info_button.pressed.connect(_on_grave_info_button_pressed)

	if end_turn_button != null:
		if not end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
			end_turn_button.pressed.connect(_on_end_turn_button_pressed)
		print("EndTurnButton 연결 완료 / 실제 경로 사용")

func _on_deck_info_button_pressed() -> void:
	if current_popup_pile_type == "deck" and pile_popup_overlay != null and pile_popup_overlay.visible:
		_hide_pile_popup()
		return

	_show_pile_popup("deck")

func _on_grave_info_button_pressed() -> void:
	if current_popup_pile_type == "grave" and pile_popup_overlay != null and pile_popup_overlay.visible:
		_hide_pile_popup()
		return

	_show_pile_popup("grave")

func _on_end_turn_button_pressed() -> void:
	if is_opening_deal_in_progress:
		print("턴 종료 무시 / 오프닝 배치 중")
		return

	if is_refill_draw_in_progress:
		print("턴 종료 무시 / 드로우 배치 중")
		return

	await _refill_empty_player_slots_from_piles()


func _build_start_deck() -> void:
	deck_cards.clear()
	grave_cards.clear()
	next_instance_id = 1

	var color_names: Array[String] = ["빨강", "파랑", "초록", "노랑"]

	for group_index in range(4):
		var combo_id: int = 1001 + group_index
		var color_name: String = color_names[group_index]

		for number_index in range(3):
			var data_id: int = 101 + group_index * 3 + number_index
			var card_name: String = "%s_%02d" % [color_name, number_index + 1]
			var new_card = _create_card_state(data_id, combo_id, card_name, "player")
			deck_cards.append(new_card)

	deck_cards.shuffle()

	print("시작 덱 생성 완료 / 총 장수:", deck_cards.size())
	for card_state in deck_cards:
		print("덱 카드:", card_state.to_log_string())

func _create_card_state(data_id: int, combo_id: int, card_name: String, owner_side: String):
	var new_card = CardStateScript.new()
	new_card.instance_id = next_instance_id
	new_card.data_id = data_id
	new_card.combo_id = combo_id
	new_card.card_name = card_name
	new_card.owner_side = owner_side

	next_instance_id += 1
	return new_card

func _on_pile_drag_requested(pile_type: String) -> void:
	if is_opening_deal_in_progress:
		print("오프닝 7장 배치 중 / 드래그 요청 무시:", pile_type)
		return

	if is_refill_draw_in_progress:
		print("빈 슬롯 드로우 중 / 드래그 요청 무시:", pile_type)
		return

	print("배틀씬에서 드래그 요청 받음:", pile_type)

	if pile_type == "deck":
		_spawn_drag_card_from_pile("deck")
		return

	if pile_type == "grave":
		_spawn_drag_card_from_pile("grave")
		return

func _spawn_drag_card_from_pile(pile_type: String) -> void:
	var card_state = _pop_card_from_pile(pile_type)

	if card_state == null:
		print("카드 생성 실패 /", pile_type, "이 비어 있음")
		return

	var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
	add_child(card_instance)

	card_instance.setup_from_card_state(card_state)
	card_instance.pile_drag_finished.connect(_on_pile_drag_finished)
	card_instance.start_drag_from_pile(pile_type, get_global_mouse_position())

	print("더미 카드 생성 완료 / 출처:", pile_type, "/", card_state.to_log_string())
	_print_pile_counts("드래그 시작 후")
	_refresh_open_pile_popup()

func _pop_card_from_pile(pile_type: String):
	if pile_type == "deck":
		if deck_cards.is_empty():
			return null
		return deck_cards.pop_back()

	if pile_type == "grave":
		if grave_cards.is_empty():
			return null
		return grave_cards.pop_back()

	return null

func _push_card_back_to_pile(pile_type: String, card_state) -> void:
	if card_state == null:
		return

	if pile_type == "deck":
		deck_cards.append(card_state)
		return

	if pile_type == "grave":
		grave_cards.append(card_state)
		return

func _on_pile_drag_finished(card_state, pile_type: String, placed: bool) -> void:
	if placed:
		print("파일 카드 배치 성공 / 출처:", pile_type, "/", card_state.to_log_string())
		_print_pile_counts("배치 성공 후")
		refresh_player_combos()
		_refresh_open_pile_popup()
		return

	_push_card_back_to_pile(pile_type, card_state)
	print("파일 카드 배치 실패 / 원래 더미로 복귀:", pile_type, "/", card_state.to_log_string())
	_print_pile_counts("배치 실패 후")
	refresh_player_combos()
	_refresh_open_pile_popup()

func _print_pile_counts(context: String) -> void:
	print("-----", context, "-----")
	print("deck_cards:", deck_cards.size())
	print("grave_cards:", grave_cards.size())

func _deal_opening_player_field() -> void:
	is_opening_deal_in_progress = true

	print("===== 오프닝 7장 배치 시작 =====")

	for slot_no in range(1, 8):
		var target_slot: FieldSlot = _get_player_slot(slot_no)
		if target_slot == null:
			print("오프닝 배치 실패 / PlayerSlot%d 없음" % slot_no)
			continue

		var card_state = _pop_card_from_pile("deck")
		if card_state == null:
			print("오프닝 배치 중단 / 덱이 비어 있음")
			break

		var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
		add_child(card_instance)

		card_instance.setup_from_card_state(card_state)

		var start_position: Vector2 = _get_pile_card_start_position(deck_body)
		await card_instance.deal_from_pile_to_slot(start_position, target_slot)

		_print_pile_counts("오프닝 슬롯 %d 배치 후" % slot_no)
		await get_tree().create_timer(0.06).timeout

	print("===== 오프닝 7장 배치 종료 =====")
	is_opening_deal_in_progress = false

func _refill_empty_player_slots_from_piles() -> void:
	is_refill_draw_in_progress = true
	clear_selected_field_card()

	var empty_slots: Array = _get_empty_player_slots_left_to_right()

	if empty_slots.is_empty():
		print("턴 종료 드로우 없음 / 빈 슬롯 없음")
		is_refill_draw_in_progress = false
		return

	print("===== 턴 종료 빈 슬롯 드로우 시작 =====")
	print("빈 슬롯 번호:", _make_slot_no_array(empty_slots))

	for slot_variant in empty_slots:
		var target_slot: FieldSlot = slot_variant as FieldSlot
		if target_slot == null:
			continue

		if target_slot.card != null:
			continue

		# 슬더스 방식:
		# 드로우를 실제로 진행하다가 덱이 0일 때만 무덤을 섞어 덱으로 만든다.
		if deck_cards.is_empty():
			if grave_cards.is_empty():
				print("턴 종료 드로우 중단 / 덱과 무덤 모두 비어 있음")
				break

			_merge_grave_into_deck_and_shuffle()

			if deck_cards.is_empty():
				print("턴 종료 드로우 중단 / 합친 뒤에도 덱이 비어 있음")
				break

		var card_state = _pop_card_from_pile("deck")
		if card_state == null:
			print("턴 종료 드로우 중단 / 덱 팝 실패")
			break

		var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
		add_child(card_instance)
		card_instance.setup_from_card_state(card_state)

		var start_position: Vector2 = _get_pile_card_start_position(deck_body)
		await card_instance.deal_from_pile_to_slot(start_position, target_slot)

		_print_pile_counts("턴 종료 슬롯 %d 배치 후" % target_slot.slot_no)
		_refresh_open_pile_popup()
		await get_tree().create_timer(0.06).timeout

	print("===== 턴 종료 빈 슬롯 드로우 종료 =====")
	is_refill_draw_in_progress = false
	refresh_player_combos()
	_refresh_open_pile_popup()

func _get_empty_player_slots_left_to_right() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		var slot: FieldSlot = _get_player_slot(slot_no)
		if slot == null:
			continue

		if slot.card == null:
			result.append(slot)

	return result

func _make_slot_no_array(slots: Array) -> Array:
	var result: Array = []

	for slot_variant in slots:
		var slot: FieldSlot = slot_variant as FieldSlot
		if slot == null:
			continue

		result.append(slot.slot_no)

	return result

func _merge_grave_into_deck_and_shuffle() -> void:
	if grave_cards.is_empty():
		return

	var moved_count: int = grave_cards.size()

	for card_state in grave_cards:
		deck_cards.append(card_state)

	grave_cards.clear()
	deck_cards.shuffle()

	print("무덤+덱 합치기 완료 / 이동 장수:", moved_count)
	_print_pile_counts("무덤 합치기 후")
	_refresh_open_pile_popup()

func _get_pile_card_start_position(pile_body: Control) -> Vector2:
	var pile_rect: Rect2 = pile_body.get_global_rect()
	var card_size: Vector2 = Vector2(150.0, 221.0)
	return pile_rect.position + (pile_rect.size - card_size) * 0.5

func on_field_card_clicked(card: TestCard) -> void:
	if card == null:
		return

	if card.current_slot == null:
		return

	if is_opening_deal_in_progress:
		return

	if is_refill_draw_in_progress:
		return

	if selected_field_card == null:
		selected_field_card = card
		if card.has_method("set_selected_visual"):
			card.set_selected_visual(true)
		print("필드 카드 선택 / 슬롯:", card.current_slot.slot_no, "/ 카드:", card.card_name)
		return

	if selected_field_card == card:
		clear_selected_field_card()
		print("필드 카드 선택 해제 / 카드:", card.card_name)
		return

	_try_move_or_swap_selected_card(card.current_slot)

func on_field_slot_clicked(slot: FieldSlot) -> void:
	if slot == null:
		return

	if slot.side != "player":
		return

	if is_opening_deal_in_progress:
		return

	if is_refill_draw_in_progress:
		return

	if selected_field_card == null:
		return

	_try_move_or_swap_selected_card(slot)

func _try_move_or_swap_selected_card(target_slot: FieldSlot) -> void:
	if selected_field_card == null:
		return

	var source_card: TestCard = selected_field_card
	var source_slot: FieldSlot = source_card.current_slot

	if source_slot == null:
		clear_selected_field_card()
		return

	if target_slot == source_slot:
		clear_selected_field_card()
		print("같은 슬롯 클릭 / 선택 해제")
		return

	if target_slot.card == null:
		source_slot.remove_card()
		var moved: bool = target_slot.place_card(source_card)

		clear_selected_field_card()

		if moved:
			print("클릭 이동 성공 /", source_slot.slot_no, "->", target_slot.slot_no)
		else:
			source_slot.place_card(source_card)
			print("클릭 이동 실패 / 원위치")

		refresh_player_combos()
		return

	var target_card = target_slot.card
	target_slot.remove_card()
	source_slot.remove_card()

	var placed_source: bool = target_slot.place_card(source_card)
	var placed_target: bool = source_slot.place_card(target_card)

	clear_selected_field_card()

	if placed_source and placed_target:
		print("클릭 교체 성공 /", source_slot.slot_no, "<->", target_slot.slot_no)
		refresh_player_combos()
		return

	if target_slot.card == source_card:
		target_slot.remove_card()
	if source_slot.card == target_card:
		source_slot.remove_card()

	source_slot.place_card(source_card)
	target_slot.place_card(target_card)
	print("클릭 교체 실패 / 원복")
	refresh_player_combos()

func clear_selected_field_card() -> void:
	if selected_field_card == null:
		return

	if selected_field_card.has_method("set_selected_visual"):
		selected_field_card.set_selected_visual(false)

	selected_field_card = null

func refresh_player_combos() -> void:
	player_combos.clear()
	_clear_combo_overlays()

	var player_slots: Array = _get_all_player_slots()
	var used_slot_nos: Dictionary = {}

	for start_idx in range(0, 5):
		var slot_a: FieldSlot = player_slots[start_idx] as FieldSlot
		var slot_b: FieldSlot = player_slots[start_idx + 1] as FieldSlot
		var slot_c: FieldSlot = player_slots[start_idx + 2] as FieldSlot

		if slot_a == null or slot_b == null or slot_c == null:
			continue

		if used_slot_nos.has(slot_a.slot_no) or used_slot_nos.has(slot_b.slot_no) or used_slot_nos.has(slot_c.slot_no):
			continue

		if slot_a.card == null or slot_b.card == null or slot_c.card == null:
			continue

		if slot_a.card.card_state == null or slot_b.card.card_state == null or slot_c.card.card_state == null:
			continue

		var combo_a: int = int(slot_a.card.card_state.combo_id)
		var combo_b: int = int(slot_b.card.card_state.combo_id)
		var combo_c: int = int(slot_c.card.card_state.combo_id)

		var combo_type: String = ""

		if combo_a == combo_b and combo_b == combo_c:
			combo_type = "strike"
		elif combo_a != combo_b and combo_a != combo_c and combo_b != combo_c:
			combo_type = "harmony"
		else:
			continue

		var combo_data: Dictionary = {
			"combo_type": combo_type,
			"slot_nos": [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no],
			"cards": [slot_a.card, slot_b.card, slot_c.card],
			"leader_card": null
		}

		player_combos.append(combo_data)

		used_slot_nos[slot_a.slot_no] = true
		used_slot_nos[slot_b.slot_no] = true
		used_slot_nos[slot_c.slot_no] = true

		_create_combo_overlay(slot_a, slot_b, slot_c, combo_type)

		print("조합 발견 / 타입:", combo_type, "/ 슬롯:", [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no])

func get_combo_data_for_card(card: TestCard) -> Dictionary:
	if card == null:
		return {}

	for combo_variant in player_combos:
		if typeof(combo_variant) != TYPE_DICTIONARY:
			continue

		var combo_data: Dictionary = combo_variant as Dictionary

		if not combo_data.has("cards"):
			continue

		var cards_value = combo_data.get("cards", [])
		if typeof(cards_value) != TYPE_ARRAY:
			continue

		var cards: Array = cards_value as Array

		if cards.has(card):
			return combo_data

	return {}

func try_use_combo_by_leader(leader_card: TestCard, mouse_global_position: Vector2) -> bool:
	if leader_card == null:
		return false

	var combo_data: Dictionary = get_combo_data_for_card(leader_card)
	if combo_data.is_empty():
		print("조합 사용 실패 / 리더 카드가 조합에 없음")
		return false

	var target_monster_slot: FieldSlot = _get_monster_slot_at_global_position(mouse_global_position)
	if target_monster_slot == null:
		print("조합 사용 실패 / 몬스터 슬롯 위가 아님")
		return false

	combo_data["leader_card"] = leader_card

	print("조합 사용 성공 / 타입:", combo_data.get("combo_type", ""), "/ 리더:", leader_card.card_name, "/ 대상 몬스터 슬롯:", target_monster_slot.slot_no)

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return false

	var combo_cards: Array = cards_value as Array

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue

		if combo_card.card_state != null:
			grave_cards.append(combo_card.card_state)

		if combo_card.current_slot != null and combo_card.current_slot.card == combo_card:
			combo_card.current_slot.remove_card()

		combo_card.queue_free()

	clear_selected_field_card()
	refresh_player_combos()
	_print_pile_counts("조합 사용 후")
	_refresh_open_pile_popup()

	return true

func _get_all_player_slots() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		result.append(_get_player_slot(slot_no))

	return result

func _get_player_slot(slot_no: int) -> FieldSlot:
	var slot_path: String = "Layer1_PlayerField/P_SlotStation/PlayerSlot%d" % slot_no

	if not has_node(slot_path):
		return null

	return get_node(slot_path) as FieldSlot

func _get_all_monster_slots() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		result.append(_get_monster_slot(slot_no))

	return result

func _get_monster_slot(slot_no: int) -> FieldSlot:
	var slot_path: String = "Layer2_MonsterField/M_SlotStation/MonsterSlot%d" % slot_no

	if not has_node(slot_path):
		return null

	return get_node(slot_path) as FieldSlot

func _get_monster_slot_at_global_position(mouse_global_position: Vector2) -> FieldSlot:
	var monster_slots: Array = _get_all_monster_slots()

	for slot_variant in monster_slots:
		var monster_slot: FieldSlot = slot_variant as FieldSlot
		if monster_slot == null:
			continue

		if monster_slot.get_global_rect().has_point(mouse_global_position):
			return monster_slot

	return null

func _clear_combo_overlays() -> void:
	for overlay_variant in combo_overlay_nodes:
		if is_instance_valid(overlay_variant):
			overlay_variant.queue_free()

	combo_overlay_nodes.clear()

func _create_combo_overlay(slot_a: FieldSlot, slot_b: FieldSlot, slot_c: FieldSlot, combo_type: String) -> void:
	if slot_a == null or slot_b == null or slot_c == null:
		return

	var rect_a: Rect2 = slot_a.get_global_rect()
	var rect_b: Rect2 = slot_b.get_global_rect()
	var rect_c: Rect2 = slot_c.get_global_rect()

	var left_x_global: float = min(rect_a.position.x, min(rect_b.position.x, rect_c.position.x))
	var right_x_global: float = max(rect_a.position.x + rect_a.size.x, max(rect_b.position.x + rect_b.size.x, rect_c.position.x + rect_c.size.x))
	var top_y_global: float = min(rect_a.position.y, min(rect_b.position.y, rect_c.position.y))
	var bottom_y_global: float = max(rect_a.position.y + rect_a.size.y, max(rect_b.position.y + rect_b.size.y, rect_c.position.y + rect_c.size.y))

	var field_origin_global: Vector2 = player_field_layer.get_global_rect().position

	var local_left_x: float = left_x_global - field_origin_global.x
	var local_top_y: float = top_y_global - field_origin_global.y
	var local_width: float = right_x_global - left_x_global
	var local_height: float = bottom_y_global - top_y_global

	var overlay: Panel = Panel.new()
	overlay.name = "ComboOverlay_%s" % combo_type
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.position = Vector2(local_left_x, local_top_y)
	overlay.size = Vector2(local_width, local_height)
	overlay.z_index = 100

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	overlay.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, -22)
	label.size = Vector2(overlay.size.x, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))

	if combo_type == "strike":
		label.text = "STRIKE"
	else:
		label.text = "HARMONY"

	overlay.add_child(label)
	player_field_layer.add_child(overlay)
	combo_overlay_nodes.append(overlay)

func _create_pile_popup() -> void:
	pile_popup_layer = CanvasLayer.new()
	pile_popup_layer.layer = 50
	add_child(pile_popup_layer)

	pile_popup_overlay = ColorRect.new()
	pile_popup_overlay.color = Color(0, 0, 0, 0.45)
	pile_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pile_popup_overlay.visible = false
	pile_popup_layer.add_child(pile_popup_overlay)

	pile_popup_panel = Panel.new()
	pile_popup_panel.size = Vector2(860, 420)
	pile_popup_overlay.add_child(pile_popup_panel)

	pile_popup_title_label = Label.new()
	pile_popup_title_label.position = Vector2(24, 18)
	pile_popup_title_label.size = Vector2(300, 28)
	pile_popup_title_label.add_theme_font_size_override("font_size", 22)
	pile_popup_panel.add_child(pile_popup_title_label)

	pile_popup_count_label = Label.new()
	pile_popup_count_label.position = Vector2(24, 52)
	pile_popup_count_label.size = Vector2(300, 24)
	pile_popup_count_label.add_theme_font_size_override("font_size", 16)
	pile_popup_panel.add_child(pile_popup_count_label)

	var close_button: Button = Button.new()
	close_button.text = "닫기"
	close_button.position = Vector2(760, 16)
	close_button.size = Vector2(72, 32)
	close_button.pressed.connect(_hide_pile_popup)
	pile_popup_panel.add_child(close_button)

	pile_popup_scroll = ScrollContainer.new()
	pile_popup_scroll.position = Vector2(24, 92)
	pile_popup_scroll.size = Vector2(812, 300)
	pile_popup_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	pile_popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pile_popup_panel.add_child(pile_popup_scroll)

	pile_popup_cards_grid = GridContainer.new()
	pile_popup_cards_grid.columns = 5
	pile_popup_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_popup_cards_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile_popup_scroll.add_child(pile_popup_cards_grid)

func _show_pile_popup(pile_type: String) -> void:
	if pile_popup_overlay == null:
		return

	current_popup_pile_type = pile_type
	pile_popup_overlay.size = get_viewport_rect().size
	pile_popup_panel.position = (pile_popup_overlay.size - pile_popup_panel.size) * 0.5
	_refresh_pile_popup()

	if pile_popup_scroll != null:
		pile_popup_scroll.scroll_vertical = 0

	pile_popup_overlay.visible = true

func _hide_pile_popup() -> void:
	if pile_popup_overlay == null:
		return

	pile_popup_overlay.visible = false
	current_popup_pile_type = ""

func _refresh_pile_popup() -> void:
	if pile_popup_title_label == null or pile_popup_count_label == null or pile_popup_cards_grid == null:
		return

	var target_cards: Array = _get_popup_target_cards()

	if current_popup_pile_type == "deck":
		pile_popup_title_label.text = "남은 덱 카드"
		pile_popup_count_label.text = "남은 카드 수: %d" % target_cards.size()
	elif current_popup_pile_type == "grave":
		pile_popup_title_label.text = "무덤 카드"
		pile_popup_count_label.text = "쌓인 카드 수: %d" % target_cards.size()
	else:
		pile_popup_title_label.text = "카드 목록"
		pile_popup_count_label.text = "카드 수: %d" % target_cards.size()

	for child in pile_popup_cards_grid.get_children():
		child.queue_free()

	if target_cards.is_empty():
		var empty_label: Label = Label.new()

		if current_popup_pile_type == "deck":
			empty_label.text = "덱이 비어 있습니다."
		elif current_popup_pile_type == "grave":
			empty_label.text = "무덤이 비어 있습니다."
		else:
			empty_label.text = "카드가 없습니다."

		empty_label.custom_minimum_size = Vector2(300, 40)
		empty_label.add_theme_font_size_override("font_size", 20)
		pile_popup_cards_grid.add_child(empty_label)
		return

	for card_state in target_cards:
		var card_view: Control = _create_popup_card(card_state)
		pile_popup_cards_grid.add_child(card_view)

func _get_popup_target_cards() -> Array:
	var source_cards: Array = []

	if current_popup_pile_type == "deck":
		source_cards = deck_cards
	elif current_popup_pile_type == "grave":
		source_cards = grave_cards
	else:
		return []

	var popup_cards: Array = source_cards.duplicate()
	popup_cards.sort_custom(Callable(self, "_sort_popup_card_states_for_popup"))
	return popup_cards

func _sort_popup_card_states_for_popup(a, b) -> bool:
	if a == null and b == null:
		return false
	if a == null:
		return false
	if b == null:
		return true

	var a_combo_id: int = int(a.combo_id)
	var b_combo_id: int = int(b.combo_id)

	if a_combo_id != b_combo_id:
		return a_combo_id < b_combo_id

	var a_data_id: int = int(a.data_id)
	var b_data_id: int = int(b.data_id)

	return a_data_id < b_data_id

func _refresh_open_pile_popup() -> void:
	if current_popup_pile_type == "":
		return

	if pile_popup_overlay == null:
		return

	if not pile_popup_overlay.visible:
		return

	_refresh_pile_popup()

func _create_popup_card(card_state) -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(150, 190)

	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(150, 190)
	bg.color = _get_popup_card_color_by_combo_id(int(card_state.combo_id))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var name_label: Label = Label.new()
	name_label.position = Vector2(0, 12)
	name_label.size = Vector2(150, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = _get_card_display_name(card_state)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var number_label: Label = Label.new()
	number_label.position = Vector2(0, 68)
	number_label.size = Vector2(150, 70)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.text = _get_card_number_text(card_state)
	number_label.add_theme_font_size_override("font_size", 34)
	number_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(number_label)

	return root

func _get_card_display_name(card_state) -> String:
	if card_state == null:
		return ""

	if "card_name" in card_state and String(card_state.card_name) != "":
		return String(card_state.card_name)

	var color_name: String = ""

	match int(card_state.combo_id):
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

	var number: int = ((int(card_state.data_id) - 101) % 3) + 1
	return "%s_%02d" % [color_name, number]

func _get_card_number_text(card_state) -> String:
	if card_state == null:
		return ""

	var display_name: String = _get_card_display_name(card_state)
	var parts: PackedStringArray = display_name.split("_")

	if parts.size() < 2:
		return ""

	return parts[1]

func _get_popup_card_color_by_combo_id(combo_id: int) -> Color:
	match combo_id:
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
