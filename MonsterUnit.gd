extends Control
class_name MonsterUnit

signal before_flip_to_back(monster_unit: MonsterUnit)
signal after_flip_to_back(monster_unit: MonsterUnit)
signal before_flip_to_front(monster_unit: MonsterUnit)
signal after_flip_to_front(monster_unit: MonsterUnit)
signal exit_hook_triggered(monster_unit: MonsterUnit)
signal enter_hook_triggered(monster_unit: MonsterUnit)

var slot_no: int = 0
var is_face_down: bool = false
var is_flipping: bool = false

var current_attack: int = 2
var current_effect_symbols: Array[String] = []

var _body: ColorRect = null

var _attack_badge_panel: Panel = null
var _attack_icon_label: Label = null
var _attack_label: Label = null

var _effect_container: HBoxContainer = null
var _effect_badge_panels: Array[Panel] = []
var _effect_labels: Array[Label] = []

var _hp_badge_root: Control = null
var _hp_icon_label: Label = null
var _hp_label: Label = null

var _front_color: Color = Color(0.18, 0.18, 0.18, 0.88)
var _back_color: Color = Color(0.10, 0.10, 0.10, 0.95)
var _highlight_color: Color = Color(0.85, 0.20, 0.20, 0.95)


func setup_unit(new_slot_no: int, unit_size: Vector2) -> void:
	slot_no = new_slot_no
	position = Vector2.ZERO
	size = unit_size
	scale = Vector2.ONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ensure_visual_nodes()
	_layout_visual_nodes()
	apply_front_face()
	set_attack_value(current_attack)
	set_effect_symbols([])
	set_hp_text(0)


func _ensure_visual_nodes() -> void:
	_body = get_node_or_null("MonsterBody") as ColorRect
	if _body == null:
		_body = ColorRect.new()
		_body.name = "MonsterBody"
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_body)

	_attack_badge_panel = get_node_or_null("MonsterAttackBadge") as Panel
	if _attack_badge_panel == null:
		_attack_badge_panel = Panel.new()
		_attack_badge_panel.name = "MonsterAttackBadge"
		_attack_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_attack_badge_panel)

	_attack_icon_label = _attack_badge_panel.get_node_or_null("MonsterAttackIconLabel") as Label
	if _attack_icon_label == null:
		_attack_icon_label = Label.new()
		_attack_icon_label.name = "MonsterAttackIconLabel"
		_attack_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attack_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attack_icon_label.add_theme_font_size_override("font_size", 18)
		_attack_icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_attack_icon_label.text = "⚔"
		_attack_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attack_badge_panel.add_child(_attack_icon_label)

	_attack_label = _attack_badge_panel.get_node_or_null("MonsterAttackLabel") as Label
	if _attack_label == null:
		_attack_label = Label.new()
		_attack_label.name = "MonsterAttackLabel"
		_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attack_label.add_theme_font_size_override("font_size", 20)
		_attack_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_attack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attack_badge_panel.add_child(_attack_label)

	_effect_container = get_node_or_null("MonsterEffectContainer") as HBoxContainer
	if _effect_container == null:
		_effect_container = HBoxContainer.new()
		_effect_container.name = "MonsterEffectContainer"
		_effect_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_effect_container.alignment = BoxContainer.ALIGNMENT_CENTER
		_effect_container.add_theme_constant_override("separation", 4)
		add_child(_effect_container)
	_effect_badge_panels.clear()
	_effect_labels.clear()

	for i in range(3):
		var badge_name: String = "MonsterEffectBadge%d" % (i + 1)
		var badge_panel: Panel = _effect_container.get_node_or_null(badge_name) as Panel
		if badge_panel == null:
			badge_panel = Panel.new()
			badge_panel.name = badge_name
			badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_panel.visible = false
			badge_panel.custom_minimum_size = Vector2(34, 34)

			var transparent_style := StyleBoxFlat.new()
			transparent_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			transparent_style.border_width_left = 0
			transparent_style.border_width_top = 0
			transparent_style.border_width_right = 0
			transparent_style.border_width_bottom = 0
			badge_panel.add_theme_stylebox_override("panel", transparent_style)

			_effect_container.add_child(badge_panel)

		var effect_name: String = "MonsterEffectLabel%d" % (i + 1)
		var effect_label: Label = badge_panel.get_node_or_null(effect_name) as Label
		if effect_label == null:
			effect_label = Label.new()
			effect_label.name = effect_name
			effect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			effect_label.offset_left = 0.0
			effect_label.offset_top = 0.0
			effect_label.offset_right = 0.0
			effect_label.offset_bottom = 0.0
			effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			effect_label.add_theme_font_size_override("font_size", 26)
			effect_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1.0))
			effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_panel.add_child(effect_label)

		_effect_badge_panels.append(badge_panel)
		_effect_labels.append(effect_label)
	_hp_badge_root = get_node_or_null("MonsterHpBadgeRoot") as Control
	if _hp_badge_root == null:
		_hp_badge_root = Control.new()
		_hp_badge_root.name = "MonsterHpBadgeRoot"
		_hp_badge_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hp_badge_root)

	_hp_icon_label = _hp_badge_root.get_node_or_null("MonsterHpIconLabel") as Label
	if _hp_icon_label == null:
		_hp_icon_label = Label.new()
		_hp_icon_label.name = "MonsterHpIconLabel"
		_hp_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hp_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_icon_label.add_theme_font_size_override("font_size", 40)
		_hp_icon_label.add_theme_color_override("font_color", Color(0.92, 0.30, 0.36, 1.0))
		_hp_icon_label.text = "♥"
		_hp_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_badge_root.add_child(_hp_icon_label)

	_hp_label = _hp_badge_root.get_node_or_null("MonsterHpLabel") as Label
	if _hp_label == null:
		_hp_label = Label.new()
		_hp_label.name = "MonsterHpLabel"
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_label.add_theme_font_size_override("font_size", 22)
		_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_badge_root.add_child(_hp_label)


