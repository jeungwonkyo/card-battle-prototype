extends Control
class_name PlayerStatusUI

@export var start_hp: int = 40
@export var start_tp: int = 5
@export var tp_filled_symbol: String = "🎗"
@export var tp_empty_symbol: String = "○"
@export var tp_ribbon_font_size: int = 32
@export var tp_ribbon_spacing: int = 6
@export_node_path("Control") var tp_container_path: NodePath = NodePath("../PlayerStatusUI2")
@export var hp_preview_font_size: int = 24
@export var hp_preview_down_color: Color = Color(0.95, 0.48, 0.48, 1.0)
@export var hp_preview_up_color: Color = Color(0.50, 0.88, 0.50, 1.0)

const PLAYER_HP_TEXT_COLOR: Color = Color(0.96, 0.78, 0.42, 1.0)
const PLAYER_HP_TEXT_OUTLINE_COLOR: Color = Color(0.16, 0.09, 0.03, 1.0)
const PLAYER_HP_TEXT_OUTLINE_SIZE: int = 4
const PLAYER_HP_LABEL_OFFSET_Y: float = -6.0

var max_hp: int = 0
var current_hp: int = 0
var current_tp: int = 0

var hp_label: Label = null
var hp_preview_label: Label = null
var tp_label: Label = null
var tp_container: Control = null
var tp_ribbon_row: HBoxContainer = null
var tp_ribbon_labels: Array = []


func _ready() -> void:
	max_hp = max(0, start_hp)
	current_hp = max_hp
	current_tp = max(0, start_tp)

	_ensure_ui()
	_refresh_ui()
	clear_hp_preview()


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
	hp_label.add_theme_color_override("font_color", PLAYER_HP_TEXT_COLOR)
	hp_label.add_theme_color_override("font_outline_color", PLAYER_HP_TEXT_OUTLINE_COLOR)
	hp_label.add_theme_constant_override("outline_size", PLAYER_HP_TEXT_OUTLINE_SIZE)
	hp_label.offset_top = PLAYER_HP_LABEL_OFFSET_Y
	hp_label.offset_bottom = PLAYER_HP_LABEL_OFFSET_Y

	hp_preview_label = get_node_or_null("HpPreviewLabel") as Label
	if hp_preview_label == null:
		hp_preview_label = Label.new()
		hp_preview_label.name = "HpPreviewLabel"
		add_child(hp_preview_label)

	hp_preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_preview_label.offset_left = 0.0
	hp_preview_label.offset_top = 28.0
	hp_preview_label.offset_right = 0.0
	hp_preview_label.offset_bottom = 0.0
	hp_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hp_preview_label.add_theme_font_size_override("font_size", hp_preview_font_size)
	hp_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_preview_label.visible = false

	tp_container = get_node_or_null(tp_container_path) as Control
	if tp_container == null:
		tp_container = self

	tp_label = tp_container.get_node_or_null("TpLabel") as Label
	if tp_label != null:
		tp_label.visible = false

	tp_ribbon_row = tp_container.get_node_or_null("TpRibbonRow") as HBoxContainer
	if tp_ribbon_row == null:
		tp_ribbon_row = HBoxContainer.new()
		tp_ribbon_row.name = "TpRibbonRow"
		tp_container.add_child(tp_ribbon_row)

	tp_ribbon_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	tp_ribbon_row.offset_left = 0.0
	tp_ribbon_row.offset_top = 0.0
	tp_ribbon_row.offset_right = 0.0
	tp_ribbon_row.offset_bottom = 0.0
	tp_ribbon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tp_ribbon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp_ribbon_row.add_theme_constant_override("separation", tp_ribbon_spacing)

	_rebuild_tp_ribbon_labels()


func _refresh_ui() -> void:
	if hp_label != null:
		hp_label.text = "HP %d/%d" % [current_hp, max_hp]

	if tp_label != null:
		tp_label.visible = false

	_refresh_tp_ribbon_ui()


func _rebuild_tp_ribbon_labels() -> void:
	if tp_ribbon_row == null:
		return

	for child in tp_ribbon_row.get_children():
		child.queue_free()

	tp_ribbon_labels.clear()

	for index in range(max(0, start_tp)):
		var ribbon_label := Label.new()
		ribbon_label.name = "TpRibbon_%d" % index
		ribbon_label.custom_minimum_size = Vector2(34, 48)
		ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ribbon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon_label.add_theme_font_size_override("font_size", tp_ribbon_font_size)
		tp_ribbon_row.add_child(ribbon_label)
		tp_ribbon_labels.append(ribbon_label)

	_refresh_tp_ribbon_ui()


func _refresh_tp_ribbon_ui() -> void:
	if tp_ribbon_row == null:
		return

	if tp_ribbon_labels.size() != max(0, start_tp):
		_rebuild_tp_ribbon_labels()
		return

	var visible_tp: int = clamp(current_tp, 0, tp_ribbon_labels.size())

	for index in range(tp_ribbon_labels.size()):
		var ribbon_label: Label = tp_ribbon_labels[index] as Label
		if ribbon_label == null:
			continue

		if index < visible_tp:
			ribbon_label.text = tp_filled_symbol
			ribbon_label.modulate = Color(1, 1, 1, 1)
		else:
			ribbon_label.text = tp_empty_symbol
			ribbon_label.modulate = Color(1, 1, 1, 0.35)


func show_hp_preview(current_hp_value: int, after_hp_value: int) -> void:
	if hp_preview_label == null:
		return

	if after_hp_value == current_hp_value:
		clear_hp_preview()
		return

	hp_preview_label.visible = true
	hp_preview_label.text = "→ %d" % clamp(after_hp_value, 0, max_hp)

	if after_hp_value < current_hp_value:
		hp_preview_label.add_theme_color_override("font_color", hp_preview_down_color)
	else:
		hp_preview_label.add_theme_color_override("font_color", hp_preview_up_color)


func clear_hp_preview() -> void:
	if hp_preview_label == null:
		return

	hp_preview_label.visible = false
	hp_preview_label.text = ""


func reset_tp_to_start() -> void:
	current_tp = max(0, start_tp)
	_refresh_ui()


func set_hp(value: int) -> void:
	current_hp = clamp(value, 0, max_hp)
	_refresh_ui()


func add_hp(value: int) -> void:
	if value == 0:
		return

	current_hp = clamp(current_hp + value, 0, max_hp)
	_refresh_ui()


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp


func set_tp(value: int) -> void:
	current_tp = clamp(value, 0, start_tp)
	_refresh_ui()


func add_tp(value: int) -> void:
	if value == 0:
		return

	current_tp = clamp(current_tp + value, 0, start_tp)
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
