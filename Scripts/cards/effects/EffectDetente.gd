extends CardEffect
class_name EffectDetente

@export var turns: int = 4

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return
	if round.has_method("activate_detente"):
		round.call("activate_detente", turns, card)
