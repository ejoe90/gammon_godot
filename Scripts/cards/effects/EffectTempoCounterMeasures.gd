extends CardEffect
class_name EffectTempoCounterMeasures

@export var bonus_dice_if_white_ahead: int = 2
@export var bonus_ap_if_black_ahead: int = 2
@export var black_bonus_dice_if_black_ahead: int = 1
@export var bonus_ap_if_tied: int = 1
@export var bonus_dice_if_tied: int = 1

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.ACROSS_ADJACENT_PAIR:
			req = r
			break

	if req == null:
		push_warning("[EffectTempoCounterMeasures] No ACROSS_ADJACENT_PAIR PatternReq on card.")
		return

	var match := _find_across_adjacent_pair(req, ctx)
	if match.is_empty():
		push_warning("[EffectTempoCounterMeasures] Pattern ready but could not locate matched points.")
		return

	var white_points: Array = match.get("white_points", [])
	var black_points: Array = match.get("black_points", [])
	var white_count: int = _sum_stack_sizes(round.state, white_points)
	var black_count: int = _sum_stack_sizes(round.state, black_points)

	var bonus_ap := 0
	var bonus_dice := 0
	var black_bonus_dice := 0

	if white_count > black_count:
		bonus_dice += bonus_dice_if_white_ahead
	elif white_count < black_count:
		bonus_ap += bonus_ap_if_black_ahead
		black_bonus_dice += black_bonus_dice_if_black_ahead
	else:
		bonus_ap += bonus_ap_if_tied
		bonus_dice += bonus_dice_if_tied

	if bonus_ap > 0:
		round.ap_left += bonus_ap

	if bonus_dice > 0 and round.dice != null and round.dice.has_method("add_bonus_die"):
		for _i in range(bonus_dice):
			round.dice.call("add_bonus_die", randi_range(1, 6))
		if round.has_method("_update_dice_ui"):
			round.call("_update_dice_ui")

	if black_bonus_dice > 0:
		round._counter_measures_black_bonus_dice += black_bonus_dice

	round.emit_signal("card_consumed", card.uid)

func _sum_stack_sizes(state: BoardState, points: Array) -> int:
	var total := 0
	for pt in points:
		var idx: int = int(pt)
		if idx < 0 or idx > 23:
			continue
		total += state.points[idx].size()
	return total

func _find_across_adjacent_pair(req: PatternReq, ctx: PatternContext) -> Dictionary:
	for a in range(0, 23):
		var b: int = a + 1
		var opp_a: int = 23 - a
		var opp_b: int = 23 - b

		if _pair_matches_range(ctx, a, b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a) \
		and _pair_matches_range(ctx, opp_a, opp_b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b):
			return _assign_white_black(req, [a, b], [opp_a, opp_b])

		if req.adj_either_order:
			if _pair_matches_range(ctx, a, b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b) \
			and _pair_matches_range(ctx, opp_a, opp_b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a):
				return _assign_white_black(req, [opp_a, opp_b], [a, b])

	return {}

func _assign_white_black(req: PatternReq, owner_a_points: Array, owner_b_points: Array) -> Dictionary:
	if req.owner_a == BoardState.Player.WHITE:
		return {"white_points": owner_a_points, "black_points": owner_b_points}
	return {"white_points": owner_b_points, "black_points": owner_a_points}

func _pair_matches_range(
	ctx: PatternContext,
	point_a: int,
	point_b: int,
	owner: int,
	min_c: int,
	max_c: int,
	require_empty: bool
) -> bool:
	return _point_matches_range(ctx, point_a, owner, min_c, max_c, require_empty) \
	and _point_matches_range(ctx, point_b, owner, min_c, max_c, require_empty)

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
