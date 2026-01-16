extends CardEffect
class_name EffectBunker

@export var defense_bonus: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null:
		return
	if round.has_method("activate_bunker"):
		round.call("activate_bunker", defense_bonus, card)
