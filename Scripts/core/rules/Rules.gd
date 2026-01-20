extends Object
class_name Rules

enum ZeroSumResult {
	NONE,
	BOTH_DESTROYED,
	MOVING_ZERO_HITS_REGULAR,
	REGULAR_HITS_ZERO
}

static func _dir(p: int) -> int:
	return 1 if p == BoardState.Player.WHITE else -1

static func _home_range(p: int) -> Vector2i:
	# WHITE home: 18..23, BLACK home: 0..5
	return Vector2i(18, 23) if p == BoardState.Player.WHITE else Vector2i(0, 5)

static func _entry_point_from_bar(p: int, die: int) -> int:
	# WHITE enters at 0..5 via die-1; BLACK enters at 23..18 via 24-die
	return (die - 1) if p == BoardState.Player.WHITE else (24 - die)

static func _blocked_by_opponent(state: BoardState, p: int, dst: int) -> bool:
	if dst < 0 or dst > 23:
		return false
	var c: int = state.stack_count(dst)
	if c == 1:
		var o_single: int = state.stack_owner(dst)
		if o_single != -1 and o_single != p:
			if int(state.detente_turns_left) > 0:
				return true
			var st_single: PackedInt32Array = state.points[dst]
			if st_single.size() == 1 and checker_is_distant_threat(state, int(st_single[0])):
				return true
	if c < 2:
		return false
	var o: int = state.stack_owner(dst)
	return o != -1 and o != p

static func _is_hit(state: BoardState, p: int, dst: int) -> bool:
	if dst < 0 or dst > 23:
		return false
	if state.stack_count(dst) != 1:
		return false
	var owner: int = state.stack_owner(dst)
	if owner == -1 or owner == p:
		return false
	var st: PackedInt32Array = state.points[dst]
	if st.size() == 1 and checker_is_distant_threat(state, int(st[0])):
		return false
	return true

static func all_in_home(state: BoardState, p: int) -> bool:
	var hr: Vector2i = _home_range(p)
	for i in range(24):
		var c: int = state.stack_count(i)
		if c == 0:
			continue
		if state.stack_owner(i) != p:
			continue
		if i < hr.x or i > hr.y:
			return false
	return state.bar_stack(p).size() == 0

static func _has_checker_behind_in_home(state: BoardState, p: int, from_i: int) -> bool:
	var hr: Vector2i = _home_range(p)
	if p == BoardState.Player.WHITE:
		for i in range(hr.x, from_i):
			if state.stack_count(i) > 0 and state.stack_owner(i) == p:
				return true
	else:
		for i in range(from_i + 1, hr.y + 1):
			if state.stack_count(i) > 0 and state.stack_owner(i) == p:
				return true
	return false

static func legal_moves_for_die(state: BoardState, p: int, die: int) -> Array[Dictionary]:
	var res: Array[Dictionary] = []

	var mag: int = absi(die)
	if mag < 1:
		return res
	mag = mini(mag, 24)

	# Forward = normal direction for that player, Backward = opposite direction
	var forward: bool = die > 0
	var step_dir: int = _dir(p) * (1 if forward else -1)

	# Must enter from bar if any on bar.
	# MVP: do NOT allow negative dice to enter from bar.
	var bar: PackedInt32Array = state.bar_stack(p)
	if bar.size() > 0:
		if not forward:
			return res
		var dst: int = _entry_point_from_bar(p, mag)
		if not _blocked_by_opponent(state, p, dst):
			var hit := _is_hit(state, p, dst)
			if _moving_checker_is_pacifism(state, p, -1) and hit:
				return res
			res.append({
				"from": -1,
				"to": dst,
				"hit": hit,
			})
		return res

	# Normal moves (includes backward moves when die < 0)
	for from_i in range(24):
		if state.stack_count(from_i) == 0:
			continue
		if state.stack_owner(from_i) != p:
			continue

		var dst_i: int = from_i + step_dir * mag

		# On-board move
		if dst_i >= 0 and dst_i <= 23:
			if not _blocked_by_opponent(state, p, dst_i):
				var hit := _is_hit(state, p, dst_i)
				if _moving_checker_is_pacifism(state, p, from_i) and hit:
					continue
				res.append({
					"from": from_i,
					"to": dst_i,
					"hit": hit,
				})
			continue

		# MVP: negative dice cannot bear off
		if not forward:
			continue

		# Bear off (forward dice only)
		if all_in_home(state, p):
			var bear_ok: bool = false
			if p == BoardState.Player.WHITE:
				if dst_i == 24:
					bear_ok = true
				elif dst_i > 24 and not _has_checker_behind_in_home(state, p, from_i):
					bear_ok = true
			else:
				if dst_i == -1:
					bear_ok = true
				elif dst_i < -1 and not _has_checker_behind_in_home(state, p, from_i):
					bear_ok = true

			if bear_ok:
				res.append({
					"from": from_i,
					"to": 24 if p == BoardState.Player.WHITE else -2,
					"hit": false,
				})

	return res
	
	
	
