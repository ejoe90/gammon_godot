extends CardEffect
class_name EffectEntanglement

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_entanglement"):
		round.call("activate_entanglement", card)
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
