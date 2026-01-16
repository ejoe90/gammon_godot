extends CardEffect
class_name EffectFlanked

@export var enemy_damage: int = 2
@export var base_attack_bonus: int = 1

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[EffectFlanked] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectFlanked] Pattern ready but could not locate matched start.")
		return

	var left_white: int = start_point
	var left_black: int = start_point + 1
	var right_black: int = start_point + 2
	var right_white: int = start_point + 3

	_handle_black_stack(round, left_black, left_white)
	_handle_black_stack(round, right_black, right_white)

	if round.run_state != null:
		round.deal_enemy_damage(enemy_damage)
		if base_attack_bonus > 0:
			if round.has_method("add_round_base_attack_bonus"):
				round.call("add_round_base_attack_bonus", base_attack_bonus)
			else:
				round.run_state.base_attack_power = maxi(0, int(round.run_state.base_attack_power) + int(base_attack_bonus))

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)


func _handle_black_stack(round: RoundController, black_pt: int, white_adjacent: int) -> void:
	var black_stack: PackedInt32Array = round.state.points[black_pt]
	if black_stack.is_empty():
		return

	if black_stack.size() == 1:
		var hit_id: int = int(black_stack[0])
		Rules.send_checker_to_bar(round.state, hit_id)
		var white_stack: PackedInt32Array = round.state.points[white_adjacent]
		if not white_stack.is_empty():
			if round.has_method("apply_move_with_zero_sum"):
				round.call("apply_move_with_zero_sum", {"from": white_adjacent, "to": black_pt, "hit": false}, BoardState.Player.WHITE)
			else:
				Rules.apply_move(round.state, BoardState.Player.WHITE, {"from": white_adjacent, "to": black_pt, "hit": false})
		return

	var top_id: int = int(black_stack[black_stack.size() - 1])
	Rules.send_checker_to_bar(round.state, top_id)
