#extends Control
#class_name AuxCardsHUD
#
#@export var round_controller_path: NodePath = NodePath("../..")
#@export var poll_interval: float = 0.10
#
#@onready var list_box: VBoxContainer = $Panel/VBox/List
#@onready var debug_label: Label = get_node_or_null("Panel/VBox/Debug") as Label
#
#var _accum: float = 0.0
#var _round: RoundController = null
#
## aux_id -> Button
#var _buttons: Dictionary = {}
#var _last_unlocked_ids: PackedStringArray = PackedStringArray()
#
#func _ready() -> void:
	#_round = get_node_or_null(round_controller_path) as RoundController
	#if _round == null:
		#push_error("[AuxCardsHUD] Could not find RoundController at: " + str(round_controller_path))
#
#func _process(delta: float) -> void:
	#_accum += delta
	#if _accum < poll_interval:
		#return
	#_accum = 0.0
	#_refresh()
#
#func _refresh() -> void:
	#if _round == null:
		#return
	#if _round.run_state == null or _round.run_state.skill_state == null:
		#_set_debug("No run_state / skill_state")
		#_rebuild_if_needed(PackedStringArray())
		#return
#
	#var ss: RunSkillState = _round.run_state.skill_state
	#var unlocked_ids := _get_unlocked_aux_ids(ss)
#
	#_rebuild_if_needed(unlocked_ids)
	#_update_buttons(ss)
#
	## Optional debug text (node levels)
	#if debug_label != null:
		#debug_label.text = "Nodes: " + str(ss.node_levels)
#
#func _get_unlocked_aux_ids(ss: RunSkillState) -> PackedStringArray:
	#var ids: Array[String] = []
	#for k in ss.aux_unlocked.keys():
		#var aux_id: String = String(k)
		#var copies: int = int(ss.aux_unlocked.get(aux_id, 0))
		#if copies > 0:
			#ids.append(aux_id)
	#ids.sort()
	#var out := PackedStringArray()
	#for a in ids:
		#out.append(a)
	#return out
#
#func _rebuild_if_needed(unlocked_ids: PackedStringArray) -> void:
	## Only rebuild if the set of unlocked aux changes
	#if unlocked_ids == _last_unlocked_ids:
		#return
#
	#_last_unlocked_ids = unlocked_ids
	#_buttons.clear()
#
	## Clear children of List
	#for c in list_box.get_children():
		#c.queue_free()
#
	## Create one button per aux
	#for aux_id in unlocked_ids:
		#var btn := Button.new()
		#btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#btn.text = aux_id
		#btn.pressed.connect(Callable(self, "_on_aux_pressed").bind(aux_id))
		#list_box.add_child(btn)
		#_buttons[aux_id] = btn
#
#func _update_buttons(ss: RunSkillState) -> void:
	#for k in _buttons.keys():
		#var aux_id: String = String(k)
		#var btn: Button = _buttons[aux_id] as Button
		#if btn == null:
			#continue
#
		#var def := AuxCardDB.get_def(aux_id)
		#var name := def.display_name if def != null else aux_id
#
		#var copies: int = int(ss.aux_unlocked.get(aux_id, 0))
		#var cd_left: int = int(_round.aux_cd_left.get(aux_id, 0)) if _round != null else 0
		#var uses: int = int(_round.aux_uses_this_round.get(aux_id, 0)) if _round != null else 0
		#var max_uses: int = def.max_uses_per_round if def != null else 999999
#
		#var ap_cost: int = 0
		#if def != null:
			#ap_cost = AuxCardDB.compute_ap_cost(def, ss)
#
		#var can_activate := _can_activate_now(aux_id, def, ss)
#
		## Display string
		#var uses_txt := "%d/%d" % [uses, max_uses] if max_uses < 999999 else str(uses)
		#btn.text = "%s  (x%d)  AP:%d  CD:%d  Uses:%s" % [name, copies, ap_cost, cd_left, uses_txt]
		#btn.disabled = not can_activate
