extends CardEffect
class_name EffectQuanta

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_quanta"):
		round.call("activate_quanta", card)
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
