extends AuxEffect
class_name AuxEffectAddBonusDie

@export var pip: int = 1

func apply(round, def, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round == null:
		return
	var p: int = int(pip) + int(mod.get("pip_delta", 0))
	if round.dice != null and round.dice.has_method("add_bonus_die"):
		round.dice.call("add_bonus_die", p)
		if round.has_method("_update_dice_ui"):
			round.call("_update_dice_ui")
	if round.has_method("show_notice"):
		round.call("show_notice", "Added bonus die: %d" % p)
