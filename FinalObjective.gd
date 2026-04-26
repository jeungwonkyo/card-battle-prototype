extends Node

const TRIGGER_TURN_START: String = "turn_start"
const TRIGGER_TURN_END: String = "turn_end"

const HP_FILL_TEXTURE_PATH: String = "res://ui/End EnemyHP.png"
const HP_FRAME_TEXTURE_PATH: String = "res://ui/End EnemyHPCase.png"

const HP_BAR_FILL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const HP_BAR_BACK_MODULATE: Color = Color(0.22, 0.05, 0.04, 1.0)
const HP_BAR_PREVIEW_LOSS_MODULATE: Color = Color(0.45, 0.45, 0.45, 0.96)

const FINAL_OBJECTIVE_HP_TEXT_COLOR: Color = Color(0.886, 0.710, 0.400, 1.0)
const FINAL_OBJECTIVE_HP_TEXT_OUTLINE_COLOR: Color = Color(0.23, 0.14, 0.05, 1.0)
const FINAL_OBJECTIVE_HP_TEXT_OUTLINE_SIZE: int = 3

const HP_FILL_OFFSET_LEFT: float = 0.0
const HP_FILL_OFFSET_TOP: float = 1.0
const HP_FILL_OFFSET_RIGHT: float = 0.0
const HP_FILL_OFFSET_BOTTOM: float = 6.0

const HP_LABEL_OFFSET_Y: float = -5.0

@export var fallback_hp: int = 40
@export_node_path("Control") var objective_root_path: NodePath
@export_node_path("Control") var objective_info_bar_path: NodePath

var final_objective_id: String = ""
var display_name: String = "최종목표"

var max_hp: int = 0
var current_hp: int = 0
var preview_hp: int = 0
var is_hp_preview_visible: bool = false

var objective_root: Control = null
var objective_info_bar: Control = null

var final_objective_image_texture: TextureRect = null

var objective_name_label: Label = null
var objective_hp_label: Label = null
var objective_hp_back_texture: TextureRect = null
var objective_hp_fill_clip: Control = null
var objective_hp_fill_texture: TextureRect = null
var objective_hp_preview_loss_clip: Control = null
var objective_hp_preview_loss_texture: TextureRect = null
var objective_hp_frame_texture: TextureRect = null
var objective_highlight_panel: Panel = null

var skill_id_by_trigger: Dictionary = {}
var skill_ui_root_by_trigger: Dictionary = {}
var skill_name_label_by_trigger: Dictionary = {}
var skill_short_label_by_trigger: Dictionary = {}
var skill_trigger_label_by_trigger: Dictionary = {}
var skill_flash_overlay_by_trigger: Dictionary = {}
var skill_feedback_tween_by_trigger: Dictionary = {}


func _ready() -> void:
	objective_root = get_node_or_null(objective_root_path) as Control
	objective_info_bar = get_node_or_null(objective_info_bar_path) as Control
	initialize()


func initialize() -> void:
	max_hp = max(0, fallback_hp)
	current_hp = max_hp
	preview_hp = current_hp
	is_hp_preview_visible = false

	skill_id_by_trigger.clear()
	skill_id_by_trigger[TRIGGER_TURN_START] = "turn_start_none"
	skill_id_by_trigger[TRIGGER_TURN_END] = "turn_end_none"

	_ensure_final_objective_image_texture()
	_ensure_objective_name_label()
	_ensure_objective_hp_label()
	_ensure_objective_highlight_panel()
	_ensure_skill_ui_by_trigger(TRIGGER_TURN_START)
	_ensure_skill_ui_by_trigger(TRIGGER_TURN_END)
	_set_default_skill_ui_text(TRIGGER_TURN_START)
	_set_default_skill_ui_text(TRIGGER_TURN_END)
	_refresh_ui()
	
func apply_definition_data(definition_data: Dictionary) -> void:
	if definition_data.is_empty():
		print("최종목표 데이터 적용 실패 / 데이터 비어있음")
		return

	final_objective_id = String(definition_data.get("final_objective_id", ""))
	display_name = String(definition_data.get("display_name", "최종목표"))

	max_hp = max(1, int(definition_data.get("max_hp", fallback_hp)))
	current_hp = max_hp
	preview_hp = current_hp
	is_hp_preview_visible = false

	var image_path: String = String(definition_data.get("image_path", ""))
	_apply_final_objective_image(image_path)

	var turn_start_skill_id: String = String(definition_data.get(TRIGGER_TURN_START, "turn_start_none"))
	var turn_end_skill_id: String = String(definition_data.get(TRIGGER_TURN_END, "turn_end_none"))
	set_skill_id_by_trigger(TRIGGER_TURN_START, turn_start_skill_id)
	set_skill_id_by_trigger(TRIGGER_TURN_END, turn_end_skill_id)

	clear_hp_preview()
	_refresh_ui()

	print(
		"최종목표 데이터 적용 완료 / id:", final_objective_id,
		" / 이름:", display_name,
		" / HP:", max_hp,
		" / 턴시작:", turn_start_skill_id,
		" / 턴종료:", turn_end_skill_id
	)

