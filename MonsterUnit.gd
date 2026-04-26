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

var current_attack: int = 0
var current_effect_symbols: Array[String] = []

var _body: ColorRect = null

var _image_panel: Control = null
var _image_texture: TextureRect = null
var _image_label: Label = null

var _attack_root: Control = null
var _attack_sword_label: Label = null
var _attack_label: Label = null

var _effect_root: Control = null
var _effect_label: Label = null

var _hp_root: Control = null
var _hp_label: Label = null

var _preview_hp_root: Control = null
var _preview_hp_label: Label = null

var _text_panel: Control = null
var _summary_label: RichTextLabel = null

@export var use_editor_layout: bool = true

var _front_color: Color = Color(0.18, 0.18, 0.18, 0.88)
var _back_color: Color = Color(0.10, 0.10, 0.10, 0.95)
var _highlight_color: Color = Color(0.85, 0.20, 0.20, 0.95)

func setup_unit(new_slot_no: int, unit_size: Vector2) -> void:
	slot_no = new_slot_no
	position = Vector2.ZERO
	size = unit_size
	custom_minimum_size = unit_size
	scale = Vector2.ONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bind_nodes()
	_apply_root_layout(unit_size)

	if _attack_root != null:
		_attack_root.self_modulate = Color(1.0, 1.0, 1.0, 0.0)

	if not use_editor_layout:
		_apply_badge_layouts()

		if _image_label != null:
			_image_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			_image_label.offset_left = 0.0
			_image_label.offset_top = 0.0
			_image_label.offset_right = 0.0
			_image_label.offset_bottom = 0.0

	if _image_label != null:
		_image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_image_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _attack_sword_label != null:
		_attack_sword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attack_sword_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _attack_label != null:
		_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _hp_root is Label:
		var hp_badge: Label = _hp_root as Label
		hp_badge.visible = true
		hp_badge.text = "♥"
		hp_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _hp_label != null:
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_monster_image_placeholder(str(slot_no))
	set_attack_value(current_attack)
	set_effect_symbols([])
	set_hp_text(0)

	set_summary_text("")
	clear_hp_preview()
	apply_front_face()

func _apply_badge_layouts() -> void:
	if _attack_root != null:
		_attack_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_attack_root.offset_left = 4.0
		_attack_root.offset_top = 4.0
		_attack_root.offset_right = 42.0
		_attack_root.offset_bottom = 22.0

	if _attack_sword_label != null:
		_attack_sword_label.text = "⚔"
		_attack_sword_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_attack_sword_label.offset_left = 4.0
		_attack_sword_label.offset_top = 0.0
		_attack_sword_label.offset_right = -18.0
		_attack_sword_label.offset_bottom = 0.0
		_attack_sword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_attack_sword_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attack_sword_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _attack_label != null:
		_attack_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_attack_label.offset_left = 16.0
		_attack_label.offset_top = 0.0
		_attack_label.offset_right = -4.0
		_attack_label.offset_bottom = 0.0
		_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _hp_root != null:
		_hp_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_hp_root.offset_left = -42.0
		_hp_root.offset_top = 4.0
		_hp_root.offset_right = -4.0
		_hp_root.offset_bottom = 22.0

	if _hp_label != null:
		_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hp_label.offset_left = 0.0
		_hp_label.offset_top = 0.0
		_hp_label.offset_right = 0.0
		_hp_label.offset_bottom = 0.0
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bind_nodes() -> void:
	_body = get_node_or_null("ColorRect") as ColorRect

	_image_panel = get_node_or_null("MonsterImagePanel") as Control
	_image_texture = get_node_or_null("MonsterImagePanel/MonsterImageTexture") as TextureRect
	_image_label = get_node_or_null("MonsterImagePanel/MonsterImageLabel") as Label

	_attack_root = get_node_or_null("MonsterImagePanel/MonsterAttackSymbol") as Control
	_attack_sword_label = get_node_or_null("MonsterImagePanel/MonsterAttackSymbol/MonsterSwordSymbol") as Label
	_attack_label = get_node_or_null("MonsterImagePanel/MonsterAttackSymbol/MonsterAttackLabel") as Label

	_effect_root = get_node_or_null("MonsterImagePanel/MonsterEffectSymbol") as Control
	_effect_label = get_node_or_null("MonsterImagePanel/MonsterEffectSymbol/MonsterEffectLabel") as Label

	_hp_root = get_node_or_null("MonsterImagePanel/MonsterLifeBadgeSymbol") as Control
	_hp_label = get_node_or_null("MonsterImagePanel/MonsterLifeBadgeSymbol/MonsterLifeLabel") as Label

	_preview_hp_root = get_node_or_null("MonsterImagePanel/PreviewLifeBadgeSymbol") as Control
	_preview_hp_label = get_node_or_null("MonsterImagePanel/PreviewLifeBadgeSymbol/PreviewLifeLabel") as Label

	_text_panel = get_node_or_null("MonsterTextPanel") as Control
	_summary_label = get_node_or_null("MonsterTextPanel/MonsterSummaryLabel") as RichTextLabel
	
func _apply_root_layout(unit_size: Vector2) -> void:
	size = unit_size
	custom_minimum_size = unit_size

	if _body != null:
		_body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_body.offset_left = 0.0
		_body.offset_top = 0.0
		_body.offset_right = 0.0
		_body.offset_bottom = 0.0

func set_monster_image_placeholder(text: String) -> void:
	if _image_texture != null:
		_image_texture.texture = null
		_image_texture.visible = false

	if _image_label == null:
		return

	_image_label.text = text
	_image_label.visible = true

