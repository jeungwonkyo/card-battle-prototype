extends RefCounted
class_name CardEffectSystem

var battle_scene: Node = null
var card_definition: CardDefinition = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(new_battle_scene: Node, new_card_definition: CardDefinition) -> void:
	battle_scene = new_battle_scene
	card_definition = new_card_definition
	rng.randomize()

func run_combo_card_effects(timing: String, combo_data: Dictionary, attack_entry: Dictionary) -> void:
	if battle_scene == null:
		return
	if card_definition == null:
		return
	if typeof(attack_entry) != TYPE_DICTIONARY:
		return

	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	var data_id: int = int(attack_card.card_state.data_id)
	var effects: Array = card_definition.get_effects_by_data_id(data_id)

	for effect_variant in effects:
		if typeof(effect_variant) != TYPE_DICTIONARY:
			continue

		var effect_data: Dictionary = effect_variant as Dictionary
		if String(effect_data.get("timing", "")) != timing:
			continue
		if not _is_trigger_matched(effect_data, combo_data, attack_entry):
			continue

		_execute_effect(effect_data, combo_data, attack_entry)

func _is_trigger_matched(effect_data: Dictionary, combo_data: Dictionary, attack_entry: Dictionary) -> bool:
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

func _execute_effect(effect_data: Dictionary, combo_data: Dictionary, attack_entry: Dictionary) -> void:
	var effect_type: String = String(effect_data.get("effect_type", ""))

	match effect_type:
		CardDefinition.EFFECT_GRANT_COMBO_BLESSING_BY_SELF_LEVEL:
			_execute_grant_combo_blessing_by_self_level(effect_data, combo_data, attack_entry)

		CardDefinition.EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH:
			_execute_grant_random_remaining_field_card_growth(effect_data, combo_data, attack_entry)

		CardDefinition.EFFECT_GRANT_ALL_SUIT_CARDS_GROWTH:
			_execute_grant_all_suit_cards_growth(effect_data)

		CardDefinition.EFFECT_GRANT_SELF_GROWTH:
			_execute_grant_self_growth(effect_data, attack_entry)

		CardDefinition.EFFECT_GAIN_SHIELD_BY_SELF_FINAL_POWER:
			_execute_gain_shield_by_self_final_power(combo_data, attack_entry)

		CardDefinition.EFFECT_GAIN_SHIELD_BY_SELF_LEVEL:
			_execute_gain_shield_by_self_level(attack_entry)

		CardDefinition.EFFECT_RESERVE_MEMBER_CLONES_BY_SELF_LEVEL:
			_execute_reserve_member_clones_by_self_level(combo_data, attack_entry)

		CardDefinition.EFFECT_RESERVE_SELF_CLONE_BY_SELF_LEVEL:
			_execute_reserve_self_clone_by_self_level(attack_entry)

		CardDefinition.EFFECT_HEAL_PLAYER_HP_BY_SELF_LEVEL_X2:
			_execute_heal_player_hp_by_self_level_x2(attack_entry)

		_:
			return

