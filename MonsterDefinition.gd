extends Node
class_name MonsterDefinition

const TYPE_ENTER_EXIT: String = "enter_exit"
const TYPE_PASSIVE: String = "passive"

const TRIGGER_ENTER: String = "enter"
const TRIGGER_EXIT: String = "exit"
const TRIGGER_PASSIVE: String = "passive"

const EFFECT_DAMAGE_PLAYER: String = "damage_player"

var definitions_by_id: Dictionary = {}

func _init() -> void:
	_build_definitions()

func _build_definitions() -> void:
	definitions_by_id.clear()

	definitions_by_id["monster1"] = {
	"monster_id": "monster1",
	"display_name": "Monster_1",
	"monster_type": TYPE_ENTER_EXIT,
	"base_attack": 2,
	"base_hp": 8,
	"image_path": "res://ui/Monster/Monster01.png",
	"attack_effect_icons": [],
	"effects": [
		{
			"trigger": TRIGGER_ENTER,
			"effect_type": EFFECT_DAMAGE_PLAYER,
			"amount": 2,
			"summary_template": "입장\n플레이어에게 {AMOUNT}데미지"
		}
	]
}

	definitions_by_id["monster2"] = {
	"monster_id": "monster2",
	"display_name": "Monster_2",
	"monster_type": TYPE_ENTER_EXIT,
	"base_attack": 3,
	"base_hp": 8,
	"image_path": "res://ui/Monster/Monster02.png",
	"attack_effect_icons": [],
	"effects": [
		{
			"trigger": TRIGGER_EXIT,
			"effect_type": EFFECT_DAMAGE_PLAYER,
			"amount": 3,
			"summary_template": "퇴장\n플레이어에게 {AMOUNT}데미지"
		}
	]
}

func get_definition(monster_id: String) -> Dictionary:
	if monster_id == "":
		return {}

	if not definitions_by_id.has(monster_id):
		return {}

	return (definitions_by_id.get(monster_id, {}) as Dictionary).duplicate(true)

func get_primary_skill_data(monster_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(monster_id)
	if definition.is_empty():
		return {}

	var effects_value: Variant = definition.get("effects", [])
	if typeof(effects_value) != TYPE_ARRAY:
		return {}

	var effects: Array = effects_value as Array
	if effects.is_empty():
		return {}

	var first_effect_value: Variant = effects[0]
	if typeof(first_effect_value) != TYPE_DICTIONARY:
		return {}

	var effect_data: Dictionary = (first_effect_value as Dictionary).duplicate(true)
	var amount: int = int(effect_data.get("amount", 0))
	var summary_template: String = String(effect_data.get("summary_template", ""))

	effect_data["summary_text"] = summary_template.replace("{AMOUNT}", str(amount))
	return effect_data
	
func get_image_path(monster_id: String) -> String:
	var definition: Dictionary = get_definition(monster_id)
	if definition.is_empty():
		return ""

	return String(definition.get("image_path", ""))
