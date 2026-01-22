extends CardEffect
class_name EffectRapidRetreat

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_rapid_retreat"):
		round.call("activate_rapid_retreat", card)
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
