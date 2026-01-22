extends CardEffect
class_name EffectMomentum

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_momentum"):
		round.call("activate_momentum", card)
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
