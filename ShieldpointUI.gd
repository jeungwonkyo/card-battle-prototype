extends Control
class_name ShieldpointUI

@export var shield_color: Color = Color(0.42, 0.76, 1.0, 1.0)
@export var value_font_size: int = 32
@export var preview_font_size: int = 22
@export var preview_color: Color = Color(0.86, 0.92, 1.0, 1.0)

var current_shield: int = 0
var preview_shield: int = -1

var background_panel: Panel = null
var shield_icon: Polygon2D = null
var value_label: Label = null
var preview_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_ui()
	update_shield(0)
	clear_shield_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_ui()


func _ensure_ui() -> void:
	background_panel = get_node_or_null("Panel") as Panel
	if background_panel == null:
		background_panel = Panel.new()
		background_panel.name = "Panel"
		add_child(background_panel)
		move_child(background_panel, 0)

	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_panel.offset_left = 0.0
	background_panel.offset_top = 0.0
	background_panel.offset_right = 0.0
	background_panel.offset_bottom = 0.0
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	shield_icon = get_node_or_null("ShieldIcon") as Polygon2D
	if shield_icon == null:
		shield_icon = Polygon2D.new()
		shield_icon.name = "ShieldIcon"
		add_child(shield_icon)

	shield_icon.color = shield_color
	shield_icon.visible = true

	value_label = get_node_or_null("ShieldValueLabel") as Label
	if value_label == null:
		value_label = Label.new()
		value_label.name = "ShieldValueLabel"
		add_child(value_label)

	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = 52.0
	value_label.offset_top = 0.0
	value_label.offset_right = -10.0
	value_label.offset_bottom = 0.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", value_font_size)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	preview_label = get_node_or_null("ShieldPreviewLabel") as Label
	if preview_label == null:
		preview_label = Label.new()
		preview_label.name = "ShieldPreviewLabel"
		add_child(preview_label)

	preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_label.offset_left = 82.0
	preview_label.offset_top = 0.0
	preview_label.offset_right = -10.0
	preview_label.offset_bottom = 0.0
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", preview_font_size)
	preview_label.add_theme_color_override("font_color", preview_color)
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.visible = false

	_layout_ui()


func _layout_ui() -> void:
	if shield_icon != null:
		var icon_width: float = min(26.0, size.x * 0.22)
		var icon_height: float = min(30.0, size.y * 0.62)
		var start_x: float = 14.0
		var start_y: float = (size.y - icon_height) * 0.5

		shield_icon.position = Vector2(start_x, start_y)
		shield_icon.polygon = PackedVector2Array([
			Vector2(icon_width * 0.50, 0.0),
			Vector2(icon_width, icon_height * 0.18),
			Vector2(icon_width * 0.90, icon_height * 0.62),
			Vector2(icon_width * 0.50, icon_height),
			Vector2(icon_width * 0.10, icon_height * 0.62),
			Vector2(0.0, icon_height * 0.18)
		])

	if value_label != null:
		value_label.offset_left = 52.0
		value_label.offset_top = 0.0
		value_label.offset_right = -10.0
		value_label.offset_bottom = 0.0

	if preview_label != null:
		preview_label.offset_left = 82.0
		preview_label.offset_top = 0.0
		preview_label.offset_right = -10.0
		preview_label.offset_bottom = 0.0


func _refresh_ui() -> void:
	var has_current: bool = current_shield > 0
	var has_preview: bool = preview_shield >= 0 and preview_shield != current_shield
	var should_show: bool = has_current or preview_shield > 0 or (current_shield > 0 and preview_shield == 0)

	visible = should_show

	if background_panel != null:
		background_panel.visible = should_show

	if shield_icon != null:
		shield_icon.visible = should_show

	if value_label != null:
		value_label.visible = has_current
		value_label.text = str(max(0, current_shield))

	if preview_label != null:
		preview_label.visible = has_preview
		if has_preview:
			preview_label.text = "→ %d" % max(0, preview_shield)
		else:
			preview_label.text = ""


func update_shield(value: int) -> void:
	current_shield = max(0, value)
	_refresh_ui()


func show_shield_preview(current_value: int, after_value: int) -> void:
	current_shield = max(0, current_value)
	preview_shield = max(0, after_value)
	_refresh_ui()


func clear_shield_preview() -> void:
	preview_shield = -1
	_refresh_ui()