func _layout_visual_nodes() -> void:
	if _body != null:
		_body.position = Vector2.ZERO
		_body.size = size

	var badge_top_y: float = 1.0
	var attack_left_x: float = 1.0
	var attack_badge_size: Vector2 = Vector2(64, 36)

	if _attack_badge_panel != null:
		_attack_badge_panel.position = Vector2(attack_left_x, badge_top_y)
		_attack_badge_panel.size = attack_badge_size

		var attack_style := StyleBoxFlat.new()
		attack_style.bg_color = Color(0.93, 0.72, 0.18, 1.0)
		attack_style.border_color = Color(1.0, 0.95, 0.72, 1.0)
		attack_style.border_width_left = 2
		attack_style.border_width_top = 2
		attack_style.border_width_right = 2
		attack_style.border_width_bottom = 2
		attack_style.corner_radius_top_left = 14
		attack_style.corner_radius_top_right = 14
		attack_style.corner_radius_bottom_left = 14
		attack_style.corner_radius_bottom_right = 14
		_attack_badge_panel.add_theme_stylebox_override("panel", attack_style)

	if _attack_icon_label != null:
		_attack_icon_label.position = Vector2(3, 1)
		_attack_icon_label.size = Vector2(24, 34)

	if _attack_label != null:
		_attack_label.position = Vector2(26, 0)
		_attack_label.size = Vector2(34, 34)

	var hp_badge_size: Vector2 = Vector2(52, 46)
	var hp_left_x: float = size.x - hp_badge_size.x + 6.0
	var hp_top_y: float = -8.0

	if _hp_badge_root != null:
		_hp_badge_root.position = Vector2(hp_left_x, hp_top_y)
		_hp_badge_root.size = hp_badge_size

	if _hp_icon_label != null:
		_hp_icon_label.position = Vector2(0, -2)
		_hp_icon_label.size = hp_badge_size

	if _hp_label != null:
		_hp_label.position = Vector2(0, 1)
		_hp_label.size = hp_badge_size
		
	if _effect_container != null:
		var effect_left_x: float = attack_left_x + attack_badge_size.x + 8.0
		var effect_right_x: float = hp_left_x - 8.0
		var effect_width: float = maxf(0.0, effect_right_x - effect_left_x)

		_effect_container.position = Vector2(effect_left_x, -2.0)
		_effect_container.size = Vector2(effect_width, 36.0)

	for i in range(_effect_badge_panels.size()):
		var badge_panel: Panel = _effect_badge_panels[i]
		if badge_panel == null:
			continue

		badge_panel.custom_minimum_size = Vector2(34, 34)


func set_attack_value(value: int) -> void:
	_ensure_visual_nodes()

	current_attack = max(0, value)

	if _attack_label != null:
		_attack_label.text = str(current_attack)


func set_hp_text(hp: int) -> void:
	_ensure_visual_nodes()

	if _hp_label == null:
		return

	_hp_label.text = str(max(0, hp))