func _execute_grant_combo_blessing_by_self_level(effect_data: Dictionary, combo_data: Dictionary, attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if attack_card.card_state == null:
		return

	if not battle_scene.has_method("get_card_final_level_by_state"):
		return
	if not battle_scene.has_method("apply_card_blessing_from_effect"):
		return

	var blessing_amount: int = int(
		battle_scene.call("get_card_final_level_by_state", attack_card.card_state)
	)

	if blessing_amount <= 0:
		return

	var target_cards: Array = _get_effect_targets(effect_data, combo_data, attack_entry)
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

		battle_scene.call(
			"apply_card_blessing_from_effect",
			int(combo_card.card_state.instance_id),
			blessing_amount
		)

func _execute_grant_self_growth(effect_data: Dictionary, attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return
	if not battle_scene.has_method("apply_card_growth_from_effect"):
		return

	var amount: int = int(effect_data.get("amount", 0))
	if amount <= 0:
		return

	battle_scene.call(
		"apply_card_growth_from_effect",
		int(attack_card.card_state.instance_id),
		amount
	)

func _execute_grant_random_remaining_field_card_growth(effect_data: Dictionary, combo_data: Dictionary, attack_entry: Dictionary) -> void:
	if not battle_scene.has_method("get_remaining_player_field_cards_excluding_combo_cards"):
		return
	if not battle_scene.has_method("apply_card_growth_from_effect"):
		return

	var amount: int = int(effect_data.get("amount", 0))
	if amount <= 0:
		return

	var combo_cards_value = combo_data.get("cards", [])
	if typeof(combo_cards_value) != TYPE_ARRAY:
		return

	var combo_cards: Array = combo_cards_value as Array
	var targets_value = battle_scene.call("get_remaining_player_field_cards_excluding_combo_cards", combo_cards)
	if typeof(targets_value) != TYPE_ARRAY:
		return

	var target_cards: Array = targets_value as Array
	if target_cards.is_empty():
		return

	var random_index: int = rng.randi_range(0, target_cards.size() - 1)
	var target_card: TestCard = target_cards[random_index] as TestCard

	if target_card == null:
		return
	if not is_instance_valid(target_card):
		return
	if target_card.card_state == null:
		return

	battle_scene.call(
		"apply_card_growth_from_effect",
		int(target_card.card_state.instance_id),
		amount
	)

func _execute_grant_all_suit_cards_growth(effect_data: Dictionary) -> void:
	if not battle_scene.has_method("apply_growth_to_all_cards_by_suit_from_effect"):
		return

	var target_suit: String = String(effect_data.get("target_suit", "")).strip_edges().to_lower()
	var amount: int = int(effect_data.get("amount", 0))

	if target_suit == "":
		return
	if amount <= 0:
		return

	battle_scene.call("apply_growth_to_all_cards_by_suit_from_effect", target_suit, amount)
func _execute_gain_shield_by_self_final_power(combo_data: Dictionary, attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	if not battle_scene.has_method("_calculate_final_power_from_card_and_combo_type"):
		return
	if not battle_scene.has_method("add_player_shield"):
		return

	var combo_type: String = String(combo_data.get("combo_type", ""))
	var shield_amount: int = int(
		battle_scene.call("_calculate_final_power_from_card_and_combo_type", attack_card, combo_type)
	)

	if shield_amount <= 0:
		return

	battle_scene.call("add_player_shield", shield_amount)

func _execute_gain_shield_by_self_level(attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	if not battle_scene.has_method("get_card_final_level_by_state"):
		return
	if not battle_scene.has_method("add_player_shield"):
		return

	var shield_amount: int = int(
		battle_scene.call("get_card_final_level_by_state", attack_card.card_state)
	)

	if shield_amount <= 0:
		return

	battle_scene.call("add_player_shield", shield_amount)

func _execute_heal_player_hp_by_self_level_x2(attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return

	if not battle_scene.has_method("get_card_final_level_by_state"):
		return
	if not battle_scene.has_method("heal_player_hp"):
		return

	var heal_amount: int = int(
		battle_scene.call("get_card_final_level_by_state", attack_card.card_state)
	) * 2

	if heal_amount <= 0:
		return

	battle_scene.call("heal_player_hp", heal_amount)

func _execute_reserve_member_clones_by_self_level(combo_data: Dictionary, attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return
	if not _can_trigger_generate_effect(attack_card.card_state):
		return

	if not battle_scene.has_method("get_card_final_level_by_state"):
		return
	if not battle_scene.has_method("reserve_clone_spawn"):
		return

	var clone_level: int = int(
		battle_scene.call("get_card_final_level_by_state", attack_card.card_state)
	)

	if clone_level <= 0:
		return

	var member_cards: Array = _get_member_cards_only(combo_data, attack_entry)
	if member_cards.is_empty():
		return

	for member_card_variant in member_cards:
		var member_card: TestCard = member_card_variant as TestCard
		if member_card == null:
			continue
		if not is_instance_valid(member_card):
			continue
		if member_card.card_state == null:
			continue

		battle_scene.call("reserve_clone_spawn", member_card, member_card, clone_level)

func _execute_reserve_self_clone_by_self_level(attack_entry: Dictionary) -> void:
	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	if attack_card == null:
		return
	if not is_instance_valid(attack_card):
		return
	if attack_card.card_state == null:
		return
	if not _can_trigger_generate_effect(attack_card.card_state):
		return

	if not battle_scene.has_method("get_card_final_level_by_state"):
		return
	if not battle_scene.has_method("reserve_clone_spawn"):
		return

	var clone_level: int = int(
		battle_scene.call("get_card_final_level_by_state", attack_card.card_state)
	)

	if clone_level <= 0:
		return

	battle_scene.call("reserve_clone_spawn", attack_card, attack_card, clone_level)

func _can_trigger_generate_effect(card_state: CardState) -> bool:
	if card_state == null:
		return false

	if not card_state.is_generated_card:
		return true

	return bool(card_state.can_trigger_generate_effect)

func _get_effect_targets(effect_data: Dictionary, combo_data: Dictionary, attack_entry: Dictionary) -> Array:
	var target_scope: String = String(effect_data.get("target_scope", "all_combo_cards"))
	match target_scope:
		"all_combo_cards":
			return _get_all_combo_cards(combo_data)

		"members_only":
			return _get_member_cards_only(combo_data, attack_entry)

		"leader_only":
			return _get_leader_card_only(attack_entry)

		_:
			return _get_all_combo_cards(combo_data)


func _get_all_combo_cards(combo_data: Dictionary) -> Array:
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


func _get_member_cards_only(combo_data: Dictionary, attack_entry: Dictionary) -> Array:
	var all_cards: Array = _get_all_combo_cards(combo_data)
	var result: Array = []

	var attack_card: TestCard = attack_entry.get("card", null) as TestCard
	var leader_instance_id: int = -1

	if attack_card != null and attack_card.card_state != null:
		leader_instance_id = int(attack_card.card_state.instance_id)

	for combo_card_variant in all_cards:
		var combo_card: TestCard = combo_card_variant as TestCard
		if combo_card == null:
			continue
		if not is_instance_valid(combo_card):
			continue
		if combo_card.card_state == null:
			continue
		if int(combo_card.card_state.instance_id) == leader_instance_id:
			continue

		result.append(combo_card)

	return result


func _get_leader_card_only(attack_entry: Dictionary) -> Array:
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
