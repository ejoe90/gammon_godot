extends Node
class_name SkillTreeDefs

# Skill tree definitions are now data-driven through a SkillTreeCatalog (.tres).
# The public query API remains the same so existing UI continues to work.

const CATALOG_PATH: String = "res://Resources/skills/skill_tree_catalog.tres"

static var _catalog: SkillTreeCatalog = null
static var _nodes_by_id: Dictionary = {} # String -> SkillNodeDef
static var _root_ids: Array[String] = []

static func _ensure() -> void:
	if _nodes_by_id.size() > 0:
		return

	_catalog = load(CATALOG_PATH) as SkillTreeCatalog
	if _catalog == null:
		push_warning("[SkillTreeDefs] Missing catalog at %s. Skill tree is empty." % CATALOG_PATH)
		return

	_root_ids = _catalog.root_ids.duplicate()

	for n in _catalog.nodes:
		var nd: SkillNodeDef = n as SkillNodeDef
		if nd == null:
			continue
		if nd.id == "":
			continue
		if _nodes_by_id.has(nd.id):
			push_warning("[SkillTreeDefs] Duplicate node id in catalog: %s" % nd.id)
		_nodes_by_id[nd.id] = nd

static func _get_node_def(node_id: String) -> SkillNodeDef:
	_ensure()
	return _nodes_by_id.get(node_id, null) as SkillNodeDef

# --------- UI option helper ----------
static func as_option(node_id: String) -> Dictionary:
	var n: SkillNodeDef = _get_node_def(node_id)
	if n == null:
		return {"id": node_id, "name": node_id, "desc": ""}
	return {"id": n.id, "name": n.name, "desc": n.desc}

# --------- Tree queries ----------
static func get_aux_id(node_id: String) -> String:
	var n: SkillNodeDef = _get_node_def(node_id)
	return "" if (n == null) else String(n.aux_id)

static func get_parent_id(node_id: String) -> String:
	var n: SkillNodeDef = _get_node_def(node_id)
	return "" if (n == null) else String(n.parent_id)

# IMPORTANT: don't name this get_children() because Node already has get_children().
static func get_child_ids(node_id: String) -> Array[String]:
	var n: SkillNodeDef = _get_node_def(node_id)
	var out: Array[String] = []
	if n == null:
		return out
	for v in n.child_ids:
		out.append(String(v))
	return out

static func get_prereq_ids(node_id: String) -> Array[String]:
	var n: SkillNodeDef = _get_node_def(node_id)
	var out: Array[String] = []
	if n == null:
		return out
	for v in n.prereq_ids:
		out.append(String(v))
	return out


static func get_max_level(node_id: String) -> int:
	var n: SkillNodeDef = _get_node_def(node_id)
	return 1 if (n == null) else int(n.max_level)

static func get_level_rules(node_id: String, level: int) -> Dictionary:
	var n: SkillNodeDef = _get_node_def(node_id)
	if n == null:
		return {}
	var idx: int = int(level) - 1
	if idx < 0 or idx >= n.level_rules.size():
		return {}
	return n.level_rules[idx] as Dictionary

static func is_root(node_id: String) -> bool:
	return get_parent_id(node_id) == ""

static func get_root_ids() -> Array[String]:
	_ensure()
	return _root_ids.duplicate()

static func _node_level(ss: RunSkillState, node_id: String) -> int:
	if ss == null:
		return 0
	return int(ss.node_levels.get(node_id, 0))

static func is_pick_allowed(ss: RunSkillState, node_id: String) -> bool:
	var n: SkillNodeDef = _get_node_def(node_id)
	if n == null:
		return false

	var cur: int = _node_level(ss, node_id)
	if cur >= get_max_level(node_id):
		return false

	# Multi-prereq gating (for merges/capstones).
	if n.prereq_ids != null and n.prereq_ids.size() > 0:
		for req in n.prereq_ids:
			if _node_level(ss, String(req)) <= 0:
				return false
		# Optional: also require parent if provided (keeps visual tree consistent).
		if String(n.parent_id) != "" and _node_level(ss, String(n.parent_id)) <= 0:
			return false
		return true

	var parent: String = get_parent_id(node_id)
	if parent == "":
		# root: allowed only if not already picked
		return cur == 0

	# child: allowed only if parent is picked (level>0)
	return _node_level(ss, parent) > 0

# --------- Gated offering ----------
static func pick_available_options(ss: RunSkillState, count: int, exclude_ids: Array = []) -> Array:
	_ensure()
	var candidates: Array[String] = []

	# Determine whether any root has been picked
	var any_root_picked: bool = false
	if ss != null:
		for r: String in _root_ids:
			if _node_level(ss, r) > 0:
				any_root_picked = true
				break

	if not any_root_picked:
		# First time: offer roots only
		for r: String in _root_ids:
			if exclude_ids.has(r):
				continue
			if is_pick_allowed(ss, r):
				candidates.append(r)
	else:
		# Offer any currently-available children (frontier)
		for key in _nodes_by_id.keys():
			var id: String = String(key)
			if exclude_ids.has(id):
				continue
			if (not is_root(id)) and is_pick_allowed(ss, id):
				candidates.append(id)

		# If not enough, fill with unpicked roots (lets you start new trees later)
		if candidates.size() < count:
			for r: String in _root_ids:
				if candidates.size() >= count:
					break
				if exclude_ids.has(r):
					continue
				if is_pick_allowed(ss, r):
					candidates.append(r)

	candidates.shuffle()

	var out: Array[Dictionary] = []
	var take: int = mini(count, candidates.size())
	for i: int in range(take):
		out.append(as_option(candidates[i]))
	return out

static func get_aux_upgrade_tier(ss: RunSkillState, aux_id: String) -> int:
	if ss == null:
		return 0

	# Count how many picked nodes map to this aux card.
	# Root unlock counts as 1; "tier" is upgrades beyond the root.
	var total_nodes: int = 0
	for k in ss.node_levels.keys():
		var node_id: String = String(k)
		var lvl: int = int(ss.node_levels.get(node_id, 0))
		if lvl <= 0:
			continue
		if get_aux_id(node_id) == aux_id:
			total_nodes += 1

	return maxi(0, total_nodes - 1)

static func get_grid(node_id: String) -> Vector2i:
	var n: SkillNodeDef = _get_node_def(node_id)
	return Vector2i.ZERO if (n == null) else (n.grid as Vector2i)

static func get_subtree_ids(root_id: String) -> Array[String]:
	# BFS from root.
	var out: Array[String] = []
	if _get_node_def(root_id) == null:
		return out
	var q: Array[String] = [root_id]
	while q.size() > 0:
		var cur: String = q.pop_front()
		if out.has(cur):
			continue
		out.append(cur)
		for child_id: String in get_child_ids(cur):
			q.append(child_id)
	return out
