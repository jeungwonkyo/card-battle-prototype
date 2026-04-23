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

# 카드 분류
# suit = 상위 분류(heart / diamond / clover / spade)
# faction = 하위 분류(sanctuary / bloodline 등)
var suit: String = ""
var faction: String = ""

# 소속 진영
var owner_side: String = "player"

# 생성카드 메타데이터
# is_generated_card = 전투 중 새로 생성된 카드 여부
# generated_card_type = clone / status / 이후 확장 타입
# source_instance_id = 생성 기준이 된 원본 카드 instance_id
# can_trigger_generate_effect = 생성 효과 발동 가능 여부
# 분신카드는 false로 써서 연쇄 생성 방지
var is_generated_card: bool = false
var generated_card_type: String = ""
var source_instance_id: int = 0
var can_trigger_generate_effect: bool = true

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

func mark_as_generated_card(new_generated_card_type: String, new_source_instance_id: int, new_can_trigger_generate_effect: bool) -> void:
	is_generated_card = true
	generated_card_type = new_generated_card_type.strip_edges().to_lower()
	source_instance_id = max(0, new_source_instance_id)
	can_trigger_generate_effect = new_can_trigger_generate_effect

func clear_generated_card_metadata() -> void:
	is_generated_card = false
	generated_card_type = ""
	source_instance_id = 0
	can_trigger_generate_effect = true

func is_clone_card() -> bool:
	return is_generated_card and generated_card_type == "clone"

func to_log_string() -> String:
	return "instance_id=%d / data_id=%d / combo_id=%d / card_name=%s / suit=%s / faction=%s / owner_side=%s / is_generated_card=%s / generated_card_type=%s / source_instance_id=%d / can_trigger_generate_effect=%s / base_level=%d / temp_level_delta=%d / current_level=%d" % [
		instance_id,
		data_id,
		combo_id,
		card_name,
		suit,
		faction,
		owner_side,
		str(is_generated_card),
		generated_card_type,
		source_instance_id,
		str(can_trigger_generate_effect),
		base_level,
		temp_level_delta,
		get_current_level()
	]
