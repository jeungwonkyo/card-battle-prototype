extends Node
class_name FinalObjectiveDefinition

const DEFAULT_FINAL_OBJECTIVE_ID: String = "test_final_objective_01"

const TRIGGER_TURN_START: String = "turn_start"
const TRIGGER_TURN_END: String = "turn_end"

var definitions_by_id: Dictionary = {}


func _init() -> void:
	_build_definitions()


func get_definition(final_objective_id: String) -> Dictionary:
	if final_objective_id == "":
		final_objective_id = DEFAULT_FINAL_OBJECTIVE_ID

	if not definitions_by_id.has(final_objective_id):
		print("최종목표 데이터 없음:", final_objective_id)
		return {}

	return (definitions_by_id.get(final_objective_id, {}) as Dictionary).duplicate(true)


func has_definition(final_objective_id: String) -> bool:
	return definitions_by_id.has(final_objective_id)


func get_all_definition_ids() -> Array:
	return definitions_by_id.keys()


func _build_definitions() -> void:
	definitions_by_id.clear()

	definitions_by_id["test_final_objective_01"] = {
		"final_objective_id": "test_final_objective_01",
		"display_name": "최종목표",
		"max_hp": 20,
		"image_path": "res://ui/FinalObjective/FinalObjective01.png",
		TRIGGER_TURN_START: "turn_start_damage_1",
		TRIGGER_TURN_END: "turn_end_damage_1"
	}

	definitions_by_id["test_final_objective_none"] = {
		"final_objective_id": "test_final_objective_none",
		"display_name": "훈련용 최종목표",
		"max_hp": 40,
		"image_path": "",
		TRIGGER_TURN_START: "turn_start_none",
		TRIGGER_TURN_END: "turn_end_none"
	}
