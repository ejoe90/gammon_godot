extends CanvasLayer
class_name SkillTreeOverlay

signal buy_extra_pick_requested
signal confirmed(chosen_ids: Array)
signal skipped

@onready var info: Label = $Panel/Root/Info
@onready var tree_root: Control = $Panel/Root/Grid
@onready var lines_layer: Control = $Panel/Root/Grid/Lines
@onready var nodes_layer: Control = $Panel/Root/Grid/Nodes
@onready var buy_btn: Button = $Panel/Root/Buttons/BuyPick
@onready var confirm_btn: Button = $Panel/Root/Buttons/Confirm

# layout tuning
# NOTE: tuned so 3 trees (attack/gold/pips) can be shown side-by-side at 1080p/1920w
# without overlap. Adjust in the editor on the SkillTreeOverlay node if you change layouts.
@export var root_gap_x: int = 620
@export var spacing_x: int = 110
@export var spacing_y: int = 105
@export var node_size: Vector2 = Vector2(160, 50)

var _options: Array[Dictionary] = []
var _chosen: Array[String] = []
var _picks_allowed: int = 1
var _buy_cost: int = 0
var _gold: int = 0
var _ss: RunSkillState = null

# runtime caches
var _available_ids: Dictionary = {}       # id -> true
var _node_buttons: Dictionary = {}        # id -> Button
var _node_centers: Dictionary = {}        # id -> Vector2 (local to nodes_layer)
var _node_rects: Dictionary = {}          # id -> Rect2 (local to nodes_layer)




func open(options: Array, picks_allowed: int, gold: int, buy_cost: int, ss: RunSkillState) -> void:
	visible = true

	_options.clear()
	for o in options:
		_options.append(o as Dictionary)

	_chosen.clear()
	_picks_allowed = max(1, picks_allowed)
	_gold = gold
	_buy_cost = buy_cost
	_ss = ss

	_rebuild_tree()
	_refresh()


func close() -> void:
	visible = false

func set_picks_allowed(picks_allowed: int) -> void:
	_picks_allowed = max(1, picks_allowed)
	_refresh()

func set_gold(gold: int) -> void:
	_gold = gold
	_refresh()

func _ready() -> void:
	visible = false
	buy_btn.pressed.connect(func(): emit_signal("buy_extra_pick_requested"))
	$Panel/Root/Buttons/Skip.pressed.connect(func(): emit_signal("skipped"))
	confirm_btn.pressed.connect(func(): emit_signal("confirmed", _chosen.duplicate()))

func _rebuild_tree() -> void:
	# clear visuals
	for c in nodes_layer.get_children():
		c.queue_free()
	for c in lines_layer.get_children():
		c.queue_free()

	_node_buttons.clear()
	_node_centers.clear()
	_node_rects.clear()
	_available_ids.clear()

	# available ids come from options (what the manager is offering to pick)
	for opt: Dictionary in _options:
		var id: String = str(opt.get("id", ""))
		if id != "":
			_available_ids[id] = true

	# Display ALL configured roots so fully-upgraded trees remain visible.
	# Only nodes in _options will be selectable; everything else is shown for context.
	var root_ids: Array[String] = SkillTreeDefs.get_root_ids()
	root_ids.sort()

	# build each subtree as a "mini tree" placed side-by-side
	for ri: int in range(root_ids.size()):
		var root_id: String = root_ids[ri]
		var origin: Vector2 = Vector2(250 + ri * root_gap_x, 70)
		_build_subtree(root_id, origin)

	# after nodes placed, draw connector lines
	_draw_lines_for_visible_subtrees()

	# apply selection highlight
	_refresh_node_visuals()

func _build_subtree(root_id: String, origin: Vector2) -> void:
	# Prefer data-driven grid positions from SkillNodeDef (more orderly than BFS).
	# Falls back to BFS-like layout only if grids are not provided.
	var ids: Array[String] = SkillTreeDefs.get_subtree_ids(root_id)
	# Sort by (y then x) for stable placement
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ga: Vector2i = SkillTreeDefs.get_grid(a)
		var gb: Vector2i = SkillTreeDefs.get_grid(b)
		if ga.y == gb.y:
			return ga.x < gb.x
		return ga.y < gb.y
	)

	var any_nonzero_grid: bool = false
	for id0: String in ids:
		var g0: Vector2i = SkillTreeDefs.get_grid(id0)
		if g0 != Vector2i.ZERO or id0 == root_id:
			any_nonzero_grid = true
			break

	if any_nonzero_grid:
		for id: String in ids:
			var g: Vector2i = SkillTreeDefs.get_grid(id)
			var pos: Vector2 = origin + Vector2(float(g.x) * float(spacing_x), float(g.y) * float(spacing_y))
			_make_node_button(id, pos)
		return

	# Fallback: BFS with (node_id, depth, x_index)
	var q: Array = [{"id": root_id, "d": 0, "x": 0}]
	var seen: Dictionary = {}
	while q.size() > 0:
		var it: Dictionary = q.pop_front() as Dictionary
		var id2: String = String(it.get("id", ""))
		if id2 == "" or seen.has(id2):
			continue
		seen[id2] = true
		var d: int = int(it.get("d", 0))
		var x: int = int(it.get("x", 0))
		var pos2: Vector2 = origin + Vector2(float(x) * float(spacing_x), float(d) * float(spacing_y))
		_make_node_button(id2, pos2)
		var children2: Array[String] = SkillTreeDefs.get_child_ids(id2)
		for ci: int in range(children2.size()):
			var child_id2: String = children2[ci]
			var dx: int = -1 if ci == 0 else 1
			q.append({"id": child_id2, "d": d + 1, "x": x + dx})

