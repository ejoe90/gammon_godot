# res://scripts/core/win/WinBearOff.gd
extends WinCondition
class_name WinBearOff

# NOTE:
# We intentionally DO NOT require a fixed target_off, because some cards can destroy checkers.
# Bear-off win should happen when a side has ZERO checkers left on points OR bar.
@export var target_off: int = 15 # kept for compatibility; not used by default

func check(state: Variant) -> bool:
	var bs := state as BoardState
	if bs == null:
		return false

	return _no_pieces_in_play(bs, BoardState.Player.WHITE) or _no_pieces_in_play(bs, BoardState.Player.BLACK)

func _no_pieces_in_play(bs: BoardState, p: int) -> bool:
	# Any checker on points?
	for i: int in range(24):
		var st: PackedInt32Array = bs.points[i]
		if st.size() == 0:
			continue
		# stacks are single-owner, so checking top is enough
		if bs.owner_of(int(st[0])) == p:
			return false

	# Any checker on bar?
	return bs.bar_stack(p).size() == 0
