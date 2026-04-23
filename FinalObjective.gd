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

var objective_hp_gauge_root: Control = null
var objective_hp_gauge_bg: ColorRect = null
var objective_hp_gauge_fill: ColorRect = null
var objective_hp_gauge_preview_overlay: ColorRect = null

var current_preview_after_hp: int = -1


func _ready() -> void:
	objective_root = get_node_or_null(objective_root_path) as Control
	objective_info_bar = get_node_or_null(objective_info_bar_path) as Control
	initialize()


func initialize() -> void:
	current_hp = max(0, start_hp)
	_ensure_objective_name_label()
	_ensure_objective_hp_gauge()
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
		found_label.add_theme_color_override("font_color", Color(1, 0.92, 0.92, 1))
		found_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		found_label.add_theme_constant_override("outline_size", 2)
		objective_root.add_child(found_label)

	objective_name_label = found_label


func _ensure_objective_hp_gauge() -> void:
	if objective_info_bar == null:
		return

	var found_root: Control = objective_info_bar.get_node_or_null("FinalObjectiveHpGaugeRoot") as Control
	if found_root == null:
		found_root = Control.new()
		found_root.name = "FinalObjectiveHpGaugeRoot"
		found_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_root.offset_left = 0.0
		found_root.offset_top = 0.0
		found_root.offset_right = 0.0
		found_root.offset_bottom = 0.0
		found_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_root.z_index = 5
		objective_info_bar.add_child(found_root)

	objective_hp_gauge_root = found_root

	var found_bg: ColorRect = objective_hp_gauge_root.get_node_or_null("FinalObjectiveHpGaugeBg") as ColorRect
	if found_bg == null:
		found_bg = ColorRect.new()
		found_bg.name = "FinalObjectiveHpGaugeBg"
		found_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_bg.offset_left = 0.0
		found_bg.offset_top = 0.0
		found_bg.offset_right = 0.0
		found_bg.offset_bottom = 0.0
		found_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_bg.color = Color(0.48, 0.48, 0.48, 1.0)
		objective_hp_gauge_root.add_child(found_bg)

	objective_hp_gauge_bg = found_bg

	var found_fill: ColorRect = objective_hp_gauge_root.get_node_or_null("FinalObjectiveHpGaugeFill") as ColorRect
	if found_fill == null:
		found_fill = ColorRect.new()
		found_fill.name = "FinalObjectiveHpGaugeFill"
		found_fill.anchor_left = 0.0
		found_fill.anchor_top = 0.0
		found_fill.anchor_right = 0.0
		found_fill.anchor_bottom = 1.0
		found_fill.offset_left = 0.0
		found_fill.offset_top = 0.0
		found_fill.offset_right = 0.0
		found_fill.offset_bottom = 0.0
		found_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_fill.color = Color(0.84, 0.20, 0.20, 1.0)
		found_fill.z_index = 1
		objective_hp_gauge_root.add_child(found_fill)

	objective_hp_gauge_fill = found_fill

	var found_preview: ColorRect = objective_hp_gauge_root.get_node_or_null("FinalObjectiveHpGaugePreviewOverlay") as ColorRect
	if found_preview == null:
		found_preview = ColorRect.new()
		found_preview.name = "FinalObjectiveHpGaugePreviewOverlay"
		found_preview.anchor_left = 0.0
		found_preview.anchor_top = 0.0
		found_preview.anchor_right = 0.0
		found_preview.anchor_bottom = 1.0
		found_preview.offset_left = 0.0
		found_preview.offset_top = 0.0
		found_preview.offset_right = 0.0
		found_preview.offset_bottom = 0.0
		found_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_preview.color = Color(0.32, 0.32, 0.32, 0.92)
		found_preview.visible = false
		found_preview.z_index = 2
		objective_hp_gauge_root.add_child(found_preview)

	objective_hp_gauge_preview_overlay = found_preview


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
		found_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		found_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		found_label.add_theme_constant_override("outline_size", 2)
		found_label.z_index = 10
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
		objective_hp_label.text = "HP %d / %d" % [current_hp, max(1, start_hp)]

	_refresh_hp_gauge_visuals()


