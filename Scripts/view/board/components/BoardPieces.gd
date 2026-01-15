extends Node
class_name BoardPieces

@export var checkers_layer_path: NodePath = NodePath("../CheckersLayer")

@export var point_markers: Array[NodePath] = []
@export var bar_marker_white: NodePath
@export var bar_marker_black: NodePath
@export var off_marker_white: NodePath
@export var off_marker_black: NodePath

@export var checker_scene: PackedScene

@export var checker_scale: float = 0.65
@export var stack_spacing: float = 18.0
@export var max_stack_visible: int = 6
@export var overflow_compress: float = 0.35
@export var base_z: int = 10

var checkers_layer: Node2D
var node_by_id: Dictionary = {} # int -> Node2D

signal checker_clicked(checker_id: int)


func _ready() -> void:
	checkers_layer = get_node_or_null(checkers_layer_path) as Node2D

func get_piece(id: int) -> Node2D:
	return node_by_id.get(id, null) as Node2D

func sync_from_state_full(state: BoardState) -> void:
	if checkers_layer == null:
		push_error("[BoardPieces] CheckersLayer missing.")
		return
	if checker_scene == null:
		push_error("[BoardPieces] checker_scene not assigned.")
		return
	if point_markers.size() != 24:
		push_error("[BoardPieces] point_markers must be size 24.")
		return

	# Build set of alive ids
	var alive: Dictionary = {}
	for i in range(24):
		var st: PackedInt32Array = state.points[i]
		for k in range(st.size()):
			alive[st[k]] = true
	for k in range(state.bar_white.size()):
		alive[state.bar_white[k]] = true
	for k in range(state.bar_black.size()):
		alive[state.bar_black[k]] = true
	for k in range(state.off_white.size()):
		alive[state.off_white[k]] = true
	for k in range(state.off_black.size()):
		alive[state.off_black[k]] = true

	# Remove nodes not in state anymore
	var to_remove: Array[int] = []
	for key in node_by_id.keys():
		var id: int = int(key)
		if not alive.has(id):
			to_remove.append(id)

	for id in to_remove:
		var n: Node2D = node_by_id[id] as Node2D
		if is_instance_valid(n):
			n.queue_free()
		node_by_id.erase(id)

	# Ensure nodes for all alive ids
	for id_key in alive.keys():
		var id2: int = int(id_key)
		_ensure_node(state, id2)

	# Layout everything from state
	for i in range(24):
		_layout_point(state, i)
	_layout_bar(state, true)
	_layout_bar(state, false)
	_layout_off(state, true)
	_layout_off(state, false)

#func _ensure_node(state: BoardState, id: int) -> void:
	#var existing: Node2D = node_by_id.get(id, null) as Node2D
	#if existing != null and is_instance_valid(existing):
		#return
#
	#var piece: Node2D = checker_scene.instantiate() as Node2D
	#checkers_layer.add_child(piece)
	#node_by_id[id] = piece
#
	#piece.scale = Vector2(checker_scale, checker_scale)
	#piece.set_meta("checker_id", id)
#
	#var is_white: bool = (state.owner_of(id) == BoardState.Player.WHITE)
	#piece.set_meta("is_white", is_white)
#
	## color hook: support either of your implementations
	#if piece.has_method("set_color_animation"):
		#piece.call("set_color_animation", is_white)
	#elif piece.has_method("set_color"):
		#piece.call("set_color", is_white)
		
		
func _ensure_node(state: BoardState, id: int) -> void:
	var piece: Node2D = node_by_id.get(id, null) as Node2D

	if piece == null or not is_instance_valid(piece):
		piece = checker_scene.instantiate() as Node2D
		checkers_layer.add_child(piece)
		node_by_id[id] = piece
		
		# Forward checker click events if supported by the scene/script
	if piece != null and piece.has_signal("clicked"):
		var cb := Callable(self, "_on_checker_node_clicked")
		if not piece.is_connected("clicked", cb):
			piece.connect("clicked", cb)


	# ALWAYS assign id (even if reused)
	piece.set_meta("checker_id", id)

	if piece.has_method("set_checker_id"):
		piece.call("set_checker_id", id)

	# Color hook (optional)
	var is_white: bool = (state.owner_of(id) == BoardState.Player.WHITE)
	if piece.has_method("set_color"):
		piece.call("set_color", is_white)
	elif piece.has_method("set_color_animation"):
		piece.call("set_color_animation", is_white)


func point_stack_dir_global(i: int) -> Vector2:
	var base: Vector2 = _point_base_pos(i)
	var center_y: float = get_viewport().get_visible_rect().size.y * 0.5
	return Vector2(0, 1) if base.y < center_y else Vector2(0, -1)

func point_slot_global(i: int, slot_index: int) -> Vector2:
	var base: Vector2 = _point_base_pos(i)
	var dir: Vector2 = point_stack_dir_global(i)
	return base + dir * _stack_offset(slot_index)

func bar_slot_global(is_white: bool, slot_index: int) -> Vector2:
	var base: Vector2 = _marker_pos(bar_marker_white if is_white else bar_marker_black)
	return base + Vector2(0, -1) * _stack_offset(slot_index)

func off_slot_global(is_white: bool, slot_index: int) -> Vector2:
	var base: Vector2 = _marker_pos(off_marker_white if is_white else off_marker_black)
	return base + Vector2(0, -1) * _stack_offset(slot_index)

func _layout_point(state: BoardState, i: int) -> void:
	var st: PackedInt32Array = state.points[i]
	for k in range(st.size()):
		var id: int = st[k]
		var n: Node2D = node_by_id[id] as Node2D
		if n == null: continue
		n.global_position = point_slot_global(i, k)
		n.z_index = clampi(base_z + k, -4096, 4096)

func _layout_bar(state: BoardState, is_white: bool) -> void:
	var st: PackedInt32Array = state.bar_white if is_white else state.bar_black
	for k in range(st.size()):
		var id: int = st[k]
		var n: Node2D = node_by_id[id] as Node2D
		if n == null: continue
		n.global_position = bar_slot_global(is_white, k)
		n.z_index = clampi(1000 + k, -4096, 4096)

func _layout_off(state: BoardState, is_white: bool) -> void:
	var st: PackedInt32Array = state.off_white if is_white else state.off_black
	for k in range(st.size()):
		var id: int = st[k]
		var n: Node2D = node_by_id[id] as Node2D
		if n == null: continue
		n.global_position = off_slot_global(is_white, k)
		n.z_index = clampi(1500 + k, -4096, 4096)

func _stack_offset(n: int) -> float:
	if n < max_stack_visible:
		return stack_spacing * float(n)
	var extra: int = n - (max_stack_visible - 1)
	return stack_spacing * float(max_stack_visible - 1) + stack_spacing * overflow_compress * float(extra)

func _fallback_pos() -> Vector2:
	var p: Node2D = get_parent() as Node2D
	return p.global_position if p != null else Vector2.ZERO

func _marker_pos(path: NodePath) -> Vector2:
	var m: Node2D = get_node_or_null(path) as Node2D
	return m.global_position if m != null else _fallback_pos()

func _point_base_pos(i: int) -> Vector2:
	var m: Node2D = get_node_or_null(point_markers[i]) as Node2D
	return m.global_position if m != null else _fallback_pos()

func _on_checker_node_clicked(checker_id: int) -> void:
	emit_signal("checker_clicked", checker_id)
