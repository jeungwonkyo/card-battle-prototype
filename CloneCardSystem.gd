extends RefCounted
class_name CloneCardSystem

const TEST_CARD_SCENE = preload("res://test_card.tscn")

var battle_scene: Node = null

# consumed_instance_id -> reservation
var reserved_clone_spawn_by_consumed_instance_id: Dictionary = {}

# clone_instance_id -> true
var active_clone_instance_ids: Dictionary = {}


func setup(new_battle_scene: Node) -> void:
	battle_scene = new_battle_scene


func reserve_clone_spawn(consumed_card: TestCard, clone_source_card: TestCard, clone_level: int) -> bool:
	if consumed_card == null:
		return false
	if not is_instance_valid(consumed_card):
		return false
	if consumed_card.card_state == null:
		return false
	if consumed_card.current_slot == null:
		return false

	if clone_source_card == null:
		return false
	if not is_instance_valid(clone_source_card):
		return false
	if clone_source_card.card_state == null:
		return false

	return reserve_clone_spawn_from_card_states(
		consumed_card.card_state,
		int(consumed_card.current_slot.slot_no),
		clone_source_card.card_state,
		clone_level
	)


func reserve_clone_spawn_from_card_states(
	consumed_card_state: CardState,
	consumed_slot_no: int,
	clone_source_card_state: CardState,
	clone_level: int
) -> bool:
	if consumed_card_state == null:
		return false
	if clone_source_card_state == null:
		return false
	if consumed_slot_no <= 0:
		return false

	var consumed_instance_id: int = int(consumed_card_state.instance_id)
	if consumed_instance_id <= 0:
		return false

	var reservation: Dictionary = {
		"consumed_instance_id": consumed_instance_id,
		"consumed_slot_no": consumed_slot_no,
		"clone_level": max(0, clone_level),

		"source_instance_id": int(clone_source_card_state.instance_id),
		"source_data_id": int(clone_source_card_state.data_id),
		"source_combo_id": int(clone_source_card_state.combo_id),
		"source_card_name": String(clone_source_card_state.card_name),
		"source_owner_side": String(clone_source_card_state.owner_side),
		"source_suit": String(clone_source_card_state.suit),
		"source_faction": String(clone_source_card_state.faction)
	}

	reserved_clone_spawn_by_consumed_instance_id[consumed_instance_id] = reservation

	print(
		"분신 생성 예약 / consumed_instance_id:", consumed_instance_id,
		" / slot:", consumed_slot_no,
		" / source_data_id:", int(clone_source_card_state.data_id),
		" / clone_level:", max(0, clone_level)
	)

	return true


func has_reserved_clone_spawn(consumed_instance_id: int) -> bool:
	return reserved_clone_spawn_by_consumed_instance_id.has(consumed_instance_id)


func spawn_reserved_clone_for_consumed_card(consumed_card: TestCard) -> TestCard:
	if consumed_card == null:
		return null
	if not is_instance_valid(consumed_card):
		return null
	if consumed_card.card_state == null:
		return null

	return spawn_reserved_clone_for_consumed_instance_id(int(consumed_card.card_state.instance_id))


func spawn_reserved_clone_for_consumed_instance_id(consumed_instance_id: int) -> TestCard:
	if consumed_instance_id <= 0:
		return null
	if not reserved_clone_spawn_by_consumed_instance_id.has(consumed_instance_id):
		return null
	if battle_scene == null:
		return null

	var reservation: Dictionary = reserved_clone_spawn_by_consumed_instance_id.get(consumed_instance_id, {}) as Dictionary
	reserved_clone_spawn_by_consumed_instance_id.erase(consumed_instance_id)

	if reservation.is_empty():
		return null

	var slot_no: int = int(reservation.get("consumed_slot_no", 0))
	var target_slot: FieldSlot = _get_player_slot(slot_no)
	if target_slot == null:
		print("분신 생성 실패 / 슬롯 없음 / slot:", slot_no)
		return null

	if target_slot.card != null:
		print("분신 생성 실패 / 슬롯이 비어있지 않음 / slot:", slot_no)
		return null

	var clone_card_state: CardState = _create_clone_card_state_from_reservation(reservation)
	if clone_card_state == null:
		print("분신 생성 실패 / 카드 상태 생성 실패 / consumed_instance_id:", consumed_instance_id)
		return null

	var clone_card: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
	if clone_card == null:
		print("분신 생성 실패 / TestCard 인스턴스 생성 실패")
		return null

	if battle_scene is Node:
		(battle_scene as Node).add_child(clone_card)
	else:
		return null

	clone_card.setup_from_card_state(clone_card_state)

	var placed: bool = target_slot.place_card(clone_card)
	if not placed:
		clone_card.queue_free()
		print("분신 생성 실패 / 슬롯 배치 실패 / slot:", slot_no)
		return null

	active_clone_instance_ids[int(clone_card_state.instance_id)] = true
	_request_combo_refresh()

	print(
		"분신 생성 완료 / clone_instance_id:", int(clone_card_state.instance_id),
		" / source_instance_id:", int(reservation.get("source_instance_id", 0)),
		" / slot:", slot_no,
		" / level:", int(clone_card_state.get_current_level())
	)

	return clone_card


