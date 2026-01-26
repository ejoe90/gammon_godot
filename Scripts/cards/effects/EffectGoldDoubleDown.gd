extends CardEffect
class_name EffectGoldDoubleDown

@export var gold_mult: int = 2

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null:
		return
	if round.has_method("activate_gold_double_down"):
		round.call("activate_gold_double_down", gold_mult, card)
		return

	if round.run_state != null:
		round.run_state.round_gold_mult = maxi(1, int(gold_mult))
		if round.has_method("show_notice"):
			round.show_notice("DOUBLE DOWN! Gold x%d for this round." % int(round.run_state.round_gold_mult))
		round.emit_signal("card_consumed", card.uid)
