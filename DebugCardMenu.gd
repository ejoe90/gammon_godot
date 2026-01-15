extends CanvasLayer
class_name DebugCardMenu

# Debug card picker for the dynamic-hand architecture (RoundController emits hand_changed)

@export var hand_hud_path: NodePath = NodePath("../HUD/HandHUD")
@export var cards_root: String = "res://Resources/cards"

# Use F2 so it doesn't conflict with the dice debug menu.
@export var toggle_key: Key = KEY_F2

# Layout
@export var panel_position: Vector2 = Vector2(20, 20)
@export var panel_size: Vector2 = Vector2(520, 260)

@onready var panel: Control = $Panel

# UI nodes expected in the scene
@onready var filter_edit: LineEdit = $Panel/Root/Filter
@onready var picker: OptionButton = $Panel/Root/CardPick
@onready var slot_spin: SpinBox = $Panel/Root/Row/Slot
@onready var set_btn: Button = $Panel/Root/Row/SetButton
@onready var fill_btn: Button = $Panel/Root/Row/FillButton
@onready var clear_btn: Button = $Panel/Root/Row/ClearButton
@onready var info: Label = $Panel/Root/Info

var hand_hud: HandHUD
var round: RoundController

var all_defs: Array[CardDef] = []
var filtered_defs: Array[CardDef] = []

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer = 50
	set_process_input(true)

	_fix_panel_layout()

	hand_hud = get_node_or_null(hand_hud_path) as HandHUD
	if hand_hud == null:
		var root0: Node = get_tree().current_scene
		if root0 != null:
			hand_hud = root0.find_child("HandHUD", true, false) as HandHUD

	round = _find_round_controller()

	visible = false

	filter_edit.text_changed.connect(func(_t: String) -> void: _rebuild_picker())
	set_btn.pressed.connect(_on_set_slot)
	fill_btn.pressed.connect(_on_fill_slots)
	clear_btn.pressed.connect(_on_clear_slots)

	_refresh_cards()
	_rebuild_picker()
	_sync_hand_info()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.keycode == toggle_key:
			visible = not visible
			if visible:
				_sync_hand_info()
				filter_edit.grab_focus()
			get_viewport().set_input_as_handled()

func _fix_panel_layout() -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _find_round_controller() -> RoundController:
	# Prefer grabbing from typed HandHUD (avoids Variant typing warnings)
	if hand_hud != null and hand_hud.round != null:
		return hand_hud.round

	var root: Node = get_tree().current_scene
	if root != null:
		var found: RoundController = root.find_child("RoundController", true, false) as RoundController
		if found != null:
			return found

	return null

func _refresh_cards() -> void:
	all_defs.clear()
	_collect_card_defs(cards_root, all_defs)

	all_defs.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		if a.title == b.title:
			return a.id < b.id
		return a.title < b.title
	)

func _collect_card_defs(dir_path: String, out: Array[CardDef]) -> void:
	for f: String in DirAccess.get_files_at(dir_path):
		if not f.ends_with(".tres"):
			continue
		var p: String = dir_path + "/" + f
		var def: CardDef = load(p) as CardDef
		if def != null:
			out.append(def)

	for d: String in DirAccess.get_directories_at(dir_path):
		_collect_card_defs(dir_path + "/" + d, out)

func _rebuild_picker() -> void:
	var q: String = filter_edit.text.strip_edges().to_lower()

	filtered_defs.clear()
	picker.clear()

	for def: CardDef in all_defs:
		var label: String = "%s  (%s)" % [def.title, def.id]
		if q == "" or label.to_lower().find(q) != -1:
			filtered_defs.append(def)
			picker.add_item(label)

	if picker.item_count > 0:
		picker.select(0)

	_sync_hand_info()

func _get_selected_def() -> CardDef:
	var idx: int = picker.selected
	if idx < 0 or idx >= filtered_defs.size():
		return null
	return filtered_defs[idx]

func _hand_target_size() -> int:
	var target: int = 5
	if round != null and ("hand_size" in round):
		target = maxi(1, int(round.hand_size))
	return target

func _hand_current_size() -> int:
	if round != null:
		if round.has_method("get_hand"):
			var h_any: Variant = round.call("get_hand")
			var h: Array = h_any as Array
			return h.size()
	return 0

func _sync_hand_info() -> void:
	if round == null:
		round = _find_round_controller()

	var target: int = _hand_target_size()
	var current: int = _hand_current_size()

	slot_spin.min_value = 0
	slot_spin.max_value = max(0, target - 1)

	info.text = "Hand: %d / %d    Cards shown: %d    (toggle: F2)" % [current, target, filtered_defs.size()]

func _call_debug(method_name: String, args: Array) -> bool:
	# Prefer HandHUD wrappers if present; otherwise call RC directly.
	if hand_hud != null and hand_hud.has_method(method_name):
		hand_hud.callv(method_name, args)
		return true
	if round != null and round.has_method(method_name):
		round.callv(method_name, args)
		return true
	return false

# -------------------------
# Buttons
# -------------------------

func _on_set_slot() -> void:
	var def: CardDef = _get_selected_def()
	if def == null:
		info.text = "Select a card first."
		return

	var idx: int = int(slot_spin.value)
	if not _call_debug("debug_set_hand_index", [idx, def]):
		info.text = "Missing debug_set_hand_index() on HandHUD/RoundController."
		return

	_sync_hand_info()
	info.text = "Set slot %d -> %s" % [idx, def.id]

func _on_fill_slots() -> void:
	var def: CardDef = _get_selected_def()
	if def == null:
		info.text = "Select a card first."
		return

	# Use -1 to mean "use default hand_size" if your RC supports it.
	if not _call_debug("debug_fill_hand", [def, -1]):
		# Fallback: set every index manually
		var target: int = _hand_target_size()
		for i: int in range(target):
			if not _call_debug("debug_set_hand_index", [i, def]):
				info.text = "Missing debug_fill_hand() and debug_set_hand_index()."
				return

	_sync_hand_info()
	info.text = "Filled all slots with %s" % def.id

func _on_clear_slots() -> void:
	if not _call_debug("debug_clear_hand", []):
		info.text = "Missing debug_clear_hand() on HandHUD/RoundController."
		return

	_sync_hand_info()
	info.text = "Cleared hand"
