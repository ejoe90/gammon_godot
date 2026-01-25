extends CardEffect
class_name EffectJailbreak

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_jailbreak"):
		round.call("activate_jailbreak", card)
	elif card != null:
		round.emit_signal("card_consumed", card.uid)
