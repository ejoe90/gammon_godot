extends CardEffect
class_name EffectChainReaction

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			req = r
			break
	if req == null:
		push_warning("[EffectChainReaction] No RUN_SEQUENCE PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectChainReaction] Pattern ready but could not locate matched start.")
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
		push_warning("[EffectChainReaction] No checkers found for chain reaction.")
		return

	if round.has_method("activate_chain_reaction"):
		round.call("activate_chain_reaction", checker_ids, card)
	else:
		for checker_id in checker_ids:
			var info: CheckerInfo = round.state.checkers.get(checker_id, null)
			if info != null:
				info.tags["chain_reaction"] = true
		if round.board != null and round.board.has_method("sync_from_state_full"):
			round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
