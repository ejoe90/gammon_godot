extends CardEffect
class_name EffectBlackMarket

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	if round.has_method("activate_black_market"):
		round.call("activate_black_market", card)
	else:
		round.emit_signal("card_consumed", card.uid)
