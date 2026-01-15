extends CardEffect
class_name EffectQuickStrike

@export var base_attack_bonus: int = 2
@export var bonus_ap: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.run_state == null:
		return

	if base_attack_bonus > 0:
		if round.has_method("add_round_base_attack_bonus"):
			round.call("add_round_base_attack_bonus", base_attack_bonus)
		else:
			round.run_state.base_attack_power = maxi(0, int(round.run_state.base_attack_power) + int(base_attack_bonus))

	if bonus_ap > 0:
		round.ap_left = int(round.ap_left) + int(bonus_ap)

	round.emit_signal("card_consumed", card.uid)
