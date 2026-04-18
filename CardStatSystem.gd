extends RefCounted
class_name CardStatSystem

var strike_combo_multiplier: int = 3
var harmony_combo_multiplier: int = 2

func setup(default_strike_multiplier: int, default_harmony_multiplier: int) -> void:
	strike_combo_multiplier = max(0, default_strike_multiplier)
	harmony_combo_multiplier = max(0, default_harmony_multiplier)

func set_combo_multiplier(combo_type: String, new_multiplier: int) -> void:
	if combo_type == "strike":
		strike_combo_multiplier = max(0, new_multiplier)
		return

	if combo_type == "harmony":
		harmony_combo_multiplier = max(0, new_multiplier)
		return

func get_combo_multiplier(combo_type: String) -> int:
	if combo_type == "strike":
		return strike_combo_multiplier

	if combo_type == "harmony":
		return harmony_combo_multiplier

	return 1

func get_current_level(card_state) -> int:
	if card_state == null:
		return 0

	var current_level: int = 0

	if card_state.has_method("get_current_level"):
		current_level = int(card_state.get_current_level())
	else:
		current_level = max(0, int(card_state.base_level) + int(card_state.temp_level_delta))

	return max(0, _apply_current_level_hooks(card_state, current_level))

func calculate_final_power(card_state, combo_type: String) -> int:
	var current_level: int = get_current_level(card_state)
	var combo_multiplier: int = get_combo_multiplier_for_card(card_state, combo_type)
	var final_power: int = max(0, current_level * max(0, combo_multiplier))

	return max(0, _apply_final_power_hooks(card_state, combo_type, final_power))

func calculate_final_power_from_multiplier(card_state, combo_type: String, combo_multiplier: int) -> int:
	var current_level: int = get_current_level(card_state)
	var hooked_multiplier: int = max(0, _apply_combo_multiplier_hooks(card_state, combo_type, combo_multiplier))
	var final_power: int = max(0, current_level * max(0, hooked_multiplier))

	return max(0, _apply_final_power_hooks(card_state, combo_type, final_power))

func get_combo_multiplier_for_card(card_state, combo_type: String) -> int:
	var combo_multiplier: int = get_combo_multiplier(combo_type)
	return max(0, _apply_combo_multiplier_hooks(card_state, combo_type, combo_multiplier))

func _apply_current_level_hooks(card_state, current_level: int) -> int:
	return current_level

func _apply_combo_multiplier_hooks(card_state, combo_type: String, combo_multiplier: int) -> int:
	return combo_multiplier

func _apply_final_power_hooks(card_state, combo_type: String, final_power: int) -> int:
	return final_power
