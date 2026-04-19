extends RefCounted
class_name CardLevelModifierSystem

const META_START_LEVEL: String = "level_start_level"
const META_RANK_UP: String = "level_rank_up"
const META_GROWTH: String = "level_growth"
const META_FORCED_BASE_LEVEL: String = "level_forced_base_level"
const META_FORCED_FINAL_LEVEL: String = "level_forced_final_level"

var default_start_level: int = 2

func setup(start_level: int = 2) -> void:
	default_start_level = max(1, start_level)

func initialize_card_state(card_state, start_level: int = -1) -> void:
	if card_state == null:
		return

	var applied_start_level: int = default_start_level
	if start_level > 0:
		applied_start_level = start_level

	_set_meta_int(card_state, META_START_LEVEL, max(1, applied_start_level))

	if not card_state.has_meta(META_RANK_UP):
		_set_meta_int(card_state, META_RANK_UP, 0)

	if not card_state.has_meta(META_GROWTH):
		_set_meta_int(card_state, META_GROWTH, 0)

func get_start_level(card_state) -> int:
	if card_state == null:
		return default_start_level

	return max(1, _get_meta_int(card_state, META_START_LEVEL, default_start_level))

func set_start_level(card_state, value: int) -> void:
	if card_state == null:
		return

	_set_meta_int(card_state, META_START_LEVEL, max(1, value))

func get_rank_up(card_state) -> int:
	return max(0, _get_meta_int(card_state, META_RANK_UP, 0))

func set_rank_up(card_state, value: int) -> void:
	if card_state == null:
		return

	_set_meta_int(card_state, META_RANK_UP, max(0, value))

func add_rank_up(card_state, delta: int) -> void:
	if card_state == null:
		return

	set_rank_up(card_state, get_rank_up(card_state) + delta)

func get_growth(card_state) -> int:
	return max(0, _get_meta_int(card_state, META_GROWTH, 0))

func set_growth(card_state, value: int) -> void:
	if card_state == null:
		return

	_set_meta_int(card_state, META_GROWTH, max(0, value))

func add_growth(card_state, delta: int) -> void:
	if card_state == null:
		return

	set_growth(card_state, get_growth(card_state) + delta)

func clear_growth(card_state) -> void:
	set_growth(card_state, 0)

func has_forced_base_level(card_state) -> bool:
	if card_state == null:
		return false

	return card_state.has_meta(META_FORCED_BASE_LEVEL)

func get_forced_base_level(card_state):
	if not has_forced_base_level(card_state):
		return null

	return int(card_state.get_meta(META_FORCED_BASE_LEVEL))

func set_forced_base_level(card_state, value: int) -> void:
	if card_state == null:
		return

	card_state.set_meta(META_FORCED_BASE_LEVEL, value)

func clear_forced_base_level(card_state) -> void:
	if card_state == null:
		return
	if not card_state.has_meta(META_FORCED_BASE_LEVEL):
		return

	card_state.remove_meta(META_FORCED_BASE_LEVEL)

func has_forced_final_level(card_state) -> bool:
	if card_state == null:
		return false

	return card_state.has_meta(META_FORCED_FINAL_LEVEL)

func get_forced_final_level(card_state):
	if not has_forced_final_level(card_state):
		return null

	return int(card_state.get_meta(META_FORCED_FINAL_LEVEL))

func set_forced_final_level(card_state, value: int) -> void:
	if card_state == null:
		return

	card_state.set_meta(META_FORCED_FINAL_LEVEL, value)

func clear_forced_final_level(card_state) -> void:
	if card_state == null:
		return
	if not card_state.has_meta(META_FORCED_FINAL_LEVEL):
		return

	card_state.remove_meta(META_FORCED_FINAL_LEVEL)

func get_base_level(card_state) -> int:
	if card_state == null:
		return default_start_level

	if has_forced_base_level(card_state):
		return max(0, int(get_forced_base_level(card_state)))

	return max(0, get_start_level(card_state) + get_rank_up(card_state))

func get_final_level(card_state, blessing_amount: int = 0, curse_amount: int = 0) -> int:
	if card_state == null:
		return default_start_level

	if has_forced_final_level(card_state):
		return max(0, int(get_forced_final_level(card_state)))

	var base_level: int = get_base_level(card_state)
	var final_level: int = base_level + get_growth(card_state) + max(0, blessing_amount) - max(0, curse_amount)

	var minimum_level: int = get_start_level(card_state)
	if has_forced_base_level(card_state):
		minimum_level = max(0, base_level)

	return max(minimum_level, final_level)

func sync_legacy_level_fields(card_state, blessing_amount: int = 0, curse_amount: int = 0) -> void:
	if card_state == null:
		return

	var base_level: int = get_base_level(card_state)
	var final_level: int = get_final_level(card_state, blessing_amount, curse_amount)
	var temp_delta: int = final_level - base_level

	if "base_level" in card_state:
		card_state.base_level = base_level

	if "temp_level_delta" in card_state:
		card_state.temp_level_delta = temp_delta

func clear_for_battle_end(card_state) -> void:
	if card_state == null:
		return

	clear_growth(card_state)
	clear_forced_base_level(card_state)
	clear_forced_final_level(card_state)

func clear_for_card_destroy(card_state) -> void:
	if card_state == null:
		return

	# Growth / Rank Up은 카드 파괴로 초기화되지 않음
	pass

func _get_meta_int(card_state, key: String, default_value: int) -> int:
	if card_state == null:
		return default_value

	if not card_state.has_meta(key):
		return default_value

	return int(card_state.get_meta(key))

func _set_meta_int(card_state, key: String, value: int) -> void:
	if card_state == null:
		return

	card_state.set_meta(key, int(value))
