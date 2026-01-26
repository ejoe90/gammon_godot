extends CardEffect
class_name EffectProfiteering

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	if round.has_method("activate_profiteering"):
		round.call("activate_profiteering", card)
	else:
		round.emit_signal("card_consumed", card.uid)
