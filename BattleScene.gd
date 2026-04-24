extends Node2D

const TEST_CARD_SCENE = preload("res://test_card.tscn")
const CardStateScript = preload("res://CardState.gd")
const MonsterActionSystemScript = preload("res://MonsterActionSystem.gd")
const CardStatSystemScript = preload("res://CardStatSystem.gd")
const CardLevelModifierSystemScript = preload("res://CardLevelModifierSystem.gd")
const CardBuffDebuffSystemScript = preload("res://CardBuffDebuffSystem.gd")
const CardDefinitionScript = preload("res://CardDefinition.gd")
const CardEffectSystemScript = preload("res://CardEffectSystem.gd")
const BattleTempResultPopupScript = preload("res://BattleTempResultPopup.gd")
const ShieldSystemScript = preload("res://ShieldSystem.gd")
const CloneCardSystemScript = preload("res://CloneCardSystem.gd")
const FinalObjectiveSkillSystemScript = preload("res://FinalObjectiveSkillSystem.gd")

const PLAYER_SHIELD_TARGET_KEY: String = "player"

@onready var player_field_layer: Control = $Layer1_PlayerField
@onready var deck_body: PileBody = $Layer1_PlayerField/Deck
@onready var grave_body: PileBody = $Layer1_PlayerField/Grave
@onready var deck_info_button: Button = $Layer1_PlayerField/DeckInfoButton
@onready var grave_info_button: Button = $Layer1_PlayerField/GraveInfoButton
@onready var end_turn_button: Button = $Layer0_UI/EndTurnButton
@onready var player_status_ui: PlayerStatusUI = $Layer0_UI/PlayerStatusUI as PlayerStatusUI
@onready var shieldpoint_ui: Control = $Layer0_UI/ShieldpointUI
@onready var turn_number_root: Control = $Layer3_Bossfield/TurnNumber

@export_node_path("Node") var final_objective_path: NodePath
var final_objective: Node = null
var final_objective_skill_system: FinalObjectiveSkillSystem = null

var deck_cards: Array = []
var grave_cards: Array = []
var next_instance_id: int = 1

# 런 중 바뀔 수 있는 전투 값
var default_card_level: int = 2
var strike_combo_multiplier: int = 3
var harmony_combo_multiplier: int = 2
var monster_start_hp: int = 20

# TP 사용 설정
# 여기만 바꾸면 전투 중 TP 사용 여부/소모값 테스트 가능
var tp_cost_by_action: Dictionary = {
	"pile_draw": 1,
	"field_move": 1,
	"field_swap": 1,
	"combo_attack": 1
}

var tp_use_enabled_by_action: Dictionary = {
	"pile_draw": true,
	"field_move": true,
	"field_swap": true,
	"combo_attack": true
}

var is_opening_deal_in_progress: bool = false
var is_refill_draw_in_progress: bool = false
var selected_field_card: TestCard = null

var move_preview_from_slot_no: int = 0
var move_preview_to_slot_no: int = 0
var move_preview_mode: String = ""
var move_preview_nodes: Array = []
var is_move_combo_preview_active: bool = false
var move_preview_source_visual_card: TestCard = null
var move_preview_target_visual_card: TestCard = null

var player_combos: Array = []
var combo_overlay_nodes: Array = []

var pile_popup_layer: CanvasLayer = null
var pile_popup_overlay: ColorRect = null
var pile_popup_panel: Panel = null
var pile_popup_title_label: Label = null
var pile_popup_count_label: Label = null
var pile_popup_scroll: ScrollContainer = null
var pile_popup_cards_grid: GridContainer = null
var current_popup_pile_type: String = ""

# 테스트 몬스터 정보
var monster_hp_by_slot_no: Dictionary = {}
var monster_root_by_slot_no: Dictionary = {}
var monster_hp_label_by_slot_no: Dictionary = {}
var monster_is_face_down_by_slot_no: Dictionary = {}
var monster_is_flipping_by_slot_no: Dictionary = {}
var combo_drag_highlighted_monster_slot_no: int = 0
var combo_drag_preview_highlight_slot_nos: Array = []
var combo_drag_preview_card_target_slot_by_id: Dictionary = {}
var combo_drag_preview_monster_hp_after_by_slot_no: Dictionary = {}
var combo_drag_preview_monster_targeted_slot_nos: Array = []
var final_objective_combo_drag_highlighted: bool = false
var final_objective_combo_drag_preview_highlighted: bool = false
var combo_drag_preview_final_objective_after_hp: int = -1

var monster_action_system: MonsterActionSystem = null
var card_stat_system: CardStatSystem = null
var card_level_modifier_system: CardLevelModifierSystem = null
var card_buff_debuff_system: CardBuffDebuffSystem = null
var card_definition: CardDefinition = null
var card_effect_system: CardEffectSystem = null
var shield_system: ShieldSystem = null
var clone_card_system: CloneCardSystem = null
var battle_temp_result_popup: BattleTempResultPopup = null
var is_temporary_battle_result_open: bool = false
var is_combo_attack_in_progress: bool = false

var current_turn_number: int = 1
var turn_number_label: Label = null

func _ready() -> void:
	_fix_scene_input_layers()
	_connect_pile_signals()
	_connect_ui_signals()
	_bind_final_objective()
	_setup_final_objective_skill_system()
	_setup_card_level_modifier_system()
	_setup_card_buff_debuff_system()
	_setup_card_definition()
	_setup_card_effect_system()
	_setup_shield_system()
	_setup_clone_card_system()
	_setup_card_stat_system()
	_setup_monster_action_system()
	_setup_battle_temp_result_popup()
	_setup_turn_number_ui()
	_build_start_deck()
	_create_pile_popup()
	_setup_test_monsters()
	_print_pile_counts("초기화 완료")

	await get_tree().process_frame
	await _deal_opening_player_field()
	refresh_player_combos()
	_refresh_player_shield_ui()
	_refresh_turn_number_ui()

func _process(_delta: float) -> void:
	_update_move_preview_hover()

func _setup_card_level_modifier_system() -> void:
	if card_level_modifier_system != null:
		return

	card_level_modifier_system = CardLevelModifierSystemScript.new() as CardLevelModifierSystem
	if card_level_modifier_system == null:
		print("카드 레벨 보정 시스템 생성 실패")
		return

	card_level_modifier_system.setup(default_card_level)
	print("카드 레벨 보정 시스템 연결 완료")

func _setup_card_buff_debuff_system() -> void:
	if card_buff_debuff_system != null:
		return

	card_buff_debuff_system = CardBuffDebuffSystemScript.new() as CardBuffDebuffSystem
	if card_buff_debuff_system == null:
		print("카드 버프/디버프 시스템 생성 실패")
		return

	print("카드 버프/디버프 시스템 연결 완료")

func _setup_card_definition() -> void:
	if card_definition != null:
		return

	card_definition = CardDefinitionScript.new() as CardDefinition
	if card_definition == null:
		print("카드 정의 시스템 생성 실패")
		return

	print("카드 정의 시스템 연결 완료")

func _setup_card_effect_system() -> void:
	if card_effect_system != null:
		return

	card_effect_system = CardEffectSystemScript.new() as CardEffectSystem
	if card_effect_system == null:
		print("카드 효과 시스템 생성 실패")
		return

	card_effect_system.setup(self, card_definition)
	print("카드 효과 시스템 연결 완료")

func _setup_shield_system() -> void:
	if shield_system != null:
		return

	shield_system = ShieldSystemScript.new() as ShieldSystem
	if shield_system == null:
		print("쉴드 시스템 생성 실패")
		return

	print("쉴드 시스템 연결 완료")

func _setup_clone_card_system() -> void:
	if clone_card_system != null:
		return

	clone_card_system = CloneCardSystemScript.new() as CloneCardSystem
	if clone_card_system == null:
		print("분신 카드 시스템 생성 실패")
		return

	clone_card_system.setup(self)
	print("분신 카드 시스템 연결 완료")

func _setup_card_stat_system() -> void:
	if card_stat_system != null:
		return

	card_stat_system = CardStatSystemScript.new() as CardStatSystem
	if card_stat_system == null:
		print("카드 스탯 시스템 생성 실패")
		return

	card_stat_system.setup(strike_combo_multiplier, harmony_combo_multiplier)
	print("카드 스탯 시스템 연결 완료")

func _setup_monster_action_system() -> void:
	if monster_action_system != null and is_instance_valid(monster_action_system):
		return

	monster_action_system = MonsterActionSystemScript.new() as MonsterActionSystem
	if monster_action_system == null:
		print("몬스터 행동 시스템 생성 실패")
		return

	monster_action_system.name = "MonsterActionSystem"
	add_child(monster_action_system)
	monster_action_system.setup(self)

	print("몬스터 행동 시스템 연결 완료")

func _setup_battle_temp_result_popup() -> void:
	if battle_temp_result_popup != null:
		return

	battle_temp_result_popup = BattleTempResultPopupScript.new() as BattleTempResultPopup
	if battle_temp_result_popup == null:
		print("임시 전투 결과 팝업 생성 실패")
		return

	add_child(battle_temp_result_popup)

	if not battle_temp_result_popup.restart_requested.is_connected(_on_battle_temp_result_restart_requested):
		battle_temp_result_popup.restart_requested.connect(_on_battle_temp_result_restart_requested)

	print("임시 전투 결과 팝업 연결 완료")

func _on_battle_temp_result_restart_requested() -> void:
	is_temporary_battle_result_open = false

	if battle_temp_result_popup != null and is_instance_valid(battle_temp_result_popup):
		battle_temp_result_popup.hide_popup()

	get_tree().reload_current_scene()

func _open_temporary_game_over() -> void:
	if is_temporary_battle_result_open:
		return

	clear_all_clone_cards_for_battle_end()
	is_temporary_battle_result_open = true

	if battle_temp_result_popup != null and is_instance_valid(battle_temp_result_popup):
		battle_temp_result_popup.show_game_over()

	print("임시 전투 결과 / GAME OVER")

func _open_temporary_stage_clear() -> void:
	if is_temporary_battle_result_open:
		return

	clear_all_clone_cards_for_battle_end()
	is_temporary_battle_result_open = true

	if battle_temp_result_popup != null and is_instance_valid(battle_temp_result_popup):
		battle_temp_result_popup.show_stage_clear()

	print("임시 전투 결과 / STAGE CLEAR")

func _get_player_hp_for_temp_result() -> int:
	if not _can_use_player_status_ui():
		return -1

	return player_status_ui.get_hp()

func _is_player_dead_for_temp_result() -> bool:
	return _get_player_hp_for_temp_result() <= 0

func _run_monster_action_phase(trigger_type: String) -> void:
	if monster_action_system == null:
		print("몬스터 행동 페이즈 실패 / 시스템 없음 / 트리거:", trigger_type)
		return

	if not is_instance_valid(monster_action_system):
		print("몬스터 행동 페이즈 실패 / 시스템 해제됨 / 트리거:", trigger_type)
		return

	await monster_action_system.run_action_phase(trigger_type)

func _bind_final_objective() -> void:
	final_objective = get_node_or_null(final_objective_path)

	if final_objective == null:
		print("최종목표 연결 실패 / final_objective_path 확인 필요")
		return

	print("최종목표 연결 완료:", final_objective.name)

func _setup_turn_number_ui() -> void:
	if turn_number_root == null:
		print("턴 번호 UI 연결 실패 / TurnNumber 노드 확인 필요")
		return

	turn_number_label = turn_number_root.get_node_or_null("TurnNumberLabel") as Label
	if turn_number_label == null:
		turn_number_label = Label.new()
		turn_number_label.name = "TurnNumberLabel"
		turn_number_root.add_child(turn_number_label)

	turn_number_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_number_label.offset_left = 0.0
	turn_number_label.offset_top = 0.0
	turn_number_label.offset_right = 0.0
	turn_number_label.offset_bottom = 0.0
	turn_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_number_label.add_theme_font_size_override("font_size", 30)
	turn_number_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	turn_number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	turn_number_label.add_theme_constant_override("outline_size", 3)

func _refresh_turn_number_ui() -> void:
	if turn_number_label == null:
		return

	turn_number_label.text = "TURN %d" % current_turn_number

func _advance_to_next_turn() -> void:
	current_turn_number += 1
	_refresh_turn_number_ui()
	print("현재 턴 변경 / TURN", current_turn_number)

func _setup_final_objective_skill_system() -> void:
	if final_objective_skill_system != null:
		return

	if final_objective == null:
		print("최종목표 턴 스킬 시스템 생성 스킵 / final_objective 없음")
		return

	final_objective_skill_system = FinalObjectiveSkillSystemScript.new() as FinalObjectiveSkillSystem
	if final_objective_skill_system == null:
		print("최종목표 턴 스킬 시스템 생성 실패")
		return

	add_child(final_objective_skill_system)
	final_objective_skill_system.setup(self, final_objective)
	final_objective_skill_system.apply_skill_profile("boss_test_damage_1")
	print("최종목표 턴 스킬 시스템 연결 완료")

func _can_use_player_status_ui() -> bool:
	return player_status_ui != null and is_instance_valid(player_status_ui)

func _try_spend_tp(cost: int, reason: String) -> bool:
	if cost <= 0:
		return true

	if not _can_use_player_status_ui():
		print("TP 사용 실패 / PlayerStatusUI 연결 필요 / 사유:", reason)
		return false

	if not player_status_ui.spend_tp(cost):
		print("TP 부족 / 사유:", reason, "/ 필요:", cost, "/ 현재 TP:", player_status_ui.get_tp())
		return false

	print("TP 사용 / 사유:", reason, "/ 소모:", cost, "/ 남은 TP:", player_status_ui.get_tp())
	return true

func _refund_tp(amount: int, reason: String) -> void:
	if amount <= 0:
		return

	if not _can_use_player_status_ui():
		return

	player_status_ui.add_tp(amount)
	print("TP 환불 / 사유:", reason, "/ 회복:", amount, "/ 현재 TP:", player_status_ui.get_tp())

func _get_tp_cost_for_action(action_key: String) -> int:
	if not bool(tp_use_enabled_by_action.get(action_key, true)):
		return 0

	return max(0, int(tp_cost_by_action.get(action_key, 0)))

func _try_spend_tp_for_action(action_key: String, reason: String) -> bool:
	return _try_spend_tp(_get_tp_cost_for_action(action_key), reason)

func _refund_tp_for_action(action_key: String, reason: String) -> void:
	_refund_tp(_get_tp_cost_for_action(action_key), reason)

func _refresh_player_shield_ui() -> void:
	if shieldpoint_ui == null:
		return
	if not is_instance_valid(shieldpoint_ui):
		return
	if not shieldpoint_ui.has_method("update_shield"):
		return

	shieldpoint_ui.call("update_shield", get_player_shield())

func get_player_shield() -> int:
	if shield_system == null:
		return 0

	return shield_system.get_shield(PLAYER_SHIELD_TARGET_KEY)

func add_player_shield(amount: int) -> int:
	if amount <= 0:
		_refresh_player_shield_ui()
		return get_player_shield()

	if shield_system == null:
		_refresh_player_shield_ui()
		return 0

	var next_shield: int = shield_system.add_shield(PLAYER_SHIELD_TARGET_KEY, amount)
	_refresh_player_shield_ui()
	print("플레이어 Shield 획득 / 증가:", amount, "/ 현재 Shield:", next_shield)
	return next_shield

func clear_player_shield() -> void:
	if shield_system == null:
		_refresh_player_shield_ui()
		return

	var before_shield: int = get_player_shield()
	shield_system.clear_shield(PLAYER_SHIELD_TARGET_KEY)
	_refresh_player_shield_ui()
	print("턴 시작 Shield 초기화 / 이전:", before_shield, "/ 현재:", get_player_shield())

