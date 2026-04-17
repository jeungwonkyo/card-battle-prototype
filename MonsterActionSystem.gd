extends Node
class_name MonsterActionSystem

@export var basic_attack_damage: int = 1
@export var final_objective_attack_damage: int = 1
@export var action_interval_sec: float = 0.25
@export var attack_dash_distance: float = 36.0
@export var attack_dash_forward_time: float = 0.08
@export var attack_dash_return_time: float = 0.10

var battle_scene: Node = null
var is_action_phase_in_progress: bool = false


func setup(owner_battle_scene: Node) -> void:
	battle_scene = owner_battle_scene


func run_action_phase(trigger_type: String) -> void:
	if is_action_phase_in_progress:
		print("몬스터 행동 페이즈 무시 / 이미 진행 중")
		return

	if battle_scene == null:
		print("몬스터 행동 페이즈 실패 / battle_scene 없음")
		return

	if not _can_run_action_phase():
		print("몬스터 행동 페이즈 실패 / 필요한 BattleScene 함수 없음")
		return

	is_action_phase_in_progress = true
	print("===== 몬스터 행동 페이즈 시작 / 트리거:", trigger_type, "=====")

	for slot_no in range(1, 8):
		if _get_monster_current_hp(slot_no) <= 0:
			continue

		await _execute_monster_action(slot_no, trigger_type)

	await _execute_final_objective_action(trigger_type)

	print("===== 몬스터 행동 페이즈 종료 / 트리거:", trigger_type, "=====")
	is_action_phase_in_progress = false


func _execute_monster_action(slot_no: int, trigger_type: String) -> void:
	if slot_no <= 0:
		return

	if _get_monster_current_hp(slot_no) <= 0:
		return

	print(
		"몬스터 행동 실행 / 슬롯:", slot_no,
		"/ 트리거:", trigger_type,
		"/ 기본 공격력:", basic_attack_damage
	)

	if basic_attack_damage > 0:
		var monster_unit: Control = _get_monster_unit(slot_no)
		await _play_attack_motion(monster_unit)
		_damage_player(basic_attack_damage)
	else:
		print("몬스터 행동 스킵 / 공격력 0 / 슬롯:", slot_no)

	if is_inside_tree():
		await get_tree().create_timer(action_interval_sec).timeout


func _execute_final_objective_action(trigger_type: String) -> void:
	if _get_final_objective_hp() <= 0:
		return

	print(
		"최종목표 행동 실행 / 트리거:", trigger_type,
		"/ 공격력:", final_objective_attack_damage
	)

	if final_objective_attack_damage > 0:
		var objective_root: Control = _get_final_objective_motion_target()
		await _play_attack_motion(objective_root)
		_damage_player(final_objective_attack_damage)
	else:
		print("최종목표 행동 스킵 / 공격력 0")

	if is_inside_tree():
		await get_tree().create_timer(action_interval_sec).timeout


func _play_attack_motion(target_control: Control) -> void:
	if target_control == null:
		return
	if not is_instance_valid(target_control):
		return

	var original_position: Vector2 = target_control.position
	var dash_position: Vector2 = original_position + Vector2(0.0, attack_dash_distance)

	var forward_tween := create_tween()
	forward_tween.tween_property(target_control, "position", dash_position, attack_dash_forward_time)
	await forward_tween.finished

	if not is_instance_valid(target_control):
		return

	var return_tween := create_tween()
	return_tween.tween_property(target_control, "position", original_position, attack_dash_return_time)
	await return_tween.finished

	if is_instance_valid(target_control):
		target_control.position = original_position


func _damage_player(damage: int) -> void:
	if damage <= 0:
		return

	var status_ui: Node = _get_player_status_ui()
	if status_ui == null:
		print("플레이어 피격 실패 / PlayerStatusUI 없음")
		return

	if not status_ui.has_method("add_hp"):
		print("플레이어 피격 실패 / add_hp 없음")
		return

	status_ui.add_hp(-damage)

	var current_hp: int = 0
	if status_ui.has_method("get_hp"):
		current_hp = int(status_ui.get_hp())

	print("플레이어 피격 / 피해:", damage, "/ 남은 HP:", current_hp)


func _get_player_status_ui() -> Node:
	if battle_scene == null:
		return null

	var found_from_property = battle_scene.get("player_status_ui")
	if found_from_property != null and is_instance_valid(found_from_property):
		return found_from_property

	if battle_scene.has_node("Layer0_UI/PlayerStatusUI"):
		return battle_scene.get_node("Layer0_UI/PlayerStatusUI")

	return null


func _get_monster_current_hp(slot_no: int) -> int:
	if battle_scene == null:
		return 0

	return int(battle_scene.call("_get_monster_current_hp", slot_no))


func _get_monster_unit(slot_no: int) -> Control:
	if battle_scene == null:
		return null

	if not battle_scene.has_method("_get_monster_unit"):
		return null

	return battle_scene.call("_get_monster_unit", slot_no) as Control


func _get_final_objective() -> Node:
	if battle_scene == null:
		return null

	var found_objective = battle_scene.get("final_objective")
	if found_objective != null and is_instance_valid(found_objective):
		return found_objective

	return null


func _get_final_objective_hp() -> int:
	var objective: Node = _get_final_objective()
	if objective == null:
		return 0

	if not objective.has_method("get_hp"):
		return 0

	return int(objective.call("get_hp"))


func _get_final_objective_motion_target() -> Control:
	var objective: Node = _get_final_objective()
	if objective == null:
		return null

	if not objective.has_method("get_action_motion_target"):
		return null

	return objective.call("get_action_motion_target") as Control


func _can_run_action_phase() -> bool:
	if battle_scene == null:
		return false

	if not battle_scene.has_method("_get_monster_current_hp"):
		return false

	return true


func set_basic_attack_damage(new_damage: int) -> void:
	basic_attack_damage = max(0, new_damage)


func get_basic_attack_damage() -> int:
	return basic_attack_damage


func set_final_objective_attack_damage(new_damage: int) -> void:
	final_objective_attack_damage = max(0, new_damage)


func get_final_objective_attack_damage() -> int:
	return final_objective_attack_damage
