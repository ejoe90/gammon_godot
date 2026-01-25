extends CardEffect
class_name EffectTempoAccelerator

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_tempo_accelerator"):
		round.call("activate_tempo_accelerator", card)
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