func heal_player_hp(amount: int) -> int:
	if amount <= 0:
		return _get_player_hp_for_temp_result()

	if not _can_use_player_status_ui():
		print("플레이어 HP 회복 실패 / PlayerStatusUI 연결 필요 / 회복:", amount)
		return -1

	player_status_ui.add_hp(amount)

	var current_hp: int = player_status_ui.get_hp()
	print("플레이어 HP 회복 / 회복:", amount, "/ 현재 HP:", current_hp)
	return current_hp

func apply_damage_to_player(damage: int) -> Dictionary:
	var result: Dictionary = {
		"blocked_damage": 0,
		"hp_damage": 0,
		"shield_before": 0,
		"shield_after": 0
	}

	if damage <= 0:
		_refresh_player_shield_ui()
		return result

	if shield_system != null:
		result = shield_system.apply_damage(PLAYER_SHIELD_TARGET_KEY, damage)
	else:
		result["hp_damage"] = damage

	var hp_damage: int = int(result.get("hp_damage", 0))

	if hp_damage > 0:
		if not _can_use_player_status_ui():
			_refresh_player_shield_ui()
			print("플레이어 피격 실패 / PlayerStatusUI 연결 필요 / HP 피해:", hp_damage)
			return result

		player_status_ui.add_hp(-hp_damage)

	_refresh_player_shield_ui()

	var current_hp: int = _get_player_hp_for_temp_result()
	print(
		"플레이어 피격 / 피해:", damage,
		"/ 쉴드 차감:", int(result.get("blocked_damage", 0)),
		"/ HP 피해:", hp_damage,
		"/ 남은 Shield:", int(result.get("shield_after", 0)),
		"/ 남은 HP:", current_hp
	)

	return result

func reserve_clone_spawn(consumed_card: TestCard, clone_source_card: TestCard, clone_level: int) -> bool:
	if clone_card_system == null:
		return false

	return clone_card_system.reserve_clone_spawn(consumed_card, clone_source_card, clone_level)

func reserve_clone_spawn_from_card_states(
	consumed_card_state: CardState,
	consumed_slot_no: int,
	clone_source_card_state: CardState,
	clone_level: int
) -> bool:
	if clone_card_system == null:
		return false

	return clone_card_system.reserve_clone_spawn_from_card_states(
		consumed_card_state,
		consumed_slot_no,
		clone_source_card_state,
		clone_level
	)

func spawn_reserved_clone_for_consumed_instance_id(consumed_instance_id: int) -> TestCard:
	if clone_card_system == null:
		return null

	return clone_card_system.spawn_reserved_clone_for_consumed_instance_id(consumed_instance_id)

func clear_all_clone_cards_for_turn_end() -> void:
	if clone_card_system == null:
		return

	clone_card_system.clear_all_clone_cards_for_turn_end()

func clear_all_clone_cards_for_battle_end() -> void:
	if clone_card_system == null:
		return

	clone_card_system.clear_all_clone_cards_for_battle_end()

func _has_alive_combo_target_slots(target_slot_nos: Array) -> bool:
	for slot_no_variant in target_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no <= 0:
			continue

		if _get_monster_current_hp(slot_no) > 0:
			return true

	return false

func is_all_monsters_defeated() -> bool:
	for slot_no in range(1, 8):
		if _get_monster_current_hp(slot_no) > 0:
			return false

	return true

func is_final_objective_highlighted_for_combo_drag() -> bool:
	return final_objective_combo_drag_highlighted

func get_final_objective_rect_for_combo_drag() -> Rect2:
	if final_objective == null:
		return Rect2()
	if not is_instance_valid(final_objective):
		return Rect2()
	if not final_objective.has_method("get_objective_rect"):
		return Rect2()

	return final_objective.call("get_objective_rect")

func _is_final_objective_combo_target_active() -> bool:
	return is_final_objective_highlighted_for_combo_drag() and _can_hit_final_objective()

func _set_final_objective_combo_drag_highlight(is_on: bool) -> void:
	final_objective_combo_drag_highlighted = is_on
	_refresh_final_objective_combo_drag_highlight_visual()

func _set_final_objective_combo_drag_preview_highlight(is_on: bool) -> void:
	final_objective_combo_drag_preview_highlighted = is_on
	_refresh_final_objective_combo_drag_highlight_visual()

func _refresh_final_objective_combo_drag_highlight_visual() -> void:
	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("set_highlight"):
		return

	final_objective.call(
		"set_highlight",
		final_objective_combo_drag_highlighted or final_objective_combo_drag_preview_highlighted
	)

func _is_point_over_final_objective(target_point_global: Vector2) -> bool:
	if not is_all_monsters_defeated():
		return false

	if final_objective == null:
		return false
	if not is_instance_valid(final_objective):
		return false
	if not final_objective.has_method("get_objective_rect"):
		return false

	var objective_rect: Rect2 = final_objective.call("get_objective_rect")
	if objective_rect.size.x <= 0.0 or objective_rect.size.y <= 0.0:
		return false

	return objective_rect.has_point(target_point_global)
func _can_hit_final_objective() -> bool:
	if final_objective == null:
		return false

	if not is_instance_valid(final_objective):
		return false

	if not final_objective.has_method("get_hp"):
		return false

	return int(final_objective.call("get_hp")) > 0

func _damage_final_objective(damage: int) -> void:
	if damage <= 0:
		return

	if not _can_hit_final_objective():
		return

	var current_hp: int = int(final_objective.call("get_hp"))
	var next_hp: int = max(0, current_hp - damage)

	final_objective.call("set_hp", next_hp)

	print("최종목표 피격 / 피해:", damage, "/ 남은 HP:", next_hp)

	if next_hp <= 0:
		_open_temporary_stage_clear()

func _fix_scene_input_layers() -> void:
	var ignore_paths: Array[String] = [
		"Layer1_PlayerField/ColorRect",
		"Layer2_MonsterField",
		"Layer2_MonsterField/ColorRect"
	]

	for node_path in ignore_paths:
		if not has_node(node_path):
			continue

		var node: Node = get_node(node_path)
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_pile_signals() -> void:
	if deck_body != null:
		deck_body.drag_requested.connect(_on_pile_drag_requested)

	if grave_body != null:
		grave_body.drag_requested.connect(_on_pile_drag_requested)

func _connect_ui_signals() -> void:
	if deck_info_button != null:
		if not deck_info_button.pressed.is_connected(_on_deck_info_button_pressed):
			deck_info_button.pressed.connect(_on_deck_info_button_pressed)

	if grave_info_button != null:
		if not grave_info_button.pressed.is_connected(_on_grave_info_button_pressed):
			grave_info_button.pressed.connect(_on_grave_info_button_pressed)

	if end_turn_button != null:
		end_turn_button.text = "Turn End"
		end_turn_button.add_theme_font_size_override("font_size", 34)

		if not end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
			end_turn_button.pressed.connect(_on_end_turn_button_pressed)

func _on_deck_info_button_pressed() -> void:
	if current_popup_pile_type == "deck" and pile_popup_overlay != null and pile_popup_overlay.visible:
		_hide_pile_popup()
		return

	_show_pile_popup("deck")

func _on_grave_info_button_pressed() -> void:
	if current_popup_pile_type == "grave" and pile_popup_overlay != null and pile_popup_overlay.visible:
		_hide_pile_popup()
		return

	_show_pile_popup("grave")
func _on_end_turn_button_pressed() -> void:
	print("턴 종료 버튼 눌림")

	if is_temporary_battle_result_open:
		return

	if is_opening_deal_in_progress:
		print("턴 종료 무시 / 오프닝 배치 중")
		return

	if is_refill_draw_in_progress:
		print("턴 종료 무시 / 드로우 배치 중")
		return

	await _run_monster_action_phase("turn_end")
	await _run_final_objective_turn_end_skill_phase()
	clear_all_clone_cards_for_turn_end()

	if _is_player_dead_for_temp_result():
		_open_temporary_game_over()
		return

	if _can_use_player_status_ui():
		player_status_ui.reset_tp_to_start()
		print("턴 시작 TP 초기화 / 현재 TP:", player_status_ui.get_tp())

	clear_player_shield()

	await _refill_empty_player_slots_from_piles()
	_advance_to_next_turn()

func _build_start_deck() -> void:
	deck_cards.clear()
	grave_cards.clear()
	next_instance_id = 1

	var color_names: Array[String] = ["빨강", "파랑", "초록", "노랑"]

	for group_index in range(4):
		var combo_id: int = 1001 + group_index
		var color_name: String = color_names[group_index]

		for number_index in range(3):
			var data_id: int = 101 + group_index * 3 + number_index
			var card_name: String = "%s_%02d" % [color_name, number_index + 1]
			var new_card = _create_card_state(data_id, combo_id, card_name, "player")
			deck_cards.append(new_card)

	deck_cards.shuffle()

	print("시작 덱 생성 완료 / 총 장수:", deck_cards.size())
	for card_state in deck_cards:
		print("덱 카드:", card_state.to_log_string())

func _create_card_state(data_id: int, combo_id: int, card_name: String, owner_side: String):
	var new_card = CardStateScript.new()
	new_card.instance_id = next_instance_id
	new_card.data_id = data_id
	new_card.combo_id = combo_id
	new_card.card_name = card_name
	new_card.suit = ""
	new_card.faction = ""
	new_card.owner_side = owner_side
	new_card.base_level = default_card_level
	new_card.temp_level_delta = 0

	if card_definition != null:
		var definition: Dictionary = card_definition.get_definition_by_data_id(data_id)
		var display_name: String = String(definition.get("display_name", card_name))
		var definition_id: String = String(definition.get("definition_id", ""))
		var suit: String = String(definition.get("suit", ""))
		var faction: String = String(definition.get("faction", ""))

		if display_name != "":
			new_card.card_name = display_name

		new_card.suit = suit
		new_card.faction = faction

		if definition_id != "":
			new_card.set_meta("card_definition_id", definition_id)

	if card_level_modifier_system != null:
		card_level_modifier_system.initialize_card_state(new_card, default_card_level)

	if card_buff_debuff_system != null:
		card_buff_debuff_system.initialize_card_state(new_card)

	_sync_card_state_level_fields(new_card)

	next_instance_id += 1
	return new_card

func _sync_card_state_level_fields(card_state: CardState) -> void:
	if card_state == null:
		return

	var blessing_amount: int = 0
	var curse_amount: int = 0

	if card_buff_debuff_system != null:
		blessing_amount = card_buff_debuff_system.get_blessing(card_state)
		curse_amount = card_buff_debuff_system.get_curse(card_state)

	if card_level_modifier_system != null:
		card_level_modifier_system.sync_legacy_level_fields(card_state, blessing_amount, curse_amount)
		return

	if "base_level" in card_state and card_state.base_level < default_card_level:
		card_state.base_level = default_card_level

func get_card_base_level_by_state(card_state: CardState) -> int:
	if card_state == null:
		return default_card_level

	if card_level_modifier_system == null:
		return int(card_state.base_level)

	return card_level_modifier_system.get_base_level(card_state)

func get_card_final_level_by_state(card_state: CardState) -> int:
	if card_state == null:
		return default_card_level

	if card_level_modifier_system == null:
		return int(card_state.get_current_level())

	var blessing_amount: int = 0
	var curse_amount: int = 0

	if card_buff_debuff_system != null:
		blessing_amount = card_buff_debuff_system.get_blessing(card_state)
		curse_amount = card_buff_debuff_system.get_curse(card_state)

	return card_level_modifier_system.get_final_level(card_state, blessing_amount, curse_amount)

func _refresh_card_state_visual_only(card_state: CardState) -> void:
	if card_state == null:
		return

	_sync_card_state_level_fields(card_state)
	_refresh_card_state_visuals(card_state.instance_id)

func _refresh_card_state_after_level_change(card_state: CardState) -> void:
	if card_state == null:
		return

	_refresh_card_state_visual_only(card_state)
	refresh_player_combos()

