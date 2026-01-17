extends CardEffect
class_name EffectDistantThreat

@export var turns: int = 3

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break

	if req == null:
		push_warning("[EffectDistantThreat] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectDistantThreat] Pattern ready but could not locate matched start.")
		return

	var sequence := _resolve_sequence(req, ctx, start_point)
	if sequence.is_empty():
		push_warning("[EffectDistantThreat] Pattern ready but could not resolve match orientation.")
		return

	var owners: PackedInt32Array = sequence["owners"]
	var mins: PackedInt32Array = sequence["mins"]
	var maxs: PackedInt32Array = sequence["maxs"]
	var empties: PackedInt32Array = sequence["empties"]

	var white_index := -1
	for i in range(owners.size()):
		if int(empties[i]) != 0:
			continue
		if int(owners[i]) == BoardState.Player.WHITE and int(mins[i]) == 1 and int(maxs[i]) == 1:
			white_index = i
			break

	if white_index == -1:
		push_warning("[EffectDistantThreat] No single white checker found in matched sequence.")
		return

	var white_point: int = start_point + white_index
	if white_point < 0 or white_point > 23:
		return
	var st: PackedInt32Array = round.state.points[white_point]
	if st.size() != 1:
		return

	var checker_id: int = int(st[0])
	if round.has_method("activate_distant_threat"):
		round.call("activate_distant_threat", checker_id, turns, card)

func _resolve_sequence(req: PatternReq, ctx: PatternContext, start_point: int) -> Dictionary:
	var owners := req.mix_owners
	var mins := req.mix_mins
	var maxs := req.mix_maxs
	var empties := req.mix_requires_empty
	if empties.size() != owners.size():
		empties = PackedInt32Array()
		for _i in range(owners.size()):
			empties.append(0)

	if _sequence_matches(ctx, start_point, owners, mins, maxs, empties):
		return {"owners": owners, "mins": mins, "maxs": maxs, "empties": empties}

	if req.mix_allow_reverse:
		var owners_rev := PackedInt32Array()
		var mins_rev := PackedInt32Array()
		var maxs_rev := PackedInt32Array()
		var empties_rev := PackedInt32Array()
		for i in range(owners.size() - 1, -1, -1):
			owners_rev.append(int(owners[i]))
			mins_rev.append(int(mins[i]))
			maxs_rev.append(int(maxs[i]))
			empties_rev.append(int(empties[i]))
		if _sequence_matches(ctx, start_point, owners_rev, mins_rev, maxs_rev, empties_rev):
			return {"owners": owners_rev, "mins": mins_rev, "maxs": maxs_rev, "empties": empties_rev}

	return {}

func _sequence_matches(
	ctx: PatternContext,
	start_point: int,
	owners: PackedInt32Array,
	mins: PackedInt32Array,
	maxs: PackedInt32Array,
	empties: PackedInt32Array
) -> bool:
	for k in range(owners.size()):
		var p_i := start_point + k
		if int(empties[k]) != 0:
			if ctx.state.points[p_i].size() != 0:
				return false
		else:
			if not _point_matches_range(ctx, p_i, int(owners[k]), int(mins[k]), int(maxs[k]), false):
				return false
	return true

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
