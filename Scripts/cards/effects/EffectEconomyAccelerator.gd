extends CardEffect
class_name EffectEconomyAccelerator

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null:
		return
	if round.has_method("activate_economy_accelerator"):
		round.call("activate_economy_accelerator", card)
