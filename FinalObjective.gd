extends Node

const TRIGGER_TURN_START: String = "turn_start"
const TRIGGER_TURN_END: String = "turn_end"

const HP_BAR_FILL_COLOR: Color = Color(0.86, 0.22, 0.22, 1.0)
const HP_BAR_PREVIEW_LOSS_COLOR: Color = Color(0.50, 0.50, 0.50, 0.96)

@export var start_hp: int = 40
@export_node_path("Control") var objective_root_path: NodePath
@export_node_path("Control") var objective_info_bar_path: NodePath

var max_hp: int = 0
var current_hp: int = 0
var preview_hp: int = 0
var is_hp_preview_visible: bool = false

var objective_root: Control = null
var objective_info_bar: Control = null

var objective_name_label: Label = null
var objective_hp_label: Label = null
var objective_hp_fill_rect: ColorRect = null
var objective_hp_preview_loss_rect: ColorRect = null
var objective_highlight_panel: Panel = null

var skill_id_by_trigger: Dictionary = {}
var skill_ui_root_by_trigger: Dictionary = {}
var skill_name_label_by_trigger: Dictionary = {}
var skill_short_label_by_trigger: Dictionary = {}
var skill_trigger_label_by_trigger: Dictionary = {}
var skill_flash_overlay_by_trigger: Dictionary = {}


func _ready() -> void:
	objective_root = get_node_or_null(objective_root_path) as Control
	objective_info_bar = get_node_or_null(objective_info_bar_path) as Control
	initialize()


func initialize() -> void:
	max_hp = max(0, start_hp)
	current_hp = max_hp
	preview_hp = current_hp
	is_hp_preview_visible = false

	skill_id_by_trigger.clear()
	skill_id_by_trigger[TRIGGER_TURN_START] = "turn_start_none"
	skill_id_by_trigger[TRIGGER_TURN_END] = "turn_end_none"

	_ensure_objective_name_label()
	_ensure_objective_hp_label()
	_ensure_objective_highlight_panel()
	_ensure_skill_ui_by_trigger(TRIGGER_TURN_START)
	_ensure_skill_ui_by_trigger(TRIGGER_TURN_END)
	_set_default_skill_ui_text(TRIGGER_TURN_START)
	_set_default_skill_ui_text(TRIGGER_TURN_END)
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

	var found_fill_rect: ColorRect = objective_info_bar.get_node_or_null("FinalObjectiveHpFillRect") as ColorRect
	if found_fill_rect == null:
		found_fill_rect = ColorRect.new()
		found_fill_rect.name = "FinalObjectiveHpFillRect"
		found_fill_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		found_fill_rect.offset_left = 0.0
		found_fill_rect.offset_top = 0.0
		found_fill_rect.offset_right = 0.0
		found_fill_rect.offset_bottom = 0.0
		found_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_fill_rect.color = HP_BAR_FILL_COLOR
		objective_info_bar.add_child(found_fill_rect)

	var found_preview_loss_rect: ColorRect = objective_info_bar.get_node_or_null("FinalObjectiveHpPreviewLossRect") as ColorRect
	if found_preview_loss_rect == null:
		found_preview_loss_rect = ColorRect.new()
		found_preview_loss_rect.name = "FinalObjectiveHpPreviewLossRect"
		found_preview_loss_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
		found_preview_loss_rect.anchor_right = 0.0
		found_preview_loss_rect.anchor_bottom = 1.0
		found_preview_loss_rect.offset_left = 0.0
		found_preview_loss_rect.offset_top = 0.0
		found_preview_loss_rect.offset_right = 0.0
		found_preview_loss_rect.offset_bottom = 0.0
		found_preview_loss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_preview_loss_rect.visible = false
		found_preview_loss_rect.color = HP_BAR_PREVIEW_LOSS_COLOR
		objective_info_bar.add_child(found_preview_loss_rect)

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

	objective_hp_fill_rect = found_fill_rect
	objective_hp_preview_loss_rect = found_preview_loss_rect
	objective_hp_label = found_label

	var background_panel: Panel = objective_info_bar.get_node_or_null("Panel") as Panel
	if background_panel != null:
		background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	objective_info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _ensure_skill_ui_by_trigger(trigger_type: String) -> void:
	var skill_ui_root: Control = _get_or_find_skill_ui_root(trigger_type)
	if skill_ui_root == null:
		return

	var ui_container: Control = skill_ui_root.get_node_or_null("Background") as Control
	if ui_container == null:
		ui_container = skill_ui_root

	var name_label: Label = ui_container.get_node_or_null("SkillNameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "SkillNameLabel"
		name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_label.offset_left = 8.0
		name_label.offset_top = 12.0
		name_label.offset_right = -8.0
		name_label.offset_bottom = -88.0
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 18)
		ui_container.add_child(name_label)

	var short_label: Label = ui_container.get_node_or_null("SkillShortTextLabel") as Label
	if short_label == null:
		short_label = Label.new()
		short_label.name = "SkillShortTextLabel"
		short_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		short_label.offset_left = 8.0
		short_label.offset_top = 56.0
		short_label.offset_right = -8.0
		short_label.offset_bottom = -30.0
		short_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		short_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		short_label.add_theme_font_size_override("font_size", 42)
		ui_container.add_child(short_label)

	var trigger_label: Label = ui_container.get_node_or_null("SkillTriggerLabel") as Label
	if trigger_label == null:
		trigger_label = Label.new()
		trigger_label.name = "SkillTriggerLabel"
		trigger_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		trigger_label.offset_left = 8.0
		trigger_label.offset_top = 110.0
		trigger_label.offset_right = -8.0
		trigger_label.offset_bottom = -6.0
		trigger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trigger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		trigger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trigger_label.add_theme_font_size_override("font_size", 14)
		ui_container.add_child(trigger_label)

	var flash_overlay: ColorRect = skill_ui_root.get_node_or_null("SkillFlashOverlay") as ColorRect
	if flash_overlay == null:
		flash_overlay = ColorRect.new()
		flash_overlay.name = "SkillFlashOverlay"
		flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_overlay.offset_left = 0.0
		flash_overlay.offset_top = 0.0
		flash_overlay.offset_right = 0.0
		flash_overlay.offset_bottom = 0.0
		flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_overlay.visible = false
		flash_overlay.color = Color(1.0, 0.95, 0.35, 0.0)
		flash_overlay.z_index = 100
		skill_ui_root.add_child(flash_overlay)

	skill_name_label_by_trigger[trigger_type] = name_label
	skill_short_label_by_trigger[trigger_type] = short_label
	skill_trigger_label_by_trigger[trigger_type] = trigger_label
	skill_flash_overlay_by_trigger[trigger_type] = flash_overlay


