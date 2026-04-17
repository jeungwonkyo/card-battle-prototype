extends Node

@export var start_hp: int = 40
@export_node_path("Control") var objective_root_path: NodePath
@export_node_path("Control") var objective_info_bar_path: NodePath

var current_hp: int = 0

var objective_root: Control = null
var objective_info_bar: Control = null

var objective_name_label: Label = null
var objective_hp_label: Label = null
var objective_highlight_panel: Panel = null


func _ready() -> void:
	objective_root = get_node_or_null(objective_root_path) as Control
	objective_info_bar = get_node_or_null(objective_info_bar_path) as Control
	initialize()


func initialize() -> void:
	current_hp = max(0, start_hp)
	_ensure_objective_name_label()
	_ensure_objective_hp_label()
	_ensure_objective_highlight_panel()
	_refresh_ui()


func _ensure_objective_name_label() -> void:
	if objective_root == null:
		return

	var found_label: Label = objective_root.get_node_or_null("FinalObjectiveNameLabel") as Label
	if found_label == null:
		found_label = Label.new()
		found_label.name = "FinalObjectiveNameLabel"
		found_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_label.offset_left = 0.0
		found_label.offset_top = 0.0
		found_label.offset_right = 0.0
		found_label.offset_bottom = 0.0
		found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		found_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		found_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_label.add_theme_font_size_override("font_size", 28)
		objective_root.add_child(found_label)

	objective_name_label = found_label


func _ensure_objective_hp_label() -> void:
	if objective_info_bar == null:
		return

	var found_label: Label = objective_info_bar.get_node_or_null("FinalObjectiveHpLabel") as Label
	if found_label == null:
		found_label = Label.new()
		found_label.name = "FinalObjectiveHpLabel"
		found_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_label.offset_left = 0.0
		found_label.offset_top = 0.0
		found_label.offset_right = 0.0
		found_label.offset_bottom = 0.0
		found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		found_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		found_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_label.add_theme_font_size_override("font_size", 24)
		objective_info_bar.add_child(found_label)

	objective_hp_label = found_label

func _ensure_objective_highlight_panel() -> void:
	if objective_root == null:
		return

	var found_panel: Panel = objective_root.get_node_or_null("FinalObjectiveHighlightPanel") as Panel
	if found_panel == null:
		found_panel = Panel.new()
		found_panel.name = "FinalObjectiveHighlightPanel"
		found_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_panel.offset_left = 0.0
		found_panel.offset_top = 0.0
		found_panel.offset_right = 0.0
		found_panel.offset_bottom = 0.0
		found_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_panel.visible = false
		found_panel.z_index = 100

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.2, 0.2, 0.14)
		style.border_color = Color(1.0, 0.2, 0.2, 1.0)
		style.border_width_left = 5
		style.border_width_top = 5
		style.border_width_right = 5
		style.border_width_bottom = 5
		found_panel.add_theme_stylebox_override("panel", style)

		objective_root.add_child(found_panel)

	objective_highlight_panel = found_panel


func _refresh_ui() -> void:
	if objective_name_label != null:
		objective_name_label.text = "최종목표"

	if objective_hp_label != null:
		objective_hp_label.text = "HP %d" % current_hp


func set_hp(value: int) -> void:
	current_hp = max(0, value)
	_refresh_ui()

func set_highlight(is_on: bool) -> void:
	if objective_highlight_panel == null:
		return

	objective_highlight_panel.visible = is_on

func get_objective_rect() -> Rect2:
	if objective_root == null:
		return Rect2()

	return objective_root.get_global_rect()

func get_action_motion_target() -> Control:
	return objective_root

func get_hp() -> int:
	return current_hp
