extends CardEffect
class_name EffectWarChest

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	if round.has_method("activate_war_chest"):
		round.call("activate_war_chest", card)
	else:
		round.emit_signal("card_consumed", card.uid)
