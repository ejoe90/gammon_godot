extends RefCounted
class_name PatternMatcher

# --------------------------------------------------------------------------
# MVP PatternMatcher
#
# Supports ONLY the two PatternReq kinds we need right now:
#
# 1) RUN_SEQUENCE:
#    - checks for a run of consecutive points that match exact stack counts
#    - can optionally allow reverse (1-2-3 or 3-2-1)
#    - can optionally force the whole sequence to stay within one board half
#      (0..11 or 12..23), preventing patterns that cross 11/12
#
# 2) ADJACENT_PAIR:
#    - checks for two neighboring points (i and i±1)
#    - point A matches owner_a + count range
#    - point B matches owner_b + count range
#    - optionally allows either order (swap A/B)
# --------------------------------------------------------------------------

static func matches_all(reqs: Array[PatternReq], ctx: PatternContext) -> bool:
	for r: PatternReq in reqs:
		if r == null:
			continue
		if not _req_ok(r, ctx):
			return false
	return true


# Used by targeted effects (Crossbow/Mortar) to determine which half a sequence
# lives in. Returns the start point of the first matched run, else -1.
static func find_run_sequence_start(r: PatternReq, ctx: PatternContext) -> int:
	if r == null:
		return -1
	if r.kind != PatternReq.Kind.RUN_SEQUENCE:
		return -1

	# Defensive: empty seq means "never matches"
	if r.seq_counts.size() == 0:
		return -1

	# Try forward then reverse (if enabled)
	var forward: PackedInt32Array = r.seq_counts
	if _find_run_start_for_sequence(ctx, r, forward) != -1:
		return _find_run_start_for_sequence(ctx, r, forward)

	if r.seq_allow_reverse:
		var rev := PackedInt32Array()
		for i in range(forward.size() - 1, -1, -1):
			rev.append(int(forward[i]))
		return _find_run_start_for_sequence(ctx, r, rev)

	return -1


static func _req_ok(r: PatternReq, ctx: PatternContext) -> bool:
	match r.kind:
		
		PatternReq.Kind.RUN_SEQUENCE:
			return find_run_sequence_start(r, ctx) != -1
		PatternReq.Kind.RUN_SEQUENCE_MIXED:
			return find_run_sequence_mixed_start(r, ctx) != -1
		PatternReq.Kind.ADJACENT_PAIR:
			return _adjacent_pair_ok(r, ctx)
		PatternReq.Kind.ACROSS_PAIR:
			return _across_pair_ok(r, ctx)
		_:
			return false


# --------------------------------------------------------------------------
# RUN_SEQUENCE matcher
# --------------------------------------------------------------------------

static func _find_run_start_for_sequence(ctx: PatternContext, r: PatternReq, counts: PackedInt32Array) -> int:
	var n: int = counts.size()
	if n <= 0:
		return -1

	# We only support consecutive for MVP (seq_max_gap must be 0)
	if r.seq_max_gap != 0:
		return -1

	for start_point in range(0, 24 - (n - 1)):
		var end_point: int = start_point + (n - 1)

		# Optional: disallow crossing the midline 11/12
		if r.seq_same_half_only:
			var start_half: int = 0 if start_point <= 11 else 1
			var end_half: int = 0 if end_point <= 11 else 1
			if start_half != end_half:
				continue

		var ok := true
		for k in range(n):
			var p_i: int = start_point + k
			var expected: int = int(counts[k])
			if not _point_matches_owner_exact(ctx, p_i, r.owner_a, expected):
				ok = false
				break

		if ok:
			return start_point

	return -1


static func _point_matches_owner_exact(ctx: PatternContext, point_i: int, owner: int, expected_count: int) -> bool:
	if point_i < 0 or point_i > 23:
		return false

	var st: PackedInt32Array = ctx.state.points[point_i]
	if st.size() != expected_count:
		return false
	if st.size() == 0:
		return false

	return ctx.state.owner_of(int(st[0])) == owner


# --------------------------------------------------------------------------
# ADJACENT_PAIR matcher
# --------------------------------------------------------------------------

static func _adjacent_pair_ok(r: PatternReq, ctx: PatternContext) -> bool:
	for a in range(24):
		for b in [a - 1, a + 1]:
			if b < 0 or b > 23:
				continue

			if _point_matches_range(ctx, a, r.owner_a, r.min_count_a, r.max_count_a, r.require_empty_a) \
			and _point_matches_range(ctx, b, r.owner_b, r.min_count_b, r.max_count_b, r.require_empty_b):
				return true

			if r.adj_either_order:
				if _point_matches_range(ctx, a, r.owner_b, r.min_count_b, r.max_count_b, r.require_empty_b) \
				and _point_matches_range(ctx, b, r.owner_a, r.min_count_a, r.max_count_a, r.require_empty_a):
					return true

	return false
	
static func _across_pair_ok(r: PatternReq, ctx: PatternContext) -> bool:
	for a in range(24):
		var b: int = 23 - a

		if _point_matches_range(ctx, a, r.owner_a, r.min_count_a, r.max_count_a, r.require_empty_a) \
		and _point_matches_range(ctx, b, r.owner_b, r.min_count_b, r.max_count_b, r.require_empty_b):
			return true

		# Optional: allow either order using the same toggle as adjacent pairs
		if r.adj_either_order:
			if _point_matches_range(ctx, a, r.owner_b, r.min_count_b, r.max_count_b, r.require_empty_b) \
			and _point_matches_range(ctx, b, r.owner_a, r.min_count_a, r.max_count_a, r.require_empty_a):
				return true

	return false
	


static func _point_matches_range(
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


static func find_run_sequence_mixed_start(r: PatternReq, ctx: PatternContext) -> int:
	if r == null or r.kind != PatternReq.Kind.RUN_SEQUENCE_MIXED:
		return -1

	var n := r.mix_owners.size()
	if n == 0:
		return -1
	if r.mix_mins.size() != n or r.mix_maxs.size() != n:
		return -1
	if r.mix_max_gap != 0:
		return -1

	var start := _find_run_mixed_start_for_arrays(ctx, r, r.mix_owners, r.mix_mins, r.mix_maxs)
	if start != -1:
		return start

	if r.mix_allow_reverse:
		var owners_rev := PackedInt32Array()
		var mins_rev := PackedInt32Array()
		var maxs_rev := PackedInt32Array()
		for i in range(n - 1, -1, -1):
			owners_rev.append(int(r.mix_owners[i]))
			mins_rev.append(int(r.mix_mins[i]))
			maxs_rev.append(int(r.mix_maxs[i]))
		return _find_run_mixed_start_for_arrays(ctx, r, owners_rev, mins_rev, maxs_rev)

	return -1


static func _find_run_mixed_start_for_arrays(
	ctx: PatternContext,
	r: PatternReq,
	owners: PackedInt32Array,
	mins: PackedInt32Array,
	maxs: PackedInt32Array
) -> int:
	var n := owners.size()
	for start_point in range(0, 24 - (n - 1)):
		var end_point := start_point + (n - 1)

		if r.mix_same_half_only:
			var start_half := 0 if start_point <= 11 else 1
			var end_half := 0 if end_point <= 11 else 1
			if start_half != end_half:
				continue

		var ok := true
		for k in range(n):
			var p_i := start_point + k
			if not _point_matches_range(ctx, p_i, int(owners[k]), int(mins[k]), int(maxs[k]), false):
				ok = false
				break
		if ok:
			return start_point

	return -1
