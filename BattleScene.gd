extends Node2D

const TEST_CARD_SCENE = preload("res://test_card.tscn")
const CardStateScript = preload("res://CardState.gd")
const MonsterActionSystemScript = preload("res://MonsterActionSystem.gd")
const CardStatSystemScript = preload("res://CardStatSystem.gd")

@onready var player_field_layer: Control = $Layer1_PlayerField
@onready var deck_body: PileBody = $Layer1_PlayerField/Deck
@onready var grave_body: PileBody = $Layer1_PlayerField/Grave
@onready var deck_info_button: Button = $Layer1_PlayerField/DeckInfoButton
@onready var grave_info_button: Button = $Layer1_PlayerField/GraveInfoButton
@onready var end_turn_button: Button = $Layer0_UI/EndTurnButton
@onready var player_status_ui: PlayerStatusUI = $Layer0_UI/PlayerStatusUI as PlayerStatusUI

@export_node_path("Node") var final_objective_path: NodePath
var final_objective: Node = null

var deck_cards: Array = []
var grave_cards: Array = []
var next_instance_id: int = 1

# 런 중 바뀔 수 있는 전투 값
var default_card_level: int = 2
var strike_combo_multiplier: int = 3
var harmony_combo_multiplier: int = 2
var monster_start_hp: int = 20

# 테스트 중 여기 숫자만 바꾸면 바로 반영됨
var field_move_tp_cost: int = 2
var pile_draw_tp_cost: int = 2

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

# 테스트 몬스터 정보
var monster_hp_by_slot_no: Dictionary = {}
var monster_root_by_slot_no: Dictionary = {}
var monster_hp_label_by_slot_no: Dictionary = {}
var monster_is_face_down_by_slot_no: Dictionary = {}
var monster_is_flipping_by_slot_no: Dictionary = {}
var combo_drag_highlighted_monster_slot_no: int = 0
var combo_drag_preview_highlight_slot_nos: Array = []
var combo_drag_preview_card_target_slot_by_id: Dictionary = {}
var final_objective_combo_drag_highlighted: bool = false

var monster_action_system: MonsterActionSystem = null
var card_stat_system: CardStatSystem = null
var is_combo_attack_in_progress: bool = false

func _ready() -> void:
	_fix_scene_input_layers()
	_connect_pile_signals()
	_connect_ui_signals()
	_bind_final_objective()
	_setup_card_stat_system()
	_setup_monster_action_system()
	_build_start_deck()
	_create_pile_popup()
	_setup_test_monsters()
	_print_pile_counts("초기화 완료")

	await get_tree().process_frame
	await _deal_opening_player_field()
	refresh_player_combos()

func _setup_card_stat_system() -> void:
	if card_stat_system != null:
		return

	card_stat_system = CardStatSystemScript.new() as CardStatSystem
	if card_stat_system == null:
		print("카드 스탯 시스템 생성 실패")
		return

	card_stat_system.setup(strike_combo_multiplier, harmony_combo_multiplier)
	print("카드 스탯 시스템 연결 완료")

func _setup_monster_action_system() -> void:
	if monster_action_system != null and is_instance_valid(monster_action_system):
		return

	monster_action_system = MonsterActionSystemScript.new() as MonsterActionSystem
	if monster_action_system == null:
		print("몬스터 행동 시스템 생성 실패")
		return

	monster_action_system.name = "MonsterActionSystem"
	add_child(monster_action_system)
	monster_action_system.setup(self)

	print("몬스터 행동 시스템 연결 완료")

func _run_monster_action_phase(trigger_type: String) -> void:
	if monster_action_system == null:
		print("몬스터 행동 페이즈 실패 / 시스템 없음 / 트리거:", trigger_type)
		return

	if not is_instance_valid(monster_action_system):
		print("몬스터 행동 페이즈 실패 / 시스템 해제됨 / 트리거:", trigger_type)
		return

	await monster_action_system.run_action_phase(trigger_type)

func _bind_final_objective() -> void:
	final_objective = get_node_or_null(final_objective_path)

	if final_objective == null:
		print("최종목표 연결 실패 / final_objective_path 확인 필요")
		return

	print("최종목표 연결 완료:", final_objective.name)

func _can_use_player_status_ui() -> bool:
	return player_status_ui != null and is_instance_valid(player_status_ui)

func _try_spend_tp(cost: int, reason: String) -> bool:
	if cost <= 0:
		return true

	if not _can_use_player_status_ui():
		print("TP 사용 실패 / PlayerStatusUI 연결 필요 / 사유:", reason)
		return false

	if not player_status_ui.spend_tp(cost):
		print("TP 부족 / 사유:", reason, "/ 필요:", cost, "/ 현재 TP:", player_status_ui.get_tp())
		return false

	print("TP 사용 / 사유:", reason, "/ 소모:", cost, "/ 남은 TP:", player_status_ui.get_tp())
	return true

