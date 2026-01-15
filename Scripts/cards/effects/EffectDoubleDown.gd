extends CardEffect
class_name EffectDoubleDown

@export var attack_mult: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.run_state == null:
		return

	round.run_state.player_attack_mult = maxi(1, int(attack_mult))
	round.show_notice("DOUBLE DOWN! Attack x%d for this round." % int(round.run_state.player_attack_mult))

	# consume
	round.emit_signal("card_consumed", card.uid)
