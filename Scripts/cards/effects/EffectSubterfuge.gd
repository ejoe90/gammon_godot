extends CardEffect
class_name EffectSubterfuge

@export var enemy_hp_damage: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[EffectSubterfuge] No RUN_SEQUENCE_MIXED req on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectSubterfuge] Pattern ready but could not locate matched start.")
		return

	var left_pt: int = start_point
	var right_pt: int = start_point + 2

	for pt in [left_pt, right_pt]:
		var st: PackedInt32Array = round.state.points[pt]
		if st.size() == 0:
			continue
		var top_id: int = int(st[st.size() - 1])
		if round.state.owner_of(top_id) == BoardState.Player.BLACK:
			Rules.send_checker_to_bar(round.state, top_id)

	if round.run_state != null:
		round.deal_enemy_damage(enemy_hp_damage)

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