func set_effect_symbols(symbols: Array) -> void:
	_ensure_visual_nodes()

	current_effect_symbols.clear()
	for symbol_variant in symbols:
		current_effect_symbols.append(String(symbol_variant))

	for i in range(_effect_labels.size()):
		var effect_label: Label = _effect_labels[i]
		var badge_panel: Panel = null

		if i < _effect_badge_panels.size():
			badge_panel = _effect_badge_panels[i]

		if effect_label == null:
			continue

		if i < current_effect_symbols.size():
			var symbol_text: String = current_effect_symbols[i]
			effect_label.text = symbol_text

			if badge_panel != null:
				badge_panel.visible = symbol_text != ""
		else:
			effect_label.text = ""

			if badge_panel != null:
				badge_panel.visible = false


func apply_front_face() -> void:
	_ensure_visual_nodes()
	_layout_visual_nodes()

	is_face_down = false

	if _body != null:
		_body.color = _front_color

	if _attack_badge_panel != null:
		_attack_badge_panel.visible = true

	if _effect_container != null:
		_effect_container.visible = true

	if _hp_badge_root != null:
		_hp_badge_root.visible = true


func apply_back_face() -> void:
	_ensure_visual_nodes()

	is_face_down = true

	if _body != null:
		_body.color = _back_color

	if _attack_badge_panel != null:
		_attack_badge_panel.visible = false

	if _effect_container != null:
		_effect_container.visible = false

	if _hp_badge_root != null:
		_hp_badge_root.visible = false


func set_highlight(is_on: bool) -> void:
	_ensure_visual_nodes()

	if _body == null:
		return

	if is_face_down:
		_body.color = _back_color
		return

	if is_on:
		_body.color = _highlight_color
	else:
		_body.color = _front_color


func play_contact_hit_effect() -> void:
	_ensure_visual_nodes()

	if is_flipping:
		return
	if _body == null:
		return

	var root_start_pos: Vector2 = position
	var root_hit_pos: Vector2 = root_start_pos + Vector2(0, -18)

	var body_start_color: Color = _body.color
	var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

	if is_inside_tree():
		await get_tree().create_timer(0.04).timeout

	var hit_tween = create_tween()
	hit_tween.set_parallel(true)
	hit_tween.tween_property(self, "position", root_hit_pos, 0.06)
	hit_tween.tween_property(_body, "color", flash_color, 0.04)
	await hit_tween.finished

	var return_tween = create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(self, "position", root_start_pos, 0.10)
	return_tween.tween_property(_body, "color", body_start_color, 0.10)
	await return_tween.finished


func flip_to_back() -> void:
	if is_flipping:
		return
	if is_face_down:
		return

	is_flipping = true
	_on_before_flip_to_back()
	before_flip_to_back.emit(self)

	scale = Vector2.ONE

	var close_tween = create_tween()
	close_tween.tween_property(self, "scale", Vector2(0.0, 1.0), 0.08)
	await close_tween.finished

	if not is_instance_valid(self):
		return

	_on_exit_hook()
	exit_hook_triggered.emit(self)

	apply_back_face()

	var open_tween = create_tween()
	open_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	await open_tween.finished

	is_flipping = false
	_on_after_flip_to_back()
	after_flip_to_back.emit(self)


func flip_to_front(hp: int) -> void:
	if is_flipping:
		return
	if not is_face_down:
		return

	is_flipping = true
	_on_before_flip_to_front()
	before_flip_to_front.emit(self)

	scale = Vector2.ONE

	var close_tween = create_tween()
	close_tween.tween_property(self, "scale", Vector2(0.0, 1.0), 0.08)
	await close_tween.finished

	if not is_instance_valid(self):
		return

	apply_front_face()
	set_attack_value(current_attack)
	set_effect_symbols(current_effect_symbols)
	set_hp_text(hp)

	var open_tween = create_tween()
	open_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	await open_tween.finished

	is_flipping = false
	_on_enter_hook()
	enter_hook_triggered.emit(self)
	_on_after_flip_to_front()
	after_flip_to_front.emit(self)


func _on_before_flip_to_back() -> void:
	pass


func _on_after_flip_to_back() -> void:
	pass


func _on_before_flip_to_front() -> void:
	pass


func _on_after_flip_to_front() -> void:
	pass


func _on_exit_hook() -> void:
	pass


func _on_enter_hook() -> void:
	pass
