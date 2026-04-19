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
			_execute_grant_combo_blessing_by_self_level(combo_data, attack_entry)

		CardDefinition.EFFECT_GRANT_RANDOM_REMAINING_FIELD_CARD_GROWTH:
			_execute_grant_random_remaining_field_card_growth(effect_data, combo_data, attack_entry)

		_:
			return

func _execute_grant_combo_blessing_by_self_level(combo_data: Dictionary, attack_entry: Dictionary) -> void:
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

	var cards_value = combo_data.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return

	var combo_cards: Array = cards_value as Array

	for combo_card_variant in combo_cards:
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
