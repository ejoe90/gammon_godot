extends CardEffect
class_name EffectStopgapEconomy

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break

	if req == null:
		push_warning("[EffectStopgapEconomy] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectStopgapEconomy] Pattern ready but could not locate matched start.")
		return

	var gap_pt: int = start_point + 1
	if round.has_method("activate_stopgap_economy"):
		round.call("activate_stopgap_economy", gap_pt, card)
	else:
		round.emit_signal("card_consumed", card.uid)