func _get_or_find_skill_ui_root(trigger_type: String) -> Control:
	if skill_ui_root_by_trigger.has(trigger_type):
		var saved_root: Control = skill_ui_root_by_trigger.get(trigger_type) as Control
		if saved_root != null and is_instance_valid(saved_root):
			return saved_root

	var found_root: Control = null

	match trigger_type:
		TRIGGER_TURN_START:
			found_root = get_node_or_null("../TurnStartSkillUI") as Control

		TRIGGER_TURN_END:
			found_root = get_node_or_null("../TurnEndSkillUI") as Control
			if found_root == null:
				found_root = get_node_or_null("../TurnStartSkillUI2") as Control

	if found_root != null:
		skill_ui_root_by_trigger[trigger_type] = found_root

	return found_root


func _set_default_skill_ui_text(trigger_type: String) -> void:
	var name_label: Label = skill_name_label_by_trigger.get(trigger_type, null) as Label
	var short_label: Label = skill_short_label_by_trigger.get(trigger_type, null) as Label
	var trigger_label: Label = skill_trigger_label_by_trigger.get(trigger_type, null) as Label

	if name_label != null:
		name_label.text = "없음"

	if short_label != null:
		short_label.text = "-"

	if trigger_label != null:
		trigger_label.text = _get_trigger_display_name(trigger_type)


func _refresh_ui() -> void:
	if objective_name_label != null:
		objective_name_label.text = "최종목표"

	_refresh_hp_ui()


