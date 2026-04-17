extends Control
class_name PlayerStatusUI

@export var start_hp: int = 40
@export var start_tp: int = 10
@export_node_path("Control") var tp_container_path: NodePath = NodePath("../PlayerStatusUI2")

var current_hp: int = 0
var current_tp: int = 0

var hp_label: Label = null
var tp_label: Label = null
var tp_container: Control = null


func _ready() -> void:
	current_hp = max(0, start_hp)
	current_tp = max(0, start_tp)

	_ensure_ui()
	_refresh_ui()


func _ensure_ui() -> void:
	hp_label = get_node_or_null("HpLabel") as Label
	if hp_label == null:
		hp_label = Label.new()
		hp_label.name = "HpLabel"
		add_child(hp_label)

	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.offset_left = 0.0
	hp_label.offset_top = 0.0
	hp_label.offset_right = 0.0
	hp_label.offset_bottom = 0.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 40)

	tp_container = get_node_or_null(tp_container_path) as Control
	if tp_container == null:
		tp_container = self

	tp_label = tp_container.get_node_or_null("TpLabel") as Label
	if tp_label == null:
		tp_label = Label.new()
		tp_label.name = "TpLabel"
		tp_container.add_child(tp_label)

	tp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tp_label.offset_left = 0.0
	tp_label.offset_top = 0.0
	tp_label.offset_right = 0.0
	tp_label.offset_bottom = 0.0
	tp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tp_label.add_theme_font_size_override("font_size", 40)


func _refresh_ui() -> void:
	if hp_label != null:
		hp_label.text = "HP %d" % current_hp

	if tp_label != null:
		tp_label.text = "TP %d" % current_tp


func reset_tp_to_start() -> void:
	current_tp = max(0, start_tp)
	_refresh_ui()


func set_hp(value: int) -> void:
	current_hp = max(0, value)
	_refresh_ui()


func add_hp(value: int) -> void:
	if value == 0:
		return

	current_hp = max(0, current_hp + value)
	_refresh_ui()


func get_hp() -> int:
	return current_hp


func set_tp(value: int) -> void:
	current_tp = max(0, value)
	_refresh_ui()


func add_tp(value: int) -> void:
	if value == 0:
		return

	current_tp = max(0, current_tp + value)
	_refresh_ui()


func can_spend_tp(cost: int) -> bool:
	if cost <= 0:
		return true

	return current_tp >= cost


func spend_tp(cost: int) -> bool:
	if cost <= 0:
		return true

	if current_tp < cost:
		return false

	current_tp -= cost
	_refresh_ui()
	return true


func get_tp() -> int:
	return current_tp
