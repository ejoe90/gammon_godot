extends RefCounted
class_name BackgammonBoardAdapter

var state: BoardState
var bearoff_home_fraction: float = 1.0

func _init(src_state: BoardState, _bearoff_home_fraction: float = 1.0) -> void:
	state = _deep_clone_state(src_state)
	bearoff_home_fraction = float(_bearoff_home_fraction)

func clone() -> BackgammonBoardAdapter:
	return BackgammonBoardAdapter.new(state, bearoff_home_fraction)

func legal_moves_for_die(die: int, player: int) -> Array:
	# Always use ADV (Rules.gd provides it); fraction is 1.0 for normal rules.
	return Rules.legal_moves_for_die_adv(state, player, int(die), bearoff_home_fraction)

func apply_move(move: Dictionary, player: int) -> void:
	Rules.apply_move(state, player, move)

func features() -> Dictionary:
	var f: Dictionary = {}
	var BLACK := BoardState.Player.BLACK
	var WHITE := BoardState.Player.WHITE

	var black_blots := 0
	var white_points_made := 0
	var black_points_made := 0

	for i in range(24):
		var c := state.stack_count(i)
		if c == 0:
			continue
		var o := state.stack_owner(i)
		if o == BLACK:
			if c == 1:
				black_blots += 1
			if c >= 2:
				black_points_made += 1
		elif o == WHITE:
			if c >= 2:
				white_points_made += 1

	f["black_blots"] = black_blots
	f["black_on_bar"] = int(state.bar_black.size())
	f["white_on_bar"] = int(state.bar_white.size())
	f["white_points_made"] = white_points_made
	f["black_points_made"] = black_points_made

	# home/off
	var black_home := 0
	for i in range(0, 6):
		if state.stack_count(i) > 0 and state.stack_owner(i) == BLACK:
			black_home += state.stack_count(i)

	var black_off := int(state.off_black.size())
	f["black_home"] = black_home + black_off
	f["black_borne_off"] = black_off
	f["black_total"] = 15

	# rough pip count (lower is better for BLACK)
	var pip := 0
	for i in range(24):
		if state.stack_count(i) == 0:
			continue
		if state.stack_owner(i) != BLACK:
			continue
		pip += (i + 1) * state.stack_count(i)

	pip += int(state.bar_black.size()) * 25
	f["black_pip_count"] = float(pip)

	return f

static func _deep_clone_state(src: BoardState) -> BoardState:
	var dst := BoardState.new()

	dst.points.resize(24)
	for i in range(24):
		dst.points[i] = PackedInt32Array(src.points[i])

	dst.bar_white = PackedInt32Array(src.bar_white)
	dst.bar_black = PackedInt32Array(src.bar_black)
	dst.off_white = PackedInt32Array(src.off_white)
	dst.off_black = PackedInt32Array(src.off_black)

	dst.turn = int(src.turn)
	dst.next_id = int(src.next_id)

	dst.checkers.clear()
	for k in src.checkers.keys():
		var id := int(k)
		var ci: CheckerInfo = src.checkers[k]
		var ci2 := CheckerInfo.new(ci.id, ci.owner)
		ci2.tags = ci.tags.duplicate(true)
		ci2.stacks = ci.stacks.duplicate(true)
		ci2.modifiers = ci.modifiers.duplicate(true)
		dst.checkers[id] = ci2

	return dst
