extends AuxEffect
class_name AuxEffectPipBoost

# Base pip bonus added to dice when this aux card is activated (Tier 0).
@export var pip_bonus: int = 1

# Whether this bonus should apply to bonus dice as well.
# (Later upgrades may set this false when bonus dice should remain unmodified.)
@export var include_bonus_dice: bool = false

func apply(round, def, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round == null:
		return

	# Tier 4A (Pips): grant AP on use (can exceed the turn limit).
	var ap_gain: int = maxi(0, int(mod.get("pip_gain_ap_on_use", 0)))
	if ap_gain > 0:
		round.ap_left += ap_gain
		if round.has_method("show_notice"):
			round.call("show_notice", "Pip Boost: +%d AP" % ap_gain)

	var base_bonus: int = maxi(0, int(pip_bonus))
	if base_bonus == 0:
		return

	# Tier 1+ can unlock a choice prompt (e.g. choose +1 or +2).
	var choice_max: int = maxi(1, int(mod.get("pip_choice_max", 1)))
	if choice_max > 1 and round.has_method("request_pip_boost_choice"):
		var options: Array[int] = []
		for b in range(1, choice_max + 1):
			options.append(int(b))
		round.call("request_pip_boost_choice", options, bool(include_bonus_dice), "Pip Boost")
		return

	# Default (Tier 0+): apply the bonus immediately.
	if round.dice != null and round.dice.has_method("apply_pip_bonus"):
		round.dice.call("apply_pip_bonus", base_bonus, bool(include_bonus_dice))

	# Tier 2+ can add bonus dice rolled AFTER the pip bonus is applied.
	var extra_dice: int = maxi(0, int(mod.get("pip_extra_dice", 0)))
	if extra_dice > 0 and round.dice != null and round.dice.has_method("add_bonus_die"):
		for _i in range(extra_dice):
			round.dice.call("add_bonus_die", randi_range(1, 6))

	# Tier 4B (Pips): duplicate each available die AFTER bonus dice are rolled.
	if bool(mod.get("pip_dice_dup_enabled", false)) and round.dice != null and round.dice.has_method("duplicate_all"):
		round.dice.call("duplicate_all")

	# Tier 3B1 (Pips): optional conversion of dice pips into HP, which ends the turn.
	if round.has_method("_maybe_pip_boost_convert_to_hp"):
		var did_convert: bool = bool(round.call("_maybe_pip_boost_convert_to_hp", "Pip Boost"))
		if did_convert:
			return

	if round.has_method("_update_dice_ui"):
		round.call("_update_dice_ui")

	if round.has_method("show_notice"):
		var msg := "Pip Boost: +%d to all dice" % base_bonus
		if extra_dice > 0:
			msg += " (+%d bonus die)" % extra_dice
		if bool(mod.get("pip_dice_dup_enabled", false)):
			msg += " (x2 dice)"
		round.call("show_notice", msg)