#
#func _can_activate_now(aux_id: String, def: AuxCardDef, ss: RunSkillState) -> bool:
	#if _round == null:
		#return false
	#if not _round.round_active:
		#return false
	#if _round.skill_tree_blocking:
		#return false
	#if _round.targeting_active:
		#return false
#
	## unlocked?
	#if int(ss.aux_unlocked.get(aux_id, 0)) <= 0:
		#return false
#
	## def exists?
	#if def == null:
		#return false
#
	## cooldown?
	#var cd_left: int = int(_round.aux_cd_left.get(aux_id, 0))
	#if cd_left > 0:
		#return false
#
	## uses per round?
	#var uses: int = int(_round.aux_uses_this_round.get(aux_id, 0))
	#if uses >= int(def.max_uses_per_round):
		#return false
#
	## ap?
	#var cost := AuxCardDB.compute_ap_cost(def, ss)
	#if _round.ap_left < cost:
		#return false
#
	#return true
#
#func _on_aux_pressed(aux_id: String) -> void:
	#if _round == null:
		#return
	#_round.request_activate_aux(aux_id)
#
#func _set_debug(t: String) -> void:
	#if debug_label != null:
		#debug_label.text = t



extends Control
class_name AuxCardsHUD

@export var round_controller_path: NodePath = NodePath("../..")
@export var poll_interval: float = 0.10
@export var max_slots: int = 6
@export var slot_scene: PackedScene

@onready var slots: HBoxContainer = $Panel/Slots

var _round: RoundController = null
var _accum: float = 0.0
var _slot_nodes: Array[AuxCardSlot] = []

func _ready() -> void:
	_round = get_node_or_null(round_controller_path) as RoundController
	if _round == null:
		push_error("[AuxCardsHUD] Could not find RoundController at: " + str(round_controller_path))
		return

	_build_slots()

func _process(delta: float) -> void:
	_accum += delta
	if _accum < poll_interval:
		return
	_accum = 0.0
	_refresh()

func _build_slots() -> void:
	for c in slots.get_children():
		c.queue_free()
	_slot_nodes.clear()

	if slot_scene == null:
		push_error("[AuxCardsHUD] slot_scene not set")
		return

	for i: int in range(max_slots):
		var inst: Node = slot_scene.instantiate()
		var slot: AuxCardSlot = inst as AuxCardSlot
		if slot == null:
			push_error("[AuxCardsHUD] slot_scene is not AuxCardSlot")
			return
		slots.add_child(slot)
		_slot_nodes.append(slot)

func _refresh() -> void:
	if _round == null or _round.run_state == null or _round.run_state.skill_state == null:
		return

	var ss: RunSkillState = _round.run_state.skill_state
	var loadout: Array[String] = _compute_loadout(ss, max_slots)

	for i: int in range(_slot_nodes.size()):
		var slot: AuxCardSlot = _slot_nodes[i]
		if i >= loadout.size() or loadout[i] == "":
			slot.visible = false
			continue

		slot.visible = true
		# Bind once, but safe to rebind each refresh for MVP simplicity
		slot.bind(_round, loadout[i], i)
		slot.refresh()

func _compute_loadout(ss: RunSkillState, limit: int) -> Array[String]:
	# Auto-fill from unlocked aux ids (stable sorted), expanding copies into
	# separate HUD slots so copy #2 becomes a second visible card.
	#
	# We encode each slot as "aux_id#copy_idx" (e.g. "aux_attack_boost#0").
	var keys: Array[String] = []
	var ids: Array[String] = []
	for k in ss.aux_unlocked.keys():
		var aux_id: String = String(k)
		var copies: int = int(ss.aux_unlocked.get(aux_id, 0))
		if copies > 0:
			ids.append(aux_id)
	ids.sort()

	for aux_id in ids:
		var copies2: int = int(ss.aux_unlocked.get(aux_id, 0))
		for ci: int in range(copies2):
			keys.append("%s#%d" % [aux_id, ci])

	if keys.size() > limit:
		keys = keys.slice(0, limit)

	return keys