static func legal_moves_for_die_adv(state: BoardState, p: int, die: int, bearoff_home_fraction: float) -> Array[Dictionary]:
	bearoff_home_fraction = clampf(bearoff_home_fraction, 0.0, 1.0)
	var res: Array[Dictionary] = []

	var mag: int = absi(die)
	if mag < 1:
		return res
	mag = mini(mag, 24)

	# Forward = normal direction for that player, Backward = opposite direction
	var forward: bool = die > 0
	var step_dir: int = _dir(p) * (1 if forward else -1)

	# Must enter from bar if any on bar.
	# MVP: do NOT allow negative dice to enter from bar.
	var bar: PackedInt32Array = state.bar_stack(p)
	if bar.size() > 0:
		if not forward:
			return res
		var dst: int = _entry_point_from_bar(p, mag)
		if not _blocked_by_opponent(state, p, dst):
			var hit := _is_hit(state, p, dst)
			if _moving_checker_is_pacifism(state, p, -1) and hit:
				return res
			res.append({
				"from": -1,
				"to": dst,
				"hit": hit,
			})
		return res

	# Normal moves (includes backward moves when die < 0)
	for from_i in range(24):
		if state.stack_count(from_i) == 0:
			continue
		if state.stack_owner(from_i) != p:
			continue

		var dst_i: int = from_i + step_dir * mag

		# On-board move
		if dst_i >= 0 and dst_i <= 23:
			if not _blocked_by_opponent(state, p, dst_i):
				var hit := _is_hit(state, p, dst_i)
				if _moving_checker_is_pacifism(state, p, from_i) and hit:
					continue
				res.append({
					"from": from_i,
					"to": dst_i,
					"hit": hit,
				})
			continue

		# MVP: negative dice cannot bear off
		if not forward:
			continue

		# Bear off (forward dice only)
		if all_in_home_fraction(state, p, bearoff_home_fraction):
			var bear_ok: bool = false
			if p == BoardState.Player.WHITE:
				if dst_i == 24:
					bear_ok = true
				elif dst_i > 24 and not _has_checker_behind_in_home(state, p, from_i):
					bear_ok = true
			else:
				if dst_i == -1:
					bear_ok = true
				elif dst_i < -1 and not _has_checker_behind_in_home(state, p, from_i):
					bear_ok = true

			if bear_ok:
				res.append({
					"from": from_i,
					"to": 24 if p == BoardState.Player.WHITE else -2,
					"hit": false,
				})

	return res

static func apply_move(state: BoardState, p: int, m: Dictionary) -> void:
	var from_i: int = int(m["from"])
	var to_i: int = int(m["to"])
	var hit: bool = bool(m.get("hit", false))

	# Pop moving checker id
	var moving_id: int = -1
	if from_i == -1:
		var bar: PackedInt32Array = state.bar_stack(p)
		moving_id = bar[bar.size() - 1]
		bar.remove_at(bar.size() - 1)
		if p == BoardState.Player.WHITE:
			state.bar_white = bar
		else:
			state.bar_black = bar
	else:
		var src: PackedInt32Array = state.points[from_i]
		moving_id = src[src.size() - 1]
		src.remove_at(src.size() - 1)
		state.points[from_i] = src

	# Handle hit on destination point
	if hit and to_i >= 0 and to_i <= 23:
		var dst: PackedInt32Array = state.points[to_i]
		if dst.size() == 1:
			var hit_id: int = dst[0]
			var opp: int = state.owner_of(hit_id)
			var hit_info: CheckerInfo = state.checkers.get(hit_id, null)
			if hit_info != null:
				hit_info.tags.erase("stealth")
			dst = PackedInt32Array() # cleared
			state.points[to_i] = dst

			var opp_bar: PackedInt32Array = state.bar_stack(opp)
			opp_bar.append(hit_id)
			if opp == BoardState.Player.WHITE:
				state.bar_white = opp_bar
			else:
				state.bar_black = opp_bar

	# Push to destination
	if to_i >= 0 and to_i <= 23:
		var dst2: PackedInt32Array = state.points[to_i]
		dst2.append(moving_id)
		state.points[to_i] = dst2
		return

	# Bear off
	if (p == BoardState.Player.WHITE and to_i == 24) or (p == BoardState.Player.BLACK and to_i == -2):
		var off: PackedInt32Array = state.off_stack(p)
		off.append(moving_id)
		if p == BoardState.Player.WHITE:
			state.off_white = off
		else:
			state.off_black = off
			
	print("moved id", moving_id, "from", from_i, "to", to_i)


