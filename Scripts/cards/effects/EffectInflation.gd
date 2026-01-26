extends CardEffect
class_name EffectInflation

@export var turns: int = 3

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return

	if round.has_method("activate_inflation"):
		round.call("activate_inflation", card, int(turns))
	else:
		if card != null:
			round.emit_signal("card_consumed", card.uid)
