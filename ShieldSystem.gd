extends RefCounted
class_name ShieldSystem

var shields_by_target: Dictionary = {}


func get_shield(target_key: Variant) -> int:
	var normalized_key: Variant = _normalize_target_key(target_key)
	if normalized_key == null:
		return 0

	return int(shields_by_target.get(normalized_key, 0))


func set_shield(target_key: Variant, value: int) -> void:
	var normalized_key: Variant = _normalize_target_key(target_key)
	if normalized_key == null:
		return

	shields_by_target[normalized_key] = max(0, value)


func add_shield(target_key: Variant, value: int) -> int:
	if value <= 0:
		return get_shield(target_key)

	var normalized_key: Variant = _normalize_target_key(target_key)
	if normalized_key == null:
		return 0

	var next_value: int = get_shield(normalized_key) + value
	shields_by_target[normalized_key] = max(0, next_value)
	return int(shields_by_target[normalized_key])


func clear_shield(target_key: Variant) -> void:
	var normalized_key: Variant = _normalize_target_key(target_key)
	if normalized_key == null:
		return

	shields_by_target.erase(normalized_key)


func clear_all_shields() -> void:
	shields_by_target.clear()


func apply_damage(target_key: Variant, damage: int) -> Dictionary:
	var result: Dictionary = {
		"blocked_damage": 0,
		"hp_damage": 0,
		"shield_before": 0,
		"shield_after": 0
	}

	if damage <= 0:
		result["shield_before"] = get_shield(target_key)
		result["shield_after"] = get_shield(target_key)
		return result

	var normalized_key: Variant = _normalize_target_key(target_key)
	if normalized_key == null:
		result["hp_damage"] = damage
		return result

	var current_shield: int = get_shield(normalized_key)
	var blocked_damage: int = min(current_shield, damage)
	var remain_damage: int = max(0, damage - blocked_damage)
	var next_shield: int = max(0, current_shield - blocked_damage)

	shields_by_target[normalized_key] = next_shield

	result["blocked_damage"] = blocked_damage
	result["hp_damage"] = remain_damage
	result["shield_before"] = current_shield
	result["shield_after"] = next_shield
	return result


func _normalize_target_key(target_key: Variant) -> Variant:
	if target_key == null:
		return null

	if target_key is Object:
		var target_object: Object = target_key as Object
		if not is_instance_valid(target_object):
			return null
		return target_object.get_instance_id()

	return target_key