static func checker_is_zero_sum(state: BoardState, checker_id: int) -> bool:
	if not state.checkers.has(checker_id):
		return false
	var info: CheckerInfo = state.checkers[checker_id]
	return bool(info.tags.get("zero_sum", false))

static func checker_is_distant_threat(state: BoardState, checker_id: int) -> bool:
	if not state.checkers.has(checker_id):
		return false
	var info: CheckerInfo = state.checkers[checker_id]
	return bool(info.tags.get("distant_threat", false))

static func checker_is_pacifism(state: BoardState, checker_id: int) -> bool:
	if not state.checkers.has(checker_id):
		return false
	var info: CheckerInfo = state.checkers[checker_id]
	return bool(info.tags.get("pacifism", false))

static func _moving_checker_is_pacifism(state: BoardState, p: int, from_i: int) -> bool:
	if from_i == -1:
		var bar: PackedInt32Array = state.bar_stack(p)
		if bar.is_empty():
			return false
		return checker_is_pacifism(state, int(bar[bar.size() - 1]))
	if from_i < 0 or from_i > 23:
		return false
	var st: PackedInt32Array = state.points[from_i]
	if st.is_empty():
		return false
	return checker_is_pacifism(state, int(st[st.size() - 1]))

static func set_checker_zero_sum(state: BoardState, checker_id: int, enabled: bool) -> void:
	if not state.checkers.has(checker_id):
		return
	var info: CheckerInfo = state.checkers[checker_id]
	if enabled:
		info.tags["zero_sum"] = true
	else:
		info.tags.erase("zero_sum")

static func apply_move_with_zero_sum(state: BoardState, p: int, m: Dictionary) -> Dictionary:
	var from_i: int = int(m.get("from", -999))
	var to_i: int = int(m.get("to", -999))
	var hit: bool = bool(m.get("hit", false))
	var result := {
		"landing": to_i,
		"zero_sum_result": ZeroSumResult.NONE,
		"moving_id": -1,
		"target_id": -1
	}

	if not hit or to_i < 0 or to_i > 23:
		apply_move(state, p, m)
		return result

	var dst: PackedInt32Array = state.points[to_i]
	if dst.size() != 1:
		apply_move(state, p, m)
		return result

	var moving_id: int = -1
	if from_i == -1:
		var bar: PackedInt32Array = state.bar_stack(p)
		if bar.is_empty():
			apply_move(state, p, m)
			return result
		moving_id = int(bar[bar.size() - 1])
	else:
		var src: PackedInt32Array = state.points[from_i]
		if src.is_empty():
			apply_move(state, p, m)
			return result
		moving_id = int(src[src.size() - 1])

	var target_id: int = int(dst[0])
	result["moving_id"] = moving_id
	result["target_id"] = target_id

	var target_pacifism: bool = checker_is_pacifism(state, target_id)
	if target_pacifism:
		var target_info: CheckerInfo = state.checkers.get(target_id, null)
		if target_info != null:
			target_info.tags.erase("stealth")
		if from_i == -1:
			var bar_stack: PackedInt32Array = state.bar_stack(p)
			if bar_stack.is_empty():
				apply_move(state, p, m)
				return result
			bar_stack.remove_at(bar_stack.size() - 1)
			if p == BoardState.Player.WHITE:
				state.bar_white = bar_stack
			else:
				state.bar_black = bar_stack
		else:
			var src_stack: PackedInt32Array = state.points[from_i]
			if src_stack.is_empty():
				apply_move(state, p, m)
				return result
			src_stack.remove_at(src_stack.size() - 1)
			state.points[from_i] = src_stack

		send_checker_to_bar(state, target_id)
		_push_checker_to_bar(state, moving_id, p)
		result["landing"] = -999
		result["pacifism_hit"] = true
		return result

	var moving_zero: bool = checker_is_zero_sum(state, moving_id)
	var target_zero: bool = checker_is_zero_sum(state, target_id)
	if not moving_zero and not target_zero:
		apply_move(state, p, m)
		return result

	if from_i == -1:
		var bar_stack: PackedInt32Array = state.bar_stack(p)
		bar_stack.remove_at(bar_stack.size() - 1)
		if p == BoardState.Player.WHITE:
			state.bar_white = bar_stack
		else:
			state.bar_black = bar_stack
	else:
		var src_stack: PackedInt32Array = state.points[from_i]
		src_stack.remove_at(src_stack.size() - 1)
		state.points[from_i] = src_stack

	if moving_zero and target_zero:
		var target_info: CheckerInfo = state.checkers.get(target_id, null)
		destroy_checker(state, moving_id)
		destroy_checker(state, target_id)
		result["landing"] = -999
		result["zero_sum_result"] = ZeroSumResult.BOTH_DESTROYED
		return result

	if moving_zero and not target_zero:
		var target_info: CheckerInfo = state.checkers.get(target_id, null)
		send_checker_to_bar(state, target_id)
		_push_checker_to_bar(state, moving_id, p)
		result["landing"] = -999
		result["zero_sum_result"] = ZeroSumResult.MOVING_ZERO_HITS_REGULAR
		return result

	if not moving_zero and target_zero:
		var target_info: CheckerInfo = state.checkers.get(target_id, null)
		set_checker_zero_sum(state, target_id, false)
		send_checker_to_bar(state, target_id)
		_push_checker_to_bar(state, moving_id, p)
		result["landing"] = -999
		result["zero_sum_result"] = ZeroSumResult.REGULAR_HITS_ZERO
		return result

	apply_move(state, p, m)
	return result

