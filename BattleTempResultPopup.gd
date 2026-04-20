extends CanvasLayer
class_name BattleTempResultPopup

signal restart_requested

var overlay: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var message_label: Label = null
var restart_button: Button = null

func _ready() -> void:
	layer = 200
	visible = false
	_build_ui()
	_refresh_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_refresh_layout()

func show_game_over() -> void:
	_show_result("GAME OVER", "Player HP reached 0.", "Restart Battle")

func show_stage_clear() -> void:
	_show_result("STAGE CLEAR", "Final Objective defeated.", "Restart Battle")

func hide_popup() -> void:
	visible = false

func _show_result(title_text: String, message_text: String, button_text: String) -> void:
	if overlay == null:
		return

	title_label.text = title_text
	message_label.text = message_text
	restart_button.text = button_text

	_refresh_layout()
	visible = true

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.16, 0.16, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(title_label)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	panel.add_child(message_label)

	restart_button = Button.new()
	restart_button.text = "Restart Battle"
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.pressed.connect(_on_restart_button_pressed)
	panel.add_child(restart_button)

func _refresh_layout() -> void:
	if overlay == null:
		return
	if panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	overlay.position = Vector2.ZERO
	overlay.size = viewport_size

	panel.size = Vector2(520, 240)
	panel.position = (viewport_size - panel.size) * 0.5

	title_label.position = Vector2(24, 28)
	title_label.size = Vector2(panel.size.x - 48, 44)

	message_label.position = Vector2(24, 88)
	message_label.size = Vector2(panel.size.x - 48, 36)

	restart_button.position = Vector2((panel.size.x - 220) * 0.5, 156)
	restart_button.size = Vector2(220, 46)

func _on_restart_button_pressed() -> void:
	restart_requested.emit()