func _refund_tp(amount: int, reason: String) -> void:
	if amount <= 0:
		return

	if not _can_use_player_status_ui():
		return

	player_status_ui.add_tp(amount)
	print("TP 환불 / 사유:", reason, "/ 회복:", amount, "/ 현재 TP:", player_status_ui.get_tp())

func _has_alive_combo_target_slots(target_slot_nos: Array) -> bool:
	for slot_no_variant in target_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no <= 0:
			continue

		if _get_monster_current_hp(slot_no) > 0:
			return true

	return false

func is_all_monsters_defeated() -> bool:
	for slot_no in range(1, 8):
		if _get_monster_current_hp(slot_no) > 0:
			return false

	return true

func is_final_objective_highlighted_for_combo_drag() -> bool:
	return final_objective_combo_drag_highlighted

func get_final_objective_rect_for_combo_drag() -> Rect2:
	if final_objective == null:
		return Rect2()
	if not is_instance_valid(final_objective):
		return Rect2()
	if not final_objective.has_method("get_objective_rect"):
		return Rect2()

	return final_objective.call("get_objective_rect")

func _is_final_objective_combo_target_active() -> bool:
	return is_final_objective_highlighted_for_combo_drag() and _can_hit_final_objective()

func _set_final_objective_combo_drag_highlight(is_on: bool) -> void:
	final_objective_combo_drag_highlighted = is_on

	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("set_highlight"):
		return

	final_objective.call("set_highlight", is_on)

func _is_point_over_final_objective(target_point_global: Vector2) -> bool:
	if not is_all_monsters_defeated():
		return false

	if final_objective == null:
		return false
	if not is_instance_valid(final_objective):
		return false
	if not final_objective.has_method("get_objective_rect"):
		return false

	var objective_rect: Rect2 = final_objective.call("get_objective_rect")
	if objective_rect.size.x <= 0.0 or objective_rect.size.y <= 0.0:
		return false

	return objective_rect.has_point(target_point_global)
func _can_hit_final_objective() -> bool:
	if final_objective == null:
		return false

	if not is_instance_valid(final_objective):
		return false

	if not final_objective.has_method("get_hp"):
		return false

	return int(final_objective.call("get_hp")) > 0

func _damage_final_objective(damage: int) -> void:
	if damage <= 0:
		return

	if not _can_hit_final_objective():
		return

	var current_hp: int = int(final_objective.call("get_hp"))
	var next_hp: int = max(0, current_hp - damage)

	final_objective.call("set_hp", next_hp)

	print("최종목표 피격 / 피해:", damage, "/ 남은 HP:", next_hp)

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
		if not deck_info_button.pressed.is_connected(_on_deck_info_button_pressed):
			deck_info_button.pressed.connect(_on_deck_info_button_pressed)

	if grave_info_button != null:
		if not grave_info_button.pressed.is_connected(_on_grave_info_button_pressed):
			grave_info_button.pressed.connect(_on_grave_info_button_pressed)

	if end_turn_button != null:
		end_turn_button.text = "Turn End"
		end_turn_button.add_theme_font_size_override("font_size", 34)

		if not end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
			end_turn_button.pressed.connect(_on_end_turn_button_pressed)

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
	print("턴 종료 버튼 눌림")

	if is_opening_deal_in_progress:
		print("턴 종료 무시 / 오프닝 배치 중")
		return

	if is_refill_draw_in_progress:
		print("턴 종료 무시 / 드로우 배치 중")
		return

	await _run_monster_action_phase("turn_end")

	if _can_use_player_status_ui():
		player_status_ui.reset_tp_to_start()
		print("턴 시작 TP 초기화 / 현재 TP:", player_status_ui.get_tp())

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
	new_card.base_level = default_card_level
	new_card.temp_level_delta = 0

	next_instance_id += 1
	return new_card

