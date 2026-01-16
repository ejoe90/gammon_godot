extends CardEffect
class_name EffectEngulf

@export var enemy_damage: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[EffectEngulf] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectEngulf] Pattern ready but could not locate matched start.")
		return

	var left_pt: int = start_point
	var mid_pt: int = start_point + 1
	var right_pt: int = start_point + 2

	if left_pt < 0 or right_pt > 23:
		return

	var hit_black: bool = false
	var mid_stack: PackedInt32Array = round.state.points[mid_pt]
	if mid_stack.size() == 1:
		var mid_id: int = int(mid_stack[0])
		hit_black = round.state.owner_of(mid_id) == BoardState.Player.BLACK

	if round.has_method("apply_move_with_zero_sum"):
		round.call("apply_move_with_zero_sum", {"from": left_pt, "to": mid_pt, "hit": hit_black}, BoardState.Player.WHITE)
		round.call("apply_move_with_zero_sum", {"from": right_pt, "to": mid_pt, "hit": false}, BoardState.Player.WHITE)
	else:
		Rules.apply_move(round.state, BoardState.Player.WHITE, {"from": left_pt, "to": mid_pt, "hit": hit_black})
		Rules.apply_move(round.state, BoardState.Player.WHITE, {"from": right_pt, "to": mid_pt, "hit": false})

	if round.run_state != null:
		round.deal_enemy_damage(enemy_damage)

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
