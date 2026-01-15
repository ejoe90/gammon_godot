extends Node2D
class_name BoardHighlights

@export var point_markers: Array[NodePath] = []
@export var bearoff_white_marker: NodePath
@export var bearoff_black_marker: NodePath

@export var highlight_texture: Texture2D
@export var highlight_scale: float = 0.6
@export var y_offset: float = 0.0
@export var z_layer: int = 500

var _active: Array[Node2D] = []

func clear() -> void:
	for n in _active:
		if is_instance_valid(n):
			n.queue_free()
	_active.clear()

func show_targets(targets: Array[int], is_white_turn: bool) -> void:
	clear()

	for t in targets:
		if t >= 0 and t <= 23:
			_spawn_at_marker(point_markers[t])
		elif t == 24 and is_white_turn:
			_spawn_at_marker(bearoff_white_marker)
		elif t == -2 and (not is_white_turn):
			_spawn_at_marker(bearoff_black_marker)

func _spawn_at_marker(path: NodePath) -> void:
	var m: Node2D = get_node_or_null(path) as Node2D
	if m == null:
		return

	var s := Sprite2D.new()
	s.texture = highlight_texture
	s.centered = true
	s.scale = Vector2(highlight_scale, highlight_scale)
	s.z_index = z_layer

	# key fix: convert marker GLOBAL -> this node's LOCAL
	s.position = to_local(m.global_position) + Vector2(0, y_offset)

	add_child(s)
	_active.append(s)
