extends Node2D
class_name BoardView

signal point_clicked(index: int)
signal bearoff_clicked(dest: int) # 24 for WHITE, -2 for BLACK
signal checker_clicked(checker_id: int)

signal bar_clicked(player: int)

@onready var bar_click_white: Area2D = get_node_or_null("BarClickWhite")
@onready var bar_click_black: Area2D = get_node_or_null("BarClickBlack")

@onready var input: BoardInput = $BoardInput
@onready var pieces: BoardPieces = $BoardPieces
@onready var animator: BoardAnimator = $BoardAnimator
@onready var highlights: BoardHighlights = $HighlightsLayer
@onready var no_mans_land_layer: Node2D = get_node_or_null("NoMansLandLayer") as Node2D
@onready var stopgap_layer: Node2D = get_node_or_null("StopgapLayer") as Node2D
@onready var wormhole_layer: Node2D = get_node_or_null("WormholeLayer") as Node2D
@onready var overwatch_label: Label = get_node_or_null("OverwatchLabel") as Label
@onready var detente_label: Label = get_node_or_null("DetenteLabel") as Label
@onready var friction_label: Label = get_node_or_null("FrictionLabel") as Label

var _no_mans_land_labels: Dictionary = {}
var _stopgap_labels: Dictionary = {}
var _wormhole_labels: Dictionary = {}

func show_move_targets(targets: Array[int], player: int) -> void:
	var is_white: bool = (player == BoardState.Player.WHITE)
	highlights.show_targets(targets, is_white)

func clear_move_targets() -> void:
	highlights.clear()

func _ready() -> void:
	input.point_clicked.connect(func(i: int) -> void:
		emit_signal("point_clicked", i)
	)
	input.bearoff_clicked.connect(func(dest: int) -> void:
		emit_signal("bearoff_clicked", dest)
	)
	
	pieces.checker_clicked.connect(func(id: int) -> void:
		emit_signal("checker_clicked", id)
	)


	if bar_click_white != null:
		bar_click_white.input_event.connect(_on_bar_input_event.bind(BoardState.Player.WHITE))

	if bar_click_black != null:
		bar_click_black.input_event.connect(_on_bar_input_event.bind(BoardState.Player.BLACK))

func sync_from_state_full(state: BoardState) -> void:
	pieces.sync_from_state_full(state)

func set_no_mans_land_counts(counts: Dictionary) -> void:
	if no_mans_land_layer == null:
		return

	for key in _no_mans_land_labels.keys():
		var label: Label = _no_mans_land_labels[key] as Label
		if is_instance_valid(label):
			label.queue_free()
	_no_mans_land_labels.clear()

	for key in counts.keys():
		var point: int = int(key)
		var uses: int = int(counts[key])
		if uses <= 0:
			continue

		var label := Label.new()
		label.text = "NML %d" % uses
		label.scale = Vector2(0.7, 0.7)
		label.z_index = 650

		var pos := Vector2.ZERO
		if pieces != null:
			pos = no_mans_land_layer.to_local(pieces.point_slot_global(point, 0))
		label.position = pos + Vector2(-12, -10)
		no_mans_land_layer.add_child(label)
		_no_mans_land_labels[point] = label

func set_stopgap_points(points: Array) -> void:
	if stopgap_layer == null:
		return

	for key in _stopgap_labels.keys():
		var label: Label = _stopgap_labels[key] as Label
		if is_instance_valid(label):
			label.queue_free()
	_stopgap_labels.clear()

	for entry in points:
		var point: int = int(entry)
		if point < 0 or point > 23:
			continue

		var label := Label.new()
		label.text = "Stopgap"
		label.scale = Vector2(0.7, 0.7)
		label.z_index = 645

		var pos := Vector2.ZERO
		if pieces != null:
			pos = stopgap_layer.to_local(pieces.point_slot_global(point, 0))
		label.position = pos + Vector2(-18, -22)
		stopgap_layer.add_child(label)
		_stopgap_labels[point] = label