static func _push_checker_to_bar(state: BoardState, checker_id: int, owner: int) -> void:
	if owner == BoardState.Player.WHITE:
		var bw: PackedInt32Array = state.bar_white
		bw.append(checker_id)
		state.bar_white = bw
	else:
		var bb: PackedInt32Array = state.bar_black
		bb.append(checker_id)
		state.bar_black = bb


static func find_checker_point(state: BoardState, checker_id: int) -> int:
	for i: int in range(24):
		var st: PackedInt32Array = state.points[i]
		if st.find(checker_id) != -1:
			return i
	return -1

static func all_in_home_fraction(state: BoardState, p: int, required_fraction: float) -> bool:
	required_fraction = clampf(required_fraction, 0.0, 1.0)
	var hr: Vector2i = _home_range(p)
	var in_home: int = 0

	for i in range(24):
		var st := state.points[i]
		if st.size() == 0:
			continue
		if state.stack_owner(i) != p:
			continue
		if i >= hr.x and i <= hr.y:
			in_home += st.size()

	# Off stack counts as home
	in_home += state.off_stack(p).size()

	var total := 15
	return float(in_home) / float(total) >= required_fraction


static func send_checker_to_bar(state: BoardState, checker_id: int) -> void:
	var owner: int = state.owner_of(checker_id)
	if state.checkers.has(checker_id):
		var info: CheckerInfo = state.checkers[checker_id]
		info.tags.erase("stealth")

	# Remove from a point if present
	var pt: int = find_checker_point(state, checker_id)
	if pt != -1:
		var st: PackedInt32Array = state.points[pt]
		var idx: int = st.find(checker_id)
		if idx != -1:
			st.remove_at(idx)
			state.points[pt] = st

	# Push to appropriate bar
	if owner == BoardState.Player.WHITE:
		var bw: PackedInt32Array = state.bar_white
		bw.append(checker_id)
		state.bar_white = bw
	else:
		var bb: PackedInt32Array = state.bar_black
		bb.append(checker_id)
		state.bar_black = bb
		
		
# --------------------------------------------------------------------------
# Utility: permanently remove a checker from play
# Used by One Man Army when self checker is "destroyed".
# --------------------------------------------------------------------------
static func destroy_checker(state: BoardState, checker_id: int) -> void:
	if not state.checkers.has(checker_id):
		return
	state.checkers[checker_id].tags.erase("stealth")

	# Remove from board point
	for i in range(24):
		var st := state.points[i]
		var idx := st.find(checker_id)
		if idx != -1:
			st.remove_at(idx)
			state.points[i] = st
			break

	# Remove from bars / off
	state.bar_white.erase(checker_id)
	state.bar_black.erase(checker_id)
	state.off_white.erase(checker_id)
	state.off_black.erase(checker_id)

	state.checkers.erase(checker_id)
