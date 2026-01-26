extends CardEffect
class_name EffectConvoy

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			req = r
			break

	if req == null:
		push_warning("[EffectConvoy] No RUN_SEQUENCE PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectConvoy] Pattern ready but could not locate matched start.")
		return

	var checker_ids: Array[int] = []
	for offset in range(req.seq_counts.size()):
		var point: int = start_point + offset
		if point < 0 or point > 23:
			continue
		var st: PackedInt32Array = round.state.points[point]
		if st.is_empty():
			continue
		checker_ids.append(int(st[st.size() - 1]))

	if checker_ids.is_empty():
		push_warning("[EffectConvoy] No checkers found for convoy.")
		return

	if round.has_method("activate_convoy"):
		round.call("activate_convoy", checker_ids, card)
	else:
		round.emit_signal("card_consumed", card.uid)