func set_wormhole_points(points: Array) -> void:
	if wormhole_layer == null:
		return

	for key in _wormhole_labels.keys():
		var label: Label = _wormhole_labels[key] as Label
		if is_instance_valid(label):
			label.queue_free()
	_wormhole_labels.clear()

	for entry in points:
		var point: int = int(entry)
		if point < 0 or point > 23:
			continue

		var label := Label.new()
		label.text = "W"
		label.scale = Vector2(0.8, 0.8)
		label.z_index = 642

		var pos := Vector2.ZERO
		if pieces != null:
			pos = wormhole_layer.to_local(pieces.point_slot_global(point, 0))
		label.position = pos + Vector2(-6, -10)
		wormhole_layer.add_child(label)
		_wormhole_labels[point] = label

func set_overwatch_active(active: bool) -> void:
	if overwatch_label == null:
		return
	overwatch_label.visible = active

func set_detente_active(active: bool) -> void:
	if detente_label == null:
		return
	detente_label.visible = active

func set_friction_active(active: bool, turns_left: int) -> void:
	if friction_label == null:
		return
	friction_label.visible = active
	if active:
		friction_label.text = "Friction (%d)" % maxi(1, int(turns_left))

func animate_move_persistent(state: BoardState, move: Dictionary, player: int, done: Callable) -> void:
	input.set_enabled(false)

	var is_white: bool = (player == BoardState.Player.WHITE)
	var from_i: int = int(move["from"])
	var to_i: int = int(move["to"])
	var hit: bool = bool(move.get("hit", false))

	# Determine moving checker id (top of source stack)
	var moving_id: int = -1
	if from_i == -1:
		var bar: PackedInt32Array = state.bar_white if is_white else state.bar_black
		if bar.size() == 0:
			input.set_enabled(true)
			return
		moving_id = bar[bar.size() - 1]
	else:
		var src: PackedInt32Array = state.points[from_i]
		if src.size() == 0:
			input.set_enabled(true)
			return
		moving_id = src[src.size() - 1]

	var moving_node: Node2D = pieces.get_piece(moving_id)
	if moving_node == null:
		input.set_enabled(true)
		return

	# Hit animation (parallel)
	if hit and to_i >= 0 and to_i <= 23:
		var dst: PackedInt32Array = state.points[to_i]
		if dst.size() == 1:
			var hit_id: int = dst[0]
			var hit_node: Node2D = pieces.get_piece(hit_id)
			if hit_node != null:
				var opp_is_white: bool = (state.owner_of(hit_id) == BoardState.Player.WHITE)
				var opp_bar_size: int = (state.bar_white.size() if opp_is_white else state.bar_black.size())
				var bar_pos: Vector2 = pieces.bar_slot_global(opp_is_white, opp_bar_size)
				hit_node.z_index = 2000
				animator.fly_to(hit_node, bar_pos, 0.20, func() -> void:
					pass
				)

	# Landing position
	if to_i >= 0 and to_i <= 23:
		var dst_size: int = state.points[to_i].size()
		var landing_index: int = dst_size - (1 if hit else 0) # if hit blot, it leaves first
		landing_index = max(0, landing_index)

		var end_pos: Vector2 = pieces.point_slot_global(to_i, landing_index)
		var dir: Vector2 = pieces.point_stack_dir_global(to_i)

		moving_node.z_index = 2001
		animator.fly_to_with_bounce(
			moving_node, end_pos, dir,
			0.20, 10.0, 0.10,
			func() -> void:
				input.set_enabled(true)
				if done.is_valid():
					done.call()
		)
		return

	# Bear off
	if (is_white and to_i == 24) or ((not is_white) and to_i == -2):
		var off_size: int = (state.off_white.size() if is_white else state.off_black.size())
		var off_pos: Vector2 = pieces.off_slot_global(is_white, off_size)
		moving_node.z_index = 2001
		animator.fly_to(moving_node, off_pos, 0.20, func() -> void:
			input.set_enabled(true)
			if done.is_valid():
				done.call()
		)
		return

	input.set_enabled(true)
	
func _on_bar_input_event(viewport: Viewport, event: InputEvent, shape_idx: int, player: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("bar_clicked", player)