func set_monster_image_by_path(image_path: String) -> void:
	if image_path == "":
		set_monster_image_placeholder(str(slot_no))
		return

	var loaded_texture: Texture2D = load(image_path) as Texture2D
	if loaded_texture == null:
		set_monster_image_placeholder(str(slot_no))
		return

	if _image_texture != null:
		_image_texture.texture = loaded_texture
		_image_texture.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_image_texture.visible = true

	if _image_label != null:
		_image_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_image_label.visible = false

func set_attack_value(value: int) -> void:
	current_attack = max(0, value)

	if _attack_root != null:
		_attack_root.visible = true

	if _attack_sword_label != null:
		_attack_sword_label.visible = true
		_attack_sword_label.text = "⚔"

	if _attack_label != null:
		_attack_label.visible = true
		_attack_label.text = str(current_attack)

func set_hp_text(hp: int) -> void:
	if _hp_root is Label:
		var hp_badge: Label = _hp_root as Label
		hp_badge.visible = true
		hp_badge.text = "♥"
		hp_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _hp_label == null:
		return

	_hp_label.visible = true
	_hp_label.text = str(max(0, hp))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func show_hp_preview(current_hp: int, after_hp: int) -> void:
	if after_hp >= current_hp:
		clear_hp_preview()
		return

	if _preview_hp_root != null:
		_preview_hp_root.visible = true

	if _preview_hp_root is Label:
		var preview_badge: Label = _preview_hp_root as Label
		preview_badge.text = "♥"
		preview_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _preview_hp_label != null:
		_preview_hp_label.visible = true
		_preview_hp_label.text = str(max(0, after_hp))
		_preview_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_preview_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func clear_hp_preview() -> void:
	if _preview_hp_root != null:
		_preview_hp_root.visible = false

	if _preview_hp_label != null:
		_preview_hp_label.visible = false
		_preview_hp_label.text = ""

func set_effect_symbols(symbols: Array) -> void:
	current_effect_symbols.clear()

	for symbol_variant in symbols:
		current_effect_symbols.append(String(symbol_variant))

	if _effect_label == null:
		return

	if current_effect_symbols.is_empty():
		_effect_label.text = ""
		if _effect_root != null:
			_effect_root.visible = false
		return

	_effect_label.text = " ".join(current_effect_symbols)
	if _effect_root != null:
		_effect_root.visible = true



func set_summary_text(text: String) -> void:
	if _summary_label == null:
		return

	_summary_label.visible = true
	_summary_label.clear()

	var lines: PackedStringArray = text.split("\n", false)
	if lines.is_empty():
		return

	var title_line: String = lines[0]
	var body_text: String = ""

	if lines.size() >= 2:
		body_text = "\n".join(lines.slice(1))

	var bbcode_text: String = "[center]"
	bbcode_text += "[color=#F3E7D3]" + title_line + "[/color]"

	if body_text != "":
		bbcode_text += "\n[color=#D9C7AE]" + body_text + "[/color]"

	bbcode_text += "[/center]"
	_summary_label.append_text(bbcode_text)

func apply_front_face() -> void:
	is_face_down = false

	if _body != null:
		_body.color = _front_color

	if _attack_root != null:
		_attack_root.visible = true

	if _hp_root != null:
		_hp_root.visible = true

	if _effect_root != null:
		_effect_root.visible = not current_effect_symbols.is_empty()

	if _image_texture != null:
		_image_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_image_texture.offset_left = 0.0
		_image_texture.offset_top = 0.0
		_image_texture.offset_right = 0.0
		_image_texture.offset_bottom = 0.0
		_image_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_image_texture.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_image_texture.visible = _image_texture.texture != null

	if _image_label != null:
		_image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_image_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_image_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_image_label.visible = _image_texture == null or _image_texture.texture == null

	if _text_panel != null:
		_text_panel.visible = true

func apply_back_face() -> void:
	is_face_down = true

	if _body != null:
		_body.color = _back_color

	if _attack_root != null:
		_attack_root.visible = false

	if _hp_root != null:
		_hp_root.visible = false

	if _effect_root != null:
		_effect_root.visible = false

	if _preview_hp_root != null:
		_preview_hp_root.visible = false

	if _image_texture != null:
		_image_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_image_texture.offset_left = 0.0
		_image_texture.offset_top = 0.0
		_image_texture.offset_right = 0.0
		_image_texture.offset_bottom = 0.0
		_image_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_image_texture.modulate = Color(0.60, 0.60, 0.60, 1.0)
		_image_texture.visible = _image_texture.texture != null

	if _image_label != null:
		_image_label.modulate = Color(0.60, 0.60, 0.60, 1.0)
		_image_label.visible = _image_texture == null or _image_texture.texture == null

	if _text_panel != null:
		_text_panel.visible = true

func set_highlight(is_on: bool) -> void:
	if _body == null:
		return

	if _image_texture != null:
		_image_texture.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _image_label != null:
		_image_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	if is_face_down:
		_body.color = _back_color
		return

	if is_on:
		_body.color = _highlight_color

		if _image_texture != null and _image_texture.visible:
			_image_texture.self_modulate = Color(1.0, 0.72, 0.72, 1.0)

		if _image_label != null and _image_label.visible:
			_image_label.self_modulate = Color(1.0, 0.72, 0.72, 1.0)
	else:
		_body.color = _front_color

func play_contact_hit_effect() -> void:
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
