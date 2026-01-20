extends Node
class_name SkillTreeManager

signal request_open(options: Array, picks_allowed: int)
signal selection_confirmed(chosen_ids: Array, gold_spent: int)

@export var thresholds: PackedFloat32Array = PackedFloat32Array([0.90, 0.75, 0.50]) # remaining ratio triggers
@export var options_shown: int = 5

@export var picks_base: int = 1
@export var picks_max: int = 2

@export var allow_buy_extra_pick: bool = true
@export var buy_pick_cost: int = 20

var _start_pips: int = 1
var _fired: Dictionary = {}          # key: String(threshold) -> bool
var _active: bool = false
var _picks_allowed: int = 0
var _gold_spent: int = 0

var _skill_state: RunSkillState = null

func begin_round(start_pips: int, skill_state: RunSkillState) -> void:
	_start_pips = max(1, start_pips)
	_skill_state = skill_state

	_fired.clear()
	for t in thresholds:
		_fired[str(t)] = false
	_active = false
	_picks_allowed = clampi(picks_base, 1, picks_max)
	_gold_spent = 0

func on_pips_updated(current_pips: int) -> void:
	if _active:
		return

	var ratio := float(current_pips) / float(_start_pips)
	for t in thresholds:
		var k := str(t)
		if ratio <= t and not bool(_fired.get(k, false)):
			_fired[k] = true
			_open()
			return

func _open() -> void:
	_active = true
	_picks_allowed = clampi(picks_base, 1, picks_max)

	var options := SkillTreeDefs.pick_available_options(_skill_state, options_shown)
	emit_signal("request_open", options, _picks_allowed)

func try_buy_extra_pick(current_gold: int) -> bool:
	if not _active:
		return false
	if not allow_buy_extra_pick:
		return false
	if _picks_allowed >= picks_max:
		return false
	if current_gold < buy_pick_cost:
		return false

	_picks_allowed += 1
	_gold_spent += buy_pick_cost
	return true

func get_picks_allowed() -> int:
	return _picks_allowed

func confirm_selection(chosen_ids: Array) -> void:
	# Enforce cap defensively
	if chosen_ids.size() > _picks_allowed:
		chosen_ids = chosen_ids.slice(0, _picks_allowed)

	_active = false
	emit_signal("selection_confirmed", chosen_ids, _gold_spent)

# -------------------------
# Debug helpers
# -------------------------

# Opens the selection overlay immediately, ignoring pips thresholds.
# Intended for testing node upgrades quickly.
func debug_force_open(skill_state: RunSkillState, picks_override: int = -1) -> void:
	if skill_state == null:
		return
	_skill_state = skill_state
	_active = true
	_gold_spent = 0
	if picks_override > 0:
		_picks_allowed = clampi(int(picks_override), 1, picks_max)
	else:
		_picks_allowed = clampi(picks_base, 1, picks_max)

	var options := SkillTreeDefs.pick_available_options(_skill_state, options_shown)
	emit_signal("request_open", options, _picks_allowed)
