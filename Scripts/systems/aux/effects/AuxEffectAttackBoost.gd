extends AuxEffect
class_name AuxEffectAttackBoost

@export var base_damage: int = 1
@export var gold_per_damage: int = 5

func apply(round: RoundController, def: AuxCardDef, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round == null:
		return
	var rs: RunState = round.run_state as RunState
	if rs == null:
		return

	var dmg_base: int = int(base_damage)

	# Damage is affected by Base ATK and ATK mult. (Base ATK is run-wide; mult is run-wide.)
	var atk_mult: int = maxi(1, int(rs.player_attack_mult))

	var base_atk: int = maxi(0, int(rs.base_attack_power))
	var raw_damage: int = maxi(0, dmg_base + base_atk)
	var potential_damage: int = raw_damage * atk_mult

	# Tier 4A: optional conversion to gold.
	var convert_enabled: bool = bool(mod.get("attack_convert_enabled", false))
	var convert_on: bool = convert_enabled and bool(rs.attack_convert_to_gold)

	var result_text: String = ""
	if convert_on:
		var gold_amt: int = maxi(0, int(potential_damage) * int(gold_per_damage))
		var gained: int = int(rs.add_gold(gold_amt, true))
		result_text = "Converted %d dmg into %d gold." % [potential_damage, gained]
	else:
		# Route through RoundController so all other systems stay consistent.
		var dealt: int = 0
		if round.has_method("deal_enemy_damage"):
			dealt = int(round.call("deal_enemy_damage", dmg_base, true))
		else:
			rs.enemy_hp -= potential_damage
			dealt = potential_damage
		result_text = "Dealt %d damage." % dealt

	# Tier 4B: Attack mult gain per use.
	var mult_enabled: bool = bool(mod.get("attack_mult_enabled", false))
	if mult_enabled:
		var inc: int = int(mod.get("attack_mult_gain_per_use", 1))
		if inc <= 0:
			inc = 1
		rs.player_attack_mult = maxi(1, int(rs.player_attack_mult) + inc)
		result_text += "  (ATK mult: x%d)" % int(rs.player_attack_mult)

	if convert_enabled:
		result_text += "  (F3 convert: %s)" % ("ON" if bool(rs.attack_convert_to_gold) else "OFF")

	if round.has_method("show_notice"):
		round.call("show_notice", result_text)
