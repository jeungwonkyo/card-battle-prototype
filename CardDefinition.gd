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
const EFFECT_GRANT_ALL_SUIT_CARDS_GROWTH: String = "grant_all_suit_cards_growth"
const EFFECT_GRANT_SELF_GROWTH: String = "grant_self_growth"
const EFFECT_GAIN_SHIELD_BY_SELF_FINAL_POWER: String = "gain_shield_by_self_final_power"
const EFFECT_GAIN_SHIELD_BY_SELF_LEVEL: String = "gain_shield_by_self_level"
const EFFECT_RESERVE_MEMBER_CLONES_BY_SELF_LEVEL: String = "reserve_member_clones_by_self_level"
const EFFECT_RESERVE_SELF_CLONE_BY_SELF_LEVEL: String = "reserve_self_clone_by_self_level"
const EFFECT_HEAL_PLAYER_HP_BY_SELF_LEVEL_X2: String = "heal_player_hp_by_self_level_x2"
var definitions_by_data_id: Dictionary = {}

func _init() -> void:
	_build_definitions()

func _build_definitions() -> void:
	definitions_by_data_id.clear()

	definitions_by_data_id[101] = {
		"definition_id": "heart_01",
		"data_id": 101,
		"display_name": "Heart_01",
		"image_path": "res://ui/Card/Heart/Heart01.png",
		"suit": "heart",
		"faction": "sanctuary",
		"summary_text": "하모니 리더\nhp를 레벨x2\n 만큼 회복({SELF_LV_X2})",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_HEAL_PLAYER_HP_BY_SELF_LEVEL_X2
			}
		]
	}

	definitions_by_data_id[102] = {
		"definition_id": "heart_02",
		"data_id": 102,
		"display_name": "Heart_02",
		"image_path": "res://ui/Card/Heart/Heart02.png",
		"suit": "heart",
		"faction": "sanctuary",
		"summary_text": "멤버\n남은 필드 카드 {REMAIN_FIELD_TARGET_COUNT}장\nGrowth +{GROWTH_AMOUNT}",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH,
				"amount": 1
			}
		]
	}

	definitions_by_data_id[103] = {
		"definition_id": "heart_03",
		"data_id": 103,
		"display_name": "Heart_03",
		"image_path": "res://ui/Card/Heart/Heart03.png",
		"suit": "heart",
		"faction": "sanctuary",
		"summary_text": "멤버\n남은 필드 카드 1장\nGrowth +1",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_AFTER_USE,
				"effect_type": EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH,
				"amount": 1
			}
		]
	}

	definitions_by_data_id[113] = {
		"definition_id": "heart_04",
		"data_id": 113,
		"display_name": "Heart_04",
		"suit": "heart",
		"faction": "sanctuary",
		"summary_text": "하모니 리더\n조합 내 카드\nBlessing +Self Lv({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_COMBO_BLESSING_BY_SELF_LEVEL,
				"target_scope": "members_only"
			}
		]
	}

	definitions_by_data_id[104] = {
		"definition_id": "spade_01",
		"data_id": 104,
		"display_name": "Spade_01",
		"image_path": "res://ui/Card/Spade/Spade01.png",
		"suit": "spade",
		"faction": "strife",
		"summary_text": "하모니 리더\n모든 스페이드 카드\nGrowth +1",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_ALL_SUIT_CARDS_GROWTH,
				"target_suit": "spade",
				"amount": 1
			}
		]
	}

	definitions_by_data_id[105] = {
		"definition_id": "spade_02",
		"data_id": 105,
		"display_name": "Spade_02",
		"image_path": "res://ui/Card/Spade/Spade02.png",
		"suit": "spade",
		"faction": "strife",
		"summary_text": "멤버\n이 카드\nGrowth +1",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_SELF_GROWTH,
				"amount": 1
			}
		]
	}

	definitions_by_data_id[106] = {
		"definition_id": "spade_03",
		"data_id": 106,
		"display_name": "Spade_03",
		"image_path": "res://ui/Card/Spade/Spade03.png",
		"suit": "spade",
		"faction": "strife",
		"summary_text": "멤버\n이 카드\nGrowth +1",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GRANT_SELF_GROWTH,
				"amount": 1
			}
		]
	}

	definitions_by_data_id[107] = {
		"definition_id": "clover_01",
		"data_id": 107,
		"display_name": "Clover_01",
		"image_path": "res://ui/Card/Clover/Clover01.png",
		"suit": "clover",
		"faction": "illusion",
		"summary_text": "하모니 리더\n멤버를 레벨과 동일\n한 분신으로 생성({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_RESERVE_MEMBER_CLONES_BY_SELF_LEVEL
			}
		]
	}

	definitions_by_data_id[108] = {
		"definition_id": "clover_02",
		"data_id": 108,
		"display_name": "Clover_02",
		"image_path": "res://ui/Card/Clover/Clover02.png",
		"suit": "clover",
		"faction": "illusion",
		"summary_text": "멤버\n레벨과 동일한 \n분신 1장 생성({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_RESERVE_SELF_CLONE_BY_SELF_LEVEL
			}
		]
	}

	definitions_by_data_id[109] = {
		"definition_id": "clover_03",
		"data_id": 109,
		"display_name": "Clover_03",
		"image_path": "res://ui/Card/Clover/Clover03.png",
		"suit": "clover",
		"faction": "illusion",
		"summary_text": "멤버\n레벨과 동일한\n분신 1장 생성({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_RESERVE_SELF_CLONE_BY_SELF_LEVEL
			}
		]
	}
	definitions_by_data_id[110] = {
		"definition_id": "diamond_01",
		"data_id": 110,
		"display_name": "Diamond_01",
		"image_path": "res://ui/Card/Diamond/Diamond01.png",
		"suit": "diamond",
		"faction": "citadel",
		"summary_text": "하모니 리더\n최종 위력만큼\nShield 획득({SELF_FINAL_POWER})",
		"effects": [
			{
				"trigger": TRIGGER_HARMONY_LEADER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GAIN_SHIELD_BY_SELF_FINAL_POWER
			}
		]
	}

	definitions_by_data_id[111] = {
		"definition_id": "diamond_02",
		"data_id": 111,
		"display_name": "Diamond_02",
		"image_path": "res://ui/Card/Diamond/Diamond02.png",
		"suit": "diamond",
		"faction": "citadel",
		"summary_text": "멤버\n본인 레벨만큼\nShield 획득({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GAIN_SHIELD_BY_SELF_LEVEL
			}
		]
	}

	definitions_by_data_id[112] = {
		"definition_id": "diamond_03",
		"data_id": 112,
		"display_name": "Diamond_03",
		"image_path": "res://ui/Card/Diamond/Diamond03.png",
		"suit": "diamond",
		"faction": "citadel",
		"summary_text": "멤버\n본인 레벨만큼\nShield 획득({SELF_LV})",
		"effects": [
			{
				"trigger": TRIGGER_MEMBER,
				"timing": TIMING_BEFORE_ATTACK,
				"effect_type": EFFECT_GAIN_SHIELD_BY_SELF_LEVEL
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

func get_summary_text_by_data_id(data_id: int) -> String:
	var definition: Dictionary = get_definition_by_data_id(data_id)
	return String(definition.get("summary_text", ""))

func get_suit_by_data_id(data_id: int) -> String:
	var definition: Dictionary = get_definition_by_data_id(data_id)
	return String(definition.get("suit", ""))

func get_faction_by_data_id(data_id: int) -> String:
	var definition: Dictionary = get_definition_by_data_id(data_id)
	return String(definition.get("faction", ""))

func _make_fallback_definition(data_id: int) -> Dictionary:
	var display_name: String = "Card_%03d" % data_id
	var suit: String = ""
	var faction: String = ""

	if data_id >= 101 and data_id <= 103:
		display_name = "Heart_%02d" % (data_id - 100)
		suit = "heart"
		faction = "sanctuary"
	elif data_id >= 104 and data_id <= 106:
		display_name = "Spade_%02d" % (data_id - 103)
		suit = "spade"
		faction = "strife"
	elif data_id >= 107 and data_id <= 109:
		display_name = "Clover_%02d" % (data_id - 106)
		suit = "clover"
		faction = "illusion"
	elif data_id >= 110 and data_id <= 112:
		display_name = "Diamond_%02d" % (data_id - 109)
		suit = "diamond"
		faction = "citadel"

	return {
		"definition_id": "fallback_%03d" % data_id,
		"data_id": data_id,
		"display_name": display_name,
		"suit": suit,
		"faction": faction,
		"summary_text": "",
		"effects": []
	}