func _ensure_final_objective_image_texture() -> void:
	if objective_root == null:
		return

	final_objective_image_texture = objective_root.get_node_or_null("FinalObjectiveImage") as TextureRect

	if final_objective_image_texture == null:
		print("최종목표 이미지 노드 없음 / Boss/FinalObjectiveImage 확인 필요")


func _apply_final_objective_image(image_path: String) -> void:
	if final_objective_image_texture == null:
		_ensure_final_objective_image_texture()

	if final_objective_image_texture == null:
		return

	if image_path == "":
		final_objective_image_texture.texture = null
		final_objective_image_texture.visible = false
		return

	var loaded_texture: Texture2D = load(image_path) as Texture2D
	if loaded_texture == null:
		print("최종목표 이미지 로드 실패:", image_path)
		final_objective_image_texture.texture = null
		final_objective_image_texture.visible = false
		return

	final_objective_image_texture.texture = loaded_texture
	final_objective_image_texture.visible = true
	print("최종목표 이미지 적용 완료:", image_path)

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

	var fill_texture_resource: Texture2D = load(HP_FILL_TEXTURE_PATH) as Texture2D
	var frame_texture_resource: Texture2D = load(HP_FRAME_TEXTURE_PATH) as Texture2D

	var old_frame_texture_rect: TextureRect = objective_info_bar.get_node_or_null("TextureRect") as TextureRect
	if old_frame_texture_rect != null:
		old_frame_texture_rect.visible = false
		old_frame_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var old_scene_fill_texture: TextureRect = objective_info_bar.get_node_or_null("End EnemyHP") as TextureRect
	if old_scene_fill_texture != null:
		old_scene_fill_texture.visible = false
		old_scene_fill_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var old_scene_frame_texture: TextureRect = objective_info_bar.get_node_or_null("End EnemyHPCase") as TextureRect
	if old_scene_frame_texture != null:
		old_scene_frame_texture.visible = false
		old_scene_frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background_panel: Panel = objective_info_bar.get_node_or_null("Panel") as Panel
	if background_panel != null:
		background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_panel.visible = false

	var old_fill_rect: ColorRect = objective_info_bar.get_node_or_null("FinalObjectiveHpFillRect") as ColorRect
	if old_fill_rect != null:
		old_fill_rect.visible = false

	var old_preview_loss_rect: ColorRect = objective_info_bar.get_node_or_null("FinalObjectiveHpPreviewLossRect") as ColorRect
	if old_preview_loss_rect != null:
		old_preview_loss_rect.visible = false

	var found_back_texture: TextureRect = objective_info_bar.get_node_or_null("End EnemyHPback") as TextureRect
	if found_back_texture == null:
		found_back_texture = TextureRect.new()
		found_back_texture.name = "End EnemyHPback"
		objective_info_bar.add_child(found_back_texture)

	found_back_texture.texture = fill_texture_resource
	found_back_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	found_back_texture.offset_left = 0.0
	found_back_texture.offset_top = 0.0
	found_back_texture.offset_right = 0.0
	found_back_texture.offset_bottom = 0.0
	found_back_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	found_back_texture.stretch_mode = TextureRect.STRETCH_SCALE
	found_back_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_back_texture.modulate = HP_BAR_BACK_MODULATE
	found_back_texture.z_index = 0
	found_back_texture.visible = true

	var found_fill_clip: Control = objective_info_bar.get_node_or_null("FinalObjectiveHpFillClip") as Control
	if found_fill_clip == null:
		found_fill_clip = Control.new()
		found_fill_clip.name = "FinalObjectiveHpFillClip"
		found_fill_clip.clip_contents = true
		found_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		objective_info_bar.add_child(found_fill_clip)

	found_fill_clip.z_index = 1

	var found_fill_texture: TextureRect = found_fill_clip.get_node_or_null("FinalObjectiveHpFillTexture") as TextureRect
	if found_fill_texture == null:
		found_fill_texture = TextureRect.new()
		found_fill_texture.name = "FinalObjectiveHpFillTexture"
		found_fill_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_fill_clip.add_child(found_fill_texture)

	found_fill_texture.texture = fill_texture_resource
	found_fill_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	found_fill_texture.stretch_mode = TextureRect.STRETCH_SCALE
	found_fill_texture.modulate = HP_BAR_FILL_MODULATE
	found_fill_texture.z_index = 1

	var found_preview_loss_clip: Control = objective_info_bar.get_node_or_null("FinalObjectiveHpPreviewLossClip") as Control
	if found_preview_loss_clip == null:
		found_preview_loss_clip = Control.new()
		found_preview_loss_clip.name = "FinalObjectiveHpPreviewLossClip"
		found_preview_loss_clip.clip_contents = true
		found_preview_loss_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_preview_loss_clip.visible = false
		objective_info_bar.add_child(found_preview_loss_clip)

	found_preview_loss_clip.z_index = 2

	var found_preview_loss_texture: TextureRect = found_preview_loss_clip.get_node_or_null("FinalObjectiveHpPreviewLossTexture") as TextureRect
	if found_preview_loss_texture == null:
		found_preview_loss_texture = TextureRect.new()
		found_preview_loss_texture.name = "FinalObjectiveHpPreviewLossTexture"
		found_preview_loss_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found_preview_loss_clip.add_child(found_preview_loss_texture)

	found_preview_loss_texture.texture = fill_texture_resource
	found_preview_loss_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	found_preview_loss_texture.stretch_mode = TextureRect.STRETCH_SCALE
	found_preview_loss_texture.modulate = HP_BAR_PREVIEW_LOSS_MODULATE
	found_preview_loss_texture.z_index = 1

	var found_frame_texture: TextureRect = objective_info_bar.get_node_or_null("FinalObjectiveHpFrameTexture") as TextureRect
	if found_frame_texture == null:
		found_frame_texture = TextureRect.new()
		found_frame_texture.name = "FinalObjectiveHpFrameTexture"
		objective_info_bar.add_child(found_frame_texture)

	found_frame_texture.texture = frame_texture_resource
	found_frame_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	found_frame_texture.offset_left = 0.0
	found_frame_texture.offset_top = 0.0
	found_frame_texture.offset_right = 0.0
	found_frame_texture.offset_bottom = 0.0
	found_frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	found_frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
	found_frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_frame_texture.z_index = 20
	found_frame_texture.visible = true

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

	found_label.add_theme_color_override("font_color", FINAL_OBJECTIVE_HP_TEXT_COLOR)
	found_label.add_theme_color_override("font_outline_color", FINAL_OBJECTIVE_HP_TEXT_OUTLINE_COLOR)
	found_label.add_theme_constant_override("outline_size", FINAL_OBJECTIVE_HP_TEXT_OUTLINE_SIZE)
	found_label.z_index = 30

	objective_hp_back_texture = found_back_texture
	objective_hp_fill_clip = found_fill_clip
	objective_hp_fill_texture = found_fill_texture
	objective_hp_preview_loss_clip = found_preview_loss_clip
	objective_hp_preview_loss_texture = found_preview_loss_texture
	objective_hp_frame_texture = found_frame_texture
	objective_hp_label = found_label

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
	if flash_overlay != null:
		flash_overlay.visible = false
		flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		objective_name_label.visible = false
		objective_name_label.text = ""

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
	var total_height: float = objective_info_bar.get_global_rect().size.y

	if total_width <= 0.0:
		total_width = objective_info_bar.size.x
	if total_height <= 0.0:
		total_height = objective_info_bar.size.y

	if total_width <= 0.0 or total_height <= 0.0:
		call_deferred("_refresh_hp_ui")
		return

	var current_ratio: float = float(clamped_current_hp) / float(safe_max_hp)
	var displayed_ratio: float = float(displayed_hp) / float(safe_max_hp)
	var current_width: float = total_width * current_ratio
	var displayed_width: float = total_width * displayed_ratio
	var preview_loss_width: float = max(0.0, current_width - displayed_width)

	if objective_hp_back_texture != null:
		objective_hp_back_texture.anchor_left = 0.0
		objective_hp_back_texture.anchor_top = 0.0
		objective_hp_back_texture.anchor_right = 0.0
		objective_hp_back_texture.anchor_bottom = 0.0
		objective_hp_back_texture.offset_left = HP_FILL_OFFSET_LEFT
		objective_hp_back_texture.offset_top = HP_FILL_OFFSET_TOP
		objective_hp_back_texture.offset_right = total_width + HP_FILL_OFFSET_RIGHT
		objective_hp_back_texture.offset_bottom = total_height + HP_FILL_OFFSET_BOTTOM
		objective_hp_back_texture.modulate = HP_BAR_BACK_MODULATE
		objective_hp_back_texture.visible = true

	if objective_hp_fill_clip != null:
		objective_hp_fill_clip.anchor_left = 0.0
		objective_hp_fill_clip.anchor_top = 0.0
		objective_hp_fill_clip.anchor_right = 0.0
		objective_hp_fill_clip.anchor_bottom = 0.0
		objective_hp_fill_clip.offset_left = 0.0
		objective_hp_fill_clip.offset_top = 0.0
		objective_hp_fill_clip.offset_right = current_width
		objective_hp_fill_clip.offset_bottom = total_height
		objective_hp_fill_clip.visible = clamped_current_hp > 0

	if objective_hp_fill_texture != null:
		objective_hp_fill_texture.anchor_left = 0.0
		objective_hp_fill_texture.anchor_top = 0.0
		objective_hp_fill_texture.anchor_right = 0.0
		objective_hp_fill_texture.anchor_bottom = 0.0
		objective_hp_fill_texture.offset_left = HP_FILL_OFFSET_LEFT
		objective_hp_fill_texture.offset_top = HP_FILL_OFFSET_TOP
		objective_hp_fill_texture.offset_right = total_width + HP_FILL_OFFSET_RIGHT
		objective_hp_fill_texture.offset_bottom = total_height + HP_FILL_OFFSET_BOTTOM
		objective_hp_fill_texture.modulate = HP_BAR_FILL_MODULATE

	if objective_hp_preview_loss_clip != null:
		objective_hp_preview_loss_clip.anchor_left = 0.0
		objective_hp_preview_loss_clip.anchor_top = 0.0
		objective_hp_preview_loss_clip.anchor_right = 0.0
		objective_hp_preview_loss_clip.anchor_bottom = 0.0
		objective_hp_preview_loss_clip.offset_left = displayed_width
		objective_hp_preview_loss_clip.offset_top = 0.0
		objective_hp_preview_loss_clip.offset_right = displayed_width + preview_loss_width
		objective_hp_preview_loss_clip.offset_bottom = total_height
		objective_hp_preview_loss_clip.visible = is_hp_preview_visible and preview_loss_width > 0.0

	if objective_hp_preview_loss_texture != null:
		objective_hp_preview_loss_texture.anchor_left = 0.0
		objective_hp_preview_loss_texture.anchor_top = 0.0
		objective_hp_preview_loss_texture.anchor_right = 0.0
		objective_hp_preview_loss_texture.anchor_bottom = 0.0
		objective_hp_preview_loss_texture.offset_left = -displayed_width + HP_FILL_OFFSET_LEFT
		objective_hp_preview_loss_texture.offset_top = HP_FILL_OFFSET_TOP
		objective_hp_preview_loss_texture.offset_right = total_width - displayed_width + HP_FILL_OFFSET_RIGHT
		objective_hp_preview_loss_texture.offset_bottom = total_height + HP_FILL_OFFSET_BOTTOM
		objective_hp_preview_loss_texture.modulate = HP_BAR_PREVIEW_LOSS_MODULATE
	if objective_hp_frame_texture != null:
		objective_hp_frame_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		objective_hp_frame_texture.offset_left = 0.0
		objective_hp_frame_texture.offset_top = 0.0
		objective_hp_frame_texture.offset_right = 0.0
		objective_hp_frame_texture.offset_bottom = 0.0
		objective_hp_frame_texture.visible = true

	if objective_hp_label != null:
		objective_hp_label.offset_top = HP_LABEL_OFFSET_Y
		objective_hp_label.offset_bottom = HP_LABEL_OFFSET_Y

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

	var skill_ui_root: Control = _get_or_find_skill_ui_root(trigger_type)
	if skill_ui_root == null:
		return

	var ui_container: Control = skill_ui_root.get_node_or_null("Background") as Control
	if ui_container == null:
		ui_container = skill_ui_root

	var skill_icon: Control = ui_container.get_node_or_null("SkillIcon") as Control
	if skill_icon == null:
		skill_icon = skill_ui_root

	var old_tween: Tween = skill_feedback_tween_by_trigger.get(trigger_type, null) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	skill_icon.scale = Vector2.ONE
	skill_icon.pivot_offset = skill_icon.size * 0.5

	var tween: Tween = create_tween()
	skill_feedback_tween_by_trigger[trigger_type] = tween

	tween.tween_property(skill_icon, "scale", Vector2(1.22, 1.22), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(skill_icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _get_trigger_display_name(trigger_type: String) -> String:
	match trigger_type:
		TRIGGER_TURN_START:
			return "턴 시작"

		TRIGGER_TURN_END:
			return "턴 종료"

	return trigger_type
