extends Control
class_name AuxCardSlot

signal pressed(aux_id: String)

@onready var btn: TextureButton = $Button
@onready var shade: ColorRect = $CooldownShade
@onready var ap_label: Label = $AP
@onready var cd_label: Label = $CD
@onready var uses_label: Label = $Uses
@onready var key_label: Label = $Key

@onready var name_label: Label = $Name


var aux_id: String = ""         # base id (e.g. "aux_attack_boost")
var copy_idx: int = 0            # which copy (0-based)
var aux_key: String = ""        # encoded key (e.g. "aux_attack_boost#1")
var slot_index: int = 0
var _round: RoundController = null

func bind(round: RoundController, new_aux_id: String, new_slot_index: int) -> void:
	_round = round
	aux_key = new_aux_id
	aux_id = new_aux_id
	copy_idx = 0
	# Support multiple visible copies by encoding keys as "aux_id#copy_idx".
	if aux_key.find("#") != -1:
		var parts: PackedStringArray = aux_key.split("#")
		if parts.size() >= 1:
			aux_id = String(parts[0])
		if parts.size() >= 2:
			copy_idx = int(parts[1])
	slot_index = new_slot_index

	if key_label != null:
		key_label.text = str(slot_index + 1)

	# Avoid double-connecting
	if not btn.pressed.is_connected(Callable(self, "_on_pressed")):
		btn.pressed.connect(Callable(self, "_on_pressed"))

	_refresh_static()
	refresh()

func _refresh_static() -> void:
	if _round == null or _round.run_state == null or _round.run_state.skill_state == null:
		return

	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		btn.texture_normal = null
		btn.tooltip_text = aux_id
		return
		
	
	if def != null and name_label != null:
		name_label.text = def.display_name
	elif name_label != null:
		name_label.text = aux_id


	btn.texture_normal = def.icon
	btn.tooltip_text = "%s\n%s" % [def.display_name, def.description]

func refresh() -> void:
	if _round == null or _round.run_state == null or _round.run_state.skill_state == null:
		_apply_visual_state(false, 0)
		ap_label.text = "AP -"
		cd_label.text = "CD -"
		uses_label.text = "-"
		return

	var ss: RunSkillState = _round.run_state.skill_state
	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		_apply_visual_state(false, 0)
		ap_label.text = "AP ?"
		cd_label.text = "CD ?"
		uses_label.text = "?"
		return

	var copies: int = int(ss.aux_unlocked.get(aux_id, 0))
	if copies <= 0:
		_apply_visual_state(false, 0)
		ap_label.text = "AP %d" % def.base_ap_cost
		cd_label.text = "CD %d" % def.base_cooldown_turns
		uses_label.text = "0"
		return

	var ap_cost: int = int(AuxCardDB.compute_ap_cost(def, ss))
	var cd_max: int = int(AuxCardDB.compute_cooldown(def, ss))
	# Cooldown and uses are tracked per copy.
	var cd_left: int = _round.get_aux_cd_left(aux_id, copy_idx) if _round.has_method("get_aux_cd_left") else _round.get_aux_cd_display(aux_id)
	var uses: int = _round.get_aux_uses_copy(aux_id, copy_idx) if _round.has_method("get_aux_uses_copy") else int(_round.aux_uses_this_round.get(aux_id, 0))
	var max_uses: int = int(def.max_uses_per_round)
	if max_uses <= 0:
		max_uses = 999999

	ap_label.text = "AP %d" % ap_cost
	# Show max cooldown when ready, and remaining/max when on cooldown.
	cd_label.text = ("CD %d" % cd_max) if cd_left <= 0 else ("CD %d/%d" % [cd_left, cd_max])
	uses_label.text = ("%d/%d" % [uses, max_uses]) if (max_uses > 0 and max_uses < 999999) else str(uses)

	if def != null and name_label != null:
		name_label.text = def.display_name
	elif name_label != null:
		name_label.text = aux_id
		
	var base_name: String = def.display_name if def != null else aux_id
	var tier: int = SkillTreeDefs.get_aux_upgrade_tier(ss, aux_id)

	var display_name: String = base_name
	if tier > 0:
		display_name = "%s %s" % [base_name, "+".repeat(tier)] # or use "+%d" if you prefer

	if name_label != null:
		name_label.text = display_name

# Also keep tooltip in sync (Godot 4: tooltip_text)
	btn.tooltip_text = "%s\n%s" % [display_name, def.description]

		
		

	var can: bool = _can_activate(def, ss, ap_cost, cd_left, uses, max_uses)
	_apply_visual_state(can, cd_left)

func _can_activate(def: AuxCardDef, ss: RunSkillState, ap_cost: int, cd_left: int, uses: int, max_uses: int) -> bool:
	if _round == null:
		return false
	if not _round.round_active:
		return false
	if _round.skill_tree_blocking:
		return false
	if _round.targeting_active:
		return false
	if ap_cost > _round.ap_left:
		return false
	if cd_left > 0:
		return false
	if uses >= max_uses:
		return false
	return true

func _apply_visual_state(can_activate: bool, cd_left: int) -> void:
	btn.disabled = not can_activate
	shade.visible = (cd_left > 0)

	# Dim if disabled
	var a: float = 1.0 if can_activate else 0.55
	modulate = Color(1, 1, 1, a)

func _on_pressed() -> void:
	if _round == null:
		return
	if _round.has_method("request_activate_aux_copy"):
		_round.request_activate_aux_copy(aux_id, copy_idx)
	else:
		_round.request_activate_aux(aux_id)
	emit_signal("pressed", aux_id)
