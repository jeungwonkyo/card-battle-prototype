extends Control
class_name FieldSlot

# 슬롯 번호 (1~7)
var slot_no: int = 0

# 소속 진영
# player / monster
var side: String = ""

# 현재 슬롯에 들어있는 카드
# 비어 있으면 null
var card = null

# 슬롯 파괴 여부
var is_broken: bool = false

# 상태 아이콘 목록
var status_icons: Array = []

# 필드 각인 / 특수효과 목록
var enchants: Array = []

func _ready() -> void:
	_apply_slot_info_from_node_name()
	add_to_group("field_slots")
	mouse_filter = Control.MOUSE_FILTER_STOP

	if has_node("ColorRect"):
		$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	print("슬롯 준비 완료 / 이름:", name, "/ 번호:", slot_no, "/ 진영:", side)

# 노드 이름을 기준으로 슬롯 번호와 진영 자동 설정
func _apply_slot_info_from_node_name() -> void:
	var node_name := String(name)

	if node_name.begins_with("PlayerSlot"):
		side = "player"
		var number_text := node_name.trim_prefix("PlayerSlot")
		slot_no = int(number_text)
		return

	if node_name.begins_with("MonsterSlot"):
		side = "monster"
		var number_text := node_name.trim_prefix("MonsterSlot")
		slot_no = int(number_text)
		return

	push_warning("슬롯 이름 규칙이 맞지 않습니다: " + node_name)

func can_place_card() -> bool:
	if is_broken:
		return false

	if card != null:
		return false

	return true

func place_card(card_node: Control) -> bool:
	if not can_place_card():
		print("카드 배치 실패 / 슬롯:", slot_no, "/ 진영:", side)
		return false

	var old_parent = card_node.get_parent()
	if old_parent != null:
		old_parent.remove_child(card_node)

	card = card_node
	add_child(card_node)

	if card_node.has_method("set_current_slot"):
		card_node.set_current_slot(self)

	card_node.position = Vector2.ZERO

	print("카드 배치 완료 / 슬롯:", slot_no, "/ 진영:", side)
	return true

func remove_card():
	if card == null:
		return null

	var removed_card = card
	remove_child(removed_card)
	card = null

	if removed_card.has_method("set_current_slot"):
		removed_card.set_current_slot(null)

	print("카드 제거 완료 / 슬롯:", slot_no, "/ 진영:", side)
	return removed_card

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return

	var battle_scene = get_tree().current_scene
	if battle_scene != null and battle_scene.has_method("on_field_slot_clicked"):
		battle_scene.on_field_slot_clicked(self)
