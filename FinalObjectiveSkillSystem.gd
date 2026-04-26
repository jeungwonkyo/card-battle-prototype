extends Node
class_name FinalObjectiveSkillSystem

const TRIGGER_TURN_START: String = "turn_start"
const TRIGGER_TURN_END: String = "turn_end"

const EFFECT_NONE: String = "none"
const EFFECT_DAMAGE_PLAYER: String = "damage_player"
const EFFECT_APPLY_PLAYER_DEBUFF: String = "apply_player_debuff"
const EFFECT_BUFF_ALL_MONSTERS: String = "buff_all_monsters"
const EFFECT_SUMMON_MONSTER: String = "summon_monster"

@export var skill_feedback_wait_seconds: float = 0.4
@export var skill_effect_interval_seconds: float = 0.18
@export var skill_end_wait_seconds: float = 0

var battle_scene: Node = null
var final_objective: Node = null
var definitions_by_skill_id: Dictionary = {}
var skill_profile_by_profile_id: Dictionary = {}


func _init() -> void:
	_build_definitions()


func setup(owner_battle_scene: Node, owner_final_objective: Node) -> void:
	battle_scene = owner_battle_scene
	final_objective = owner_final_objective
	refresh_skill_ui()

func apply_skill_profile(profile_id: String) -> void:
	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("set_skill_id_by_trigger"):
		return

	if not skill_profile_by_profile_id.has(profile_id):
		print("최종목표 스킬 프로필 없음:", profile_id)
		return

	var profile_data: Dictionary = skill_profile_by_profile_id.get(profile_id, {}) as Dictionary
	var turn_start_skill_id: String = String(profile_data.get(TRIGGER_TURN_START, "turn_start_none"))
	var turn_end_skill_id: String = String(profile_data.get(TRIGGER_TURN_END, "turn_end_none"))

	final_objective.call("set_skill_id_by_trigger", TRIGGER_TURN_START, turn_start_skill_id)
	final_objective.call("set_skill_id_by_trigger", TRIGGER_TURN_END, turn_end_skill_id)
	refresh_skill_ui()

	print(
		"최종목표 스킬 프로필 적용 / 프로필:", profile_id,
		"/ turn_start:", turn_start_skill_id,
		"/ turn_end:", turn_end_skill_id
	)


func refresh_skill_ui() -> void:
	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("get_skill_id_by_trigger"):
		return

	_refresh_skill_ui_by_trigger(TRIGGER_TURN_START)
	_refresh_skill_ui_by_trigger(TRIGGER_TURN_END)


func _refresh_skill_ui_by_trigger(trigger_type: String) -> void:
	var skill_id: String = String(final_objective.call("get_skill_id_by_trigger", trigger_type))
	var skill_data: Dictionary = get_definition(skill_id)

	var display_name: String = String(skill_data.get("display_name", "없음"))
	var short_text: String = String(skill_data.get("short_text", "-"))

	if final_objective.has_method("set_skill_display"):
		final_objective.call("set_skill_display", trigger_type, display_name, short_text)


func get_definition(skill_id: String) -> Dictionary:
	if skill_id == "":
		return {}

	if not definitions_by_skill_id.has(skill_id):
		return {}

	return (definitions_by_skill_id.get(skill_id, {}) as Dictionary).duplicate(true)


func run_trigger(trigger_type: String) -> void:
	if battle_scene == null:
		return

	if final_objective == null:
		return

	if not is_instance_valid(final_objective):
		return

	if final_objective.has_method("get_hp"):
		if int(final_objective.call("get_hp")) <= 0:
			print("최종목표 턴 스킬 스킵 / 최종목표 HP 0")
			return

	if not final_objective.has_method("get_skill_id_by_trigger"):
		return

	var skill_id: String = String(final_objective.call("get_skill_id_by_trigger", trigger_type))
	if skill_id == "":
		print("최종목표 턴 스킬 스킵 / 스킬 ID 없음 / 트리거:", trigger_type)
		return

	var skill_data: Dictionary = get_definition(skill_id)
	if skill_data.is_empty():
		print("최종목표 턴 스킬 스킵 / 정의 없음 / 트리거:", trigger_type, "/ 스킬:", skill_id)
		return

	if String(skill_data.get("trigger", "")) != trigger_type:
		print("최종목표 턴 스킬 스킵 / 트리거 불일치 / 트리거:", trigger_type, "/ 스킬:", skill_id)
		return

	if final_objective.has_method("play_skill_ui_trigger_feedback"):
		final_objective.call("play_skill_ui_trigger_feedback", trigger_type)

	await _wait(skill_feedback_wait_seconds)

	print("===== 최종목표 턴 스킬 시작 / 트리거:", trigger_type, "/ 스킬:", skill_id, "=====")

	var effects_value = skill_data.get("effects", [])
	if typeof(effects_value) != TYPE_ARRAY:
		print("최종목표 턴 스킬 스킵 / effects 배열 아님 / 스킬:", skill_id)
		return

	for effect_variant in effects_value:
		if typeof(effect_variant) != TYPE_DICTIONARY:
			continue

		var effect_data: Dictionary = effect_variant as Dictionary
		await _execute_effect(effect_data, skill_data)
		await _wait(skill_effect_interval_seconds)

	await _wait(skill_end_wait_seconds)

	print("===== 최종목표 턴 스킬 종료 / 트리거:", trigger_type, "/ 스킬:", skill_id, "=====")


