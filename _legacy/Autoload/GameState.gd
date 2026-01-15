extends Node

enum Player { WHITE, BLACK }

# points[i] = signed checker count:
#   >0 means WHITE checkers
#   <0 means BLACK checkers
# abs(value) is count
var points: Array[int] = []
var bar_white := 0
var bar_black := 0
var off_white := 0
var off_black := 0

var turn: Player = Player.WHITE

func _ready() -> void:
	reset_standard()

func reset_standard() -> void:
	points = []
	points.resize(24)
	for i in range(24):
		points[i] = 0

	# Standard backgammon start (indices 0..23)
	# WHITE moves 0 -> 23
	# BLACK moves 23 -> 0
	#
	# Common mapping:
	# WHITE: 2 on 0, 5 on 11, 3 on 16, 5 on 18
	# BLACK: 2 on 23, 5 on 12, 3 on 7, 5 on 5
	points[0] = 2
	points[11] = 5
	points[16] = 3
	points[18] = 5

	points[23] = -2
	points[12] = -5
	points[7] = -3
	points[5] = -5

	bar_white = 0
	bar_black = 0
	off_white = 0
	off_black = 0
	turn = Player.WHITE

func is_white(p: Player) -> bool:
	return p == Player.WHITE

func sign_for(p: Player) -> int:
	return 1 if is_white(p) else -1

func opponent(p: Player) -> Player:
	return Player.BLACK if p == Player.WHITE else Player.WHITE

func bar_count(p: Player) -> int:
	return bar_white if is_white(p) else bar_black

func set_bar_count(p: Player, v: int) -> void:
	if is_white(p): bar_white = v
	else: bar_black = v

func off_count(p: Player) -> int:
	return off_white if is_white(p) else off_black

func set_off_count(p: Player, v: int) -> void:
	if is_white(p): off_white = v
	else: off_black = v

func point_owner(i: int) -> int:
	#  1 for WHITE, -1 for BLACK, 0 empty
	var v := points[i]
	if v > 0: return 1
	if v < 0: return -1
	return 0

func point_count(i: int) -> int:
	return abs(points[i])

func can_land(p: Player, dst: int) -> bool:
	# blocked if opponent has 2+ on dst
	var v := points[dst]
	var s := sign_for(p)
	if v == 0: return true
	if (v * s) > 0:
		# own point
		return true
	# opponent point
	return abs(v) == 1  # hit allowed only if blot (1)

func home_range(p: Player) -> Vector2i:
	# inclusive ranges
	# WHITE home: 18..23
	# BLACK home: 0..5
	return Vector2i(18, 23) if is_white(p) else Vector2i(0, 5)

func all_in_home(p: Player) -> bool:
	# Must have none on bar
	if bar_count(p) > 0:
		return false

	var s := sign_for(p)
	var hr := home_range(p)
	for i in range(24):
		var v := points[i]
		if v * s > 0:
			# own checker exists on i
			if i < hr.x or i > hr.y:
				return false
	return true

func entry_point_from_bar(p: Player, die: int) -> int:
	# WHITE enters at die-1
	# BLACK enters at 24-die
	return (die - 1) if is_white(p) else (24 - die)

func direction(p: Player) -> int:
	# WHITE increases index, BLACK decreases
	return 1 if is_white(p) else -1

func bearing_off_target_index(p: Player) -> int:
	# WHITE bears off beyond 23, BLACK beyond 0
	return 23 if is_white(p) else 0

func distance_to_bear_off(p: Player, from: int) -> int:
	# pip distance to bear-off edge using 1..6 dice
	# WHITE edge is 23, BLACK edge is 0
	return (23 - from) if is_white(p) else from

func has_checker_behind(p: Player, from: int) -> bool:
	# For overshoot bearing-off rule:
	# WHITE: "behind" means lower index than from within home
	# BLACK: "behind" means higher index than from within home
	var s := sign_for(p)
	var hr := home_range(p)
	if is_white(p):
		for i in range(hr.x, from):
			if points[i] * s > 0:
				return true
	else:
		for i in range(from + 1, hr.y + 1):
			if points[i] * s > 0:
				return true
	return false

# --- Move representation ---
# Dictionary fields:
#   from: int  (0..23) or -1 means from bar
#   to: int    (0..23) or 24 means bear off (WHITE) or -2 means bear off (BLACK)
#   die: int
#   hit: bool

func legal_moves_for_die(p: Player, die: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	# Must enter from bar if any
	if bar_count(p) > 0:
		var dst := entry_point_from_bar(p, die)
		if can_land(p, dst):
			var hit := (point_owner(dst) == -sign_for(p) and point_count(dst) == 1)
			moves.append({"from": -1, "to": dst, "die": die, "hit": hit})
		return moves

	# Regular moves from points
	var s := sign_for(p)
	var dir := direction(p)

	for from_i in range(24):
		if points[from_i] * s <= 0:
			continue

		var dst_i := from_i + dir * die

		# Normal on-board move
		if dst_i >= 0 and dst_i <= 23:
			if can_land(p, dst_i):
				var hit := (point_owner(dst_i) == -s and point_count(dst_i) == 1)
				moves.append({"from": from_i, "to": dst_i, "die": die, "hit": hit})
			continue

		# Bearing off
		if all_in_home(p):
			# Exact or overshoot allowed if no checker behind
			if is_white(p):
				# dst_i > 23 overshoots
				var dist := distance_to_bear_off(p, from_i) + 1 # exact die needed
				if die == dist or (die > dist and not has_checker_behind(p, from_i)):
					moves.append({"from": from_i, "to": 24, "die": die, "hit": false})
			else:
				# BLACK dst_i < 0 overshoots
				var distb := distance_to_bear_off(p, from_i) + 1
				if die == distb or (die > distb and not has_checker_behind(p, from_i)):
					moves.append({"from": from_i, "to": -2, "die": die, "hit": false})

	return moves

func apply_move(p: Player, move: Dictionary) -> void:
	var s := sign_for(p)

	# remove from source
	if move["from"] == -1:
		set_bar_count(p, bar_count(p) - 1)
	else:
		var from_i: int = move["from"]
		points[from_i] -= s

	# handle destination
	var to_i: int = move["to"]
	if to_i == 24 or to_i == -2:
		# bear off
		set_off_count(p, off_count(p) + 1)
		return

	# hitting
	if move.get("hit", false):
		# opponent blot -> send 1 to opponent bar
		var opp := opponent(p)
		set_bar_count(opp, bar_count(opp) + 1)
		# clear the blot point first (it had exactly 1 opponent checker)
		points[to_i] = 0

	# place checker
	points[to_i] += s
