extends CardEffect
class_name EffectZeroSum

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.ADJACENT_PAIR:
			req = r
			break

	if req == null:
		push_warning("[EffectZeroSum] No ADJACENT_PAIR PatternReq on card.")
		return

	var points := _find_adjacent_pair(req, ctx)
	if points.is_empty():
		push_warning("[EffectZeroSum] Pattern ready but could not locate matched points.")
		return

	if round.has_method("activate_zero_sum"):
		round.call("activate_zero_sum", points, card)

func _find_adjacent_pair(req: PatternReq, ctx: PatternContext) -> PackedInt32Array:
	for a in range(24):
		for b in [a - 1, a + 1]:
			if b < 0 or b > 23:
				continue

			if _point_matches_range(ctx, a, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a) \
			and _point_matches_range(ctx, b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b):
				return PackedInt32Array([a, b])

			if req.adj_either_order:
				if _point_matches_range(ctx, a, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b) \
				and _point_matches_range(ctx, b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a):
					return PackedInt32Array([a, b])

	return PackedInt32Array()

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
