extends CardEffect
class_name EffectCounterMeasures

@export var enemy_damage: int = 4
@export var base_attack_bonus: int = 1
@export var bonus_dice: int = 1
@export var target_owner: int = BoardState.Player.BLACK

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.ACROSS_ADJACENT_PAIR:
			req = r
			break
	if req == null:
		push_warning("[EffectCounterMeasures] No ACROSS_ADJACENT_PAIR PatternReq on card.")
		return

	var target_points: Array[int] = _find_target_points(req, ctx)
	if target_points.is_empty():
		push_warning("[EffectCounterMeasures] Pattern ready but could not locate matched points.")
		return

	for pt in target_points:
		var st: PackedInt32Array = round.state.points[pt]
		if st.size() == 0:
			continue
		var top_id: int = int(st[st.size() - 1])
		if round.state.owner_of(top_id) == target_owner:
			Rules.send_checker_to_bar(round.state, top_id)

	if round.run_state != null:
		round.deal_enemy_damage(enemy_damage)

	if round.run_state != null and base_attack_bonus > 0:
		if round.has_method("add_turn_base_attack_bonus"):
			round.call("add_turn_base_attack_bonus", base_attack_bonus)
		else:
			round.run_state.base_attack_power = maxi(0, int(round.run_state.base_attack_power) + int(base_attack_bonus))

	if bonus_dice > 0 and round.dice != null and round.dice.has_method("add_bonus_die"):
		for _i in range(bonus_dice):
			round.dice.call("add_bonus_die", randi_range(1, 6))
		if round.has_method("_update_dice_ui"):
			round.call("_update_dice_ui")

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)


func _find_target_points(req: PatternReq, ctx: PatternContext) -> Array[int]:
	for a in range(0, 23):
		var b: int = a + 1
		var opp_a: int = 23 - a
		var opp_b: int = 23 - b

		if _pair_matches_range(ctx, a, b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a) \
		and _pair_matches_range(ctx, opp_a, opp_b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b):
			return _target_points_for_match(req, a, b, opp_a, opp_b)

		if req.adj_either_order:
			if _pair_matches_range(ctx, a, b, req.owner_b, req.min_count_b, req.max_count_b, req.require_empty_b) \
			and _pair_matches_range(ctx, opp_a, opp_b, req.owner_a, req.min_count_a, req.max_count_a, req.require_empty_a):
				return _target_points_for_match(req, opp_a, opp_b, a, b)

	return []


func _target_points_for_match(req: PatternReq, owner_a_pt1: int, owner_a_pt2: int, owner_b_pt1: int, owner_b_pt2: int) -> Array[int]:
	if req.owner_a == target_owner:
		return [owner_a_pt1, owner_a_pt2]
	return [owner_b_pt1, owner_b_pt2]


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
