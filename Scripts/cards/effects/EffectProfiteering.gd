extends CardEffect
class_name EffectProfiteering

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			req = r
			break

	if req == null:
		push_warning("[EffectProfiteering] No RUN_SEQUENCE PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectProfiteering] Pattern ready but could not locate matched start.")
		return

	if round.has_method("activate_profiteering"):
		round.call("activate_profiteering", start_point, req.seq_counts, card)
	else:
		round.emit_signal("card_consumed", card.uid)
