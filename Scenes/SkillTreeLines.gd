extends Control
class_name SkillTreeLines

@export var graph_path: NodePath = NodePath("..") # Tree
var _graph: SkillTreeGraphView = null

func _ready() -> void:
	_graph = get_node_or_null(graph_path) as SkillTreeGraphView

func _draw() -> void:
	if _graph == null:
		return

	# Draw lines parent->child for nodes that exist in this view
	for k in _graph._nodes_by_id.keys():
		var parent_id: String = String(k)
		var parent_pos: Vector2 = _graph._pos_by_id.get(parent_id, Vector2.ZERO)

		for child_id: String in SkillTreeDefs.get_child_ids(parent_id):
			if not _graph._pos_by_id.has(child_id):
				continue
			var child_pos: Vector2 = _graph._pos_by_id.get(child_id, Vector2.ZERO)

			# connect center points
			var a: Vector2 = parent_pos + Vector2(60, 30)
			var b: Vector2 = child_pos + Vector2(60, 30)
			draw_line(a, b, Color(0.0, 2.629, 2.14, 0.937), 3.0)
