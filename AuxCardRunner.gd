extends Node
class_name AuxCardRunner

static func activate(round: RoundController, aux_id: String, use_index: int = 1) -> void:
	if round == null:
		return
	var rs := round.run_state
	if rs == null:
		return
	var ss := rs.skill_state

	var def := AuxCardDB.get_def(aux_id)
	if def == null:
		return

	var mod: Dictionary = {}
	if ss != null:
		mod = ss.get_aux_mod(aux_id)

	# Preferred: resource-driven effects.
	if def.effect != null:
		var ctx: Dictionary = {"use_index": int(use_index)}
		def.effect.apply(round, def, mod, ctx)
		return

	# Legacy routing (kept for safety during migration).
	var params := def.effect_params.duplicate(true)
	# Optional: modify potency
	if def.effect_kind == "GAIN_GOLD":
		params["amount"] = int(params.get("amount", 0)) + int(mod.get("amount_delta", 0))
	if def.effect_kind == "ADD_BONUS_DIE":
		params["pip"] = int(params.get("pip", 0)) + int(mod.get("pip_delta", 0))

	match def.effect_kind:
		"GAIN_GOLD":
			var amt := int(params.get("amount", 0))
			if rs != null and rs.has_method("add_gold"):
				rs.call("add_gold", amt, true)
			else:
				rs.gold += amt
		"ADD_BONUS_DIE":
			var pip := int(params.get("pip", 0))
			if round.dice != null and round.dice.has_method("add_bonus_die"):
				round.dice.call("add_bonus_die", pip)
				round._update_dice_ui()
		"INC_ATK_MULT":
			rs.player_attack_mult = maxi(1, int(rs.player_attack_mult) + int(params.get("delta", 0)))
		_:
			# MVP placeholder
			round.show_notice("Aux effect not implemented: %s" % def.effect_kind)
