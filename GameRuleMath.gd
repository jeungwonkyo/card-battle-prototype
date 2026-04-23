extends Node
class_name GameRuleMath

func round_value(value: float) -> int:
	if value >= 0.0:
		return int(floor(value + 0.5))

	return int(ceil(value - 0.5))


func scaled_value(base_value: float, ratio: float) -> int:
	return round_value(base_value * ratio)


func half_value(base_value: float) -> int:
	return scaled_value(base_value, 0.5)


func to_text(value: float) -> String:
	return str(round_value(value))


func half_to_text(base_value: float) -> String:
	return str(half_value(base_value))
