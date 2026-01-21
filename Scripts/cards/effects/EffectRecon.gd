extends CardEffect
class_name EffectRecon

func apply(round: RoundController, card: CardInstance, _ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break

	if req == null:
		push_warning("[EffectRecon] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	if round.has_method("activate_recon"):
		round.call("activate_recon", req, card)
	else:
		round.emit_signal("card_consumed", card.uid)
