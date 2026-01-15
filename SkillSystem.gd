extends Node
class_name SkillSystem

static func apply_node_picks(rs: RunState, chosen_node_ids: Array) -> void:
	if rs == null:
		return
	if rs.skill_state == null:
		rs.skill_state = RunSkillState.new()

	for raw in chosen_node_ids:
		var node_id := String(raw)
		var aux_id := SkillTreeDefs.get_aux_id(node_id)
		if aux_id == "":
			continue
		if not SkillTreeDefs.is_pick_allowed(rs.skill_state, node_id):
			push_warning("[SkillSystem] Pick not allowed: %s" % node_id)
			continue


		var new_level := rs.skill_state.inc_node_level(node_id, 1)




		# Apply level rules
		var rules := SkillTreeDefs.get_level_rules(node_id, new_level)

		# Unlock copies at level 1 (or any level that gives copies)
		var unlock_copies := int(rules.get("unlock_copies", 0))
		if unlock_copies != 0:
			rs.skill_state.add_aux_copies(aux_id, unlock_copies)

		# Accumulate mods onto aux_mods[aux_id]
		var mod := rs.skill_state.get_aux_mod(aux_id)
		mod["ap_cost_delta"] = int(mod.get("ap_cost_delta", 0)) + int(rules.get("ap_cost_delta", 0))
		mod["cooldown_delta"] = int(mod.get("cooldown_delta", 0)) + int(rules.get("cooldown_delta", 0))

		# Potency examples (for effect_params adjustments)
		mod["amount_delta"] = int(mod.get("amount_delta", 0)) + int(rules.get("amount_delta", 0))
		mod["pip_delta"] = int(mod.get("pip_delta", 0)) + int(rules.get("pip_delta", 0))
		# Pip Boost-specific choice modifier (Tier 1+).
		var choice_max := int(rules.get("pip_choice_max", 0))
		if choice_max > 0:
			# Keep the highest unlocked choice ceiling.
			mod["pip_choice_max"] = maxi(int(mod.get("pip_choice_max", 1)), choice_max)

		
		# Pip Boost-specific extra dice rolled on use.
		mod["pip_extra_dice"] = int(mod.get("pip_extra_dice", 0)) + int(rules.get("pip_extra_dice", 0))

		# Pip Boost-specific HP conversion toggle unlock.
		if bool(rules.get("pip_hp_convert_enabled", false)):
			mod["pip_hp_convert_enabled"] = true

		# Pip Boost-specific: grant AP on use (Tier 4A).
		mod["pip_gain_ap_on_use"] = int(mod.get("pip_gain_ap_on_use", 0)) + int(rules.get("pip_gain_ap_on_use", 0))

		# Pip Boost-specific: duplicate dice on use (Tier 4B).
		if bool(rules.get("pip_dice_dup_enabled", false)):
			mod["pip_dice_dup_enabled"] = true

		# Attack-specific run stats
		rs.base_attack_power = int(rs.base_attack_power) + int(rules.get("base_attack_delta", 0))
		rs.enemy_drain_per_turn = maxi(0, int(rs.enemy_drain_per_turn) + int(rules.get("enemy_drain_delta", 0)))

		# Attack-specific aux modifiers (used by Attack Boost effect)
		mod["attack_mult_gain_per_use"] = int(mod.get("attack_mult_gain_per_use", 0)) + int(rules.get("attack_mult_gain_per_use", 0))
		if bool(rules.get("attack_convert_enabled", false)):
			mod["attack_convert_enabled"] = true
		if bool(rules.get("attack_mult_enabled", false)):
			mod["attack_mult_enabled"] = true

		# Gold-specific extensible modifiers (ignored by other aux effects).
		mod["gold_scaling_per_use"] = int(mod.get("gold_scaling_per_use", 0)) + int(rules.get("gold_scaling_per_use", 0))
		mod["gold_mult_gain_per_use"] = int(mod.get("gold_mult_gain_per_use", 0)) + int(rules.get("gold_mult_gain_per_use", 0))
		if bool(rules.get("convert_enabled", false)):
			mod["convert_enabled"] = true
		if bool(rules.get("gold_mult_enabled", false)):
			mod["gold_mult_enabled"] = true

		rs.skill_state.set_aux_mod(aux_id, mod)