func _make_node_button(id: String, pos: Vector2) -> void:
	# Look up name/desc from defs for ALL nodes (not just options)
	var opt: Dictionary = SkillTreeDefs.as_option(id)
	var nm: String = String(opt.get("name", id))
	var desc: String = String(opt.get("desc", ""))

	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size = node_size
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = "%s\n%s" % [nm, desc]
	b.position = pos

	# determine state
	var owned: bool = false
	if _ss != null:
		owned = int(_ss.node_levels.get(id, 0)) > 0

	# Only nodes that are currently being offered may be clicked.
	# We still render the full tree for context.
	var offered: bool = _available_ids.has(id)
	var pick_ok: bool = true
	if _ss != null:
		pick_ok = SkillTreeDefs.is_pick_allowed(_ss, id)
	var available: bool = offered and pick_ok

	if owned:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 1.0)
	elif available:
		b.disabled = false
		b.modulate = Color(1, 1, 1, 1.0)
	else:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.25)

	b.pressed.connect(func() -> void:
		_toggle_choice(id)
	)

	nodes_layer.add_child(b)

	_node_buttons[id] = b
	_node_centers[id] = pos + node_size * 0.5
	_node_rects[id] = Rect2(pos, node_size)

func _draw_lines_for_visible_subtrees() -> void:
	# Draw parent links plus prereq links (for merge nodes like tier-4 gates).
	# This ensures nodes with multiple prerequisites show all intended connections.
	var seen: Dictionary = {} # "from->to" -> true
	for k in _node_buttons.keys():
		var to_id: String = String(k)
		if not _node_rects.has(to_id):
			continue

		# Parent link
		var p: String = SkillTreeDefs.get_parent_id(to_id)
		_try_add_edge(p, to_id, seen)

		# Prerequisite links (merges/capstones)
		var prereqs: Array[String] = SkillTreeDefs.get_prereq_ids(to_id)
		for req_id: String in prereqs:
			_try_add_edge(req_id, to_id, seen)

func _try_add_edge(from_id: String, to_id: String, seen: Dictionary) -> void:
	if from_id == "" or to_id == "":
		return
	if not _node_rects.has(from_id) or not _node_rects.has(to_id):
		return

	var key: String = "%s->%s" % [from_id, to_id]
	if seen.has(key):
		return
	seen[key] = true

	var from_rect: Rect2 = _node_rects.get(from_id, Rect2())
	var to_rect: Rect2 = _node_rects.get(to_id, Rect2())

	var a: Vector2 = from_rect.position + Vector2(node_size.x * 0.5, node_size.y) # bottom-center
	var b: Vector2 = to_rect.position + Vector2(node_size.x * 0.5, 0.0) # top-center

	# Use an elbow connector to keep the graph tidy.
	var mid_y: float = (a.y + b.y) * 0.5

	var ln := Line2D.new()
	ln.width = 3.0
	ln.default_color = Color(1, 1, 1, 0.35)
	ln.add_point(a)
	ln.add_point(Vector2(a.x, mid_y))
	ln.add_point(Vector2(b.x, mid_y))
	ln.add_point(b)
	lines_layer.add_child(ln)

func _get_root_id(id: String) -> String:
	var cur: String = id
	var guard: int = 0
	while cur != "" and guard < 64:
		guard += 1
		var p: String = SkillTreeDefs.get_parent_id(cur)
		if p == "":
			return cur
		cur = p
	return id

func _toggle_choice(id: String) -> void:
	if _chosen.has(id):
		_chosen.erase(id)
	else:
		if _chosen.size() >= _picks_allowed:
			return
		_chosen.append(id)
	_refresh()

func _refresh() -> void:
	info.text = "Choose %d (selected %d). Gold: %d. Buy +1 pick: %d" % [
		_picks_allowed, _chosen.size(), _gold, _buy_cost
	]

	confirm_btn.disabled = (_chosen.size() == 0)
	buy_btn.disabled = (_gold < _buy_cost)

	_refresh_node_visuals()

func _refresh_node_visuals() -> void:
	# add a simple selection highlight
	for k in _node_buttons.keys():
		var id: String = String(k)
		var b: Button = _node_buttons[id] as Button
		if b == null:
			continue

		# preserve dim/locked alpha but brighten selection
		if _chosen.has(id):
			b.modulate = Color(1.0, 1.0, 0.75, b.modulate.a)
		else:
			# reset: if disabled keep its alpha, else full white
			var a: float = b.modulate.a
			b.modulate = Color(1, 1, 1, a)
