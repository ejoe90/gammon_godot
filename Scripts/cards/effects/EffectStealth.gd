extends CardEffect
class_name EffectStealth

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[EffectStealth] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectStealth] Pattern ready but could not locate matched start.")
		return

	var mid_point: int = start_point + 1
	if mid_point < 0 or mid_point > 23:
		return

	var st: PackedInt32Array = round.state.points[mid_point]
	if st.is_empty():
		push_warning("[EffectStealth] Expected a checker in the middle point.")
		return

	var checker_id: int = int(st[st.size() - 1])
	if round.has_method("activate_stealth"):
		round.call("activate_stealth", checker_id, card)
	else:
		var info: CheckerInfo = round.state.checkers.get(checker_id, null)
		if info != null:
			info.tags["stealth"] = true
		if round.board != null and round.board.has_method("sync_from_state_full"):
			round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
