extends RefCounted
class_name BoardState

enum Player { WHITE, BLACK }

# Per-point stacks of checker IDs (bottom->top order):
var points: Array[PackedInt32Array] = []

# Bar/off stacks of checker IDs:
var bar_white: PackedInt32Array = PackedInt32Array()
var bar_black: PackedInt32Array = PackedInt32Array()
var off_white: PackedInt32Array = PackedInt32Array()
var off_black: PackedInt32Array = PackedInt32Array()

var turn: int = Player.WHITE

# ID registry
var next_id: int = 1
var checkers: Dictionary = {} # int -> CheckerInfo

func _init() -> void:
	points.resize(24)
	for i in range(24):
		points[i] = PackedInt32Array()

func opponent(p: int) -> int:
	return Player.BLACK if p == Player.WHITE else Player.WHITE

func create_checker(owner: int) -> int:
	var id: int = next_id
	next_id += 1
	checkers[id] = CheckerInfo.new(id, owner)
	return id

func owner_of(id: int) -> int:
	return (checkers[id] as CheckerInfo).owner

func stack_count(i: int) -> int:
	return points[i].size()

func stack_owner(i: int) -> int:
	var st: PackedInt32Array = points[i]
	if st.size() == 0:
		return -1
	return owner_of(st[0])

func bar_stack(p: int) -> PackedInt32Array:
	return bar_white if p == Player.WHITE else bar_black

func off_stack(p: int) -> PackedInt32Array:
	return off_white if p == Player.WHITE else off_black

func reset_standard() -> void:
	for i in range(24):
		points[i] = PackedInt32Array()

	bar_white = PackedInt32Array()
	bar_black = PackedInt32Array()
	off_white = PackedInt32Array()
	off_black = PackedInt32Array()

	checkers.clear()
	next_id = 1
	turn = Player.WHITE

	_spawn_stack(0, Player.WHITE, 2)
	_spawn_stack(11, Player.WHITE, 5)
	_spawn_stack(16, Player.WHITE, 3)
	_spawn_stack(18, Player.WHITE, 5)

	_spawn_stack(23, Player.BLACK, 2)
	_spawn_stack(12, Player.BLACK, 5)
	_spawn_stack(7, Player.BLACK, 3)
	_spawn_stack(5, Player.BLACK, 5)

func _spawn_stack(point_i: int, owner: int, count: int) -> void:
	for _n in range(count):
		var id: int = create_checker(owner)
		points[point_i].append(id)


func count_in_play(player: int) -> int:
	var c: int = 0

	# points (fast: stacks should never mix owners)
	for i: int in range(24):
		var st: PackedInt32Array = points[i]
		if st.size() == 0:
			continue
		if stack_owner(i) == player:
			c += st.size()

	# bar
	if player == Player.WHITE:
		c += bar_white.size()
	else:
		c += bar_black.size()

	return c
