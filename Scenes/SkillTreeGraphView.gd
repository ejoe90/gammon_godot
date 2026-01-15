extends Control
class_name SkillTreeGraphView

@export var node_scene: PackedScene
@export var spacing_x: int = 170
@export var spacing_y: int = 120
@export var tree_gap_x: int = 260

var _round: RoundController = null
var _ss: RunSkillState = null

var _root_ids: Array[String] = []
var _nodes_by_id: Dictionary = {} # String -> SkillTreeNode
var _pos_by_id: Dictionary = {}   # String -> Vector2

@onready var lines_layer: Control = $Lines
@onready var nodes_layer: Control = $Nodes

func build(round: RoundController, ss: RunSkillState, offered_roots: Array[String]) -> void:
	_round = round
	_ss = ss
	_root_ids = offered_roots.duplicate()
	_rebuild()

func _rebuild() -> void:
	# clear
	for c in nodes_layer.get_children():
		c.queue_free()
	_nodes_by_id.clear()
	_pos_by_id.clear()

	# layout each root as a separate mini-tree column
	for idx: int in range(_root_ids.size()):
		var root_id: String = _root_ids[idx]
		var origin: Vector2 = Vector2( (idx * tree_gap_x) + 120, 60 )

		var ids: Array[String] = SkillTreeDefs.get_subtree_ids(root_id)
		for node_id: String in ids:
			_make_node(node_id, origin)

	# After nodes exist, update their states and redraw lines
	_refresh_states()
	lines_layer.queue_redraw()

func _make_node(node_id: String, origin: Vector2) -> void:
	if node_scene == null:
		return
	if _nodes_by_id.has(node_id):
		return

	var inst: Node = node_scene.instantiate()
	var node: SkillTreeNode = inst as SkillTreeNode
	if node == null:
		return

	var name: String = SkillTreeDefs.as_option(node_id).get("name", node_id)
	node.setup(node_id, name)
	node.pressed.connect(Callable(self, "_on_node_pressed"))

	nodes_layer.add_child(node)

	var g: Vector2i = SkillTreeDefs.get_grid(node_id)
	var pos: Vector2 = origin + Vector2(g.x * float(spacing_x), g.y * float(spacing_y))

	node.position = pos
	_nodes_by_id[node_id] = node
	_pos_by_id[node_id] = pos

func _refresh_states() -> void:
	if _ss == null:
		return

	for k in _nodes_by_id.keys():
		var node_id: String = String(k)
		var n: SkillTreeNode = _nodes_by_id[node_id] as SkillTreeNode
		if n == null:
			continue

		var owned: bool = int(_ss.node_levels.get(node_id, 0)) > 0
		if owned:
			n.set_state(2)
		else:
			var avail: bool = SkillTreeDefs.is_pick_allowed(_ss, node_id)
			n.set_state(1 if avail else 0)

func _on_node_pressed(node_id: String) -> void:
	# Your overlay should still enforce picks_allowed, gold buy, etc.
	# Here you forward the click to the overlay’s selection logic.
	get_parent().call("toggle_choice_from_tree", node_id)

func _draw() -> void:
	# Not used; we draw on Lines layer
	pass