func set_card_base_level(instance_id: int, new_level: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 기본 레벨 변경 실패 / instance_id:", instance_id)
		return

	card_state.set_base_level(new_level)
	_refresh_card_state_visuals(instance_id)
	refresh_player_combos()
	print("카드 기본 레벨 변경 / instance_id:", instance_id, "/ base_level:", card_state.base_level, "/ current_level:", card_state.get_current_level())

func add_card_base_level(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 기본 레벨 가산 실패 / instance_id:", instance_id)
		return

	card_state.add_base_level(delta)
	_refresh_card_state_visuals(instance_id)
	refresh_player_combos()
	print("카드 기본 레벨 가산 / instance_id:", instance_id, "/ delta:", delta, "/ base_level:", card_state.base_level, "/ current_level:", card_state.get_current_level())

func set_card_temp_level_delta(instance_id: int, new_delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 임시 레벨 변경 실패 / instance_id:", instance_id)
		return

	card_state.set_temp_level_delta(new_delta)
	_refresh_card_state_visuals(instance_id)
	refresh_player_combos()
	print("카드 임시 레벨 변경 / instance_id:", instance_id, "/ temp_level_delta:", card_state.temp_level_delta, "/ current_level:", card_state.get_current_level())

func add_card_temp_level_delta(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 임시 레벨 가산 실패 / instance_id:", instance_id)
		return

	card_state.add_temp_level_delta(delta)
	_refresh_card_state_visuals(instance_id)
	refresh_player_combos()
	print("카드 임시 레벨 가산 / instance_id:", instance_id, "/ delta:", delta, "/ temp_level_delta:", card_state.temp_level_delta, "/ current_level:", card_state.get_current_level())

func clear_card_temp_level_delta(instance_id: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 임시 레벨 초기화 실패 / instance_id:", instance_id)
		return

	card_state.clear_temp_level_delta()
	_refresh_card_state_visuals(instance_id)
	refresh_player_combos()
	print("카드 임시 레벨 초기화 / instance_id:", instance_id, "/ current_level:", card_state.get_current_level())
func _find_card_state_by_instance_id(instance_id: int) -> CardState:
	for card_state_variant in deck_cards:
		var deck_card_state: CardState = card_state_variant as CardState
		if deck_card_state == null:
			continue
		if int(deck_card_state.instance_id) == instance_id:
			return deck_card_state

	for card_state_variant in grave_cards:
		var grave_card_state: CardState = card_state_variant as CardState
		if grave_card_state == null:
			continue
		if int(grave_card_state.instance_id) == instance_id:
			return grave_card_state

	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if test_card.card_state == null:
			continue
		if int(test_card.card_state.instance_id) == instance_id:
			return test_card.card_state as CardState

	return null

func _refresh_card_state_visuals(instance_id: int) -> void:
	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if test_card.card_state == null:
			continue
		if int(test_card.card_state.instance_id) != instance_id:
			continue

		if test_card.has_method("refresh_from_card_state"):
			test_card.refresh_from_card_state()

func _collect_test_cards_recursive(root_node: Node, result: Array) -> void:
	for child in root_node.get_children():
		if child is TestCard:
			result.append(child)

		_collect_test_cards_recursive(child, result)

func set_combo_multiplier(combo_type: String, new_multiplier: int) -> void:
	if combo_type == "strike":
		strike_combo_multiplier = new_multiplier
	elif combo_type == "harmony":
		harmony_combo_multiplier = new_multiplier
	else:
		return

	if card_stat_system != null:
		card_stat_system.set_combo_multiplier(combo_type, new_multiplier)

	refresh_player_combos()
	print("조합 배수 변경 / 타입:", combo_type, "/ 값:", _get_combo_multiplier(combo_type))

func _get_card_level_from_card(card: TestCard) -> int:
	if card == null:
		return default_card_level

	if card.card_state == null:
		return default_card_level

	if card_stat_system == null:
		return int(card.card_state.get_current_level())

	return card_stat_system.get_current_level(card.card_state)

func _calculate_final_power_from_card_and_multiplier(card: TestCard, combo_multiplier: int) -> int:
	if card == null:
		return 0

	if card.card_state == null:
		return max(0, default_card_level * max(0, combo_multiplier))

	if card_stat_system == null:
		var fallback_level: int = _get_card_level_from_card(card)
		return max(0, fallback_level * max(0, combo_multiplier))

	return card_stat_system.calculate_final_power_from_multiplier(card.card_state, "", combo_multiplier)

func _calculate_final_power_from_card_and_combo_type(card: TestCard, combo_type: String) -> int:
	if card == null:
		return 0

	if card.card_state == null:
		return max(0, default_card_level * max(0, _get_combo_multiplier(combo_type)))

	if card_stat_system == null:
		return _calculate_final_power_from_card_and_multiplier(card, _get_combo_multiplier(combo_type))

	return card_stat_system.calculate_final_power(card.card_state, combo_type)

func _get_combo_multiplier(combo_type: String) -> int:
	if card_stat_system != null:
		return card_stat_system.get_combo_multiplier(combo_type)

	if combo_type == "strike":
		return strike_combo_multiplier

	if combo_type == "harmony":
		return harmony_combo_multiplier

	return 1

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
	if not _try_spend_tp(pile_draw_tp_cost, "%s 드로우" % pile_type):
		return

	var card_state = _pop_card_from_pile(pile_type)

	if card_state == null:
		_refund_tp(pile_draw_tp_cost, "%s 드로우 실패" % pile_type)
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

	_refund_tp(pile_draw_tp_cost, "%s 드로우 취소" % pile_type)
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
		await _flip_face_down_monsters_to_front_left_to_right()
		is_refill_draw_in_progress = false
		refresh_player_combos()
		_refresh_open_pile_popup()
		return

	print("===== 턴 종료 빈 슬롯 드로우 시작 =====")
	print("빈 슬롯 번호:", _make_slot_no_array(empty_slots))

	for slot_variant in empty_slots:
		var target_slot: FieldSlot = slot_variant as FieldSlot
		if target_slot == null:
			continue

		if target_slot.card != null:
			continue

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
	await _flip_face_down_monsters_to_front_left_to_right()
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
		if not _try_spend_tp(field_move_tp_cost, "필드 이동"):
			return

		source_slot.remove_card()
		var moved: bool = target_slot.place_card(source_card)

		clear_selected_field_card()

		if moved:
			print("클릭 이동 성공 /", source_slot.slot_no, "->", target_slot.slot_no)
		else:
			source_slot.place_card(source_card)
			_refund_tp(field_move_tp_cost, "필드 이동 실패 원복")
			print("클릭 이동 실패 / 원위치")

		refresh_player_combos()
		return

	if not _try_spend_tp(field_move_tp_cost, "필드 교체"):
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
	_refund_tp(field_move_tp_cost, "필드 교체 실패 원복")
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
	_clear_all_player_card_final_power_displays()

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

		var combo_multiplier: int = _get_combo_multiplier(combo_type)
		var combo_cards: Array = [slot_a.card, slot_b.card, slot_c.card]

		var combo_data: Dictionary = {
			"combo_type": combo_type,
			"combo_multiplier": combo_multiplier,
			"slot_nos": [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no],
			"cards": combo_cards,
			"leader_card": null
		}

		player_combos.append(combo_data)

		used_slot_nos[slot_a.slot_no] = true
		used_slot_nos[slot_b.slot_no] = true
		used_slot_nos[slot_c.slot_no] = true

		_apply_combo_final_power_displays(combo_cards, combo_type)
		_create_combo_overlay(slot_a, slot_b, slot_c, combo_type)

		print("조합 발견 / 타입:", combo_type, "/ 슬롯:", [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no])

func _clear_all_player_card_final_power_displays() -> void:
	for slot_variant in _get_all_player_slots():
		var player_slot: FieldSlot = slot_variant as FieldSlot
		if player_slot == null:
			continue
		if player_slot.card == null:
			continue

		var field_card: TestCard = player_slot.card as TestCard
		if field_card == null:
			continue
		if not is_instance_valid(field_card):
			continue

		if field_card.has_method("clear_final_power_display"):
			field_card.clear_final_power_display()

func _apply_combo_final_power_displays(combo_cards: Array, combo_type: String) -> void:
	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue

		var final_power: int = _calculate_final_power_from_card_and_combo_type(combo_card, combo_type)

		if combo_card.has_method("set_final_power_display"):
			combo_card.set_final_power_display(final_power)

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

func try_use_combo_by_leader(leader_card: TestCard, _mouse_global_position: Vector2) -> bool:
	if leader_card == null:
		return false

	if is_combo_attack_in_progress:
		print("조합 사용 실패 / 다른 조합 공격 진행 중")
		return false

	var combo_data: Dictionary = get_combo_data_for_card(leader_card)
	if combo_data.is_empty():
		print("조합 사용 실패 / 리더 카드가 조합에 없음")
		return false

	var use_final_objective: bool = _is_final_objective_combo_target_active()
	var target_monster_slot: FieldSlot = _get_combo_drag_highlighted_monster_slot()

	if use_final_objective:
		if leader_card.has_method("snap_combo_drag_preview_to_final_objective"):
			leader_card.snap_combo_drag_preview_to_final_objective()
	elif target_monster_slot != null:
		if leader_card.has_method("snap_combo_drag_preview_to_monster_slot"):
			leader_card.snap_combo_drag_preview_to_monster_slot(target_monster_slot)
	else:
		print("조합 사용 실패 / 하이라이트된 몬스터나 최종목표가 없음")
		return false

	combo_data["leader_card"] = leader_card

	var combo_type: String = String(combo_data.get("combo_type", ""))
	var combo_multiplier: int = _get_combo_multiplier(combo_type)

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return false

	var attack_plan: Dictionary = _build_combo_attack_plan(combo_data, leader_card)

	print(
		"조합 사용 시작 / 타입:", combo_type,
		"/ 배수:", combo_multiplier,
		"/ 리더:", leader_card.card_name,
		"/ 리더 타겟 슬롯:", int(attack_plan.get("leader_target_slot_no", 0)),
		"/ 리더 타겟 타입:", String(attack_plan.get("leader_target_type", "monster"))
	)

	clear_selected_field_card()
	player_combos.clear()
	_clear_combo_overlays()

	is_combo_attack_in_progress = true
	_play_combo_attack_sequence(combo_type, attack_plan, leader_card)

	return true

func _get_combo_drag_highlighted_monster_slot() -> FieldSlot:
	if combo_drag_highlighted_monster_slot_no <= 0:
		return null

	if _get_monster_current_hp(combo_drag_highlighted_monster_slot_no) <= 0:
		return null

	return _get_monster_slot(combo_drag_highlighted_monster_slot_no)

func _play_combo_attack_sequence(combo_type: String, attack_plan: Dictionary, leader_card: TestCard) -> void:
	var removed_card_instance_ids: Dictionary = {}
	var detached_cards_to_free: Array = []
	var preview_owner: TestCard = leader_card
	var attack_order_index: int = 1

	var attack_entries_value = attack_plan.get("entries", [])
	if typeof(attack_entries_value) != TYPE_ARRAY:
		attack_entries_value = []

	var attack_entries: Array = attack_entries_value as Array
	var leader_target_slot_no: int = int(attack_plan.get("leader_target_slot_no", 0))
	var leader_target_type: String = String(attack_plan.get("leader_target_type", "monster"))
	var is_final_objective_target: bool = leader_target_type == "final_objective"

	var overlap_priority_value = attack_plan.get("overlap_priority_slot_nos", [])
	if typeof(overlap_priority_value) != TYPE_ARRAY:
		overlap_priority_value = []

	var overlap_priority_slot_nos: Array = overlap_priority_value as Array

	for attack_entry_variant in attack_entries:
		if is_inside_tree():
			await get_tree().create_timer(0.3).timeout

		if attack_order_index == 1:
			if preview_owner != null and is_instance_valid(preview_owner):
				if preview_owner.has_method("hide_combo_drag_preview_overlay"):
					preview_owner.hide_combo_drag_preview_overlay()

		if typeof(attack_entry_variant) != TYPE_DICTIONARY:
			continue

		var attack_entry: Dictionary = attack_entry_variant as Dictionary
		var attack_card: TestCard = attack_entry.get("card", null) as TestCard

		if attack_card == null:
			continue
		if not is_instance_valid(attack_card):
			continue

		var target_slot_no: int = 0
		var is_fixed_overlap: bool = bool(attack_entry.get("is_fixed_overlap", false))

		if is_fixed_overlap:
			target_slot_no = int(attack_entry.get("target_slot_no", 0))
		else:
			target_slot_no = _resolve_non_overlapped_combo_target_slot_no(
				leader_target_slot_no,
				overlap_priority_slot_nos
			)
			
		var hit_damage: int = _calculate_final_power_from_card_and_combo_type(attack_card, combo_type)

		if is_final_objective_target:
			if preview_owner != null and is_instance_valid(preview_owner):
				if is_fixed_overlap:
					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)
				else:
					if preview_owner.has_method("play_combo_dash_hit_preview_to_final_objective"):
						await preview_owner.play_combo_dash_hit_preview_to_final_objective(attack_card)

					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)

			_damage_final_objective(hit_damage)
		elif target_slot_no > 0 and _get_monster_current_hp(target_slot_no) > 0:
			if preview_owner != null and is_instance_valid(preview_owner):
				if is_fixed_overlap:
					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)
				else:
					if preview_owner.has_method("play_combo_dash_hit_preview"):
						await preview_owner.play_combo_dash_hit_preview(attack_card, target_slot_no)

					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)

			await _play_monster_contact_hit_effect(target_slot_no)
			await _damage_monster(target_slot_no, hit_damage)
		elif not _has_alive_combo_target_slots(overlap_priority_slot_nos) and _can_hit_final_objective():
			if preview_owner != null and is_instance_valid(preview_owner):
				if preview_owner.has_method("play_combo_dash_hit_preview_to_final_objective"):
					await preview_owner.play_combo_dash_hit_preview_to_final_objective(attack_card)

				if preview_owner.has_method("play_combo_contact_hit_preview"):
					await preview_owner.play_combo_contact_hit_preview(attack_card)

			_damage_final_objective(hit_damage)
		else:
			print("조합 타격 실패 / 유효한 타겟 없음 / 카드:", attack_card.card_name)

		if preview_owner != null and is_instance_valid(preview_owner):
			if preview_owner.has_method("consume_combo_drag_preview_card"):
				preview_owner.consume_combo_drag_preview_card(attack_card)

		_send_combo_card_to_grave(attack_card, removed_card_instance_ids, detached_cards_to_free)
		_print_pile_counts("조합 타격 %d 후" % attack_order_index)

		attack_order_index += 1

	if preview_owner != null and is_instance_valid(preview_owner):
		if preview_owner.has_method("finish_combo_drag_attack_preview"):
			preview_owner.finish_combo_drag_attack_preview()

	for detached_card_variant in detached_cards_to_free:
		var detached_card: TestCard = detached_card_variant as TestCard
		if detached_card == null:
			continue
		if not is_instance_valid(detached_card):
			continue

		detached_card.queue_free()
	refresh_player_combos()
	_print_pile_counts("조합 사용 후")
	_refresh_open_pile_popup()
	clear_combo_drag_target_highlight()

	await _run_monster_action_phase("after_combo")

	is_combo_attack_in_progress = false

func _send_combo_card_to_grave(combo_card: TestCard, removed_card_instance_ids: Dictionary, detached_cards_to_free: Array) -> void:
	if combo_card == null:
		return
	if not is_instance_valid(combo_card):
		return

	var node_instance_id: int = combo_card.get_instance_id()
	if removed_card_instance_ids.has(node_instance_id):
		return

	removed_card_instance_ids[node_instance_id] = true

	if combo_card.card_state != null:
		grave_cards.append(combo_card.card_state)
		combo_card.card_state = null

	if combo_card.current_slot != null and combo_card.current_slot.card == combo_card:
		combo_card.current_slot.remove_card()

	detached_cards_to_free.append(combo_card)

func _build_combo_attack_plan(combo_data: Dictionary, leader_card: TestCard) -> Dictionary:
	var result: Dictionary = {
		"entries": [],
		"leader_target_slot_no": 0,
		"leader_target_type": "monster",
		"overlap_priority_slot_nos": []
	}

	if leader_card == null:
		return result

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return result

	var combo_cards: Array = cards_value as Array
	var is_final_objective_target: bool = _is_final_objective_combo_target_active()

	if is_final_objective_target:
		var final_objective_entries: Array = []
		var non_leader_cards: Array = []

		final_objective_entries.append({
			"card": leader_card,
			"target_slot_no": 0,
			"is_fixed_overlap": true
		})

		for combo_card_variant in combo_cards:
			var combo_card: TestCard = combo_card_variant as TestCard
			if combo_card == null:
				continue
			if combo_card == leader_card:
				continue

			non_leader_cards.append(combo_card)

		non_leader_cards.sort_custom(Callable(self, "_sort_cards_by_slot_no"))

		for combo_card_variant in non_leader_cards:
			var combo_card: TestCard = combo_card_variant as TestCard
			if combo_card == null:
				continue

			final_objective_entries.append({
				"card": combo_card,
				"target_slot_no": 0,
				"is_fixed_overlap": false
			})

		result["entries"] = final_objective_entries
		result["leader_target_type"] = "final_objective"
		return result

	var leader_card_id: int = leader_card.get_instance_id()
	var leader_target_slot_no: int = int(
		combo_drag_preview_card_target_slot_by_id.get(
			leader_card_id,
			combo_drag_highlighted_monster_slot_no
		)
	)

	if _get_monster_current_hp(leader_target_slot_no) <= 0:
		leader_target_slot_no = 0

	var overlap_priority_slot_nos: Array = []
	if leader_target_slot_no > 0:
		overlap_priority_slot_nos.append(leader_target_slot_no)

	var overlapped_entries: Array = []
	var non_overlapped_entries: Array = []
	var result_entries: Array = []

	result_entries.append({
		"card": leader_card,
		"target_slot_no": leader_target_slot_no,
		"is_fixed_overlap": true
	})

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if combo_card == leader_card:
			continue

		var own_target_slot_no: int = int(
			combo_drag_preview_card_target_slot_by_id.get(combo_card.get_instance_id(), 0)
		)

		var sort_slot_no: int = 999
		if combo_card.current_slot != null:
			sort_slot_no = combo_card.current_slot.slot_no

		var entry := {
			"card": combo_card,
			"target_slot_no": own_target_slot_no,
			"is_fixed_overlap": own_target_slot_no > 0,
			"sort_slot_no": sort_slot_no
		}

		if own_target_slot_no > 0:
			overlapped_entries.append(entry)

			if not overlap_priority_slot_nos.has(own_target_slot_no):
				overlap_priority_slot_nos.append(own_target_slot_no)
		else:
			non_overlapped_entries.append(entry)

	overlapped_entries.sort_custom(Callable(self, "_sort_attack_entries_by_slot_no"))
	non_overlapped_entries.sort_custom(Callable(self, "_sort_attack_entries_by_slot_no"))

	for entry_variant in overlapped_entries:
		var entry: Dictionary = entry_variant as Dictionary
		result_entries.append({
			"card": entry.get("card", null),
			"target_slot_no": int(entry.get("target_slot_no", 0)),
			"is_fixed_overlap": true
		})

	for entry_variant in non_overlapped_entries:
		var entry: Dictionary = entry_variant as Dictionary
		result_entries.append({
			"card": entry.get("card", null),
			"target_slot_no": 0,
			"is_fixed_overlap": false
		})

	result["entries"] = result_entries
	result["leader_target_slot_no"] = leader_target_slot_no
	result["overlap_priority_slot_nos"] = overlap_priority_slot_nos
	return result

func _sort_attack_entries_by_slot_no(a, b) -> bool:
	if typeof(a) != TYPE_DICTIONARY and typeof(b) != TYPE_DICTIONARY:
		return false
	if typeof(a) != TYPE_DICTIONARY:
		return false
	if typeof(b) != TYPE_DICTIONARY:
		return true

	var entry_a: Dictionary = a as Dictionary
	var entry_b: Dictionary = b as Dictionary

	return int(entry_a.get("sort_slot_no", 999)) < int(entry_b.get("sort_slot_no", 999))

func _resolve_non_overlapped_combo_target_slot_no(leader_target_slot_no: int, overlap_priority_slot_nos: Array) -> int:
	if leader_target_slot_no > 0 and _get_monster_current_hp(leader_target_slot_no) > 0:
		return leader_target_slot_no

	for slot_no_variant in overlap_priority_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no == leader_target_slot_no:
			continue

		if _get_monster_current_hp(slot_no) > 0:
			return slot_no

	return 0



func _get_combo_attack_order(combo_data: Dictionary, leader_card: TestCard) -> Array:
	var ordered_cards: Array = []

	if leader_card == null:
		return ordered_cards

	ordered_cards.append(leader_card)

	var remaining_cards: Array = []
	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return ordered_cards

	var cards: Array = cards_value as Array

	for card_variant in cards:
		var combo_card: TestCard = card_variant as TestCard
		if combo_card == null:
			continue

		if combo_card == leader_card:
			continue

		remaining_cards.append(combo_card)

	remaining_cards.sort_custom(Callable(self, "_sort_cards_by_slot_no"))

	for remaining_card_variant in remaining_cards:
		ordered_cards.append(remaining_card_variant)

	return ordered_cards

func _sort_cards_by_slot_no(a, b) -> bool:
	var card_a: TestCard = a as TestCard
	var card_b: TestCard = b as TestCard

	if card_a == null and card_b == null:
		return false
	if card_a == null:
		return false
	if card_b == null:
		return true

	var slot_no_a: int = 999
	var slot_no_b: int = 999

	if card_a.current_slot != null:
		slot_no_a = card_a.current_slot.slot_no

	if card_b.current_slot != null:
		slot_no_b = card_b.current_slot.slot_no

	return slot_no_a < slot_no_b

func _setup_test_monsters() -> void:
	monster_hp_by_slot_no.clear()
	monster_root_by_slot_no.clear()
	monster_hp_label_by_slot_no.clear()
	monster_is_face_down_by_slot_no.clear()
	monster_is_flipping_by_slot_no.clear()

	var monster_slot_nos: Array[int] = [2,  6]

	for slot_no in monster_slot_nos:
		monster_hp_by_slot_no[slot_no] = monster_start_hp
		monster_is_face_down_by_slot_no[slot_no] = false
		monster_is_flipping_by_slot_no[slot_no] = false
		_ensure_monster_visual(slot_no)
		_update_monster_visual(slot_no)

	print("테스트 몬스터 생성 완료 / 슬롯: 2, 6 / HP:", monster_start_hp)

func _ensure_monster_visual(slot_no: int) -> void:
	var slot: FieldSlot = _get_monster_slot(slot_no)
	if slot == null:
		return

	var unit: MonsterUnit = slot.get_node_or_null("MonsterUnit") as MonsterUnit
	if unit == null:
		unit = MonsterUnit.new()
		unit.name = "MonsterUnit"
		slot.add_child(unit)

	unit.setup_unit(slot_no, slot.size)

	monster_root_by_slot_no[slot_no] = unit
	monster_hp_label_by_slot_no[slot_no] = unit.get_node_or_null("MonsterHpLabel") as Label

func _update_monster_visual(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	var hp: int = int(monster_hp_by_slot_no.get(slot_no, 0))
	unit.visible = true
	unit.set_hp_text(hp)

	if slot_no == 4:
		unit.set_effect_symbols(["❄"])
	else:
		unit.set_effect_symbols([])

	if bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
		unit.apply_back_face()
	else:
		unit.apply_front_face()

func _get_monster_current_hp(slot_no: int) -> int:
	return int(monster_hp_by_slot_no.get(slot_no, 0))

func update_combo_drag_target_highlight_by_point(target_point_global: Vector2) -> void:
	if _is_point_over_final_objective(target_point_global):
		combo_drag_highlighted_monster_slot_no = 0
		combo_drag_preview_card_target_slot_by_id.clear()
		_apply_combo_drag_preview_highlight_slots([])
		_set_final_objective_combo_drag_highlight(true)
		return

	_set_final_objective_combo_drag_highlight(false)

	var target_slot: FieldSlot = _get_alive_monster_slot_at_global_position(target_point_global)

	if target_slot == null:
		combo_drag_highlighted_monster_slot_no = 0
	else:
		combo_drag_highlighted_monster_slot_no = target_slot.slot_no

func get_combo_drag_highlighted_monster_slot_for_preview() -> FieldSlot:
	return _get_combo_drag_highlighted_monster_slot()

func update_combo_drag_snapped_overlap_preview(card_rect_datas: Array) -> void:
	var next_slot_nos: Array = []
	var next_card_targets: Dictionary = {}

	for card_rect_data_variant in card_rect_datas:
		if typeof(card_rect_data_variant) != TYPE_DICTIONARY:
			continue

		var card_rect_data: Dictionary = card_rect_data_variant as Dictionary
		var source_card_id: int = int(card_rect_data.get("source_card_id", 0))

		if not card_rect_data.has("rect"):
			continue

		var card_rect: Rect2 = card_rect_data.get("rect", Rect2())
		var target_slot: FieldSlot = _get_best_alive_monster_slot_for_rect(card_rect)

		if target_slot == null:
			continue

		next_card_targets[source_card_id] = target_slot.slot_no

		if not next_slot_nos.has(target_slot.slot_no):
			next_slot_nos.append(target_slot.slot_no)

	next_slot_nos.sort()
	_apply_combo_drag_preview_highlight_slots(next_slot_nos)
	combo_drag_preview_card_target_slot_by_id = next_card_targets

func clear_combo_drag_target_highlight() -> void:
	_apply_combo_drag_preview_highlight_slots([])
	_set_final_objective_combo_drag_highlight(false)
	combo_drag_highlighted_monster_slot_no = 0
	combo_drag_preview_card_target_slot_by_id.clear()
	
func _apply_combo_drag_preview_highlight_slots(next_slot_nos: Array) -> void:
	for prev_slot_no_variant in combo_drag_preview_highlight_slot_nos:
		var prev_slot_no: int = int(prev_slot_no_variant)
		if next_slot_nos.has(prev_slot_no):
			continue
		_set_combo_drag_monster_highlight(prev_slot_no, false)

	for next_slot_no_variant in next_slot_nos:
		var next_slot_no: int = int(next_slot_no_variant)
		if combo_drag_preview_highlight_slot_nos.has(next_slot_no):
			continue
		_set_combo_drag_monster_highlight(next_slot_no, true)

	combo_drag_preview_highlight_slot_nos = next_slot_nos.duplicate()

func _get_best_alive_monster_slot_for_rect(card_rect: Rect2) -> FieldSlot:
	var best_slot: FieldSlot = null
	var best_overlap_area: float = 0.0

	for slot_variant in _get_all_monster_slots():
		var monster_slot: FieldSlot = slot_variant as FieldSlot
		if monster_slot == null:
			continue

		if _get_monster_current_hp(monster_slot.slot_no) <= 0:
			continue

		var monster_rect: Rect2 = monster_slot.get_global_rect()
		if not monster_rect.intersects(card_rect):
			continue

		var overlap_rect: Rect2 = monster_rect.intersection(card_rect)
		var overlap_area: float = overlap_rect.size.x * overlap_rect.size.y

		if overlap_area > best_overlap_area:
			best_overlap_area = overlap_area
			best_slot = monster_slot
		elif overlap_area > 0.0 and is_equal_approx(overlap_area, best_overlap_area):
			if best_slot == null or monster_slot.slot_no < best_slot.slot_no:
				best_slot = monster_slot

	return best_slot

func _set_combo_drag_monster_highlight(slot_no: int, is_on: bool) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	unit.set_highlight(is_on)

func _damage_monster(slot_no: int, damage: int) -> void:
	if not monster_hp_by_slot_no.has(slot_no):
		return

	var current_hp: int = int(monster_hp_by_slot_no.get(slot_no, 0))
	var next_hp: int = max(0, current_hp - damage)
	monster_hp_by_slot_no[slot_no] = next_hp

	print("몬스터 피격 / 슬롯:", slot_no, "/ 피해:", damage, "/ 남은 HP:", next_hp)

	if next_hp <= 0:
		await _flip_monster_to_back(slot_no)
	else:
		_update_monster_visual(slot_no)

func _get_monster_unit(slot_no: int) -> MonsterUnit:
	if not monster_root_by_slot_no.has(slot_no):
		return null

	return monster_root_by_slot_no.get(slot_no, null) as MonsterUnit

func _flip_monster_to_back(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	monster_is_flipping_by_slot_no[slot_no] = true
	await unit.flip_to_back()
	monster_is_face_down_by_slot_no[slot_no] = true
	monster_is_flipping_by_slot_no[slot_no] = false
	_update_monster_visual(slot_no)

func _flip_monster_to_front(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return
	if not bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
		return

	monster_is_flipping_by_slot_no[slot_no] = true
	monster_hp_by_slot_no[slot_no] = monster_start_hp
	await unit.flip_to_front(monster_start_hp)
	monster_is_face_down_by_slot_no[slot_no] = false
	monster_is_flipping_by_slot_no[slot_no] = false
	_update_monster_visual(slot_no)

func _flip_face_down_monsters_to_front_left_to_right() -> void:
	for slot_no in range(1, 8):
		if not monster_is_face_down_by_slot_no.has(slot_no):
			continue
		if not bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
			continue

		await _flip_monster_to_front(slot_no)
		await get_tree().create_timer(0.06).timeout

func _play_monster_contact_hit_effect(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	await unit.play_contact_hit_effect()

func _get_alive_monster_slot_at_global_position(mouse_global_position: Vector2) -> FieldSlot:
	var monster_slots: Array = _get_all_monster_slots()

	for slot_variant in monster_slots:
		var monster_slot: FieldSlot = slot_variant as FieldSlot
		if monster_slot == null:
			continue

		if not monster_slot.get_global_rect().has_point(mouse_global_position):
			continue

		if not monster_hp_by_slot_no.has(monster_slot.slot_no):
			return null

		var hp: int = int(monster_hp_by_slot_no.get(monster_slot.slot_no, 0))
		if hp <= 0:
			return null

		return monster_slot

	return null

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