func set_card_rank_up(instance_id: int, new_value: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Rank Up 변경 실패 / instance_id:", instance_id)
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.set_rank_up(card_state, new_value)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Rank Up 변경 / instance_id:", instance_id, "/ Rank Up:", max(0, new_value), "/ final_level:", get_card_final_level_by_state(card_state))

func add_card_rank_up(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Rank Up 가산 실패 / instance_id:", instance_id)
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.add_rank_up(card_state, delta)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Rank Up 가산 / instance_id:", instance_id, "/ delta:", delta, "/ final_level:", get_card_final_level_by_state(card_state))

func set_card_growth(instance_id: int, new_value: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Growth 변경 실패 / instance_id:", instance_id)
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.set_growth(card_state, new_value)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Growth 변경 / instance_id:", instance_id, "/ Growth:", max(0, new_value), "/ final_level:", get_card_final_level_by_state(card_state))

func add_card_growth(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Growth 가산 실패 / instance_id:", instance_id)
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.add_growth(card_state, delta)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Growth 가산 / instance_id:", instance_id, "/ delta:", delta, "/ final_level:", get_card_final_level_by_state(card_state))

func clear_card_growth(instance_id: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Growth 초기화 실패 / instance_id:", instance_id)
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.clear_growth(card_state)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Growth 초기화 / instance_id:", instance_id, "/ final_level:", get_card_final_level_by_state(card_state))

func set_card_blessing(instance_id: int, new_value: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Blessing 변경 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.set_blessing(card_state, new_value)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Blessing 변경 / instance_id:", instance_id, "/ Blessing:", max(0, new_value), "/ final_level:", get_card_final_level_by_state(card_state))

func add_card_blessing(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Blessing 가산 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.add_blessing(card_state, delta)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Blessing 가산 / instance_id:", instance_id, "/ delta:", delta, "/ final_level:", get_card_final_level_by_state(card_state))

func clear_card_blessing(instance_id: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Blessing 초기화 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.clear_blessing(card_state)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Blessing 초기화 / instance_id:", instance_id, "/ final_level:", get_card_final_level_by_state(card_state))

func set_card_curse(instance_id: int, new_value: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Curse 변경 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.set_curse(card_state, new_value)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Curse 변경 / instance_id:", instance_id, "/ Curse:", max(0, new_value), "/ final_level:", get_card_final_level_by_state(card_state))

func add_card_curse(instance_id: int, delta: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Curse 가산 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.add_curse(card_state, delta)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Curse 가산 / instance_id:", instance_id, "/ delta:", delta, "/ final_level:", get_card_final_level_by_state(card_state))

func clear_card_curse(instance_id: int) -> void:
	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		print("카드 Curse 초기화 실패 / instance_id:", instance_id)
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.clear_curse(card_state)

	_refresh_card_state_after_level_change(card_state)
	print("카드 Curse 초기화 / instance_id:", instance_id, "/ final_level:", get_card_final_level_by_state(card_state))

func set_card_base_level(instance_id: int, new_level: int) -> void:
	var normalized_level: int = max(default_card_level, new_level)
	var rank_up_value: int = max(0, normalized_level - default_card_level)
	set_card_rank_up(instance_id, rank_up_value)

func add_card_base_level(instance_id: int, delta: int) -> void:
	add_card_rank_up(instance_id, delta)

func set_card_temp_level_delta(instance_id: int, new_delta: int) -> void:
	set_card_growth(instance_id, max(0, new_delta))

func add_card_temp_level_delta(instance_id: int, delta: int) -> void:
	add_card_growth(instance_id, delta)

func clear_card_temp_level_delta(instance_id: int) -> void:
	clear_card_growth(instance_id)

func _consume_card_attack_use_modifiers(card: TestCard) -> void:
	if card == null:
		return
	if card.card_state == null:
		return

	var card_state: CardState = card.card_state as CardState
	if card_state == null:
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.consume_attack_use_modifiers(card_state)

	_refresh_card_state_visual_only(card_state)

func clear_all_card_battle_only_modifiers_for_battle_end() -> void:
	var all_card_states: Array = _get_all_unique_card_states()

	for card_state_variant in all_card_states:
		var card_state: CardState = card_state_variant as CardState
		if card_state == null:
			continue

		if card_level_modifier_system != null:
			card_level_modifier_system.clear_for_battle_end(card_state)

		if card_buff_debuff_system != null:
			card_buff_debuff_system.clear_for_battle_end(card_state)

		_refresh_card_state_visual_only(card_state)

	refresh_player_combos()

func _get_all_unique_card_states() -> Array:
	var result: Array = []
	var used_instance_ids: Dictionary = {}

	for card_state_variant in deck_cards:
		var deck_card_state: CardState = card_state_variant as CardState
		if deck_card_state == null:
			continue

		var deck_instance_id: int = int(deck_card_state.instance_id)
		if used_instance_ids.has(deck_instance_id):
			continue

		used_instance_ids[deck_instance_id] = true
		result.append(deck_card_state)

	for card_state_variant in grave_cards:
		var grave_card_state: CardState = card_state_variant as CardState
		if grave_card_state == null:
			continue

		var grave_instance_id: int = int(grave_card_state.instance_id)
		if used_instance_ids.has(grave_instance_id):
			continue

		used_instance_ids[grave_instance_id] = true
		result.append(grave_card_state)

	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if test_card.card_state == null:
			continue

		var card_state: CardState = test_card.card_state as CardState
		if card_state == null:
			continue

		var instance_id: int = int(card_state.instance_id)
		if used_instance_ids.has(instance_id):
			continue

		used_instance_ids[instance_id] = true
		result.append(card_state)

	return result

func apply_card_blessing_from_effect(instance_id: int, amount: int) -> void:
	if amount <= 0:
		return

	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		return

	if card_buff_debuff_system != null:
		card_buff_debuff_system.add_blessing(card_state, amount)

	_refresh_card_state_visual_only(card_state)
	_refresh_active_combo_drag_preview_labels()

func apply_card_growth_from_effect(instance_id: int, amount: int) -> void:
	if amount <= 0:
		return

	var card_state: CardState = _find_card_state_by_instance_id(instance_id)
	if card_state == null:
		return

	if card_level_modifier_system != null:
		card_level_modifier_system.add_growth(card_state, amount)

	_refresh_card_state_visual_only(card_state)
	_refresh_active_combo_drag_preview_labels()

func apply_growth_to_all_cards_by_suit_from_effect(target_suit: String, amount: int) -> void:
	if amount <= 0:
		return

	var normalized_target_suit: String = target_suit.strip_edges().to_lower()
	if normalized_target_suit == "":
		return

	var all_card_states: Array = _get_all_unique_card_states()

	for card_state_variant in all_card_states:
		var card_state: CardState = card_state_variant as CardState
		if card_state == null:
			continue

		var card_suit: String = String(card_state.suit).strip_edges().to_lower()
		if card_suit != normalized_target_suit:
			continue

		if card_level_modifier_system != null:
			card_level_modifier_system.add_growth(card_state, amount)

		_refresh_card_state_visual_only(card_state)

	_refresh_active_combo_drag_preview_labels()

func get_remaining_player_field_cards_excluding_combo_cards(excluded_cards: Array) -> Array:
	var result: Array = []
	var excluded_ids: Dictionary = {}

	for excluded_card_variant in excluded_cards:
		var excluded_card: TestCard = excluded_card_variant as TestCard
		if excluded_card == null:
			continue
		if not is_instance_valid(excluded_card):
			continue

		excluded_ids[excluded_card.get_instance_id()] = true

	for slot_variant in _get_all_player_slots():
		var slot: FieldSlot = slot_variant as FieldSlot
		if slot == null:
			continue
		if slot.card == null:
			continue

		var field_card: TestCard = slot.card as TestCard
		if field_card == null:
			continue
		if not is_instance_valid(field_card):
			continue
		if field_card.card_state == null:
			continue
		if excluded_ids.has(field_card.get_instance_id()):
			continue

		result.append(field_card)

	return result

func _refresh_active_combo_drag_preview_labels() -> void:
	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if not is_instance_valid(test_card):
			continue

		if test_card.has_method("is_active_combo_drag_leader") and test_card.is_active_combo_drag_leader():
			if test_card.has_method("refresh_combo_drag_preview_all_card_labels"):
				test_card.refresh_combo_drag_preview_all_card_labels()
			return

func _run_combo_card_effects(timing: String, combo_data: Dictionary, attack_entry: Dictionary) -> void:
	if card_effect_system == null:
		return

	card_effect_system.run_combo_card_effects(timing, combo_data, attack_entry)

func refresh_runtime_combo_card_displays(combo_data: Dictionary) -> void:
	var combo_type: String = String(combo_data.get("combo_type", ""))

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return

	var combo_cards: Array = cards_value as Array
	var alive_combo_cards: Array = []

	for combo_card_variant in combo_cards:
		if combo_card_variant == null:
			continue
		if not is_instance_valid(combo_card_variant):
			continue

		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if combo_card.card_state == null:
			continue

		alive_combo_cards.append(combo_card)

		_refresh_card_state_visual_only(combo_card.card_state as CardState)

		var final_power: int = _calculate_final_power_from_card_and_combo_type(combo_card, combo_type)
		if combo_card.has_method("set_final_power_display"):
			combo_card.set_final_power_display(final_power)

	combo_data["cards"] = alive_combo_cards

	var leader_card_variant = combo_data.get("leader_card", null)
	if leader_card_variant == null:
		combo_data["leader_card"] = null
		return
	if not is_instance_valid(leader_card_variant):
		combo_data["leader_card"] = null
		return

	var leader_card: TestCard = leader_card_variant as TestCard
	if leader_card == null:
		combo_data["leader_card"] = null
		return

	if leader_card.has_method("refresh_combo_drag_preview_all_card_labels"):
		leader_card.refresh_combo_drag_preview_all_card_labels()

func _find_card_state_by_instance_id(instance_id: int) -> CardState:
	for card_state_variant in deck_cards:
		var deck_card_state: CardState = card_state_variant as CardState
		if deck_card_state == null:
			continue
		if int(deck_card_state.instance_id) == instance_id:
			return deck_card_state

	for card_state_variant in grave_cards:
		var grave_card_state: CardState = card_state_variant as CardState
		if grave_card_state == null:
			continue
		if int(grave_card_state.instance_id) == instance_id:
			return grave_card_state

	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if test_card.card_state == null:
			continue
		if int(test_card.card_state.instance_id) == instance_id:
			return test_card.card_state as CardState

	return null

func _refresh_card_state_visuals(instance_id: int) -> void:
	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if test_card.card_state == null:
			continue
		if int(test_card.card_state.instance_id) != instance_id:
			continue

		if test_card.has_method("refresh_from_card_state"):
			test_card.refresh_from_card_state()

func _collect_test_cards_recursive(root_node: Node, result: Array) -> void:
	for child in root_node.get_children():
		if child is TestCard:
			result.append(child)

		_collect_test_cards_recursive(child, result)

func set_combo_multiplier(combo_type: String, new_multiplier: int) -> void:
	if combo_type == "strike":
		strike_combo_multiplier = new_multiplier
	elif combo_type == "harmony":
		harmony_combo_multiplier = new_multiplier
	else:
		return

	if card_stat_system != null:
		card_stat_system.set_combo_multiplier(combo_type, new_multiplier)

	refresh_player_combos()
	print("조합 배수 변경 / 타입:", combo_type, "/ 값:", _get_combo_multiplier(combo_type))

func _get_card_level_from_card(card: TestCard) -> int:
	if card == null:
		return default_card_level

	if card.card_state == null:
		return default_card_level

	return get_card_final_level_by_state(card.card_state as CardState)

func _calculate_final_power_from_card_and_multiplier(card: TestCard, combo_multiplier: int) -> int:
	if card == null:
		return 0

	if card.card_state == null:
		return max(0, default_card_level * max(0, combo_multiplier))

	if card_stat_system == null:
		var fallback_level: int = _get_card_level_from_card(card)
		return max(0, fallback_level * max(0, combo_multiplier))

	return card_stat_system.calculate_final_power_from_multiplier(card.card_state, "", combo_multiplier)

func _calculate_final_power_from_card_and_combo_type(card: TestCard, combo_type: String) -> int:
	if card == null:
		return 0

	if card.card_state == null:
		return max(0, default_card_level * max(0, _get_combo_multiplier(combo_type)))

	if card_stat_system == null:
		return _calculate_final_power_from_card_and_multiplier(card, _get_combo_multiplier(combo_type))

	return card_stat_system.calculate_final_power(card.card_state, combo_type)

func _get_combo_multiplier(combo_type: String) -> int:
	if card_stat_system != null:
		return card_stat_system.get_combo_multiplier(combo_type)

	if combo_type == "strike":
		return strike_combo_multiplier

	if combo_type == "harmony":
		return harmony_combo_multiplier

	return 1

func _on_pile_drag_requested(pile_type: String) -> void:
	if is_opening_deal_in_progress:
		print("오프닝 7장 배치 중 / 드래그 요청 무시:", pile_type)
		return

	if is_refill_draw_in_progress:
		print("빈 슬롯 드로우 중 / 드래그 요청 무시:", pile_type)
		return

	print("배틀씬에서 드래그 요청 받음:", pile_type)

	if pile_type == "deck":
		_spawn_drag_card_from_pile("deck")
		return

	if pile_type == "grave":
		_spawn_drag_card_from_pile("grave")
		return

func _spawn_drag_card_from_pile(pile_type: String) -> void:
	if not _try_spend_tp_for_action("pile_draw", "%s 드로우" % pile_type):
		return

	var card_state = _pop_card_from_pile(pile_type)

	if card_state == null:
		_refund_tp_for_action("pile_draw", "%s 드로우 실패" % pile_type)
		print("카드 생성 실패 /", pile_type, "이 비어 있음")
		return

	var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
	add_child(card_instance)

	card_instance.setup_from_card_state(card_state)
	card_instance.pile_drag_finished.connect(_on_pile_drag_finished)
	card_instance.start_drag_from_pile(pile_type, get_global_mouse_position())

	print("더미 카드 생성 완료 / 출처:", pile_type, "/", card_state.to_log_string())
	_print_pile_counts("드래그 시작 후")
	_refresh_open_pile_popup()

func _pop_card_from_pile(pile_type: String):
	if pile_type == "deck":
		if deck_cards.is_empty():
			return null
		return deck_cards.pop_back()

	if pile_type == "grave":
		if grave_cards.is_empty():
			return null
		return grave_cards.pop_back()

	return null

func _push_card_back_to_pile(pile_type: String, card_state) -> void:
	if card_state == null:
		return

	if pile_type == "deck":
		deck_cards.append(card_state)
		return

	if pile_type == "grave":
		grave_cards.append(card_state)
		return

func _on_pile_drag_finished(card_state, pile_type: String, placed: bool) -> void:
	if placed:
		print("파일 카드 배치 성공 / 출처:", pile_type, "/", card_state.to_log_string())
		_print_pile_counts("배치 성공 후")
		refresh_player_combos()
		_refresh_open_pile_popup()
		return

	_refund_tp_for_action("pile_draw", "%s 드로우 취소" % pile_type)
	_push_card_back_to_pile(pile_type, card_state)
	print("파일 카드 배치 실패 / 원래 더미로 복귀:", pile_type, "/", card_state.to_log_string())
	_print_pile_counts("배치 실패 후")
	refresh_player_combos()
	_refresh_open_pile_popup()

func _print_pile_counts(context: String) -> void:
	print("-----", context, "-----")
	print("deck_cards:", deck_cards.size())
	print("grave_cards:", grave_cards.size())

func _deal_opening_player_field() -> void:
	is_opening_deal_in_progress = true

	print("===== 오프닝 7장 배치 시작 =====")

	for slot_no in range(1, 8):
		var target_slot: FieldSlot = _get_player_slot(slot_no)
		if target_slot == null:
			print("오프닝 배치 실패 / PlayerSlot%d 없음" % slot_no)
			continue

		var card_state = _pop_card_from_pile("deck")
		if card_state == null:
			print("오프닝 배치 중단 / 덱이 비어 있음")
			break

		var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
		add_child(card_instance)

		card_instance.setup_from_card_state(card_state)

		var start_position: Vector2 = _get_pile_card_start_position(deck_body)
		await card_instance.deal_from_pile_to_slot(start_position, target_slot)

		_print_pile_counts("오프닝 슬롯 %d 배치 후" % slot_no)
		await get_tree().create_timer(0.06).timeout

	print("===== 오프닝 7장 배치 종료 =====")
	is_opening_deal_in_progress = false

func _refill_empty_player_slots_from_piles() -> void:
	is_refill_draw_in_progress = true
	clear_selected_field_card()

	var empty_slots: Array = _get_empty_player_slots_left_to_right()

	if empty_slots.is_empty():
		print("턴 종료 드로우 없음 / 빈 슬롯 없음")
		await _flip_face_down_monsters_to_front_left_to_right()
		is_refill_draw_in_progress = false
		refresh_player_combos()
		_refresh_open_pile_popup()
		await _run_final_objective_turn_start_skill_phase()
		return

	print("===== 턴 종료 빈 슬롯 드로우 시작 =====")
	print("빈 슬롯 번호:", _make_slot_no_array(empty_slots))

	for slot_variant in empty_slots:
		var target_slot: FieldSlot = slot_variant as FieldSlot
		if target_slot == null:
			continue

		if target_slot.card != null:
			continue

		if deck_cards.is_empty():
			if grave_cards.is_empty():
				print("턴 종료 드로우 중단 / 덱과 무덤 모두 비어 있음")
				break

			_merge_grave_into_deck_and_shuffle()

			if deck_cards.is_empty():
				print("턴 종료 드로우 중단 / 합친 뒤에도 덱이 비어 있음")
				break

		var card_state = _pop_card_from_pile("deck")
		if card_state == null:
			print("턴 종료 드로우 중단 / 덱 팝 실패")
			break

		var card_instance: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
		add_child(card_instance)
		card_instance.setup_from_card_state(card_state)

		var start_position: Vector2 = _get_pile_card_start_position(deck_body)
		await card_instance.deal_from_pile_to_slot(start_position, target_slot)

		_print_pile_counts("턴 종료 슬롯 %d 배치 후" % target_slot.slot_no)
		_refresh_open_pile_popup()
		await get_tree().create_timer(0.06).timeout

	print("===== 턴 종료 빈 슬롯 드로우 종료 =====")
	await _flip_face_down_monsters_to_front_left_to_right()
	is_refill_draw_in_progress = false
	refresh_player_combos()
	_refresh_open_pile_popup()
	await _run_final_objective_turn_start_skill_phase()

func _run_final_objective_turn_start_skill_phase() -> void:
	if final_objective_skill_system == null:
		return

	await final_objective_skill_system.run_trigger(FinalObjectiveSkillSystem.TRIGGER_TURN_START)

func _run_final_objective_turn_end_skill_phase() -> void:
	if final_objective_skill_system == null:
		return

	await final_objective_skill_system.run_trigger(FinalObjectiveSkillSystem.TRIGGER_TURN_END)
func _get_empty_player_slots_left_to_right() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		var slot: FieldSlot = _get_player_slot(slot_no)
		if slot == null:
			continue

		if slot.card == null:
			result.append(slot)

	return result

func _make_slot_no_array(slots: Array) -> Array:
	var result: Array = []

	for slot_variant in slots:
		var slot: FieldSlot = slot_variant as FieldSlot
		if slot == null:
			continue

		result.append(slot.slot_no)

	return result

func _merge_grave_into_deck_and_shuffle() -> void:
	if grave_cards.is_empty():
		return

	var moved_count: int = grave_cards.size()

	for card_state in grave_cards:
		deck_cards.append(card_state)

	grave_cards.clear()
	deck_cards.shuffle()

	print("무덤+덱 합치기 완료 / 이동 장수:", moved_count)
	_print_pile_counts("무덤 합치기 후")
	_refresh_open_pile_popup()

func _get_pile_card_start_position(pile_body: Control) -> Vector2:
	var pile_rect: Rect2 = pile_body.get_global_rect()
	var card_size: Vector2 = Vector2(150.0, 221.0)
	return pile_rect.position + (pile_rect.size - card_size) * 0.5

func on_field_card_clicked(card: TestCard) -> void:
	if card == null:
		return

	if card.current_slot == null:
		return

	if is_opening_deal_in_progress:
		return

	if is_refill_draw_in_progress:
		return

	if selected_field_card == null:
		selected_field_card = card
		if card.has_method("set_selected_visual"):
			card.set_selected_visual(true)
		print("필드 카드 선택 / 슬롯:", card.current_slot.slot_no, "/ 카드:", card.card_name)
		return

	if selected_field_card == card:
		clear_selected_field_card()
		print("필드 카드 선택 해제 / 카드:", card.card_name)
		return

	_try_move_or_swap_selected_card(card.current_slot)

func on_field_slot_clicked(slot: FieldSlot) -> void:
	if slot == null:
		return

	if slot.side != "player":
		return

	if is_opening_deal_in_progress:
		return

	if is_refill_draw_in_progress:
		return

	if selected_field_card == null:
		return

	_try_move_or_swap_selected_card(slot)

func _update_move_preview_hover() -> void:
	if is_opening_deal_in_progress:
		clear_move_preview()
		return

	if is_refill_draw_in_progress:
		clear_move_preview()
		return

	if selected_field_card == null:
		clear_move_preview()
		return

	var source_slot: FieldSlot = selected_field_card.current_slot
	if source_slot == null:
		clear_move_preview()
		return

	var hovered_slot: FieldSlot = _get_hovered_player_slot_by_mouse()

	if hovered_slot == null:
		clear_move_preview()
		return

	if hovered_slot == source_slot:
		clear_move_preview()
		return

	if hovered_slot.is_broken:
		clear_move_preview()
		return

	if move_preview_from_slot_no == source_slot.slot_no and move_preview_to_slot_no == hovered_slot.slot_no:
		return

	_show_move_preview(hovered_slot)

func _get_hovered_player_slot_by_mouse() -> FieldSlot:
	var mouse_global: Vector2 = get_viewport().get_mouse_position()

	for slot_no in range(1, 8):
		var slot: FieldSlot = _get_player_slot(slot_no)
		if slot == null:
			continue

		var rect: Rect2 = slot.get_global_rect()
		if rect.has_point(mouse_global):
			return slot

	return null

func _show_move_preview(target_slot: FieldSlot) -> void:
	clear_move_preview()

	if selected_field_card == null:
		return

	var source_card: TestCard = selected_field_card
	var source_slot: FieldSlot = source_card.current_slot

	if source_slot == null:
		return

	if target_slot == null:
		return

	if target_slot.side != "player":
		return

	if target_slot == source_slot:
		return

	if target_slot.is_broken:
		return

	var target_card: TestCard = target_slot.card as TestCard

	move_preview_from_slot_no = source_slot.slot_no
	move_preview_to_slot_no = target_slot.slot_no
	move_preview_mode = "move" if target_card == null else "swap"

	if source_slot.has_method("set_move_preview_visual"):
		source_slot.set_move_preview_visual("source")

	if target_slot.has_method("set_move_preview_visual"):
		if target_card == null:
			target_slot.set_move_preview_visual("move_target")
		else:
			target_slot.set_move_preview_visual("swap_target")

	source_card.visible = false

	move_preview_source_visual_card = _create_move_preview_card(source_card, target_slot)
	if move_preview_source_visual_card != null:
		move_preview_nodes.append(move_preview_source_visual_card)

	move_preview_target_visual_card = null

	if target_card != null:
		target_card.visible = false

		move_preview_target_visual_card = _create_move_preview_card(target_card, source_slot)
		if move_preview_target_visual_card != null:
			move_preview_nodes.append(move_preview_target_visual_card)

	_refresh_move_preview_combo_overlays()

func clear_move_preview() -> void:
	var had_preview: bool = is_move_combo_preview_active or (move_preview_from_slot_no > 0 and move_preview_to_slot_no > 0)

	var source_slot: FieldSlot = _get_player_slot(move_preview_from_slot_no)
	var target_slot: FieldSlot = _get_player_slot(move_preview_to_slot_no)

	if source_slot != null and source_slot.has_method("clear_preview_visual"):
		source_slot.clear_preview_visual()

	if target_slot != null and target_slot.has_method("clear_preview_visual"):
		target_slot.clear_preview_visual()

	if source_slot != null and source_slot.card != null and is_instance_valid(source_slot.card):
		source_slot.card.visible = true

	if target_slot != null and target_slot.card != null and is_instance_valid(target_slot.card):
		target_slot.card.visible = true

	for preview_node in move_preview_nodes:
		if preview_node != null and is_instance_valid(preview_node):
			preview_node.queue_free()

	move_preview_nodes.clear()
	move_preview_source_visual_card = null
	move_preview_target_visual_card = null
	move_preview_from_slot_no = 0
	move_preview_to_slot_no = 0
	move_preview_mode = ""
	is_move_combo_preview_active = false

	if had_preview:
		refresh_player_combos()

func _create_move_preview_card(source_card: TestCard, target_slot: FieldSlot) -> TestCard:
	if source_card == null:
		return null

	if target_slot == null:
		return null

	if source_card.card_state == null:
		return null

	var preview_card: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
	target_slot.add_child(preview_card)

	preview_card.setup_from_card_state(source_card.card_state)
	preview_card.position = Vector2.ZERO
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.modulate = Color(1, 1, 1, 0.55)
	preview_card.process_mode = Node.PROCESS_MODE_DISABLED

	if preview_card.has_method("set_selected_visual"):
		preview_card.set_selected_visual(false)

	return preview_card

func _refresh_move_preview_combo_overlays() -> void:
	if move_preview_from_slot_no <= 0 or move_preview_to_slot_no <= 0:
		return

	var logic_cards_by_slot_no: Dictionary = {}
	var visual_cards_by_slot_no: Dictionary = {}

	for slot_no in range(1, 8):
		var slot: FieldSlot = _get_player_slot(slot_no)
		if slot == null:
			logic_cards_by_slot_no[slot_no] = null
			visual_cards_by_slot_no[slot_no] = null
			continue

		var slot_card: TestCard = slot.card as TestCard
		logic_cards_by_slot_no[slot_no] = slot_card
		visual_cards_by_slot_no[slot_no] = slot_card

	var source_slot: FieldSlot = _get_player_slot(move_preview_from_slot_no)
	var target_slot: FieldSlot = _get_player_slot(move_preview_to_slot_no)

	if source_slot == null or target_slot == null:
		return

	var source_card: TestCard = source_slot.card as TestCard
	var target_card: TestCard = target_slot.card as TestCard

	logic_cards_by_slot_no[move_preview_from_slot_no] = target_card
	logic_cards_by_slot_no[move_preview_to_slot_no] = source_card

	visual_cards_by_slot_no[move_preview_from_slot_no] = move_preview_target_visual_card
	visual_cards_by_slot_no[move_preview_to_slot_no] = move_preview_source_visual_card

	_clear_combo_overlays()
	_clear_all_player_card_final_power_displays()
	_clear_move_preview_card_final_power_displays()
	is_move_combo_preview_active = true

	var used_slot_nos: Dictionary = {}

	for start_slot_no in range(1, 6):
		var slot_no_a: int = start_slot_no
		var slot_no_b: int = start_slot_no + 1
		var slot_no_c: int = start_slot_no + 2

		if used_slot_nos.has(slot_no_a) or used_slot_nos.has(slot_no_b) or used_slot_nos.has(slot_no_c):
			continue

		var logic_card_a: TestCard = logic_cards_by_slot_no.get(slot_no_a, null) as TestCard
		var logic_card_b: TestCard = logic_cards_by_slot_no.get(slot_no_b, null) as TestCard
		var logic_card_c: TestCard = logic_cards_by_slot_no.get(slot_no_c, null) as TestCard

		if logic_card_a == null or logic_card_b == null or logic_card_c == null:
			continue

		if logic_card_a.card_state == null or logic_card_b.card_state == null or logic_card_c.card_state == null:
			continue

		var combo_a: int = int(logic_card_a.card_state.combo_id)
		var combo_b: int = int(logic_card_b.card_state.combo_id)
		var combo_c: int = int(logic_card_c.card_state.combo_id)

		var combo_type: String = ""

		if combo_a == combo_b and combo_b == combo_c:
			combo_type = "strike"
		elif combo_a != combo_b and combo_a != combo_c and combo_b != combo_c:
			combo_type = "harmony"
		else:
			continue

		var slot_a: FieldSlot = _get_player_slot(slot_no_a)
		var slot_b: FieldSlot = _get_player_slot(slot_no_b)
		var slot_c: FieldSlot = _get_player_slot(slot_no_c)

		_create_combo_overlay(slot_a, slot_b, slot_c, combo_type)

		_apply_move_preview_combo_final_power_display(
			logic_card_a,
			visual_cards_by_slot_no.get(slot_no_a, null) as TestCard,
			combo_type
		)
		_apply_move_preview_combo_final_power_display(
			logic_card_b,
			visual_cards_by_slot_no.get(slot_no_b, null) as TestCard,
			combo_type
		)
		_apply_move_preview_combo_final_power_display(
			logic_card_c,
			visual_cards_by_slot_no.get(slot_no_c, null) as TestCard,
			combo_type
		)

		used_slot_nos[slot_no_a] = true
		used_slot_nos[slot_no_b] = true
		used_slot_nos[slot_no_c] = true

func _clear_move_preview_card_final_power_displays() -> void:
	for preview_node in move_preview_nodes:
		var preview_card: TestCard = preview_node as TestCard
		if preview_card == null:
			continue
		if not is_instance_valid(preview_card):
			continue

		if preview_card.has_method("clear_final_power_display"):
			preview_card.clear_final_power_display()

func _apply_move_preview_combo_final_power_display(logic_card: TestCard, visual_card: TestCard, combo_type: String) -> void:
	if logic_card == null:
		return

	if visual_card == null:
		return

	if not is_instance_valid(visual_card):
		return

	var final_power: int = _calculate_final_power_from_card_and_combo_type(logic_card, combo_type)

	if visual_card.has_method("set_final_power_display"):
		visual_card.set_final_power_display(final_power)

func _redraw_actual_combo_overlays() -> void:
	_clear_combo_overlays()

	for combo_variant in player_combos:
		if typeof(combo_variant) != TYPE_DICTIONARY:
			continue

		var combo_data: Dictionary = combo_variant as Dictionary
		var slot_nos_value = combo_data.get("slot_nos", [])

		if typeof(slot_nos_value) != TYPE_ARRAY:
			continue

		var slot_nos: Array = slot_nos_value as Array
		if slot_nos.size() != 3:
			continue

		var slot_a: FieldSlot = _get_player_slot(int(slot_nos[0]))
		var slot_b: FieldSlot = _get_player_slot(int(slot_nos[1]))
		var slot_c: FieldSlot = _get_player_slot(int(slot_nos[2]))
		var combo_type: String = String(combo_data.get("combo_type", ""))

		_create_combo_overlay(slot_a, slot_b, slot_c, combo_type)

func _try_move_or_swap_selected_card(target_slot: FieldSlot) -> void:
	if selected_field_card == null:
		return

	var source_card: TestCard = selected_field_card
	var source_slot: FieldSlot = source_card.current_slot

	if source_slot == null:
		clear_selected_field_card()
		return

	if target_slot == source_slot:
		clear_selected_field_card()
		print("같은 슬롯 클릭 / 선택 해제")
		return

	if target_slot.card == null:
		if not _try_spend_tp_for_action("field_move", "필드 이동"):
			return

		source_slot.remove_card()
		var moved: bool = target_slot.place_card(source_card)

		clear_selected_field_card()

		if moved:
			print("클릭 이동 성공 /", source_slot.slot_no, "->", target_slot.slot_no)
		else:
			source_slot.place_card(source_card)
			_refund_tp_for_action("field_move", "필드 이동 실패 원복")
			print("클릭 이동 실패 / 원위치")

		refresh_player_combos()
		return

	if not _try_spend_tp_for_action("field_swap", "필드 교체"):
		return

	var target_card = target_slot.card
	target_slot.remove_card()
	source_slot.remove_card()

	var placed_source: bool = target_slot.place_card(source_card)
	var placed_target: bool = source_slot.place_card(target_card)

	clear_selected_field_card()

	if placed_source and placed_target:
		print("클릭 교체 성공 /", source_slot.slot_no, "<->", target_slot.slot_no)
		refresh_player_combos()
		return

	if target_slot.card == source_card:
		target_slot.remove_card()
	if source_slot.card == target_card:
		source_slot.remove_card()

	source_slot.place_card(source_card)
	target_slot.place_card(target_card)
	_refund_tp_for_action("field_swap", "필드 교체 실패 원복")
	print("클릭 교체 실패 / 원복")
	refresh_player_combos()

func clear_selected_field_card() -> void:
	clear_move_preview()

	if selected_field_card == null:
		return

	if selected_field_card.has_method("set_selected_visual"):
		selected_field_card.set_selected_visual(false)

	selected_field_card = null

func refresh_player_combos() -> void:
	player_combos.clear()
	_clear_combo_overlays()
	_clear_all_player_card_final_power_displays()

	var player_slots: Array = _get_all_player_slots()
	var used_slot_nos: Dictionary = {}

	for start_idx in range(0, 5):
		var slot_a: FieldSlot = player_slots[start_idx] as FieldSlot
		var slot_b: FieldSlot = player_slots[start_idx + 1] as FieldSlot
		var slot_c: FieldSlot = player_slots[start_idx + 2] as FieldSlot

		if slot_a == null or slot_b == null or slot_c == null:
			continue

		if used_slot_nos.has(slot_a.slot_no) or used_slot_nos.has(slot_b.slot_no) or used_slot_nos.has(slot_c.slot_no):
			continue

		if slot_a.card == null or slot_b.card == null or slot_c.card == null:
			continue

		if slot_a.card.card_state == null or slot_b.card.card_state == null or slot_c.card.card_state == null:
			continue

		var combo_a: int = int(slot_a.card.card_state.combo_id)
		var combo_b: int = int(slot_b.card.card_state.combo_id)
		var combo_c: int = int(slot_c.card.card_state.combo_id)

		var combo_type: String = ""

		if combo_a == combo_b and combo_b == combo_c:
			combo_type = "strike"
		elif combo_a != combo_b and combo_a != combo_c and combo_b != combo_c:
			combo_type = "harmony"
		else:
			continue

		var combo_multiplier: int = _get_combo_multiplier(combo_type)
		var combo_cards: Array = [slot_a.card, slot_b.card, slot_c.card]

		var combo_data: Dictionary = {
			"combo_type": combo_type,
			"combo_multiplier": combo_multiplier,
			"slot_nos": [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no],
			"cards": combo_cards,
			"leader_card": null,
			"card_role_by_instance_id": {}
		}

		player_combos.append(combo_data)

		used_slot_nos[slot_a.slot_no] = true
		used_slot_nos[slot_b.slot_no] = true
		used_slot_nos[slot_c.slot_no] = true

		_apply_combo_final_power_displays(combo_cards, combo_type)
		_create_combo_overlay(slot_a, slot_b, slot_c, combo_type)

		print("조합 발견 / 타입:", combo_type, "/ 슬롯:", [slot_a.slot_no, slot_b.slot_no, slot_c.slot_no])

func _clear_all_player_card_final_power_displays() -> void:
	for slot_variant in _get_all_player_slots():
		var player_slot: FieldSlot = slot_variant as FieldSlot
		if player_slot == null:
			continue
		if player_slot.card == null:
			continue

		var field_card: TestCard = player_slot.card as TestCard
		if field_card == null:
			continue
		if not is_instance_valid(field_card):
			continue

		if field_card.has_method("clear_final_power_display"):
			field_card.clear_final_power_display()

func _apply_combo_final_power_displays(combo_cards: Array, combo_type: String) -> void:
	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue

		var final_power: int = _calculate_final_power_from_card_and_combo_type(combo_card, combo_type)

		if combo_card.has_method("set_final_power_display"):
			combo_card.set_final_power_display(final_power)

func get_combo_data_for_card(card: TestCard) -> Dictionary:
	if card == null:
		return {}

	for combo_variant in player_combos:
		if typeof(combo_variant) != TYPE_DICTIONARY:
			continue

		var combo_data: Dictionary = combo_variant as Dictionary

		if not combo_data.has("cards"):
			continue

		var cards_value = combo_data.get("cards", [])
		if typeof(cards_value) != TYPE_ARRAY:
			continue

		var cards: Array = cards_value as Array

		if cards.has(card):
			return combo_data

	return {}

func try_use_combo_by_leader(leader_card: TestCard, _mouse_global_position: Vector2) -> bool:
	if leader_card == null:
		return false

	if is_combo_attack_in_progress:
		print("조합 사용 실패 / 다른 조합 공격 진행 중")
		return false

	var combo_data: Dictionary = get_combo_data_for_card(leader_card)
	if combo_data.is_empty():
		print("조합 사용 실패 / 리더 카드가 조합에 없음")
		return false

	var use_final_objective: bool = _is_final_objective_combo_target_active()
	var target_monster_slot: FieldSlot = _get_combo_drag_highlighted_monster_slot()

	if use_final_objective:
		if leader_card.has_method("snap_combo_drag_preview_to_final_objective"):
			leader_card.snap_combo_drag_preview_to_final_objective()
	elif target_monster_slot != null:
		if leader_card.has_method("snap_combo_drag_preview_to_monster_slot"):
			leader_card.snap_combo_drag_preview_to_monster_slot(target_monster_slot)
	else:
		print("조합 사용 실패 / 하이라이트된 몬스터나 최종목표가 없음")
		return false

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return false

	var combo_cards: Array = cards_value as Array

	combo_data["leader_card"] = leader_card
	combo_data["card_role_by_instance_id"] = _build_combo_card_role_map(combo_cards, leader_card)

	var combo_type: String = String(combo_data.get("combo_type", ""))
	var combo_multiplier: int = _get_combo_multiplier(combo_type)
	var attack_plan: Dictionary = _build_combo_attack_plan(combo_data, leader_card)

	if not _try_spend_tp_for_action("combo_attack", "조합 드래그 공격"):
		return false

	print(
		"조합 사용 시작 / 타입:", combo_type,
		"/ 배수:", combo_multiplier,
		"/ 리더:", leader_card.card_name,
		"/ 리더 타겟 슬롯:", int(attack_plan.get("leader_target_slot_no", 0)),
		"/ 리더 타겟 타입:", String(attack_plan.get("leader_target_type", "monster"))
	)

	clear_selected_field_card()
	player_combos.clear()
	_clear_combo_overlays()

	is_combo_attack_in_progress = true
	_play_combo_attack_sequence(combo_data, attack_plan, leader_card)

	return true

func _get_combo_drag_highlighted_monster_slot() -> FieldSlot:
	if combo_drag_highlighted_monster_slot_no <= 0:
		return null

	if _get_monster_current_hp(combo_drag_highlighted_monster_slot_no) <= 0:
		return null

	return _get_monster_slot(combo_drag_highlighted_monster_slot_no)

func _play_combo_attack_sequence(combo_data: Dictionary, attack_plan: Dictionary, leader_card: TestCard) -> void:
	var removed_card_instance_ids: Dictionary = {}
	var detached_cards_to_free: Array = []
	var preview_owner: TestCard = leader_card
	var attack_order_index: int = 1
	var combo_type: String = String(combo_data.get("combo_type", ""))

	var attack_entries_value = attack_plan.get("entries", [])
	if typeof(attack_entries_value) != TYPE_ARRAY:
		attack_entries_value = []

	var attack_entries: Array = attack_entries_value as Array
	var leader_target_slot_no: int = int(attack_plan.get("leader_target_slot_no", 0))
	var leader_target_type: String = String(attack_plan.get("leader_target_type", "monster"))
	var is_final_objective_target: bool = leader_target_type == "final_objective"

	var overlap_priority_value = attack_plan.get("overlap_priority_slot_nos", [])
	if typeof(overlap_priority_value) != TYPE_ARRAY:
		overlap_priority_value = []

	var overlap_priority_slot_nos: Array = overlap_priority_value as Array

	for attack_entry_variant in attack_entries:
		if is_inside_tree():
			await get_tree().create_timer(0.3).timeout

		if attack_order_index == 1:
			if preview_owner != null and is_instance_valid(preview_owner):
				if preview_owner.has_method("hide_combo_drag_preview_overlay"):
					preview_owner.hide_combo_drag_preview_overlay()

		if typeof(attack_entry_variant) != TYPE_DICTIONARY:
			continue

		var attack_entry: Dictionary = attack_entry_variant as Dictionary
		var attack_card: TestCard = attack_entry.get("card", null) as TestCard

		if attack_card == null:
			continue
		if not is_instance_valid(attack_card):
			continue

		_run_combo_card_effects(CardDefinition.TIMING_BEFORE_ATTACK, combo_data, attack_entry)
		refresh_runtime_combo_card_displays(combo_data)

		var target_slot_no: int = 0
		var is_fixed_overlap: bool = bool(attack_entry.get("is_fixed_overlap", false))

		if is_fixed_overlap:
			target_slot_no = int(attack_entry.get("target_slot_no", 0))
		else:
			target_slot_no = _resolve_non_overlapped_combo_target_slot_no(
				leader_target_slot_no,
				overlap_priority_slot_nos
			)

		var hit_damage: int = _calculate_final_power_from_card_and_combo_type(attack_card, combo_type)
		if is_final_objective_target:
			if preview_owner != null and is_instance_valid(preview_owner):
				if is_fixed_overlap:
					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)
				else:
					if preview_owner.has_method("play_combo_dash_hit_preview_to_final_objective"):
						await preview_owner.play_combo_dash_hit_preview_to_final_objective(attack_card)

					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)

			_damage_final_objective(hit_damage)
		elif target_slot_no > 0 and _get_monster_current_hp(target_slot_no) > 0:
			if preview_owner != null and is_instance_valid(preview_owner):
				if is_fixed_overlap:
					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)
				else:
					if preview_owner.has_method("play_combo_dash_hit_preview"):
						await preview_owner.play_combo_dash_hit_preview(attack_card, target_slot_no)

					if preview_owner.has_method("play_combo_contact_hit_preview"):
						await preview_owner.play_combo_contact_hit_preview(attack_card)

			await _play_monster_contact_hit_effect(target_slot_no)
			await _damage_monster(target_slot_no, hit_damage)
		elif not _has_alive_combo_target_slots(overlap_priority_slot_nos) and _can_hit_final_objective():
			if preview_owner != null and is_instance_valid(preview_owner):
				if preview_owner.has_method("play_combo_dash_hit_preview_to_final_objective"):
					await preview_owner.play_combo_dash_hit_preview_to_final_objective(attack_card)

				if preview_owner.has_method("play_combo_contact_hit_preview"):
					await preview_owner.play_combo_contact_hit_preview(attack_card)

			_damage_final_objective(hit_damage)
		else:
			print("조합 타격 실패 / 유효한 타겟 없음 / 카드:", attack_card.card_name)

		if preview_owner != null and is_instance_valid(preview_owner):
			if preview_owner.has_method("consume_combo_drag_preview_card"):
				preview_owner.consume_combo_drag_preview_card(attack_card)

		_consume_card_attack_use_modifiers(attack_card)
		_run_combo_card_effects(CardDefinition.TIMING_AFTER_USE, combo_data, attack_entry)
		_send_combo_card_to_grave(attack_card, removed_card_instance_ids, detached_cards_to_free)
		_print_pile_counts("조합 타격 %d 후" % attack_order_index)

		attack_order_index += 1

		if is_temporary_battle_result_open:
			break

	if preview_owner != null and is_instance_valid(preview_owner):
		if preview_owner.has_method("finish_combo_drag_attack_preview"):
			preview_owner.finish_combo_drag_attack_preview()

	for detached_card_variant in detached_cards_to_free:
		var detached_card: TestCard = detached_card_variant as TestCard
		if detached_card == null:
			continue
		if not is_instance_valid(detached_card):
			continue

		detached_card.queue_free()

	refresh_player_combos()
	_print_pile_counts("조합 사용 후")
	_refresh_open_pile_popup()
	clear_combo_drag_target_highlight()

	if is_temporary_battle_result_open:
		is_combo_attack_in_progress = false
		return

	is_combo_attack_in_progress = false

func _send_combo_card_to_grave(combo_card: TestCard, removed_card_instance_ids: Dictionary, detached_cards_to_free: Array) -> void:
	if combo_card == null:
		return
	if not is_instance_valid(combo_card):
		return

	var node_instance_id: int = combo_card.get_instance_id()
	if removed_card_instance_ids.has(node_instance_id):
		return

	removed_card_instance_ids[node_instance_id] = true

	var consumed_card_state: CardState = combo_card.card_state as CardState
	var consumed_instance_id: int = 0
	var is_clone_card: bool = false

	if consumed_card_state != null:
		consumed_instance_id = int(consumed_card_state.instance_id)
		is_clone_card = consumed_card_state.is_clone_card()

	if is_clone_card:
		var detached_clone: bool = false

		if clone_card_system != null:
			detached_clone = clone_card_system.detach_clone_card_for_combo_use(combo_card)

		if not detached_clone:
			if combo_card.current_slot != null and combo_card.current_slot.card == combo_card:
				combo_card.current_slot.remove_card()

			combo_card.card_state = null

		detached_cards_to_free.append(combo_card)
	else:
		if combo_card.card_state != null:
			grave_cards.append(combo_card.card_state)
			combo_card.card_state = null

		if combo_card.current_slot != null and combo_card.current_slot.card == combo_card:
			combo_card.current_slot.remove_card()

		detached_cards_to_free.append(combo_card)

	if consumed_instance_id > 0 and clone_card_system != null:
		clone_card_system.spawn_reserved_clone_for_consumed_instance_id(consumed_instance_id)

func _build_combo_card_role_map(combo_cards: Array, leader_card: TestCard) -> Dictionary:
	var result: Dictionary = {}

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue

		var role: String = "member"
		if combo_card == leader_card:
			role = "leader"

		result[combo_card.get_instance_id()] = role

	return result

func get_combo_card_role(combo_data: Dictionary, target_card: TestCard) -> String:
	if target_card == null:
		return ""

	var role_map_value = combo_data.get("card_role_by_instance_id", {})
	if typeof(role_map_value) != TYPE_DICTIONARY:
		return ""

	var role_map: Dictionary = role_map_value as Dictionary
	return String(role_map.get(target_card.get_instance_id(), ""))

func _build_combo_attack_plan(combo_data: Dictionary, leader_card: TestCard) -> Dictionary:
	var result: Dictionary = {
		"entries": [],
		"leader_target_slot_no": 0,
		"leader_target_type": "monster",
		"overlap_priority_slot_nos": []
	}

	if leader_card == null:
		return result

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return result

	var role_map_value = combo_data.get("card_role_by_instance_id", {})
	if typeof(role_map_value) != TYPE_DICTIONARY:
		role_map_value = {}

	var card_role_by_instance_id: Dictionary = role_map_value as Dictionary
	var combo_cards: Array = cards_value as Array
	var is_final_objective_target: bool = _is_final_objective_combo_target_active()

	if is_final_objective_target:
		var final_objective_entries: Array = []
		var non_leader_cards: Array = []

		final_objective_entries.append({
			"card": leader_card,
			"card_role": String(card_role_by_instance_id.get(leader_card.get_instance_id(), "leader")),
			"target_slot_no": 0,
			"is_fixed_overlap": true
		})

		for combo_card_variant in combo_cards:
			var combo_card: TestCard = combo_card_variant as TestCard
			if combo_card == null:
				continue
			if combo_card == leader_card:
				continue

			non_leader_cards.append(combo_card)

		non_leader_cards.sort_custom(Callable(self, "_sort_cards_by_slot_no"))

		for combo_card_variant in non_leader_cards:
			var combo_card: TestCard = combo_card_variant as TestCard
			if combo_card == null:
				continue

			final_objective_entries.append({
				"card": combo_card,
				"card_role": String(card_role_by_instance_id.get(combo_card.get_instance_id(), "member")),
				"target_slot_no": 0,
				"is_fixed_overlap": false
			})

		result["entries"] = final_objective_entries
		result["leader_target_type"] = "final_objective"
		return result

	var leader_card_id: int = leader_card.get_instance_id()
	var leader_target_slot_no: int = int(
		combo_drag_preview_card_target_slot_by_id.get(
			leader_card_id,
			combo_drag_highlighted_monster_slot_no
		)
	)

	if _get_monster_current_hp(leader_target_slot_no) <= 0:
		leader_target_slot_no = 0

	var overlap_priority_slot_nos: Array = []
	if leader_target_slot_no > 0:
		overlap_priority_slot_nos.append(leader_target_slot_no)

	var overlapped_entries: Array = []
	var non_overlapped_entries: Array = []
	var result_entries: Array = []

	result_entries.append({
		"card": leader_card,
		"card_role": String(card_role_by_instance_id.get(leader_card_id, "leader")),
		"target_slot_no": leader_target_slot_no,
		"is_fixed_overlap": true
	})

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if combo_card == leader_card:
			continue

		var own_target_slot_no: int = int(
			combo_drag_preview_card_target_slot_by_id.get(combo_card.get_instance_id(), 0)
		)

		var sort_slot_no: int = 999
		if combo_card.current_slot != null:
			sort_slot_no = combo_card.current_slot.slot_no

		var entry := {
			"card": combo_card,
			"card_role": String(card_role_by_instance_id.get(combo_card.get_instance_id(), "member")),
			"target_slot_no": own_target_slot_no,
			"is_fixed_overlap": own_target_slot_no > 0,
			"sort_slot_no": sort_slot_no
		}

		if own_target_slot_no > 0:
			overlapped_entries.append(entry)

			if not overlap_priority_slot_nos.has(own_target_slot_no):
				overlap_priority_slot_nos.append(own_target_slot_no)
		else:
			non_overlapped_entries.append(entry)

	overlapped_entries.sort_custom(Callable(self, "_sort_attack_entries_by_slot_no"))
	non_overlapped_entries.sort_custom(Callable(self, "_sort_attack_entries_by_slot_no"))

	for entry_variant in overlapped_entries:
		var entry: Dictionary = entry_variant as Dictionary
		result_entries.append({
			"card": entry.get("card", null),
			"card_role": String(entry.get("card_role", "member")),
			"target_slot_no": int(entry.get("target_slot_no", 0)),
			"is_fixed_overlap": true
		})

	for entry_variant in non_overlapped_entries:
		var entry: Dictionary = entry_variant as Dictionary
		result_entries.append({
			"card": entry.get("card", null),
			"card_role": String(entry.get("card_role", "member")),
			"target_slot_no": 0,
			"is_fixed_overlap": false
		})

	result["entries"] = result_entries
	result["leader_target_slot_no"] = leader_target_slot_no
	result["overlap_priority_slot_nos"] = overlap_priority_slot_nos
	return result

func _sort_attack_entries_by_slot_no(a, b) -> bool:
	if typeof(a) != TYPE_DICTIONARY and typeof(b) != TYPE_DICTIONARY:
		return false
	if typeof(a) != TYPE_DICTIONARY:
		return false
	if typeof(b) != TYPE_DICTIONARY:
		return true

	var entry_a: Dictionary = a as Dictionary
	var entry_b: Dictionary = b as Dictionary

	return int(entry_a.get("sort_slot_no", 999)) < int(entry_b.get("sort_slot_no", 999))

func _resolve_non_overlapped_combo_target_slot_no(leader_target_slot_no: int, overlap_priority_slot_nos: Array) -> int:
	if leader_target_slot_no > 0 and _get_monster_current_hp(leader_target_slot_no) > 0:
		return leader_target_slot_no

	for slot_no_variant in overlap_priority_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no == leader_target_slot_no:
			continue

		if _get_monster_current_hp(slot_no) > 0:
			return slot_no

	return 0



func _get_combo_attack_order(combo_data: Dictionary, leader_card: TestCard) -> Array:
	var ordered_cards: Array = []

	if leader_card == null:
		return ordered_cards

	ordered_cards.append(leader_card)

	var remaining_cards: Array = []
	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return ordered_cards

	var cards: Array = cards_value as Array

	for card_variant in cards:
		var combo_card: TestCard = card_variant as TestCard
		if combo_card == null:
			continue

		if combo_card == leader_card:
			continue

		remaining_cards.append(combo_card)

	remaining_cards.sort_custom(Callable(self, "_sort_cards_by_slot_no"))

	for remaining_card_variant in remaining_cards:
		ordered_cards.append(remaining_card_variant)

	return ordered_cards

func _sort_cards_by_slot_no(a, b) -> bool:
	var card_a: TestCard = a as TestCard
	var card_b: TestCard = b as TestCard

	if card_a == null and card_b == null:
		return false
	if card_a == null:
		return false
	if card_b == null:
		return true

	var slot_no_a: int = 999
	var slot_no_b: int = 999

	if card_a.current_slot != null:
		slot_no_a = card_a.current_slot.slot_no

	if card_b.current_slot != null:
		slot_no_b = card_b.current_slot.slot_no

	return slot_no_a < slot_no_b

func _setup_test_monsters() -> void:
	monster_hp_by_slot_no.clear()
	monster_root_by_slot_no.clear()
	monster_hp_label_by_slot_no.clear()
	monster_is_face_down_by_slot_no.clear()
	monster_is_flipping_by_slot_no.clear()
	combo_drag_preview_monster_hp_after_by_slot_no.clear()
	combo_drag_preview_monster_targeted_slot_nos.clear()

	var monster_slot_nos: Array[int] = [2,  6]

	for slot_no in monster_slot_nos:
		monster_hp_by_slot_no[slot_no] = monster_start_hp
		monster_is_face_down_by_slot_no[slot_no] = false
		monster_is_flipping_by_slot_no[slot_no] = false
		_ensure_monster_visual(slot_no)
		_update_monster_visual(slot_no)

	print("테스트 몬스터 생성 완료 / 슬롯: 2, 6 / HP:", monster_start_hp)

func _ensure_monster_visual(slot_no: int) -> void:
	var slot: FieldSlot = _get_monster_slot(slot_no)
	if slot == null:
		return

	var unit: MonsterUnit = slot.get_node_or_null("MonsterUnit") as MonsterUnit
	if unit == null:
		unit = MonsterUnit.new()
		unit.name = "MonsterUnit"
		slot.add_child(unit)

	unit.setup_unit(slot_no, slot.size)

	monster_root_by_slot_no[slot_no] = unit
	monster_hp_label_by_slot_no[slot_no] = unit.get_node_or_null("MonsterHpLabel") as Label

func _update_monster_visual(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	var hp: int = int(monster_hp_by_slot_no.get(slot_no, 0))
	var attack_value: int = _get_basic_monster_attack_display_value()
	unit.visible = true
	unit.set_attack_value(attack_value)
	unit.set_hp_text(hp)

	if unit.has_method("clear_hp_preview"):
		unit.clear_hp_preview()

	if slot_no == 4:
		unit.set_effect_symbols(["❄"])
	else:
		unit.set_effect_symbols([])

	if bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
		unit.apply_back_face()
	else:
		unit.apply_front_face()

func _get_basic_monster_attack_display_value() -> int:
	if monster_action_system == null:
		return 0

	if monster_action_system.has_method("get_basic_attack_damage"):
		return max(0, int(monster_action_system.get_basic_attack_damage()))

	return max(0, int(monster_action_system.basic_attack_damage))

func refresh_all_monster_attack_displays() -> void:
	for slot_no_variant in monster_root_by_slot_no.keys():
		var slot_no: int = int(slot_no_variant)
		var unit: MonsterUnit = _get_monster_unit(slot_no)
		if unit == null:
			continue

		unit.set_attack_value(_get_basic_monster_attack_display_value())

func _get_monster_current_hp(slot_no: int) -> int:
	return int(monster_hp_by_slot_no.get(slot_no, 0))

func update_combo_drag_target_highlight_by_point(target_point_global: Vector2) -> void:
	if _is_point_over_final_objective(target_point_global):
		combo_drag_highlighted_monster_slot_no = 0
		combo_drag_preview_card_target_slot_by_id.clear()
		_apply_combo_drag_preview_highlight_slots([])
		_clear_combo_drag_monster_hp_previews()
		_set_final_objective_combo_drag_highlight(true)
		_refresh_final_objective_combo_drag_preview_from_active_leader()
		return

	_set_final_objective_combo_drag_highlight(false)

	var target_slot: FieldSlot = _get_alive_monster_slot_at_global_position(target_point_global)

	if target_slot == null:
		combo_drag_highlighted_monster_slot_no = 0
	else:
		combo_drag_highlighted_monster_slot_no = target_slot.slot_no

	_refresh_final_objective_combo_drag_preview_from_active_leader()
func get_combo_drag_highlighted_monster_slot_for_preview() -> FieldSlot:
	return _get_combo_drag_highlighted_monster_slot()

func update_combo_drag_snapped_overlap_preview(card_rect_datas: Array) -> void:
	var next_slot_nos: Array = []
	var next_card_targets: Dictionary = {}

	for card_rect_data_variant in card_rect_datas:
		if typeof(card_rect_data_variant) != TYPE_DICTIONARY:
			continue

		var card_rect_data: Dictionary = card_rect_data_variant as Dictionary
		var source_card_id: int = int(card_rect_data.get("source_card_id", 0))

		if not card_rect_data.has("rect"):
			continue

		var card_rect: Rect2 = card_rect_data.get("rect", Rect2())
		var target_slot: FieldSlot = _get_best_alive_monster_slot_for_rect(card_rect)

		if target_slot == null:
			continue

		next_card_targets[source_card_id] = target_slot.slot_no

		if not next_slot_nos.has(target_slot.slot_no):
			next_slot_nos.append(target_slot.slot_no)

	next_slot_nos.sort()
	_apply_combo_drag_preview_highlight_slots(next_slot_nos)
	combo_drag_preview_card_target_slot_by_id = next_card_targets
	_refresh_combo_drag_monster_hp_preview_from_active_leader()

	if combo_drag_preview_card_target_slot_by_id.is_empty():
		_set_final_objective_combo_drag_preview_highlight(false)
		return

	_refresh_final_objective_combo_drag_preview_from_active_leader()

func clear_combo_drag_target_highlight() -> void:
	_apply_combo_drag_preview_highlight_slots([])
	_set_final_objective_combo_drag_highlight(false)
	_clear_combo_drag_monster_hp_previews()
	_clear_final_objective_combo_drag_hp_preview()
	_set_final_objective_combo_drag_preview_highlight(false)
	combo_drag_highlighted_monster_slot_no = 0
	combo_drag_preview_card_target_slot_by_id.clear()
func _apply_combo_drag_preview_highlight_slots(next_slot_nos: Array) -> void:
	for prev_slot_no_variant in combo_drag_preview_highlight_slot_nos:
		var prev_slot_no: int = int(prev_slot_no_variant)
		if next_slot_nos.has(prev_slot_no):
			continue
		_set_combo_drag_monster_highlight(prev_slot_no, false)

	for next_slot_no_variant in next_slot_nos:
		var next_slot_no: int = int(next_slot_no_variant)
		if combo_drag_preview_highlight_slot_nos.has(next_slot_no):
			continue
		_set_combo_drag_monster_highlight(next_slot_no, true)

	combo_drag_preview_highlight_slot_nos = next_slot_nos.duplicate()

func _refresh_combo_drag_monster_hp_preview_from_active_leader() -> void:
	var leader_card: TestCard = _get_active_combo_drag_leader_card()
	if leader_card == null:
		_clear_combo_drag_monster_hp_previews()
		return

	var combo_data: Dictionary = get_combo_data_for_card(leader_card)
	if combo_data.is_empty():
		_clear_combo_drag_monster_hp_previews()
		return

	var preview_combo_data: Dictionary = combo_data.duplicate(true)
	var cards_value = preview_combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		_clear_combo_drag_monster_hp_previews()
		return

	var combo_cards: Array = cards_value as Array
	preview_combo_data["leader_card"] = leader_card
	preview_combo_data["card_role_by_instance_id"] = _build_combo_card_role_map(combo_cards, leader_card)

	var preview_result: Dictionary = _build_combo_drag_monster_hp_preview_result(preview_combo_data, leader_card)
	var after_hp_value = preview_result.get("after_hp_by_slot_no", {})
	if typeof(after_hp_value) != TYPE_DICTIONARY:
		_clear_combo_drag_monster_hp_previews()
		return

	_apply_combo_drag_monster_hp_previews(after_hp_value as Dictionary)

func _apply_combo_drag_monster_hp_previews(after_hp_by_slot_no: Dictionary) -> void:
	var next_targeted_slot_nos: Array = []

	for slot_no_variant in after_hp_by_slot_no.keys():
		next_targeted_slot_nos.append(int(slot_no_variant))

	for prev_slot_no_variant in combo_drag_preview_monster_targeted_slot_nos:
		var prev_slot_no: int = int(prev_slot_no_variant)
		if next_targeted_slot_nos.has(prev_slot_no):
			continue

		var prev_unit: MonsterUnit = _get_monster_unit(prev_slot_no)
		if prev_unit != null and prev_unit.has_method("clear_hp_preview"):
			prev_unit.clear_hp_preview()

	combo_drag_preview_monster_hp_after_by_slot_no = after_hp_by_slot_no.duplicate(true)
	combo_drag_preview_monster_targeted_slot_nos = next_targeted_slot_nos.duplicate()

	for next_slot_no_variant in next_targeted_slot_nos:
		var next_slot_no: int = int(next_slot_no_variant)
		var unit: MonsterUnit = _get_monster_unit(next_slot_no)
		if unit == null:
			continue

		var current_hp: int = _get_monster_current_hp(next_slot_no)
		var after_hp: int = int(after_hp_by_slot_no.get(next_slot_no, current_hp))

		if unit.has_method("show_hp_preview"):
			unit.show_hp_preview(current_hp, after_hp)

func _clear_combo_drag_monster_hp_previews() -> void:
	for slot_no_variant in combo_drag_preview_monster_targeted_slot_nos:
		var slot_no: int = int(slot_no_variant)
		var unit: MonsterUnit = _get_monster_unit(slot_no)
		if unit != null and unit.has_method("clear_hp_preview"):
			unit.clear_hp_preview()

	combo_drag_preview_monster_hp_after_by_slot_no.clear()
	combo_drag_preview_monster_targeted_slot_nos.clear()

func _get_active_combo_drag_leader_card() -> TestCard:
	var all_test_cards: Array = []
	_collect_test_cards_recursive(self, all_test_cards)

	for card_variant in all_test_cards:
		var test_card: TestCard = card_variant as TestCard
		if test_card == null:
			continue
		if not is_instance_valid(test_card):
			continue

		if test_card.has_method("is_active_combo_drag_leader") and test_card.is_active_combo_drag_leader():
			return test_card

	return null

func _build_combo_drag_monster_hp_preview_result(combo_data: Dictionary, leader_card: TestCard) -> Dictionary:
	var result: Dictionary = {
		"after_hp_by_slot_no": {}
	}

	if combo_data.is_empty():
		return result

	if leader_card == null:
		return result

	var attack_plan: Dictionary = _build_combo_attack_plan(combo_data, leader_card)
	if String(attack_plan.get("leader_target_type", "monster")) != "monster":
		return result

	var combo_type: String = String(combo_data.get("combo_type", ""))

	var attack_entries_value = attack_plan.get("entries", [])
	if typeof(attack_entries_value) != TYPE_ARRAY:
		attack_entries_value = []
	var attack_entries: Array = attack_entries_value as Array

	var leader_target_slot_no: int = int(attack_plan.get("leader_target_slot_no", 0))

	var overlap_priority_value = attack_plan.get("overlap_priority_slot_nos", [])
	if typeof(overlap_priority_value) != TYPE_ARRAY:
		overlap_priority_value = []
	var overlap_priority_slot_nos: Array = overlap_priority_value as Array

	var simulated_hp_by_slot_no: Dictionary = {}
	for slot_no in range(1, 8):
		simulated_hp_by_slot_no[slot_no] = _get_monster_current_hp(slot_no)

	var targeted_slot_nos: Dictionary = {}
	var before_attack_preview_state: Dictionary = _make_before_attack_combo_preview_state(combo_data)

	for attack_entry_variant in attack_entries:
		if typeof(attack_entry_variant) != TYPE_DICTIONARY:
			continue

		var attack_entry: Dictionary = attack_entry_variant as Dictionary
		var attack_card: TestCard = attack_entry.get("card", null) as TestCard
		if attack_card == null:
			continue
		if not is_instance_valid(attack_card):
			continue
		if attack_card.card_state == null:
			continue

		_apply_before_attack_effects_to_combo_preview(combo_data, attack_entry, before_attack_preview_state)

		var target_slot_no: int = 0
		var is_fixed_overlap: bool = bool(attack_entry.get("is_fixed_overlap", false))

		if is_fixed_overlap:
			target_slot_no = int(attack_entry.get("target_slot_no", 0))
		else:
			target_slot_no = _resolve_non_overlapped_combo_target_slot_no_from_simulated_hp(
				leader_target_slot_no,
				overlap_priority_slot_nos,
				simulated_hp_by_slot_no
			)

		if target_slot_no <= 0:
			continue

		if int(simulated_hp_by_slot_no.get(target_slot_no, 0)) <= 0:
			continue

		targeted_slot_nos[target_slot_no] = true

		var hit_damage: int = _calculate_preview_final_power_from_card_and_combo_type(
			attack_card,
			combo_type,
			before_attack_preview_state
		)

		var current_hp: int = int(simulated_hp_by_slot_no.get(target_slot_no, 0))
		simulated_hp_by_slot_no[target_slot_no] = max(0, current_hp - hit_damage)

	var after_hp_by_slot_no: Dictionary = {}

	for targeted_slot_no_variant in targeted_slot_nos.keys():
		var targeted_slot_no: int = int(targeted_slot_no_variant)
		after_hp_by_slot_no[targeted_slot_no] = int(
			simulated_hp_by_slot_no.get(targeted_slot_no, _get_monster_current_hp(targeted_slot_no))
		)

	result["after_hp_by_slot_no"] = after_hp_by_slot_no
	return result

func _resolve_non_overlapped_combo_target_slot_no_from_simulated_hp(
	leader_target_slot_no: int,
	overlap_priority_slot_nos: Array,
	simulated_hp_by_slot_no: Dictionary
) -> int:
	if leader_target_slot_no > 0 and int(simulated_hp_by_slot_no.get(leader_target_slot_no, 0)) > 0:
		return leader_target_slot_no

	for slot_no_variant in overlap_priority_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no == leader_target_slot_no:
			continue

		if int(simulated_hp_by_slot_no.get(slot_no, 0)) > 0:
			return slot_no

	return 0

func _make_before_attack_combo_preview_state(combo_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"growth_by_instance_id": {},
		"blessing_by_instance_id": {}
	}

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return result

	var combo_cards: Array = cards_value as Array

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue

		var instance_id: int = int(combo_card.card_state.instance_id)
		var growth_map: Dictionary = result.get("growth_by_instance_id", {}) as Dictionary
		var blessing_map: Dictionary = result.get("blessing_by_instance_id", {}) as Dictionary

		growth_map[instance_id] = 0
		blessing_map[instance_id] = 0

		result["growth_by_instance_id"] = growth_map
		result["blessing_by_instance_id"] = blessing_map

	return result

func _apply_before_attack_effects_to_combo_preview(
	combo_data: Dictionary,
	attack_entry: Dictionary,
	preview_state: Dictionary
) -> void:
	if card_definition == null:
		return

	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	var effects: Array = card_definition.get_effects_by_data_id(int(attack_card.card_state.data_id))

	for effect_variant in effects:
		if typeof(effect_variant) != TYPE_DICTIONARY:
			continue

		var effect_data: Dictionary = effect_variant as Dictionary

		if String(effect_data.get("timing", "")) != CardDefinition.TIMING_BEFORE_ATTACK:
			continue

		if not _is_preview_before_attack_trigger_matched(effect_data, combo_data, attack_entry):
			continue

		_apply_single_before_attack_effect_to_combo_preview(effect_data, combo_data, attack_entry, preview_state)

func _is_preview_before_attack_trigger_matched(
	effect_data: Dictionary,
	combo_data: Dictionary,
	attack_entry: Dictionary
) -> bool:
	var trigger: String = String(effect_data.get("trigger", ""))
	var combo_type: String = String(combo_data.get("combo_type", ""))
	var card_role: String = String(attack_entry.get("card_role", ""))

	match trigger:
		CardDefinition.TRIGGER_HARMONY_LEADER:
			return combo_type == "harmony" and card_role == "leader"

		CardDefinition.TRIGGER_STRIKE_LEADER:
			return combo_type == "strike" and card_role == "leader"

		CardDefinition.TRIGGER_MEMBER:
			return card_role == "member"

		_:
			return false

func _apply_single_before_attack_effect_to_combo_preview(
	effect_data: Dictionary,
	combo_data: Dictionary,
	attack_entry: Dictionary,
	preview_state: Dictionary
) -> void:
	var effect_type: String = String(effect_data.get("effect_type", ""))

	match effect_type:
		CardDefinition.EFFECT_GRANT_COMBO_BLESSING_BY_SELF_LEVEL:
			_apply_preview_effect_grant_combo_blessing_by_self_level(effect_data, combo_data, attack_entry, preview_state)

		CardDefinition.EFFECT_GRANT_ALL_SUIT_CARDS_GROWTH:
			_apply_preview_effect_grant_all_suit_cards_growth(effect_data, combo_data, preview_state)

		CardDefinition.EFFECT_GRANT_SELF_GROWTH:
			_apply_preview_effect_grant_self_growth(effect_data, attack_entry, preview_state)

		_:
			pass

func _apply_preview_effect_grant_combo_blessing_by_self_level(
	effect_data: Dictionary,
	combo_data: Dictionary,
	attack_entry: Dictionary,
	preview_state: Dictionary
) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	var blessing_amount: int = _get_preview_card_final_level(attack_card, preview_state)
	if blessing_amount <= 0:
		return

	var target_cards: Array = _get_preview_effect_target_cards(effect_data, combo_data, attack_entry)
	if target_cards.is_empty():
		return

	for combo_card_variant in target_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue

		_add_preview_blessing_delta(
			preview_state,
			int(combo_card.card_state.instance_id),
			blessing_amount
		)

func _apply_preview_effect_grant_all_suit_cards_growth(
	effect_data: Dictionary,
	combo_data: Dictionary,
	preview_state: Dictionary
) -> void:
	var target_suit: String = String(effect_data.get("target_suit", "")).strip_edges().to_lower()
	var amount: int = int(effect_data.get("amount", 0))

	if target_suit == "":
		return
	if amount <= 0:
		return

	var combo_cards: Array = _get_preview_all_combo_cards(combo_data)

	for combo_card_variant in combo_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue

		var card_suit: String = String(combo_card.card_state.suit).strip_edges().to_lower()
		if card_suit != target_suit:
			continue

		_add_preview_growth_delta(
			preview_state,
			int(combo_card.card_state.instance_id),
			amount
		)

func _apply_preview_effect_grant_self_growth(
	effect_data: Dictionary,
	attack_entry: Dictionary,
	preview_state: Dictionary
) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	var amount: int = int(effect_data.get("amount", 0))
	if amount <= 0:
		return

	_add_preview_growth_delta(
		preview_state,
		int(attack_card.card_state.instance_id),
		amount
	)

func _add_preview_growth_delta(preview_state: Dictionary, instance_id: int, amount: int) -> void:
	if instance_id <= 0:
		return
	if amount == 0:
		return

	var growth_map: Dictionary = preview_state.get("growth_by_instance_id", {}) as Dictionary
	growth_map[instance_id] = int(growth_map.get(instance_id, 0)) + amount
	preview_state["growth_by_instance_id"] = growth_map

func _add_preview_blessing_delta(preview_state: Dictionary, instance_id: int, amount: int) -> void:
	if instance_id <= 0:
		return
	if amount == 0:
		return

	var blessing_map: Dictionary = preview_state.get("blessing_by_instance_id", {}) as Dictionary
	blessing_map[instance_id] = int(blessing_map.get(instance_id, 0)) + amount
	preview_state["blessing_by_instance_id"] = blessing_map

func _get_preview_growth_delta(preview_state: Dictionary, instance_id: int) -> int:
	var growth_map: Dictionary = preview_state.get("growth_by_instance_id", {}) as Dictionary
	return int(growth_map.get(instance_id, 0))

func _get_preview_blessing_delta(preview_state: Dictionary, instance_id: int) -> int:
	var blessing_map: Dictionary = preview_state.get("blessing_by_instance_id", {}) as Dictionary
	return int(blessing_map.get(instance_id, 0))

func _get_preview_card_final_level(card: TestCard, preview_state: Dictionary) -> int:
	if card == null:
		return default_card_level
	if not is_instance_valid(card):
		return default_card_level
	if card.card_state == null:
		return default_card_level

	var instance_id: int = int(card.card_state.instance_id)
	var base_final_level: int = get_card_final_level_by_state(card.card_state as CardState)
	var preview_growth_delta: int = _get_preview_growth_delta(preview_state, instance_id)
	var preview_blessing_delta: int = _get_preview_blessing_delta(preview_state, instance_id)

	return max(0, base_final_level + preview_growth_delta + preview_blessing_delta)

func _calculate_preview_final_power_from_card_and_combo_type(
	card: TestCard,
	combo_type: String,
	preview_state: Dictionary
) -> int:
	if card == null:
		return 0

	var preview_final_level: int = _get_preview_card_final_level(card, preview_state)
	var combo_multiplier: int = _get_combo_multiplier(combo_type)
	return max(0, preview_final_level * max(0, combo_multiplier))

func _get_preview_effect_target_cards(
	effect_data: Dictionary,
	combo_data: Dictionary,
	attack_entry: Dictionary
) -> Array:
	var target_scope: String = String(effect_data.get("target_scope", "all_combo_cards"))

	match target_scope:
		"all_combo_cards":
			return _get_preview_all_combo_cards(combo_data)

		"members_only":
			return _get_preview_member_cards_only(combo_data, attack_entry)

		"leader_only":
			return _get_preview_leader_card_only(attack_entry)

		_:
			return _get_preview_all_combo_cards(combo_data)

func _get_preview_all_combo_cards(combo_data: Dictionary) -> Array:
	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return []

	var result: Array = []

	for combo_card_variant in cards_value:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue

		result.append(combo_card)

	return result

func _get_preview_member_cards_only(combo_data: Dictionary, attack_entry: Dictionary) -> Array:
	var all_cards: Array = _get_preview_all_combo_cards(combo_data)
	var result: Array = []

	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	var excluded_instance_id: int = -1

	if attack_card != null and attack_card.card_state != null:
		excluded_instance_id = int(attack_card.card_state.instance_id)

	for combo_card_variant in all_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue
		if int(combo_card.card_state.instance_id) == excluded_instance_id:
			continue

		result.append(combo_card)

	return result

func _get_preview_leader_card_only(attack_entry: Dictionary) -> Array:
	var result: Array = []

	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return result
	if not is_instance_valid(attack_card):
		return result
	if attack_card.card_state == null:
		return result

	result.append(attack_card)
	return result

func _refresh_final_objective_combo_drag_preview_from_active_leader() -> void:
	var leader_card: TestCard = _get_active_combo_drag_leader_card()
	if leader_card == null:
		_clear_final_objective_combo_drag_hp_preview()
		_set_final_objective_combo_drag_preview_highlight(false)
		return

	if not final_objective_combo_drag_highlighted and combo_drag_preview_card_target_slot_by_id.is_empty():
		_clear_final_objective_combo_drag_hp_preview()
		_set_final_objective_combo_drag_preview_highlight(false)
		return

	var combo_data: Dictionary = get_combo_data_for_card(leader_card)
	if combo_data.is_empty():
		_clear_final_objective_combo_drag_hp_preview()
		_set_final_objective_combo_drag_preview_highlight(false)
		return

	var preview_result: Dictionary = _build_final_objective_combo_drag_hp_preview_result(combo_data, leader_card)
	var should_preview: bool = bool(preview_result.get("should_preview", false))
	var after_hp: int = int(preview_result.get("after_hp", -1))

	if not should_preview or after_hp < 0:
		_clear_final_objective_combo_drag_hp_preview()
		_set_final_objective_combo_drag_preview_highlight(false)
		return

	_apply_final_objective_combo_drag_hp_preview(after_hp)
	_set_final_objective_combo_drag_preview_highlight(true)

func _will_combo_drag_preview_hit_final_objective(combo_data: Dictionary, leader_card: TestCard) -> bool:
	var preview_result: Dictionary = _build_final_objective_combo_drag_hp_preview_result(combo_data, leader_card)
	return bool(preview_result.get("should_preview", false))


func _apply_final_objective_combo_drag_hp_preview(after_hp: int) -> void:
	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("show_hp_preview"):
		return
	if not final_objective.has_method("get_hp"):
		return

	var current_hp: int = int(final_objective.call("get_hp"))
	var clamped_after_hp: int = max(0, min(after_hp, current_hp))
	combo_drag_preview_final_objective_after_hp = clamped_after_hp
	final_objective.call("show_hp_preview", current_hp, clamped_after_hp)


func _clear_final_objective_combo_drag_hp_preview() -> void:
	combo_drag_preview_final_objective_after_hp = -1

	if final_objective == null:
		return
	if not is_instance_valid(final_objective):
		return
	if not final_objective.has_method("clear_hp_preview"):
		return

	final_objective.call("clear_hp_preview")


func _build_final_objective_combo_drag_hp_preview_result(combo_data: Dictionary, leader_card: TestCard) -> Dictionary:
	var result: Dictionary = {
		"should_preview": false,
		"after_hp": -1
	}

	if combo_data.is_empty():
		return result

	if leader_card == null:
		return result

	if not _can_hit_final_objective():
		return result

	var attack_plan: Dictionary = _build_combo_attack_plan(combo_data, leader_card)
	var leader_target_type: String = String(attack_plan.get("leader_target_type", "monster"))
	var is_final_objective_target: bool = leader_target_type == "final_objective"
	var combo_type: String = String(combo_data.get("combo_type", ""))

	var attack_entries_value = attack_plan.get("entries", [])
	if typeof(attack_entries_value) != TYPE_ARRAY:
		attack_entries_value = []
	var attack_entries: Array = attack_entries_value as Array

	var leader_target_slot_no: int = int(attack_plan.get("leader_target_slot_no", 0))

	var overlap_priority_value = attack_plan.get("overlap_priority_slot_nos", [])
	if typeof(overlap_priority_value) != TYPE_ARRAY:
		overlap_priority_value = []
	var overlap_priority_slot_nos: Array = overlap_priority_value as Array

	var simulated_hp_by_slot_no: Dictionary = {}
	for slot_no in range(1, 8):
		simulated_hp_by_slot_no[slot_no] = _get_monster_current_hp(slot_no)

	var simulated_final_objective_hp: int = int(final_objective.call("get_hp"))
	var before_attack_preview_state: Dictionary = _make_before_attack_combo_preview_state(combo_data)

	for attack_entry_variant in attack_entries:
		if typeof(attack_entry_variant) != TYPE_DICTIONARY:
			continue

		var attack_entry: Dictionary = attack_entry_variant as Dictionary
		var attack_card: TestCard = attack_entry.get("card", null) as TestCard
		if attack_card == null:
			continue
		if not is_instance_valid(attack_card):
			continue
		if attack_card.card_state == null:
			continue

		_apply_before_attack_effects_to_combo_preview(combo_data, attack_entry, before_attack_preview_state)

		var target_slot_no: int = 0
		var is_fixed_overlap: bool = bool(attack_entry.get("is_fixed_overlap", false))

		if is_fixed_overlap:
			target_slot_no = int(attack_entry.get("target_slot_no", 0))
		else:
			target_slot_no = _resolve_non_overlapped_combo_target_slot_no_from_simulated_hp(
				leader_target_slot_no,
				overlap_priority_slot_nos,
				simulated_hp_by_slot_no
			)

		var hit_damage: int = _calculate_preview_final_power_from_card_and_combo_type(
			attack_card,
			combo_type,
			before_attack_preview_state
		)

		if is_final_objective_target:
			simulated_final_objective_hp = max(0, simulated_final_objective_hp - hit_damage)
			result["should_preview"] = true
			continue

		if target_slot_no > 0 and int(simulated_hp_by_slot_no.get(target_slot_no, 0)) > 0:
			var current_hp: int = int(simulated_hp_by_slot_no.get(target_slot_no, 0))
			simulated_hp_by_slot_no[target_slot_no] = max(0, current_hp - hit_damage)
			continue

		if not _has_alive_combo_target_slots_from_simulated_hp(overlap_priority_slot_nos, simulated_hp_by_slot_no):
			simulated_final_objective_hp = max(0, simulated_final_objective_hp - hit_damage)
			result["should_preview"] = true

	result["after_hp"] = simulated_final_objective_hp
	return result


func _has_alive_combo_target_slots_from_simulated_hp(
	target_slot_nos: Array,
	simulated_hp_by_slot_no: Dictionary
) -> bool:
	for slot_no_variant in target_slot_nos:
		var slot_no: int = int(slot_no_variant)

		if slot_no <= 0:
			continue

		if int(simulated_hp_by_slot_no.get(slot_no, 0)) > 0:
			return true

	return false

func _get_best_alive_monster_slot_for_rect(card_rect: Rect2) -> FieldSlot:
	var best_slot: FieldSlot = null
	var best_overlap_area: float = 0.0

	for slot_variant in _get_all_monster_slots():
		var monster_slot: FieldSlot = slot_variant as FieldSlot
		if monster_slot == null:
			continue

		if _get_monster_current_hp(monster_slot.slot_no) <= 0:
			continue

		var monster_rect: Rect2 = monster_slot.get_global_rect()
		if not monster_rect.intersects(card_rect):
			continue

		var overlap_rect: Rect2 = monster_rect.intersection(card_rect)
		var overlap_area: float = overlap_rect.size.x * overlap_rect.size.y

		if overlap_area > best_overlap_area:
			best_overlap_area = overlap_area
			best_slot = monster_slot
		elif overlap_area > 0.0 and is_equal_approx(overlap_area, best_overlap_area):
			if best_slot == null or monster_slot.slot_no < best_slot.slot_no:
				best_slot = monster_slot

	return best_slot

func _set_combo_drag_monster_highlight(slot_no: int, is_on: bool) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	unit.set_highlight(is_on)

func _damage_monster(slot_no: int, damage: int) -> void:
	if not monster_hp_by_slot_no.has(slot_no):
		return

	var current_hp: int = int(monster_hp_by_slot_no.get(slot_no, 0))
	var next_hp: int = max(0, current_hp - damage)
	monster_hp_by_slot_no[slot_no] = next_hp

	print("몬스터 피격 / 슬롯:", slot_no, "/ 피해:", damage, "/ 남은 HP:", next_hp)

	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit != null and unit.has_method("play_hp_preview_confirm_animation"):
		await unit.play_hp_preview_confirm_animation(next_hp)

	if next_hp <= 0:
		await _flip_monster_to_back(slot_no)
	else:
		_update_monster_visual(slot_no)

func _get_monster_unit(slot_no: int) -> MonsterUnit:
	if not monster_root_by_slot_no.has(slot_no):
		return null

	return monster_root_by_slot_no.get(slot_no, null) as MonsterUnit

func _flip_monster_to_back(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	monster_is_flipping_by_slot_no[slot_no] = true
	await unit.flip_to_back()
	monster_is_face_down_by_slot_no[slot_no] = true
	monster_is_flipping_by_slot_no[slot_no] = false
	_update_monster_visual(slot_no)

func _flip_monster_to_front(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return
	if not bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
		return

	monster_is_flipping_by_slot_no[slot_no] = true
	monster_hp_by_slot_no[slot_no] = monster_start_hp
	await unit.flip_to_front(monster_start_hp)
	monster_is_face_down_by_slot_no[slot_no] = false
	monster_is_flipping_by_slot_no[slot_no] = false
	_update_monster_visual(slot_no)

func _flip_face_down_monsters_to_front_left_to_right() -> void:
	for slot_no in range(1, 8):
		if not monster_is_face_down_by_slot_no.has(slot_no):
			continue
		if not bool(monster_is_face_down_by_slot_no.get(slot_no, false)):
			continue

		await _flip_monster_to_front(slot_no)
		await get_tree().create_timer(0.06).timeout

func _play_monster_contact_hit_effect(slot_no: int) -> void:
	var unit: MonsterUnit = _get_monster_unit(slot_no)
	if unit == null:
		return

	await unit.play_contact_hit_effect()

func _get_alive_monster_slot_at_global_position(mouse_global_position: Vector2) -> FieldSlot:
	var monster_slots: Array = _get_all_monster_slots()

	for slot_variant in monster_slots:
		var monster_slot: FieldSlot = slot_variant as FieldSlot
		if monster_slot == null:
			continue

		if not monster_slot.get_global_rect().has_point(mouse_global_position):
			continue

		if not monster_hp_by_slot_no.has(monster_slot.slot_no):
			return null

		var hp: int = int(monster_hp_by_slot_no.get(monster_slot.slot_no, 0))
		if hp <= 0:
			return null

		return monster_slot

	return null

func _get_all_player_slots() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		result.append(_get_player_slot(slot_no))

	return result

func _get_player_slot(slot_no: int) -> FieldSlot:
	var slot_path: String = "Layer1_PlayerField/P_SlotStation/PlayerSlot%d" % slot_no

	if not has_node(slot_path):
		return null

	return get_node(slot_path) as FieldSlot

func _get_all_monster_slots() -> Array:
	var result: Array = []

	for slot_no in range(1, 8):
		result.append(_get_monster_slot(slot_no))

	return result

func _get_monster_slot(slot_no: int) -> FieldSlot:
	var slot_path: String = "Layer2_MonsterField/M_SlotStation/MonsterSlot%d" % slot_no

	if not has_node(slot_path):
		return null

	return get_node(slot_path) as FieldSlot

func _clear_combo_overlays() -> void:
	for overlay_variant in combo_overlay_nodes:
		if is_instance_valid(overlay_variant):
			overlay_variant.queue_free()

	combo_overlay_nodes.clear()

func _create_combo_overlay(slot_a: FieldSlot, slot_b: FieldSlot, slot_c: FieldSlot, combo_type: String) -> void:
	if slot_a == null or slot_b == null or slot_c == null:
		return

	var rect_a: Rect2 = slot_a.get_global_rect()
	var rect_b: Rect2 = slot_b.get_global_rect()
	var rect_c: Rect2 = slot_c.get_global_rect()

	var left_x_global: float = min(rect_a.position.x, min(rect_b.position.x, rect_c.position.x))
	var right_x_global: float = max(rect_a.position.x + rect_a.size.x, max(rect_b.position.x + rect_b.size.x, rect_c.position.x + rect_c.size.x))
	var top_y_global: float = min(rect_a.position.y, min(rect_b.position.y, rect_c.position.y))
	var bottom_y_global: float = max(rect_a.position.y + rect_a.size.y, max(rect_b.position.y + rect_b.size.y, rect_c.position.y + rect_c.size.y))

	var field_origin_global: Vector2 = player_field_layer.get_global_rect().position

	var local_left_x: float = left_x_global - field_origin_global.x
	var local_top_y: float = top_y_global - field_origin_global.y
	var local_width: float = right_x_global - left_x_global
	var local_height: float = bottom_y_global - top_y_global

	var overlay: Panel = Panel.new()
	overlay.name = "ComboOverlay_%s" % combo_type
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.position = Vector2(local_left_x, local_top_y)
	overlay.size = Vector2(local_width, local_height)
	overlay.z_index = 100

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	overlay.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, -22)
	label.size = Vector2(overlay.size.x, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))

	if combo_type == "strike":
		label.text = "STRIKE"
	else:
		label.text = "HARMONY"

	overlay.add_child(label)
	player_field_layer.add_child(overlay)
	combo_overlay_nodes.append(overlay)

func _create_pile_popup() -> void:
	pile_popup_layer = CanvasLayer.new()
	pile_popup_layer.layer = 50
	add_child(pile_popup_layer)

	pile_popup_overlay = ColorRect.new()
	pile_popup_overlay.color = Color(0, 0, 0, 0.45)
	pile_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pile_popup_overlay.visible = false
	pile_popup_layer.add_child(pile_popup_overlay)

	pile_popup_panel = Panel.new()
	pile_popup_panel.size = Vector2(860, 420)
	pile_popup_overlay.add_child(pile_popup_panel)

	pile_popup_title_label = Label.new()
	pile_popup_title_label.position = Vector2(24, 18)
	pile_popup_title_label.size = Vector2(300, 28)
	pile_popup_title_label.add_theme_font_size_override("font_size", 22)
	pile_popup_panel.add_child(pile_popup_title_label)

	pile_popup_count_label = Label.new()
	pile_popup_count_label.position = Vector2(24, 52)
	pile_popup_count_label.size = Vector2(300, 24)
	pile_popup_count_label.add_theme_font_size_override("font_size", 16)
	pile_popup_panel.add_child(pile_popup_count_label)

	var close_button: Button = Button.new()
	close_button.text = "닫기"
	close_button.position = Vector2(760, 16)
	close_button.size = Vector2(72, 32)
	close_button.pressed.connect(_hide_pile_popup)
	pile_popup_panel.add_child(close_button)

	pile_popup_scroll = ScrollContainer.new()
	pile_popup_scroll.position = Vector2(24, 92)
	pile_popup_scroll.size = Vector2(812, 300)
	pile_popup_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	pile_popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pile_popup_panel.add_child(pile_popup_scroll)

	pile_popup_cards_grid = GridContainer.new()
	pile_popup_cards_grid.columns = 5
	pile_popup_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_popup_cards_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile_popup_scroll.add_child(pile_popup_cards_grid)

func _show_pile_popup(pile_type: String) -> void:
	if pile_popup_overlay == null:
		return

	current_popup_pile_type = pile_type
	pile_popup_overlay.size = get_viewport_rect().size
	pile_popup_panel.position = (pile_popup_overlay.size - pile_popup_panel.size) * 0.5
	_refresh_pile_popup()

	if pile_popup_scroll != null:
		pile_popup_scroll.scroll_vertical = 0

	pile_popup_overlay.visible = true

func _hide_pile_popup() -> void:
	if pile_popup_overlay == null:
		return

	pile_popup_overlay.visible = false
	current_popup_pile_type = ""

func _refresh_pile_popup() -> void:
	if pile_popup_title_label == null or pile_popup_count_label == null or pile_popup_cards_grid == null:
		return

	var target_cards: Array = _get_popup_target_cards()

	if current_popup_pile_type == "deck":
		pile_popup_title_label.text = "남은 덱 카드"
		pile_popup_count_label.text = "남은 카드 수: %d" % target_cards.size()
	elif current_popup_pile_type == "grave":
		pile_popup_title_label.text = "무덤 카드"
		pile_popup_count_label.text = "쌓인 카드 수: %d" % target_cards.size()
	else:
		pile_popup_title_label.text = "카드 목록"
		pile_popup_count_label.text = "카드 수: %d" % target_cards.size()

	for child in pile_popup_cards_grid.get_children():
		child.queue_free()

	if target_cards.is_empty():
		var empty_label: Label = Label.new()

		if current_popup_pile_type == "deck":
			empty_label.text = "덱이 비어 있습니다."
		elif current_popup_pile_type == "grave":
			empty_label.text = "무덤이 비어 있습니다."
		else:
			empty_label.text = "카드가 없습니다."

		empty_label.custom_minimum_size = Vector2(300, 40)
		empty_label.add_theme_font_size_override("font_size", 20)
		pile_popup_cards_grid.add_child(empty_label)
		return

	for card_state in target_cards:
		var card_view: Control = _create_popup_card(card_state)
		pile_popup_cards_grid.add_child(card_view)

func _get_popup_target_cards() -> Array:
	var source_cards: Array = []

	if current_popup_pile_type == "deck":
		source_cards = deck_cards
	elif current_popup_pile_type == "grave":
		source_cards = grave_cards
	else:
		return []

	var popup_cards: Array = source_cards.duplicate()
	popup_cards.sort_custom(Callable(self, "_sort_popup_card_states_for_popup"))
	return popup_cards

func _sort_popup_card_states_for_popup(a, b) -> bool:
	if a == null and b == null:
		return false
	if a == null:
		return false
	if b == null:
		return true

	var a_combo_id: int = int(a.combo_id)
	var b_combo_id: int = int(b.combo_id)

	if a_combo_id != b_combo_id:
		return a_combo_id < b_combo_id

	var a_data_id: int = int(a.data_id)
	var b_data_id: int = int(b.data_id)

	return a_data_id < b_data_id

func _refresh_open_pile_popup() -> void:
	if current_popup_pile_type == "":
		return

	if pile_popup_overlay == null:
		return

	if not pile_popup_overlay.visible:
		return

	_refresh_pile_popup()

func _create_popup_card(card_state) -> Control:
	var popup_card: TestCard = TEST_CARD_SCENE.instantiate() as TestCard
	if popup_card == null:
		var fallback_root: Control = Control.new()
		fallback_root.custom_minimum_size = Vector2(150, 221)
		return fallback_root

	popup_card.custom_minimum_size = Vector2(150, 221)
	popup_card.size = Vector2(150, 221)
	popup_card.scale = Vector2.ONE
	popup_card.position = Vector2.ZERO
	popup_card.current_slot = null
	popup_card.original_slot = null
	popup_card.source_pile_type = ""
	popup_card.is_dragging = false
	popup_card.is_combo_dragging = false
	popup_card.is_field_press_pending = false

	popup_card.setup_from_card_state(card_state)
	popup_card.clear_final_power_display()

	_set_popup_card_mouse_filter_recursive(popup_card, Control.MOUSE_FILTER_IGNORE)

	return popup_card

func _set_popup_card_mouse_filter_recursive(target_node: Node, target_filter: int) -> void:
	if target_node == null:
		return

	if target_node is Control:
		var target_control: Control = target_node as Control
		target_control.mouse_filter = target_filter

	for child in target_node.get_children():
		_set_popup_card_mouse_filter_recursive(child, target_filter)

func _get_card_display_name(card_state) -> String:
	if card_state == null:
		return ""

	if "card_name" in card_state and String(card_state.card_name) != "":
		return String(card_state.card_name)

	var color_name: String = ""

	match int(card_state.combo_id):
		1001:
			color_name = "빨강"
		1002:
			color_name = "파랑"
		1003:
			color_name = "초록"
		1004:
			color_name = "노랑"
		_:
			color_name = "기타"

	var number: int = ((int(card_state.data_id) - 101) % 3) + 1
	return "%s_%02d" % [color_name, number]

func _get_card_number_text(card_state) -> String:
	if card_state == null:
		return ""

	var display_name: String = _get_card_display_name(card_state)
	var parts: PackedStringArray = display_name.split("_")

	if parts.size() < 2:
		return ""

	return parts[1]

func _get_popup_card_level_color(card_state) -> Color:
	if card_state == null:
		return Color(0, 0, 0, 1)

	var current_level: int = int(card_state.get_current_level())
	var base_level: int = int(card_state.base_level)

	if current_level > base_level:
		return Color(1.0, 0.85, 0.1, 1.0)

	if current_level < base_level:
		return Color(1.0, 0.25, 0.25, 1.0)

	return Color(0, 0, 0, 1)

func _get_popup_card_color_by_combo_id(combo_id: int) -> Color:
	match combo_id:
		1001:
			return Color(0.90, 0.30, 0.30, 1.0)
		1002:
			return Color(0.30, 0.55, 0.90, 1.0)
		1003:
			return Color(0.30, 0.80, 0.40, 1.0)
		1004:
			return Color(0.95, 0.85, 0.35, 1.0)
		_:
			return Color(0.70, 0.70, 0.70, 1.0)