func consume_clone_card(clone_card: TestCard) -> bool:
	if clone_card == null:
		return false
	if not is_instance_valid(clone_card):
		return false
	if clone_card.card_state == null:
		return false
	if not clone_card.card_state.is_clone_card():
		return false

	var clone_instance_id: int = int(clone_card.card_state.instance_id)
	active_clone_instance_ids.erase(clone_instance_id)

	if clone_card.current_slot != null and clone_card.current_slot.card == clone_card:
		clone_card.current_slot.remove_card()

	clone_card.card_state = null
	clone_card.queue_free()

	_request_combo_refresh()

	print("분신 소멸 / clone_instance_id:", clone_instance_id)
	return true


func detach_clone_card_for_combo_use(clone_card: TestCard) -> bool:
	if clone_card == null:
		return false
	if not is_instance_valid(clone_card):
		return false
	if clone_card.card_state == null:
		return false
	if not clone_card.card_state.is_clone_card():
		return false

	var clone_instance_id: int = int(clone_card.card_state.instance_id)
	active_clone_instance_ids.erase(clone_instance_id)

	if clone_card.current_slot != null and clone_card.current_slot.card == clone_card:
		clone_card.current_slot.remove_card()

	clone_card.card_state = null

	print("분신 전투 이탈(즉시 해제 안 함) / clone_instance_id:", clone_instance_id)
	return true


func clear_all_clone_cards_for_turn_end() -> void:
	if battle_scene == null:
		active_clone_instance_ids.clear()
		return

	var all_test_cards: Array = []
	_collect_test_cards_recursive(battle_scene, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if not is_instance_valid(test_card):
			continue
		if test_card.card_state == null:
			continue
		if not test_card.card_state.is_clone_card():
			continue

		if test_card.current_slot != null and test_card.current_slot.card == test_card:
			test_card.current_slot.remove_card()

		test_card.card_state = null
		test_card.queue_free()

	active_clone_instance_ids.clear()

	_request_combo_refresh()
	print("턴 종료 분신 전체 소멸 완료")


func clear_all_clone_cards_for_battle_end() -> void:
	if battle_scene == null:
		reserved_clone_spawn_by_consumed_instance_id.clear()
		active_clone_instance_ids.clear()
		return

	var all_test_cards: Array = []
	_collect_test_cards_recursive(battle_scene, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if not is_instance_valid(test_card):
			continue
		if test_card.card_state == null:
			continue
		if not test_card.card_state.is_clone_card():
			continue

		if test_card.current_slot != null and test_card.current_slot.card == test_card:
			test_card.current_slot.remove_card()

		test_card.card_state = null
		test_card.queue_free()

	reserved_clone_spawn_by_consumed_instance_id.clear()
	active_clone_instance_ids.clear()

	_request_combo_refresh()
	print("전투 종료 분신 전체 초기화 완료")

func clear_all_reserved_clone_spawns() -> void:
	reserved_clone_spawn_by_consumed_instance_id.clear()


func is_clone_card_instance_id(instance_id: int) -> bool:
	return active_clone_instance_ids.has(instance_id)


func _create_clone_card_state_from_reservation(reservation: Dictionary) -> CardState:
	if battle_scene == null:
		return null
	if not battle_scene.has_method("_create_card_state"):
		return null

	var source_data_id: int = int(reservation.get("source_data_id", 0))
	var source_combo_id: int = int(reservation.get("source_combo_id", 0))
	var source_card_name: String = String(reservation.get("source_card_name", ""))
	var source_owner_side: String = String(reservation.get("source_owner_side", "player"))
	var clone_level: int = max(0, int(reservation.get("clone_level", 0)))
	var source_instance_id: int = int(reservation.get("source_instance_id", 0))

	var new_card_state_variant = battle_scene.call(
		"_create_card_state",
		source_data_id,
		source_combo_id,
		source_card_name,
		source_owner_side
	)

	var new_card_state: CardState = new_card_state_variant as CardState
	if new_card_state == null:
		return null

	new_card_state.set_base_level(clone_level)
	new_card_state.clear_temp_level_delta()
	new_card_state.suit = String(reservation.get("source_suit", new_card_state.suit))
	new_card_state.faction = String(reservation.get("source_faction", new_card_state.faction))
	new_card_state.mark_as_generated_card("clone", source_instance_id, false)

	if battle_scene.has_method("_sync_card_state_level_fields"):
		battle_scene.call("_sync_card_state_level_fields", new_card_state)

	return new_card_state


func _get_player_slot(slot_no: int) -> FieldSlot:
	if battle_scene == null:
		return null
	if slot_no <= 0:
		return null

	if battle_scene.has_method("_get_player_slot"):
		return battle_scene.call("_get_player_slot", slot_no) as FieldSlot

	var fallback_path: String = "Layer1_PlayerField/P_SlotStation/PlayerSlot%d" % slot_no
	if battle_scene.has_node(fallback_path):
		return battle_scene.get_node(fallback_path) as FieldSlot

	return null


func _request_combo_refresh() -> void:
	if battle_scene == null:
		return
	if not battle_scene.has_method("refresh_player_combos"):
		return

	battle_scene.call_deferred("refresh_player_combos")


func _collect_test_cards_recursive(root_node: Node, result: Array) -> void:
	if root_node == null:
		return

	for child in root_node.get_children():
		var test_card: TestCard = child as TestCard
		if test_card != null:
			result.append(test_card)

		_collect_test_cards_recursive(child, result)
