extends CardEffect
class_name EffectOverwatch

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return
	if round.has_method("activate_overwatch"):
		round.call("activate_overwatch", card)
