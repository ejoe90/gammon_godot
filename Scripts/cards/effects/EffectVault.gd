extends CardEffect
class_name EffectVault

@export var gold_amount: int = 50

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or round.run_state == null:
		return

	var amount := maxi(0, int(gold_amount))
	if round.run_state.has_method("add_gold"):
		round.run_state.add_gold(amount, true)
	else:
		round.run_state.gold += amount

	if card != null:
		round.emit_signal("card_consumed", card.uid)
