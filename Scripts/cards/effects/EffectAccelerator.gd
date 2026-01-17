extends CardEffect
class_name EffectAccelerator

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null:
		return
	if round.has_method("activate_accelerator"):
		round.call("activate_accelerator", card)
