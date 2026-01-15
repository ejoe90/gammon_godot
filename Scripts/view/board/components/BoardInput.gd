extends Node
class_name BoardInput

signal point_clicked(index: int)
signal bearoff_clicked(dest: int) # 24 for WHITE, -2 for BLACK

@export var point_nodes: Array[NodePath] = []
@export var bearoff_white_node: NodePath
@export var bearoff_black_node: NodePath

var enabled: bool = true

# cache wired areas so we can toggle input_pickable properly
var _point_areas: Array[Area2D] = []
var _bearoff_areas: Array[Area2D] = []

func set_enabled(v: bool) -> void:
	enabled = v

	# IMPORTANT: stop these Areas from intercepting clicks while targeting
	for a: Area2D in _point_areas:
		if is_instance_valid(a):
			a.input_pickable = enabled

	for a2: Area2D in _bearoff_areas:
		if is_instance_valid(a2):
			a2.input_pickable = enabled

func _ready() -> void:
	_wire_points()
	_wire_bearoff()
	# apply initial enabled state to the cached nodes
	set_enabled(enabled)

func _wire_points() -> void:
	_point_areas.clear()

	for i in range(point_nodes.size()):
		var area: Area2D = get_node_or_null(point_nodes[i]) as Area2D
		if area == null:
			push_warning("[BoardInput] Missing point Area2D at %d path=%s" % [i, str(point_nodes[i])])
			continue

		_point_areas.append(area)
		area.input_pickable = true
		area.input_event.connect(Callable(self, "_on_point_input_event").bind(i))

func _wire_bearoff() -> void:
	_bearoff_areas.clear()

	var w: Area2D = get_node_or_null(bearoff_white_node) as Area2D
	if w != null:
		_bearoff_areas.append(w)
		w.input_pickable = true
		w.input_event.connect(Callable(self, "_on_bearoff_input_event").bind(24))
	else:
		push_warning("[BoardInput] bearoff_white_node not set or not an Area2D")

	var b: Area2D = get_node_or_null(bearoff_black_node) as Area2D
	if b != null:
		_bearoff_areas.append(b)
		b.input_pickable = true
		b.input_event.connect(Callable(self, "_on_bearoff_input_event").bind(-2))
	else:
		push_warning("[BoardInput] bearoff_black_node not set or not an Area2D")

func _on_point_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int, point_index: int) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("point_clicked", point_index)

func _on_bearoff_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int, dest: int) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("bearoff_clicked", dest)
