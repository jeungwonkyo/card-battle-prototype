extends RefCounted
class_name CardBuffDebuffSystem

const META_BLESSING: String = "buff_blessing"
const META_CURSE: String = "debuff_curse"

func initialize_card_state(card_state) -> void:
	if card_state == null:
		return

	if not card_state.has_meta(META_BLESSING):
		_set_meta_int(card_state, META_BLESSING, 0)

	if not card_state.has_meta(META_CURSE):
		_set_meta_int(card_state, META_CURSE, 0)

func get_blessing(card_state) -> int:
	return max(0, _get_meta_int(card_state, META_BLESSING, 0))

func set_blessing(card_state, value: int) -> void:
	if card_state == null:
		return

	_set_meta_int(card_state, META_BLESSING, max(0, value))

func add_blessing(card_state, delta: int) -> void:
	if card_state == null:
		return

	set_blessing(card_state, get_blessing(card_state) + delta)

func clear_blessing(card_state) -> void:
	set_blessing(card_state, 0)

func get_curse(card_state) -> int:
	return max(0, _get_meta_int(card_state, META_CURSE, 0))

func set_curse(card_state, value: int) -> void:
	if card_state == null:
		return

	_set_meta_int(card_state, META_CURSE, max(0, value))

func add_curse(card_state, delta: int) -> void:
	if card_state == null:
		return

	set_curse(card_state, get_curse(card_state) + delta)

func clear_curse(card_state) -> void:
	set_curse(card_state, 0)

func consume_attack_use_modifiers(card_state) -> void:
	if card_state == null:
		return

	clear_blessing(card_state)
	clear_curse(card_state)

func clear_for_battle_end(card_state) -> void:
	consume_attack_use_modifiers(card_state)

func clear_for_card_destroy(card_state) -> void:
	consume_attack_use_modifiers(card_state)

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
