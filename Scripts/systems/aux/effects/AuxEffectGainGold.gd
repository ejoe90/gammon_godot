extends AuxEffect
class_name AuxEffectGainGold

@export var amount: int = 0

func apply(round: RoundController, def: AuxCardDef, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round == null:
		return
	var rs: RunState = round.run_state as RunState
	if rs == null:
		return

	# Use index (1-based) of this aux activation this round.
	var use_index: int = int(ctx.get("use_index", 1))

	# Base gold from the aux card (+ skill flat bonuses).
	var base_amt: int = int(amount) + int(mod.get("amount_delta", 0))

	# Scaling: +X per card use (tiered upgrades add to this).
	var per_use: int = int(mod.get("gold_scaling_per_use", 0))
	var scaling_amt: int = per_use * use_index

	var raw_value: int = base_amt + scaling_amt

	# Tier4-B: gold multiplier mechanic.
	# Each use can increase multiplier by N (default 1), and multiplier applies to all gold gains.
	var gold_mult_enabled: bool = bool(mod.get("gold_mult_enabled", false))
	if gold_mult_enabled:
		var inc: int = int(mod.get("gold_mult_gain_per_use", 1))
		if inc <= 0:
			inc = 1
		rs.gold_mult = maxi(1, int(rs.gold_mult) + inc)

	# Tier4-A: conversion mode (gold -> HP or pips).
	var convert_enabled: bool = bool(mod.get("convert_enabled", false))
	var result_text: String = ""
	if convert_enabled:
		match int(rs.gold_convert_mode):
			rs.GoldConvertMode.HP:
				var healed: int = int(rs.add_player_hp(raw_value))
				result_text = "Converted %d into %d HP." % [raw_value, healed]
			rs.GoldConvertMode.PIPS:
				var pip_val: int = clampi(raw_value, 1, 6)
				if round.dice != null and round.dice.has_method("add_bonus_die"):
					round.dice.call("add_bonus_die", pip_val)
					if round.has_method("_update_dice_ui"):
						round.call("_update_dice_ui")
				result_text = "Converted %d into bonus die (%d)." % [raw_value, pip_val]
			_:
				var gained: int = int(rs.add_gold(raw_value, true))
				result_text = "Gained %d gold." % gained
	else:
		var gained2: int = int(rs.add_gold(raw_value, true))
		result_text = "Gained %d gold." % gained2

	if gold_mult_enabled:
		result_text += "  (Gold Mult: x%d)" % int(rs.gold_mult)

	if round.has_method("show_notice"):
		round.call("show_notice", result_text)
