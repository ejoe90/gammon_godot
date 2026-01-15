extends Resource
class_name SkillNodeDef

@export var id: String = ""
@export var name: String = ""
@export_multiline var desc: String = ""

@export var aux_id: String = ""
@export var parent_id: String = "" # empty means root
@export var child_ids: Array[String] = []

# Optional: additional prerequisites for unlocking (supports merges/capstones).
# If non-empty, the node is only pickable once ALL prereq_ids have level > 0.
@export var prereq_ids: Array[String] = []




@export var max_level: int = 1

# index 0 = rules for level 1, index 1 = level 2, etc.
@export var level_rules: Array[Dictionary] = []

# Optional: for graph-style layouts
@export var grid: Vector2i = Vector2i.ZERO