func _refresh_hp_ui() -> void:
	if objective_info_bar == null:
		return

	var safe_max_hp: int = max(1, max_hp)
	var clamped_current_hp: int = clamp(current_hp, 0, max_hp)
	var displayed_hp: int = clamped_current_hp

	if is_hp_preview_visible:
		displayed_hp = clamp(preview_hp, 0, clamped_current_hp)

	var total_width: float = objective_info_bar.get_global_rect().size.x
	if total_width <= 0.0:
		total_width = objective_info_bar.size.x
	if total_width <= 0.0:
		call_deferred("_refresh_hp_ui")
		return

	var current_ratio: float = float(clamped_current_hp) / float(safe_max_hp)
	var displayed_ratio: float = float(displayed_hp) / float(safe_max_hp)
	var current_width: float = total_width * current_ratio
	var displayed_width: float = total_width * displayed_ratio

	if objective_hp_fill_rect != null:
		objective_hp_fill_rect.color = HP_BAR_FILL_COLOR
		objective_hp_fill_rect.anchor_left = 0.0
		objective_hp_fill_rect.anchor_top = 0.0
		objective_hp_fill_rect.anchor_right = 0.0
		objective_hp_fill_rect.anchor_bottom = 1.0
		objective_hp_fill_rect.offset_left = 0.0
		objective_hp_fill_rect.offset_top = 0.0
		objective_hp_fill_rect.offset_right = current_width
		objective_hp_fill_rect.offset_bottom = 0.0
		objective_hp_fill_rect.visible = clamped_current_hp > 0

	if objective_hp_preview_loss_rect != null:
		var preview_loss_width: float = max(0.0, current_width - displayed_width)
		objective_hp_preview_loss_rect.color = HP_BAR_PREVIEW_LOSS_COLOR
		objective_hp_preview_loss_rect.offset_left = displayed_width
		objective_hp_preview_loss_rect.offset_top = 0.0
		objective_hp_preview_loss_rect.offset_right = preview_loss_width
		objective_hp_preview_loss_rect.offset_bottom = 0.0
		objective_hp_preview_loss_rect.visible = is_hp_preview_visible and preview_loss_width > 0.0

	if objective_hp_label != null:
		if is_hp_preview_visible and displayed_hp != clamped_current_hp:
			objective_hp_label.text = "HP %d >> %d/%d" % [clamped_current_hp, displayed_hp, max_hp]
		else:
			objective_hp_label.text = "HP %d/%d" % [clamped_current_hp, max_hp]


func set_hp(value: int) -> void:
	current_hp = clamp(value, 0, max_hp)
	clear_hp_preview()
	_refresh_ui()


func show_hp_preview(_current_value: int, preview_value: int) -> void:
	var clamped_preview_hp: int = clamp(preview_value, 0, current_hp)

	if clamped_preview_hp == current_hp:
		clear_hp_preview()
		return

	preview_hp = clamped_preview_hp
	is_hp_preview_visible = true
	_refresh_hp_ui()


func clear_hp_preview() -> void:
	preview_hp = current_hp
	is_hp_preview_visible = false
	_refresh_hp_ui()


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


func get_max_hp() -> int:
	return max_hp


func set_skill_id_by_trigger(trigger_type: String, skill_id: String) -> void:
	if trigger_type != TRIGGER_TURN_START and trigger_type != TRIGGER_TURN_END:
		print("최종목표 스킬 저장 실패 / 알 수 없는 trigger:", trigger_type)
		return

	skill_id_by_trigger[trigger_type] = skill_id


func get_skill_id_by_trigger(trigger_type: String) -> String:
	return String(skill_id_by_trigger.get(trigger_type, ""))


func set_skill_display(trigger_type: String, display_name: String, short_text: String) -> void:
	_ensure_skill_ui_by_trigger(trigger_type)

	var name_label: Label = skill_name_label_by_trigger.get(trigger_type, null) as Label
	var short_label: Label = skill_short_label_by_trigger.get(trigger_type, null) as Label
	var trigger_label: Label = skill_trigger_label_by_trigger.get(trigger_type, null) as Label

	if name_label != null:
		name_label.text = display_name

	if short_label != null:
		short_label.text = short_text

	if trigger_label != null:
		trigger_label.text = _get_trigger_display_name(trigger_type)


func play_skill_ui_trigger_feedback(trigger_type: String) -> void:
	_ensure_skill_ui_by_trigger(trigger_type)

	var flash_overlay: ColorRect = skill_flash_overlay_by_trigger.get(trigger_type, null) as ColorRect
	if flash_overlay == null:
		return

	flash_overlay.visible = true
	flash_overlay.color = Color(1.0, 0.95, 0.35, 0.82)
	flash_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()
	tween.tween_property(flash_overlay, "modulate:a", 1.0, 0.08)
	tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.2)
	tween.finished.connect(
		func() -> void:
			if flash_overlay != null and is_instance_valid(flash_overlay):
				flash_overlay.visible = false
	)


func _get_trigger_display_name(trigger_type: String) -> String:
	match trigger_type:
		TRIGGER_TURN_START:
			return "턴 시작"

		TRIGGER_TURN_END:
			return "턴 종료"

	return trigger_type