func _execute_effect(effect_data: Dictionary, skill_data: Dictionary) -> void:
	var effect_type: String = String(effect_data.get("effect_type", ""))

	match effect_type:
		EFFECT_NONE:
			return

		EFFECT_DAMAGE_PLAYER:
			_execute_damage_player(effect_data, skill_data)

		EFFECT_APPLY_PLAYER_DEBUFF:
			_execute_apply_player_debuff(effect_data, skill_data)

		EFFECT_BUFF_ALL_MONSTERS:
			_execute_buff_all_monsters(effect_data, skill_data)

		EFFECT_SUMMON_MONSTER:
			_execute_summon_monster(effect_data, skill_data)

		_:
			print("최종목표 턴 스킬 미구현 effect_type:", effect_type)


func _execute_damage_player(effect_data: Dictionary, skill_data: Dictionary) -> void:
	var amount: int = int(effect_data.get("amount", 0))
	if amount <= 0:
		return

	if battle_scene.has_method("apply_damage_to_player"):
		battle_scene.call("apply_damage_to_player", amount)

	print(
		"최종목표 턴 스킬 효과 / 플레이어 피해:",
		amount,
		"/ 스킬:",
		String(skill_data.get("skill_id", ""))
	)


func _execute_apply_player_debuff(effect_data: Dictionary, skill_data: Dictionary) -> void:
	print(
		"최종목표 턴 스킬 예약 effect / 플레이어 디버프",
		"/ 스킬:", String(skill_data.get("skill_id", "")),
		"/ effect_data:", effect_data
	)


func _execute_buff_all_monsters(effect_data: Dictionary, skill_data: Dictionary) -> void:
	print(
		"최종목표 턴 스킬 예약 effect / 몬스터 버프",
		"/ 스킬:", String(skill_data.get("skill_id", "")),
		"/ effect_data:", effect_data
	)


func _execute_summon_monster(effect_data: Dictionary, skill_data: Dictionary) -> void:
	print(
		"최종목표 턴 스킬 예약 effect / 몬스터 소환",
		"/ 스킬:", String(skill_data.get("skill_id", "")),
		"/ effect_data:", effect_data
	)


func _build_definitions() -> void:
	definitions_by_skill_id.clear()
	skill_profile_by_profile_id.clear()

	definitions_by_skill_id["turn_start_none"] = {
		"skill_id": "turn_start_none",
		"display_name": "없음",
		"short_text": "-",
		"trigger": TRIGGER_TURN_START,
		"effects": []
	}

	definitions_by_skill_id["turn_end_none"] = {
		"skill_id": "turn_end_none",
		"display_name": "없음",
		"short_text": "-",
		"trigger": TRIGGER_TURN_END,
		"effects": []
	}

	definitions_by_skill_id["turn_start_damage_1"] = {
		"skill_id": "turn_start_damage_1",
		"display_name": "예고된 상처",
		"short_text": "1",
		"trigger": TRIGGER_TURN_START,
		"effects": [
			{
				"effect_type": EFFECT_DAMAGE_PLAYER,
				"amount": 1
			}
		]
	}

	definitions_by_skill_id["turn_end_damage_1"] = {
		"skill_id": "turn_end_damage_1",
		"display_name": "마무리 타격",
		"short_text": "1",
		"trigger": TRIGGER_TURN_END,
		"effects": [
			{
				"effect_type": EFFECT_DAMAGE_PLAYER,
				"amount": 1
			}
		]
	}

	skill_profile_by_profile_id["boss_none"] = {
		TRIGGER_TURN_START: "turn_start_none",
		TRIGGER_TURN_END: "turn_end_none"
	}

	skill_profile_by_profile_id["boss_test_damage_1"] = {
		TRIGGER_TURN_START: "turn_start_damage_1",
		TRIGGER_TURN_END: "turn_end_damage_1"
	}
func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return

	await get_tree().create_timer(seconds).timeout
