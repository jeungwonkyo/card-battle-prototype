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

func to_log_string() -> String:
	return "instance_id=%d / data_id=%d / combo_id=%d / card_name=%s / owner_side=%s" % [
		instance_id,
		data_id,
		combo_id,
		card_name,
		owner_side
	]
