extends CardEffect
class_name EffectPlunder

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.ACROSS_PAIR:
			req = r
			break

	if req == null:
		push_warning("[EffectPlunder] No ACROSS_PAIR PatternReq on card.")
		return

	var points := _find_across_pair_points(req, ctx)
	if points.is_empty():
		push_warning("[EffectPlunder] Pattern ready but could not locate matched points.")
		return

	var black_point: int = int(points.get("black", -1))
	if black_point == -1:
		push_warning("[EffectPlunder] Could not determine black point for plunder.")
		return

	if round.has_method("activate_plunder"):
		round.call("activate_plunder", black_point, card)
	else:
		round.emit_signal("card_consumed", card.uid)

func _find_across_pair_points(req: PatternReq, ctx: PatternContext) -> Dictionary:
	for a in range(24):
		var b: int = 23 - a
		if _point_matches_range(ctx, a, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a) \
		and _point_matches_range(ctx, b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b):
			return _resolve_points(a, b, req.owner_a, req.owner_b)

		if req.adj_either_order:
			if _point_matches_range(ctx, a, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b) \
			and _point_matches_range(ctx, b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a):
				return _resolve_points(a, b, req.owner_b, req.owner_a)

	return {}

func _resolve_points(a: int, b: int, owner_a: int, owner_b: int) -> Dictionary:
	var result := {"white": -1, "black": -1}
	if owner_a == BoardState.Player.WHITE:
		result["white"] = a
	if owner_b == BoardState.Player.WHITE:
		result["white"] = b
	if owner_a == BoardState.Player.BLACK:
		result["black"] = a
	if owner_b == BoardState.Player.BLACK:
		result["black"] = b
	return result

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
