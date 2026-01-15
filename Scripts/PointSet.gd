extends Resource
class_name PointSet

# Defines which points are considered by a PatternReq.
enum Mode {
	ANY,            # 0..23
	RANGE,          # start..end
	LIST,           # explicit indices
	UNION,          # union of other PointSets
	HALF_LOW,       # 0..11
	HALF_HIGH,      # 12..23
	QUADRANT_0,     # 0..5
	QUADRANT_1,     # 6..11
	QUADRANT_2,     # 12..17
	QUADRANT_3,     # 18..23
	HOME_SELF,      # WHITE:18..23  BLACK:0..5
	OUTER_SELF,     # WHITE:12..17  BLACK:6..11
	HOME_ENEMY,     # opposite player's home
	OUTER_ENEMY,    # opposite player's outer
}

@export var mode: Mode = Mode.ANY

# RANGE params
@export_range(0, 23) var range_start: int = 0
@export_range(0, 23) var range_end: int = 23
@export_range(1, 23) var step: int = 1

# LIST params
@export var points: PackedInt32Array = PackedInt32Array()

# UNION params
@export var sets: Array[PointSet] = []

# Optional: include mirrored points (23 - i) in the set
@export var include_mirror: bool = false


func get_points(self_player: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()

	match mode:
		Mode.ANY:
			for i: int in range(24):
				out.append(i)

		Mode.RANGE:
			var a: int = mini(range_start, range_end)
			var b: int = maxi(range_start, range_end)
			var st: int = maxi(1, step)
			for i: int in range(a, b + 1, st):
				out.append(i)

		Mode.LIST:
			for i: int in points:
				if i >= 0 and i <= 23:
					out.append(i)

		Mode.UNION:
			for s: PointSet in sets:
				if s != null:
					var pts: PackedInt32Array = s.get_points(self_player)
					for i: int in pts:
						out.append(i)

		Mode.HALF_LOW:
			for i: int in range(0, 12):
				out.append(i)

		Mode.HALF_HIGH:
			for i: int in range(12, 24):
				out.append(i)

		Mode.QUADRANT_0:
			for i: int in range(0, 6):
				out.append(i)

		Mode.QUADRANT_1:
			for i: int in range(6, 12):
				out.append(i)

		Mode.QUADRANT_2:
			for i: int in range(12, 18):
				out.append(i)

		Mode.QUADRANT_3:
			for i: int in range(18, 24):
				out.append(i)

		Mode.HOME_SELF:
			var r: Vector2i = _home_range(self_player)
			for i: int in range(r.x, r.y + 1):
				out.append(i)

		Mode.OUTER_SELF:
			var r: Vector2i = _outer_range(self_player)
			for i: int in range(r.x, r.y + 1):
				out.append(i)

		Mode.HOME_ENEMY:
			var enemy: int = BoardState.Player.BLACK if self_player == BoardState.Player.WHITE else BoardState.Player.WHITE
			var r: Vector2i = _home_range(enemy)
			for i: int in range(r.x, r.y + 1):
				out.append(i)

		Mode.OUTER_ENEMY:
			var enemy: int = BoardState.Player.BLACK if self_player == BoardState.Player.WHITE else BoardState.Player.WHITE
			var r: Vector2i = _outer_range(enemy)
			for i: int in range(r.x, r.y + 1):
				out.append(i)

	if include_mirror:
		var extra: PackedInt32Array = PackedInt32Array()
		for i: int in out:
			extra.append(23 - i)
		for j: int in extra:
			out.append(j)

	out = _unique_sorted(out)
	return out


func _home_range(p: int) -> Vector2i:
	return Vector2i(18, 23) if p == BoardState.Player.WHITE else Vector2i(0, 5)


func _outer_range(p: int) -> Vector2i:
	return Vector2i(12, 17) if p == BoardState.Player.WHITE else Vector2i(6, 11)


func _unique_sorted(arr: PackedInt32Array) -> PackedInt32Array:
	var seen: Dictionary = {}
	for v: int in arr:
		seen[v] = true

	var keys: Array = seen.keys()
	keys.sort()

	var out: PackedInt32Array = PackedInt32Array()
	for k in keys:
		out.append(int(k))
	return out