func _refresh_hp_gauge_visuals() -> void:
	if objective_hp_gauge_root == null:
		return
	if objective_hp_gauge_fill == null:
		return

	var gauge_width: float = objective_hp_gauge_root.size.x
	var fill_width: float = _get_hp_width_by_value(current_hp)

	objective_hp_gauge_fill.position = Vector2.ZERO
	objective_hp_gauge_fill.size = Vector2(fill_width, objective_hp_gauge_root.size.y)

	if objective_hp_gauge_preview_overlay != null and objective_hp_gauge_preview_overlay.visible:
		_update_preview_overlay_visual(current_preview_after_hp)


func _get_hp_width_by_value(value: int) -> float:
	if objective_hp_gauge_root == null:
		return 0.0

	var max_hp: int = max(1, start_hp)
	var clamped_value: int = clamp(value, 0, max_hp)
	return objective_hp_gauge_root.size.x * (float(clamped_value) / float(max_hp))


func show_hp_preview(after_hp: int) -> void:
	if objective_hp_gauge_preview_overlay == null:
		return

	var preview_hp: int = clamp(after_hp, 0, current_hp)

	if preview_hp >= current_hp:
		clear_hp_preview()
		return

	current_preview_after_hp = preview_hp
	objective_hp_gauge_preview_overlay.visible = true
	_update_preview_overlay_visual(preview_hp)

	if objective_hp_label != null:
		objective_hp_label.text = "HP %d → %d / %d" % [current_hp, preview_hp, max(1, start_hp)]


func _update_preview_overlay_visual(after_hp: int) -> void:
	if objective_hp_gauge_root == null:
		return
	if objective_hp_gauge_preview_overlay == null:
		return

	var current_width: float = _get_hp_width_by_value(current_hp)
	var after_width: float = _get_hp_width_by_value(after_hp)
	var preview_width: float = maxf(0.0, current_width - after_width)

	objective_hp_gauge_preview_overlay.position = Vector2(after_width, 0.0)
	objective_hp_gauge_preview_overlay.size = Vector2(preview_width, objective_hp_gauge_root.size.y)
	objective_hp_gauge_preview_overlay.modulate = Color(1, 1, 1, 1)


func clear_hp_preview() -> void:
	current_preview_after_hp = -1

	if objective_hp_gauge_preview_overlay != null:
		objective_hp_gauge_preview_overlay.visible = false
		objective_hp_gauge_preview_overlay.position = Vector2.ZERO
		objective_hp_gauge_preview_overlay.size = Vector2.ZERO
		objective_hp_gauge_preview_overlay.modulate = Color(1, 1, 1, 1)

	if objective_hp_label != null:
		objective_hp_label.text = "HP %d / %d" % [current_hp, max(1, start_hp)]


func play_hp_preview_confirm_animation(final_hp: int) -> void:
	var next_hp: int = clamp(final_hp, 0, max(1, start_hp))

	if objective_hp_gauge_fill == null:
		current_hp = next_hp
		_refresh_ui()
		return

	if objective_hp_gauge_preview_overlay == null or not objective_hp_gauge_preview_overlay.visible:
		current_hp = next_hp
		_refresh_ui()
		return

	var next_width: float = _get_hp_width_by_value(next_hp)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(objective_hp_gauge_fill, "size", Vector2(next_width, objective_hp_gauge_root.size.y), 0.14)
	tween.tween_property(objective_hp_gauge_preview_overlay, "modulate", Color(1, 1, 1, 0.0), 0.14)
	await tween.finished

	current_hp = next_hp
	clear_hp_preview()
	_refresh_ui()


func set_hp(value: int) -> void:
	current_hp = max(0, value)
	clear_hp_preview()
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
