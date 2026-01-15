extends CardEffect
class_name EffectSuperiority

@export var enemy_damage: int = 4

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.ADJACENT_PAIR:
			req = r
			break

	if req == null:
		push_warning("[EffectSuperiority] No ADJACENT_PAIR PatternReq on card.")
		return

	var match := _find_adjacent_pair(req, ctx)
	if match.is_empty():
		push_warning("[EffectSuperiority] Pattern ready but could not locate matched points.")
		return

	var white_pt: int = int(match["white"])
	var black_pt: int = int(match["black"])

	for _i in range(2):
		var black_stack: PackedInt32Array = round.state.points[black_pt]
		if black_stack.is_empty():
			break
		var hit_id: int = int(black_stack[black_stack.size() - 1])
		Rules.send_checker_to_bar(round.state, hit_id)

	for _i in range(2):
		var white_stack: PackedInt32Array = round.state.points[white_pt]
		if white_stack.is_empty():
			break
		Rules.apply_move(round.state, BoardState.Player.WHITE, {"from": white_pt, "to": black_pt, "hit": false})

	if round.run_state != null:
		round.deal_enemy_damage(enemy_damage)

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)


func _find_adjacent_pair(req: PatternReq, ctx: PatternContext) -> Dictionary:
	for a in range(24):
		for b in [a - 1, a + 1]:
			if b < 0 or b > 23:
				continue

			if _point_matches_range(ctx, a, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a) \
			and _point_matches_range(ctx, b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b):
				return _assign_white_black(req, a, b)

			if req.adj_either_order:
				if _point_matches_range(ctx, a, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b) \
				and _point_matches_range(ctx, b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a):
					return _assign_white_black(req, b, a)

	return {}


func _assign_white_black(req: PatternReq, owner_a_point: int, owner_b_point: int) -> Dictionary:
	if req.owner_a == BoardState.Player.WHITE:
		return {"white": owner_a_point, "black": owner_b_point}
	return {"white": owner_b_point, "black": owner_a_point}


func _point_matches_range(
	ctx: PatternContext,
	point_i: int,
	owner: int,
	min_c: int,
	max_c: int,
	require_empty: bool
) -> bool:
	if point_i < 0 or point_i > 23:
		return false

	var st: PackedInt32Array = ctx.state.points[point_i]
	var n: int = st.size()

	if require_empty:
		return n == 0
	if n == 0:
		return false
	if ctx.state.owner_of(int(st[0])) != owner:
		return false

	return n >= min_c and n <= max_c
