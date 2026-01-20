extends CardEffect
class_name EffectFriction

@export var turns: int = 3

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round.has_method("activate_friction"):
		round.call("activate_friction", int(turns), card)
	else:
		round.state.friction_turns_left = maxi(0, int(turns))
		round.emit_signal("card_consumed", card.uid)
