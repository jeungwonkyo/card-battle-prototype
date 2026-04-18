extends RefCounted
class_name CardState

# 실제 카드 1장 고유값
var instance_id: int = 0

# 카드 내용 / 이름 / 스킬용 값
var data_id: int = 0

# 조합 판정용 그룹값
var combo_id: int = 0

# 카드 이름
# 예: 빨강_01 / 파랑_03
var card_name: String = ""

# 소속 진영
var owner_side: String = "player"

# 카드 레벨 구조
# base_level = 런 내 성장으로 유지되는 기본 레벨
# temp_level_delta = 전투 중 버프/디버프로 즉시 바뀌는 변화량
var base_level: int = 1
var temp_level_delta: int = 0

func get_current_level() -> int:
	return max(0, base_level + temp_level_delta)

func set_base_level(new_level: int) -> void:
	base_level = max(0, new_level)

func add_base_level(delta: int) -> void:
	base_level = max(0, base_level + delta)

func set_temp_level_delta(new_delta: int) -> void:
	temp_level_delta = new_delta

func add_temp_level_delta(delta: int) -> void:
	temp_level_delta += delta

func clear_temp_level_delta() -> void:
	temp_level_delta = 0

func to_log_string() -> String:
	return "instance_id=%d / data_id=%d / combo_id=%d / card_name=%s / owner_side=%s / base_level=%d / temp_level_delta=%d / current_level=%d" % [
		instance_id,
		data_id,
		combo_id,
		card_name,
		owner_side,
		base_level,
		temp_level_delta,
		get_current_level()
	]
