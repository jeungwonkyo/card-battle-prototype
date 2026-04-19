extends RefCounted
class_name CardDefinition

const TRIGGER_HARMONY_LEADER: String = "harmony_leader"
const TRIGGER_STRIKE_LEADER: String = "strike_leader"
const TRIGGER_MEMBER: String = "member"
const TRIGGER_MOVE: String = "move"
const TRIGGER_RESTORE: String = "restore"

const TIMING_BEFORE_ATTACK: String = "before_attack"
const TIMING_AFTER_USE: String = "after_use"

const EFFECT_GRANT_COMBO_BLESSING_BY_SELF_LEVEL: String = "grant_combo_blessing_by_self_level"
const EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH: String = "grant_random_remaining_field_card_growth"

var definitions_by_data_id: Dictionary = {}

func _init() -> void:
	_build_definitions()

func _build_definitions() -> void:
	definitions_by_data_id.clear()

	definitions_by_data_id[101] = {
		"definition_id": "heart_01",
		"data_id": 101,
		"display_name": "Heart_01",
		"suit": "heart",
		"faction": "sanctuary",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_COMBO_BLESSING_BY_SELF_LEVEL
			}
		]
	}

	definitions_by_data_id[102] = {
		"definition_id": "heart_02",
		"data_id": 102,
		"display_name": "Heart_02",
		"suit": "heart",
		"faction": "sanctuary",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_AFTER_USE,
				"effect_type": EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH,
				"amount": 1
			}
		]
	}

	definitions_by_data_id[103] = {
		"definition_id": "heart_03",
		"data_id": 103,
		"display_name": "Heart_03",
		"suit": "heart",
		"faction": "sanctuary",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_AFTER_USE,
				"effect_type": EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH,
				"amount": 1
			}
		]
	}

func get_definition_by_data_id(data_id: int) -> Dictionary:
	if definitions_by_data_id.has(data_id):
		return (definitions_by_data_id[data_id] as Dictionary).duplicate(true)

	return _make_fallback_definition(data_id)

func get_card_name_by_data_id(data_id: int) -> String:
	var definition: Dictionary = get_definition_by_data_id(data_id)
	return String(definition.get("display_name", ""))

func get_effects_by_data_id(data_id: int) -> Array:
	var definition: Dictionary = get_definition_by_data_id(data_id)
	var effects_value = definition.get("effects", [])

	if typeof(effects_value) != TYPE_ARRAY:
		return []

	return (effects_value as Array).duplicate(true)

func _make_fallback_definition(data_id: int) -> Dictionary:
	var display_name: String = "Card_%03d" % data_id

	if data_id >= 104 and data_id <= 106:
		display_name = "Blue_%02d" % (data_id - 103)
	elif data_id >= 107 and data_id <= 109:
		display_name = "Green_%02d" % (data_id - 106)
	elif data_id >= 110 and data_id <= 112:
		display_name = "Yellow_%02d" % (data_id - 109)

	return {
		"definition_id": "fallback_%03d" % data_id,
		"data_id": data_id,
		"display_name": display_name,
		"suit": "",
		"faction": "",
		"effects": []
	}
