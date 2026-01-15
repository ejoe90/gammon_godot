extends Node
class_name RoundController

signal round_won()
signal round_lost()
signal round_restarted()

signal hand_changed(hand: Array[CardInstance])

@export var hand_size: int = 5
var hand: Array[CardInstance] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []

# --- Phase 2 targeting/card signals (Step 2.5) ---
signal card_consumed(card_uid: int)
signal targeting_started()
signal targeting_ended()

# Assign in inspector (e.g., win_bearoff.tres)
@export var win_conditions: Array[WinCondition] = []

# --- Phase 2 AP (Step 2.5) ---
@export var base_ap_per_turn: int = 2
var ap_left: int = 0

# --- Phase 2 targeting state (Step 2.5) ---
var targeting_active: bool = false
var targeting_required_half: int = -1   # 0 = low (0..11), 1 = high (12..23)
var targeting_enemy: int = BoardState.Player.BLACK
var targeting_consume_uid: int = -1
var targeting_damage_enemy: int = 0
var targeting_max_stack_hits: int = 1
var targeting_card_uid: int = -1
var targeting_card_id: String = ""

var aux_cd_left: Dictionary = {}          # aux_id -> turns remaining
var aux_uses_this_round: Dictionary = {}  # aux_id -> uses
var aux_uses_by_copy: Dictionary = {}     # aux_id -> Array[int] (per-copy uses)
var aux_used_this_turn: Dictionary = {}  # aux_id -> bool (per WHITE turn)


# Scene expectations (RoundScene root):
@onready var board: Node = $BoardView
@onready var board_input: Node = get_node_or_null("BoardView/BoardInput")
@onready var dice: Node = $Dice
@onready var dice_ui: Node = get_node_or_null("HUD/DiceUI")
@onready var round_end: Node = get_node_or_null("HUD/RoundEndOverlay")
@onready var debug_menu: DebugMenu = get_node_or_null("DebugMenu") as DebugMenu

# --- Skill tree wiring (MVP) ---
@onready var skill_tree: SkillTreeManager = get_node_or_null("SkillTreeManager") as SkillTreeManager
@onready var skill_overlay: SkillTreeOverlay = get_node_or_null("HUD/SkillTreeOverlay") as SkillTreeOverlay
var skill_tree_blocking: bool = false
var _skill_tree_pending_post_move: bool = false






var run_state: RunState = null
var state: BoardState = null

var selected_from: int = -999 # -1 bar, 0..23 point, -999 none
var round_active: bool = false

enum RoundResult { NONE, PLAYER_WIN, ENEMY_WIN }
var last_result: int = RoundResult.NONE

signal notice(text: String)

var turn_hit_victims_by_attacker: Dictionary = {}
var turn_double_down_ready: bool = false

# --- Pip Boost choice prompt (Tier 1+) ---
var _pip_choice_menu: PopupMenu = null
var _pip_choice_pending: Dictionary = {} # {options:Array, include_bonus:bool, label:String, applied:bool}


@export var ai_enabled: bool = true
@export var ai_step_delay_sec: float = 0.20
@export var ai_turn_start_delay_sec: float = 0.60

var black_turn_index: int = 0
var _ai_running: bool = false

@onready var ai: AIController = get_node_or_null("AIController")


func _is_black_ai_turn_active() -> bool:
	return _ai_running and ai_enabled and state != null and state.turn == BoardState.Player.BLACK




func _pip_boost_hp_convert_unlocked() -> bool:
	if run_state == null or run_state.skill_state == null:
		return false
	var mod: Dictionary = run_state.skill_state.get_aux_mod("aux_pip_boost")
	return bool(mod.get("pip_hp_convert_enabled", false))

func _maybe_pip_boost_convert_to_hp(label: String = "Pip Boost") -> bool:
	# Converts dice pips into HP (5 pips = 1 HP) and ends the turn.
	# Gated by the Pip tree tier3-B1 unlock, and controlled by a run_state toggle.
	if run_state == null:
		return false
	if not _pip_boost_hp_convert_unlocked():
		return false
	if not bool(run_state.pip_convert_to_hp):
		return false
	if dice == null:
		return false

	var total_pips: int = 0
	for v in dice.remaining:
		total_pips += absi(int(v))

	var hp_gain: int = int(total_pips / 5)
	var healed: int = 0
	if hp_gain > 0:
		healed = int(run_state.add_player_hp_overcap(hp_gain)) if run_state.has_method("add_player_hp_overcap") else int(run_state.add_player_hp(hp_gain))

	# Consume dice regardless of hp_gain.
	if dice.has_method("clear_remaining"):
		dice.call("clear_remaining")
	else:
		dice.remaining.clear()
		if "remaining_is_bonus" in dice:
			dice.remaining_is_bonus.clear()

	if has_method("_update_dice_ui"):
		call("_update_dice_ui")
	show_notice("%s: Converted %d pips into %d HP." % [label, total_pips, healed])
	end_turn()
	return true

func _pip_ui_parent() -> Node:
	var hud: Node = get_node_or_null("HUD")
	return hud if hud != null else self

func _ensure_pip_choice_menu() -> void:
	if _pip_choice_menu != null:
		return
	_pip_choice_menu = PopupMenu.new()
	_pip_choice_menu.name = "PipChoiceMenu"
	_pip_ui_parent().add_child(_pip_choice_menu)
	_pip_choice_menu.id_pressed.connect(Callable(self, "_on_pip_choice_id_pressed"))
	_pip_choice_menu.popup_hide.connect(Callable(self, "_on_pip_choice_menu_hide"))

# Shows a simple popup allowing the player to select the pip bonus amount for Pip Boost.
# If the popup is dismissed without a selection, the default option (first) is applied.
func request_pip_boost_choice(options: Array[int], include_bonus_dice: bool, label: String = "Pip Boost") -> void:
	if options.is_empty():
		return
	_ensure_pip_choice_menu()

	_pip_choice_pending = {
		"options": options.duplicate(),
		"include_bonus": bool(include_bonus_dice),
		"label": String(label),
		"applied": false,
	}

	skill_tree_blocking = true

	_pip_choice_menu.clear()
	for b in options:
		_pip_choice_menu.add_item("+%d" % int(b), int(b))
	_pip_choice_menu.add_separator()
	_pip_choice_menu.add_item("Default (+%d)" % int(options[0]), -1)
	_pip_choice_menu.popup_centered()

func _on_pip_choice_id_pressed(id: int) -> void:
	if _pip_choice_pending.is_empty():
		return
	if int(id) <= 0:
		_apply_pip_choice_default()
	else:
		_apply_pip_choice(int(id))

func _on_pip_choice_menu_hide() -> void:
	if _pip_choice_pending.is_empty():
		return
	if bool(_pip_choice_pending.get("applied", false)):
		return
	# PopupMenu signal order can be platform-dependent; `popup_hide` may fire
	# before `id_pressed`. Defer applying the default so a valid selection can
	# be processed first.
	call_deferred("_apply_pip_choice_default")

func _apply_pip_choice_default() -> void:
	var opts: Array = _pip_choice_pending.get("options", [])
	if opts.is_empty():
		_pip_choice_pending.clear()
		skill_tree_blocking = false
		return
	_apply_pip_choice(int(opts[0]))

func _apply_pip_choice(bonus: int) -> void:
	bonus = maxi(0, int(bonus))
	var include_bonus: bool = bool(_pip_choice_pending.get("include_bonus", true))
	var label: String = String(_pip_choice_pending.get("label", "Pip Boost"))

	_pip_choice_pending["applied"] = true
	skill_tree_blocking = false

	var extra_dice: int = 0
	var did_dup: bool = false

	if dice != null and dice.has_method("apply_pip_bonus"):
		dice.call("apply_pip_bonus", bonus, include_bonus)

		# Tier 2+ (Pips tree): roll bonus dice AFTER pip bonus is applied.
		if run_state != null and run_state.skill_state != null:
			var _m := run_state.skill_state.get_aux_mod("aux_pip_boost")
			extra_dice = maxi(0, int(_m.get("pip_extra_dice", 0)))
		if extra_dice > 0 and dice.has_method("add_bonus_die"):
			for _i in range(extra_dice):
				dice.call("add_bonus_die", randi_range(1, 6))

		# Tier 4B (Pips): duplicate each available die AFTER bonus dice are rolled.
		if run_state != null and run_state.skill_state != null:
			var _m2 := run_state.skill_state.get_aux_mod("aux_pip_boost")
			if bool(_m2.get("pip_dice_dup_enabled", false)) and dice != null and dice.has_method("duplicate_all"):
				dice.call("duplicate_all")
				did_dup = true

		if has_method("_update_dice_ui"):
			call("_update_dice_ui")

	var _msg := "%s: +%d to all dice" % [label, bonus]
	if extra_dice > 0:
		_msg += " (+%d bonus die)" % extra_dice
	if did_dup:
		_msg += " (x2 dice)"
	show_notice(_msg)
	_pip_choice_pending.clear()
	# Tier 3B1 (Pips): optional conversion of dice pips into HP, which ends the turn.
	_maybe_pip_boost_convert_to_hp(label)


func show_notice(text: String) -> void:
	emit_signal("notice", text)

func compute_player_damage(base_damage: int, include_base_attack: bool = true) -> int:
	if run_state == null:
		return 0
	var dmg: int = int(base_damage)
	if include_base_attack:
		dmg += maxi(0, int(run_state.base_attack_power))
	dmg = maxi(0, dmg)
	var mult: int = maxi(1, int(run_state.player_attack_mult))
	return dmg * mult

func deal_enemy_damage(base_damage: int, include_base_attack: bool = true) -> int:
	if run_state == null:
		return 0
	var dealt: int = compute_player_damage(base_damage, include_base_attack)
	run_state.enemy_hp = maxi(0, int(run_state.enemy_hp) - dealt)
	return dealt

func _reset_turn_combos() -> void:
	turn_hit_victims_by_attacker.clear()
	turn_double_down_ready = false

func _record_turn_hit_if_any(move: Dictionary, player: int) -> void:
	# Only track WHITE hits on BLACK for this card.
	if player != BoardState.Player.WHITE:
		return
	if not bool(move.get("hit", false)):
		return

	var to_i: int = int(move.get("to", -999))
	if to_i < 0 or to_i > 23:
		return

	# Victim is the single checker currently on dst (pre-move).
	var dst: PackedInt32Array = state.points[to_i]
	if dst.size() != 1:
		return

	var victim_id: int = int(dst[0])
	if state.owner_of(victim_id) != BoardState.Player.BLACK:
		return

	# Attacker is the top checker on src (or bar) pre-move.
	var from_i: int = int(move.get("from", -999))
	var attacker_id: int = -1

	if from_i == -1:
		var bar: PackedInt32Array = state.bar_white
		if bar.size() == 0:
			return
		attacker_id = int(bar[bar.size() - 1])
	else:
		var src: PackedInt32Array = state.points[from_i]
		if src.size() == 0:
			return
		attacker_id = int(src[src.size() - 1])

	var arr: PackedInt32Array
	if turn_hit_victims_by_attacker.has(attacker_id):
		arr = turn_hit_victims_by_attacker[attacker_id]
	else:
		arr = PackedInt32Array()

	if arr.find(victim_id) == -1:
		arr.append(victim_id)
		turn_hit_victims_by_attacker[attacker_id] = arr

		if arr.size() >= 2:
			turn_double_down_ready = true


func _ready() -> void:
	randomize()
	# Keep internal hand list in sync when cards are consumed
	card_consumed.connect(_on_card_consumed_internal)

	# Connect click signals (prefer BoardView, fallback to BoardInput)
	if board != null and board.has_signal("point_clicked"):
		board.connect("point_clicked", Callable(self, "_on_point_clicked"))
	elif board_input != null and board_input.has_signal("point_clicked"):
		board_input.connect("point_clicked", Callable(self, "_on_point_clicked"))

	if board != null and board.has_signal("bearoff_clicked"):
		board.connect("bearoff_clicked", Callable(self, "_on_bearoff_clicked"))
	elif board_input != null and board_input.has_signal("bearoff_clicked"):
		board_input.connect("bearoff_clicked", Callable(self, "_on_bearoff_clicked"))

	# --- Phase 2: checker targeting click ---
	if board != null and board.has_signal("checker_clicked"):
		board.connect("checker_clicked", Callable(self, "_on_checker_clicked"))
	if board != null and board.has_signal("bar_clicked"):
		board.connect("bar_clicked", Callable(self, "_on_bar_clicked"))

	# Round end overlay buttons (optional)
	if round_end != null:
		if round_end.has_signal("restart_pressed"):
			round_end.connect("restart_pressed", Callable(self, "_on_round_end_restart"))
		if round_end.has_signal("next_pressed"):
			round_end.connect("next_pressed", Callable(self, "_on_round_end_next"))

	# Debug menu hooks (optional)
	if debug_menu != null:
		if debug_menu.has_signal("request_point_delta"):
			debug_menu.connect("request_point_delta", Callable(self, "_on_debug_point_delta"))
		if debug_menu.has_signal("request_point_clear"):
			debug_menu.connect("request_point_clear", Callable(self, "_on_debug_point_clear"))
		if debug_menu.has_signal("request_force_dice"):
			debug_menu.connect("request_force_dice", Callable(self, "_on_debug_force_dice"))
		if debug_menu.has_signal("request_roll_random"):
			debug_menu.connect("request_roll_random", Callable(self, "_on_debug_roll_random"))
		if debug_menu.has_signal("request_setup_home_boards"):
			debug_menu.connect("request_setup_home_boards", Callable(self, "_on_debug_setup_home_boards"))

	# --- Skill tree wiring (MVP) ---
	if skill_tree != null:
		skill_tree.request_open.connect(_on_skill_tree_request_open)
		skill_tree.selection_confirmed.connect(_on_skill_tree_selection_confirmed)

	if skill_overlay != null:
		skill_overlay.buy_extra_pick_requested.connect(_on_skill_tree_buy_extra_pick)
		skill_overlay.confirmed.connect(_on_skill_tree_overlay_confirmed)
		skill_overlay.skipped.connect(_on_skill_tree_overlay_skipped)

# Called by RunController each round
func start_round(rs: RunState) -> void:
	run_state = rs

	if run_state != null:
		run_state.player_attack_mult = 1

	state = BoardState.new()
	state.reset_standard()

	if skill_tree != null:
		if run_state.skill_state == null:
			run_state.skill_state = RunSkillState.new()
		skill_tree.begin_round(get_pips_remaining(BoardState.Player.WHITE), run_state.skill_state)

	selected_from = -999
	last_result = RoundResult.NONE
	round_active = true

	# --- Phase 2 AP reset (Step 2.5) ---
	ap_left = base_ap_per_turn
	hand.clear()
	_reset_card_piles()
	_draw_cards_into_hand(_count_empty_hand_slots())

	# Clear any pending targeting
	targeting_active = false
	targeting_required_half = -1
	targeting_consume_uid = -1

	# Skill tree blocking reset
	skill_tree_blocking = false
	_skill_tree_pending_post_move = false
	if skill_overlay != null:
		skill_overlay.close()

	_set_input_enabled(true)

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	_clear_targets()
	_hide_round_end()
	
	aux_cd_left.clear()
	aux_uses_this_round.clear()
	aux_uses_by_copy.clear()
	aux_used_this_turn.clear()
	
	black_turn_index = 0
	_ai_running = false


	start_turn()

func start_turn() -> void:
	if not round_active:
		return

	_reset_turn_combos()

	selected_from = -999
	_clear_targets()

	if dice != null and dice.has_method("roll"):
		dice.call("roll")

	_update_dice_ui()

	# --- BLACK AI TURN ----------------------------------------------------
	if ai_enabled and ai != null and state != null and state.turn == BoardState.Player.BLACK:
		_start_black_ai_turn()
		return

	# --- WHITE TURN SETUP -------------------------------------------------
	if state != null and state.turn == BoardState.Player.WHITE:
		# IMPORTANT: if BLACK had no moves, input might still be disabled.
		_set_input_enabled(true)

		# New WHITE turn: reset per-turn aux usage gates.
		aux_used_this_turn.clear()
		_draw_cards_into_hand(_count_empty_hand_slots())

		# Tick down aux cooldowns (supports multi-copy arrays).
		for k in aux_cd_left.keys():
			var v: Variant = aux_cd_left[k]
			if v is Array:
				var arr: Array = v as Array
				for i in range(arr.size()):
					arr[i] = maxi(0, int(arr[i]) - 1)
				aux_cd_left[k] = arr
			else:
				aux_cd_left[k] = maxi(0, int(v) - 1)

		# Passive enemy drain (Attack tree): once per WHITE turn.
		if run_state != null and int(run_state.enemy_drain_per_turn) > 0:
			var drain_base: int = int(run_state.enemy_drain_per_turn)
			var drained: int = compute_player_damage(drain_base, false) # NOT affected by Base ATK
			run_state.enemy_hp = maxi(0, int(run_state.enemy_hp) - drained)
			if has_method("show_notice"):
				show_notice("Enemy drained %d HP." % drained)

	# Auto-pass if no legal moves
	if _count_all_legal_moves() == 0:
		end_turn()
		return


func _start_black_ai_turn() -> void:
	if _ai_running or not round_active:
		return
	_ai_running = true

	black_turn_index += 1

	# Apply "speed" (extra dice) first so legal-move checks see them.
	if ai != null and ai.advantage != null and dice != null:
		var extra: int = ai.advantage.extra_dice_count(black_turn_index)
		for _i in range(extra):
			dice.call("add_bonus_die", randi_range(1, 6))
		_update_dice_ui()

	# Disable input while AI plays
	_set_input_enabled(false)

	# If truly no moves, pass.
	if _count_legal_moves_black_ai() == 0:
		_ai_running = false
		end_turn()
		_set_input_enabled(true)
		return

	call_deferred("_black_ai_play")


func _count_legal_moves_black_ai() -> int:
	var total := 0
	if dice == null:
		return 0

	for d in dice.remaining:
		if ai != null and ai.advantage != null:
			total += Rules.legal_moves_for_die_adv(state, BoardState.Player.BLACK, int(d), ai.advantage.bearoff_home_fraction).size()
		else:
			total += Rules.legal_moves_for_die(state, BoardState.Player.BLACK, int(d)).size()

	return total


func _black_ai_play() -> void:
	# Deterministic, no-animation AI turn driver.
	# Goal: always progress the game (never hang on an unconsumed die).
	if not round_active:
		_ai_running = false
		return
	if state == null or state.turn != BoardState.Player.BLACK:
		_ai_running = false
		return

	# Optional: give the player time to see BLACK's dice before moves start.
	if ai_turn_start_delay_sec > 0.0:
		await get_tree().create_timer(ai_turn_start_delay_sec).timeout
		if not round_active or state == null or state.turn != BoardState.Player.BLACK:
			_ai_running = false
			_set_input_enabled(true)
			return

	if dice == null:
		_ai_running = false
		end_turn()
		_set_input_enabled(true)
		return

	# Apply moves one-at-a-time, always based on the current state + current remaining dice.
	await _black_ai_take_turn_no_anim()
func _black_ai_apply_sequence(seq: Array) -> void:
	# Deprecated: older AI sequence runner. Keep for compatibility, but route to the safe driver.
	await _black_ai_take_turn_no_anim()
func _black_ai_animate_and_apply(die_used: int, move: Dictionary) -> void:
	# Animation disabled for stability: commit immediately.
	_apply_move_no_turn_end_safe(die_used, move, BoardState.Player.BLACK)

func _black_ai_take_turn_no_anim() -> void:
	_set_input_enabled(false)

	while true:
		if not round_active:
			_ai_running = false
			_set_input_enabled(true)
			return
		if state == null or state.turn != BoardState.Player.BLACK:
			_ai_running = false
			_set_input_enabled(true)
			return

		# No dice left -> end turn.
		if dice == null or dice.remaining.is_empty():
			break

		# If there are no legal moves for ANY remaining die, pass immediately.
		if _count_legal_moves_black_ai() == 0:
			break

		# Pick the next move to maximize using remaining dice.
		var pick: Dictionary = _black_ai_pick_next_move_maximize_usage()
		if pick.is_empty():
			# Fail-safe: if we couldn't pick, just pass.
			break

		var die_used: int = int(pick.get("die", 0))
		var move: Dictionary = pick.get("move", {})
		if die_used == 0 or move.is_empty():
			break

		# Apply immediately (no animation), consume die, and sync board.
		var applied: bool = _apply_move_no_turn_end_safe(die_used, move, BoardState.Player.BLACK)
		if applied:
			_apply_black_damage_from_move(move)

			# End immediately if player HP hits 0
			if run_state != null and int(run_state.player_hp) <= 0:
				_ai_running = false
				_end_round_from_black_hp_win()
				_set_input_enabled(true)
				return
		else:
			# Move was not applicable (state changed unexpectedly). Recompute on next loop.
			pass

		# Optional pacing (set to 0 for instant).
		if ai_step_delay_sec > 0.0:
			await get_tree().create_timer(ai_step_delay_sec).timeout

	# Finish BLACK turn (even if dice remain but no legal moves).
	_ai_running = false
	end_turn()
	_set_input_enabled(true)


func _apply_move_no_turn_end_safe(die_used: int, move: Dictionary, player: int) -> bool:
	# Validate "from" stack exists before Rules.apply_move to avoid apply_move index -1 crashes.
	if state == null:
		return false
	if not move.has("from") or not move.has("to"):
		return false

	var from_i: int = int(move.get("from", -999))
	if from_i == -1:
		var bar: PackedInt32Array = state.bar_stack(player)
		if bar.size() <= 0:
			return false
	elif from_i >= 0 and from_i <= 23:
		if state.points[from_i].size() <= 0:
			return false
	else:
		return false

	_record_turn_hit_if_any(move, player)
	Rules.apply_move(state, player, move)

	_black_ai_consume_die_safe(die_used)
	_update_dice_ui()

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999

	# Elimination/bear-off check
	if state.count_in_play(BoardState.Player.WHITE) == 0 or state.count_in_play(BoardState.Player.BLACK) == 0:
		_end_round_from_state()
		return true

	# Do NOT end turn here (BLACK driver controls turn end)
	return true


func _black_ai_consume_die_safe(die_used: int) -> void:
	if dice == null:
		return
	if dice.has_method("consume_die"):
		var ok: bool = bool(dice.call("consume_die", die_used))
		if ok:
			return
		# Fallback: remove by magnitude
		ok = bool(dice.call("consume_die", absi(die_used)))
		if ok:
			return
	# Ultimate fallback: drop one remaining die to prevent AI stalling on an unconsumable value.
	if dice.remaining.size() > 0:
		dice.remaining.remove_at(0)
		if dice.remaining_is_bonus.size() > 0:
			dice.remaining_is_bonus.remove_at(0)


func _black_ai_pick_next_move_maximize_usage() -> Dictionary:
	# Returns {"die": int, "move": Dictionary}
	if dice == null or state == null:
		return {}

	var dice_list: Array[int] = dice.remaining.duplicate()

	# If exactly two dice remain and not doubles, try to find a 2-move line that uses both.
	if dice_list.size() == 2 and int(dice_list[0]) != int(dice_list[1]):
		var plan: Array = _black_ai_plan_two_dice_use_both_if_possible(int(dice_list[0]), int(dice_list[1]))
		if plan.size() > 0:
			return plan[0] # first step of plan

	# General case: evaluate all candidate moves and prefer those that preserve future moves.
	var best_score: int = -999999
	var best: Dictionary = {}

	for d in dice_list:
		var moves: Array[Dictionary] = _black_ai_legal_moves_for_die(state, int(d))
		for m in moves:
			var sim: BoardState = _black_ai_clone_state_for_sim(state)
			Rules.apply_move(sim, BoardState.Player.BLACK, m)
			# score = (how many dice remain usable after this move)
			var remaining_after: Array[int] = dice_list.duplicate()
			remaining_after.erase(int(d))
			var future_moves: int = _black_ai_total_legal_moves_for_dice(sim, remaining_after)
			var score: int = future_moves

			# Prefer hits a bit, so AI doesn't feel totally random.
			if bool(m.get("hit", false)):
				score += 5

			if score > best_score:
				best_score = score
				best = {"die": int(d), "move": m}

	if best.is_empty():
		# Absolute fallback: first legal move for any remaining die.
		for d in dice_list:
			var moves2: Array[Dictionary] = _black_ai_legal_moves_for_die(state, int(d))
			if moves2.size() > 0:
				return {"die": int(d), "move": moves2[0]}

	return best


func _black_ai_plan_two_dice_use_both_if_possible(d1: int, d2: int) -> Array:
	# Returns an array of steps: [{"die": d, "move": m}, ...]
	# Tries both orders and returns the first plan that uses both dice.
	var orders: Array = [[d1, d2], [d2, d1]]
	for ord in orders:
		var sim: BoardState = _black_ai_clone_state_for_sim(state)
		var plan: Array = []
		var ok := true
		for die_val in ord:
			var moves: Array[Dictionary] = _black_ai_legal_moves_for_die(sim, int(die_val))
			if moves.is_empty():
				ok = false
				break
			# Choose the move that maximizes remaining moves after it.
			var best_local: Dictionary = moves[0]
			var best_local_score: int = -999999
			for m in moves:
				var sim2: BoardState = _black_ai_clone_state_for_sim(sim)
				Rules.apply_move(sim2, BoardState.Player.BLACK, m)
				var future: int = _black_ai_total_legal_moves_for_dice(sim2, [int(ord[0]), int(ord[1])])
				if bool(m.get("hit", false)):
					future += 5
				if future > best_local_score:
					best_local_score = future
					best_local = m
			plan.append({"die": int(die_val), "move": best_local})
			Rules.apply_move(sim, BoardState.Player.BLACK, best_local)
		if ok and plan.size() == 2:
			# Verify 2nd move is still legal on post-1st state (it should be, we derived it from sim).
			return plan
	return []


func _black_ai_legal_moves_for_die(s: BoardState, die: int) -> Array[Dictionary]:
	if ai != null and ai.advantage != null:
		return Rules.legal_moves_for_die_adv(s, BoardState.Player.BLACK, die, ai.advantage.bearoff_home_fraction)
	return Rules.legal_moves_for_die(s, BoardState.Player.BLACK, die)


func _black_ai_total_legal_moves_for_dice(s: BoardState, dice_vals: Array[int]) -> int:
	var total := 0
	for d in dice_vals:
		total += _black_ai_legal_moves_for_die(s, int(d)).size()
	return total


func _black_ai_clone_state_for_sim(src: BoardState) -> BoardState:
	# Deep-copy only the mutable position stacks (points/bar/off). Checker info dict is shared.
	var c: BoardState = BoardState.new()
	c.turn = src.turn
	c.checkers = src.checkers

	c.points = []
	for i in range(24):
		c.points.append((src.points[i] as PackedInt32Array).duplicate())

	c.bar_white = src.bar_white.duplicate()
	c.bar_black = src.bar_black.duplicate()
	c.off_white = src.off_white.duplicate()
	c.off_black = src.off_black.duplicate()
	return c

func _apply_move_no_turn_end(die_used: int, move: Dictionary, player: int) -> void:
	# Same as _apply_move_and_continue, but NEVER ends the turn.
	_record_turn_hit_if_any(move, player)

	Rules.apply_move(state, player, move)
	dice.call("consume_die", die_used)
	_update_dice_ui()

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999

	# Elimination/bear-off check
	if state.count_in_play(BoardState.Player.WHITE) == 0 or state.count_in_play(BoardState.Player.BLACK) == 0:
		_end_round_from_state()
		return

	# Win check
	for wc in win_conditions:
		if wc != null and wc.check(state):
			_end_round_from_state()
			return

	# Skill tree trigger check (only after WHITE moves)
	if skill_tree != null and player == BoardState.Player.WHITE:
		skill_tree.on_pips_updated(get_pips_remaining(BoardState.Player.WHITE))
		if skill_tree_blocking:
			_skill_tree_pending_post_move = true
			return

func _apply_black_damage_from_move(m: Dictionary) -> void:
	if run_state == null or ai == null or ai.advantage == null:
		return

	var dmg := 0
	if bool(m.get("hit", false)):
		dmg += ai.advantage.hit_damage(black_turn_index)

	# BLACK bearoff in your Rules is "to" == -2
	if int(m.get("to", -999)) == -2:
		dmg += ai.advantage.bearoff_total_damage(1, black_turn_index)

	if dmg > 0:
		run_state.player_hp = maxi(0, int(run_state.player_hp) - dmg)
		if has_method("show_notice"):
			show_notice("You take %d HP." % dmg)


func _end_round_from_black_hp_win() -> void:
	round_active = false
	_clear_targets()
	_set_input_enabled(false)
	_show_round_end("DEFEAT")



func end_turn() -> void:
	if not round_active:
		return

	_ai_running = false
	state.turn = state.opponent(state.turn)

	ap_left = base_ap_per_turn
	call_deferred("start_turn")


func _on_point_clicked(i: int) -> void:
	if not round_active:
		return
	if _is_black_ai_turn_active():
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return # while targeting, ignore point clicks

	var p: int = state.turn

	# Force from bar if needed
	# If you have checkers on the bar, you must explicitly click the bar to select it.
	var bar: PackedInt32Array = state.bar_white if p == BoardState.Player.WHITE else state.bar_black
	if bar.size() > 0:
		# If bar is NOT selected, ignore point clicks (prevents confusing behavior).
		if selected_from != -1:
			return

		# Bar is selected: allow clicking entry points.
		_show_targets_for_selected()
		_try_move_to(i)
		return

	# No selection -> select friendly stack
	if selected_from == -999:
		if i >= 0 and i <= 23 and state.stack_count(i) > 0 and state.stack_owner(i) == p:
			selected_from = i
			_show_targets_for_selected()
		return

	# Selection exists -> try move first
	if _try_move_to(i):
		return

	# Switch selection if clicked another friendly stack
	if i >= 0 and i <= 23 and state.stack_count(i) > 0 and state.stack_owner(i) == p:
		selected_from = i
		_show_targets_for_selected()
		return

	# Otherwise clear
	selected_from = -999
	_clear_targets()

func _on_bar_clicked(player: int) -> void:
	if not round_active:
		return
	if _is_black_ai_turn_active():
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return
	if state == null:
		return
	if state.turn != player:
		return

	var bar: PackedInt32Array = state.bar_white if player == BoardState.Player.WHITE else state.bar_black
	if bar.size() == 0:
		return

	selected_from = -1
	_show_targets_for_selected()

func _on_bearoff_clicked(dest: int) -> void:
	if not round_active:
		return
	if _is_black_ai_turn_active():
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return
	if selected_from == -999:
		return
	_try_move_to(dest)

func _show_targets_for_selected() -> void:
	if board == null or not board.has_method("show_move_targets"):
		return
	board.call("show_move_targets", _compute_targets_for_selected(), state.turn)

func _compute_targets_for_selected() -> Array[int]:
	var p: int = state.turn
	var targets: Array[int] = []

	if selected_from == -999:
		return targets

	for d in dice.remaining:
		var moves: Array[Dictionary] = Rules.legal_moves_for_die(state, p, d)
		for m in moves:
			if int(m["from"]) == selected_from:
				var to_i: int = int(m["to"])
				if not targets.has(to_i):
					targets.append(to_i)

	return targets

func _try_move_to(dst_index: int) -> bool:
	var p: int = state.turn

	for d in dice.remaining.duplicate():
		var moves: Array[Dictionary] = Rules.legal_moves_for_die(state, p, d)
		for m in moves:
			if int(m["from"]) == selected_from and int(m["to"]) == dst_index:
				_clear_targets()

				# Animate if BoardView supports it; otherwise apply instantly
				if board != null and board.has_method("animate_move_persistent"):
					board.call("animate_move_persistent", state, m, p, func() -> void:
						_apply_move_and_continue(d, m, p)
					)
				else:
					_apply_move_and_continue(d, m, p)

				return true

	return false

func _apply_move_and_continue(die_used: int, move: Dictionary, player: int) -> void:
	_record_turn_hit_if_any(move, player)

	Rules.apply_move(state, player, move)
	dice.call("consume_die", die_used)
	_update_dice_ui()

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999

	# --- NEW: elimination/bear-off check ---
	if state.count_in_play(BoardState.Player.WHITE) == 0 or state.count_in_play(BoardState.Player.BLACK) == 0:
		_end_round_from_state()
		return

	# Win check
	for wc in win_conditions:
		if wc != null and wc.check(state):
			_end_round_from_state()
			return

	# --- Skill tree trigger check (MVP: only after WHITE moves) ---
	if skill_tree != null and player == BoardState.Player.WHITE:
		skill_tree.on_pips_updated(get_pips_remaining(BoardState.Player.WHITE))
		if skill_tree_blocking:
			# Pause progression until overlay completes
			_skill_tree_pending_post_move = true
			return

	# Turn progression
	if not dice.call("has_moves"):
		end_turn()
	elif _count_all_legal_moves() == 0:
		end_turn()


func _count_all_legal_moves() -> int:
	var p: int = state.turn
	var total: int = 0
	for d in dice.remaining:
		total += Rules.legal_moves_for_die(state, p, d).size()
	return total

func _end_round_from_state() -> void:
	round_active = false
	_clear_targets()
	_set_input_enabled(false)

	# Clear targeting
	targeting_active = false
	targeting_required_half = -1
	targeting_consume_uid = -1

	var white_left: int = state.count_in_play(BoardState.Player.WHITE)
	var black_left: int = state.count_in_play(BoardState.Player.BLACK)

	# Determine player vs enemy win (player assumed WHITE)
	if white_left == 0 and black_left > 0:
		last_result = RoundResult.PLAYER_WIN
		_show_round_end("ROUND WON")
	elif black_left == 0 and white_left > 0:
		last_result = RoundResult.ENEMY_WIN
		_show_round_end("ROUND LOST")
	elif white_left == 0 and black_left == 0:
		# Extremely rare: both eliminated/removed simultaneously
		last_result = RoundResult.NONE
		_show_round_end("ROUND ENDED")
	else:
		last_result = RoundResult.NONE
		_show_round_end("ROUND ENDED")

func _on_round_end_restart() -> void:
	emit_signal("round_restarted")
	start_round(run_state)

func _on_round_end_next() -> void:
	_hide_round_end()

	if last_result == RoundResult.PLAYER_WIN:
		emit_signal("round_won")
	elif last_result == RoundResult.ENEMY_WIN:
		emit_signal("round_lost")
	else:
		emit_signal("round_restarted")
		start_round(run_state)

# -----------------------
# UI helpers
# -----------------------

func _update_dice_ui() -> void:
	if dice_ui != null and dice_ui.has_method("set_dice"):
		# Bonus dice are marked with parentheses in the UI.
		var rolled_bonus: Array = []
		var remaining_bonus: Array = []
		if dice != null:
			rolled_bonus = dice.dice_is_bonus
			remaining_bonus = dice.remaining_is_bonus
		dice_ui.call("set_dice", dice.dice, dice.remaining, rolled_bonus, remaining_bonus)


func _clear_targets() -> void:
	if board != null and board.has_method("clear_move_targets"):
		board.call("clear_move_targets")

func _set_input_enabled(v: bool) -> void:
	if board_input != null and board_input.has_method("set_enabled"):
		board_input.call("set_enabled", v)

func _show_round_end(text: String) -> void:
	if round_end != null and round_end.has_method("show_result"):
		round_end.call("show_result", text)
		return
	print("[RoundController] " + text)

func _hide_round_end() -> void:
	if round_end != null and round_end.has_method("hide_overlay"):
		round_end.call("hide_overlay")

# -----------------------
# Pips (for skill-tree thresholds; StatsHUD displays via its own polling)
# -----------------------

func get_pips_remaining(player: int) -> int:
	return _pips_remaining_for(player)

func _pips_remaining_for(player: int) -> int:
	if state == null:
		return 0

	var total: int = 0

	# On-board pips
	for i in range(24):
		var st: PackedInt32Array = state.points[i]
		for cid in st:
			var id: int = int(cid)
			if state.owner_of(id) != player:
				continue

			# Assumption:
			# WHITE bears off past 23 (moves 0 -> 23), BLACK bears off past 0 (moves 23 -> 0)
			if player == BoardState.Player.WHITE:
				total += (24 - i) # point 23 => 1 pip, point 0 => 24 pips
			else:
				total += (i + 1)  # point 0 => 1 pip, point 23 => 24 pips

	# Bar pips (approx)
	if player == BoardState.Player.WHITE:
		for _c in state.bar_white:
			total += 25
	else:
		for _c in state.bar_black:
			total += 25

	return total

# -----------------------
# Skill Tree (MVP)
# -----------------------

func _on_skill_tree_request_open(options: Array, picks_allowed: int) -> void:
	skill_tree_blocking = true
	_skill_tree_pending_post_move = false

	# Clear selection/targets, disable board clicks
	selected_from = -999
	_clear_targets()
	_set_input_enabled(false)

	if skill_overlay != null and skill_tree != null:
		skill_overlay.open(options, picks_allowed, run_state.gold, skill_tree.buy_pick_cost, run_state.skill_state)

func _on_skill_tree_buy_extra_pick() -> void:
	if skill_tree == null:
		return

	var gold: int = _get_gold()
	if skill_tree.try_buy_extra_pick(gold):
		_set_gold(gold - int(skill_tree.buy_pick_cost))

		if skill_overlay != null:
			skill_overlay.set_gold(_get_gold())
			skill_overlay.set_picks_allowed(skill_tree.get_picks_allowed())

func _on_skill_tree_overlay_confirmed(chosen_ids: Array) -> void:
	if skill_overlay != null:
		skill_overlay.close()

	skill_tree_blocking = false
	_set_input_enabled(true)

	if skill_tree != null:
		skill_tree.confirm_selection(chosen_ids)

	_resume_after_skill_tree_post_move()

func _on_skill_tree_overlay_skipped() -> void:
	if skill_overlay != null:
		skill_overlay.close()

	skill_tree_blocking = false
	_set_input_enabled(true)

	if skill_tree != null:
		skill_tree.confirm_selection([])

	_resume_after_skill_tree_post_move()

func _on_skill_tree_selection_confirmed(chosen_ids: Array, gold_spent: int) -> void:
	if run_state == null:
		return
	# Collect cooldown deltas BEFORE applying, so we can immediately reduce any
	# currently-running cooldown timers (not just future activations).
	var cd_delta_by_aux: Dictionary = {}
	var touched_aux: Dictionary = {}
	if run_state.skill_state != null:
		var ss0: RunSkillState = run_state.skill_state
		for raw in chosen_ids:
			var node_id: String = String(raw)
			var aux_id: String = SkillTreeDefs.get_aux_id(node_id)
			if aux_id == "":
				continue
			# Defensive: only consider allowed picks.
			if not SkillTreeDefs.is_pick_allowed(ss0, node_id):
				continue
			touched_aux[aux_id] = true
			var prev_level: int = int(ss0.node_levels.get(node_id, 0))
			var next_level: int = prev_level + 1
			var rules: Dictionary = SkillTreeDefs.get_level_rules(node_id, next_level)
			var dcd: int = int(rules.get("cooldown_delta", 0))
			if dcd != 0:
				cd_delta_by_aux[aux_id] = int(cd_delta_by_aux.get(aux_id, 0)) + dcd

	SkillSystem.apply_node_picks(run_state, chosen_ids)

	# Immediately apply cooldown delta to any aux currently on cooldown.
	for aux_id in cd_delta_by_aux.keys():
		_apply_immediate_aux_cooldown_delta(String(aux_id), int(cd_delta_by_aux[aux_id]))

	# Reconcile cooldown arrays for any touched aux (handles copy unlocks and clamps to new max).
	for aux_id in touched_aux.keys():
		_reconcile_aux_cooldowns(String(aux_id))

	print("[SkillTree] chosen_ids=", chosen_ids, " skill_state=", run_state.skill_state)
	print("[SkillTree] node_levels=", run_state.skill_state.node_levels, " aux_unlocked=", run_state.skill_state.aux_unlocked, " aux_mods=", run_state.skill_state.aux_mods)


# -----------------------
# Debug helpers (fast testing)
# -----------------------

# Force-open the skill tree selection UI immediately (ignores pips thresholds).
func debug_open_skill_tree(picks_override: int = 2) -> void:
	if not round_active:
		return
	if skill_tree_blocking:
		return
	if skill_tree == null or skill_overlay == null:
		return
	if run_state == null:
		return
	if run_state.skill_state == null:
		run_state.skill_state = RunSkillState.new()

	skill_tree.debug_force_open(run_state.skill_state, int(picks_override))


# Clears aux cooldowns and per-round use counters so you can spam-test aux cards.
func debug_reset_aux_cooldowns() -> void:
	# Reset cooldowns (supports multi-copy arrays).
	for k in aux_cd_left.keys():
		var v: Variant = aux_cd_left[k]
		if v is Array:
			var arr: Array = v as Array
			for i in range(arr.size()):
				arr[i] = 0
			aux_cd_left[k] = arr
		else:
			aux_cd_left[k] = 0

	# Reset per-round usage
	aux_uses_this_round.clear()
	aux_uses_by_copy.clear()
	aux_used_this_turn.clear()

	# Optional: refill AP for convenience
	ap_left = base_ap_per_turn


func _resume_after_skill_tree_post_move() -> void:
	if not _skill_tree_pending_post_move:
		return
	_skill_tree_pending_post_move = false

	if not round_active:
		return

	# Re-run progression logic that was paused
	if dice != null and dice.call("has_moves") == false:
		end_turn()
	elif _count_all_legal_moves() == 0:
		end_turn()

func _get_aux_copies(aux_id: String) -> int:
	if run_state == null or run_state.skill_state == null:
		return 0
	return maxi(0, int(run_state.skill_state.aux_unlocked.get(aux_id, 0)))

# When a cooldown reduction node is bought, apply the change immediately to any
# currently-running cooldown timers for that aux.
func _apply_immediate_aux_cooldown_delta(aux_id: String, cd_delta: int) -> void:
	if cd_delta == 0:
		return
	if run_state == null or run_state.skill_state == null:
		return
	var copies: int = _get_aux_copies(aux_id)
	if copies <= 0:
		return
	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		return

	var new_max: int = int(AuxCardDB.compute_cooldown(def, run_state.skill_state))
	var cds: Array = []
	var v: Variant = aux_cd_left.get(aux_id, null)
	if v is Array:
		cds = v as Array
	elif v != null:
		cds = [int(v)]

	# Ensure size matches copies.
	while cds.size() < copies:
		cds.append(0)
	if cds.size() > copies:
		cds = cds.slice(0, copies)

	for i in range(cds.size()):
		var cur: int = int(cds[i])
		# cd_delta is typically negative (cooldown reduction), so this reduces remaining time.
		cur = maxi(0, cur + cd_delta)
		cur = mini(cur, new_max)
		cds[i] = cur

	aux_cd_left[aux_id] = cds

func _reconcile_aux_cooldowns(aux_id: String) -> void:
	if run_state == null or run_state.skill_state == null:
		return
	var copies: int = _get_aux_copies(aux_id)
	if copies <= 0:
		return
	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		return

	var new_max: int = int(AuxCardDB.compute_cooldown(def, run_state.skill_state))
	var cds: Array = []
	var v: Variant = aux_cd_left.get(aux_id, null)
	if v is Array:
		cds = v as Array
	elif v != null:
		cds = [int(v)]

	while cds.size() < copies:
		cds.append(0)
	if cds.size() > copies:
		cds = cds.slice(0, copies)

	for i in range(cds.size()):
		cds[i] = mini(maxi(0, int(cds[i])), new_max)

	aux_cd_left[aux_id] = cds

func get_aux_cd_display(aux_id: String) -> int:
	var v: Variant = aux_cd_left.get(aux_id, 0)
	if v is Array:
		var arr: Array = v as Array
		if arr.is_empty():
			return 0
		var min_cd: int = 999999
		for c in arr:
			min_cd = mini(min_cd, int(c))
		return 0 if min_cd == 999999 else min_cd
	return maxi(0, int(v))

# Per-copy cooldown access (for HUD slots that show each copy as its own card).
func get_aux_cd_left(aux_id: String, copy_idx: int) -> int:
	var v: Variant = aux_cd_left.get(aux_id, 0)
	if v is Array:
		var arr: Array = v as Array
		if copy_idx < 0 or copy_idx >= arr.size():
			return 0
		return maxi(0, int(arr[copy_idx]))
	# single-value fallback
	return maxi(0, int(v))

# Per-copy uses access. If we don't have a per-copy array yet, fall back to total uses.
func get_aux_uses_copy(aux_id: String, copy_idx: int) -> int:
	var v: Variant = aux_uses_by_copy.get(aux_id, null)
	if v is Array:
		var arr: Array = v as Array
		if copy_idx < 0 or copy_idx >= arr.size():
			return 0
		return maxi(0, int(arr[copy_idx]))
	return maxi(0, int(aux_uses_this_round.get(aux_id, 0)))

func is_aux_ready(aux_id: String) -> bool:
	var v: Variant = aux_cd_left.get(aux_id, 0)
	if v is Array:
		var arr: Array = v as Array
		for c in arr:
			if int(c) <= 0:
				return true
		return false
	return int(v) <= 0

func is_aux_fully_on_cooldown(aux_id: String) -> bool:
	var v: Variant = aux_cd_left.get(aux_id, 0)
	if v is Array:
		var arr: Array = v as Array
		if arr.is_empty():
			return false
		for c in arr:
			if int(c) <= 0:
				return false
		return true
	return int(v) > 0

func request_activate_aux(aux_id: String) -> void:
	# Back-compat wrapper: activates the first ready copy.
	if run_state == null or run_state.skill_state == null:
		return
	var copies: int = _get_aux_copies(aux_id)
	if copies <= 0:
		return
	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		return
	var max_uses: int = int(def.max_uses_per_round)
	if max_uses <= 0:
		max_uses = 999999

	for i: int in range(copies):
		if get_aux_cd_left(aux_id, i) > 0:
			continue
		if get_aux_uses_copy(aux_id, i) >= max_uses:
			continue
		request_activate_aux_copy(aux_id, i)
		return


func request_activate_aux_copy(aux_id: String, copy_idx: int) -> void:
	if not round_active:
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return
	if run_state == null or run_state.skill_state == null:
		return

	# For now: player-only aux usage.
	if state == null or state.turn != BoardState.Player.WHITE:
		return

	var copies: int = _get_aux_copies(aux_id)
	if copies <= 0:
		return
	if copy_idx < 0 or copy_idx >= copies:
		return

	var def: AuxCardDef = AuxCardDB.get_def(aux_id)
	if def == null:
		return

	# Aux cards are allowed to be used multiple times per WHITE turn as long as
	# they have AP, are off cooldown, and still have uses remaining.
	# (Enemy drain is the mechanic that is once-per-WHITE-turn.)

	var max_uses: int = int(def.max_uses_per_round)
	if max_uses <= 0:
		max_uses = 999999

	# Ensure per-copy uses array.
	var uses_arr: Array = []
	var uv: Variant = aux_uses_by_copy.get(aux_id, null)
	if uv is Array:
		uses_arr = uv as Array
	while uses_arr.size() < copies:
		uses_arr.append(0)
	if uses_arr.size() > copies:
		uses_arr = uses_arr.slice(0, copies)

	var uses_copy: int = maxi(0, int(uses_arr[copy_idx]))
	if uses_copy >= max_uses:
		return

	var uses_total: int = int(aux_uses_this_round.get(aux_id, 0))
	# Defensive total cap (should be implied by per-copy caps).
	if uses_total >= max_uses * copies:
		return

	# Ensure cooldown array sized.
	var cds: Array = []
	var v: Variant = aux_cd_left.get(aux_id, null)
	if v is Array:
		cds = v as Array
	elif v != null:
		cds = [int(v)]
	while cds.size() < copies:
		cds.append(0)
	if cds.size() > copies:
		cds = cds.slice(0, copies)

	if maxi(0, int(cds[copy_idx])) > 0:
		return

	var cost: int = int(AuxCardDB.compute_ap_cost(def, run_state.skill_state))
	if ap_left < cost:
		return

	ap_left -= cost

	AuxCardRunner.activate(self, aux_id, uses_total + 1)

	cds[copy_idx] = int(AuxCardDB.compute_cooldown(def, run_state.skill_state))
	aux_cd_left[aux_id] = cds

	uses_arr[copy_idx] = uses_copy + 1
	aux_uses_by_copy[aux_id] = uses_arr
	aux_uses_this_round[aux_id] = uses_total + 1



func _get_gold() -> int:
	if run_state == null:
		return 0
	return int(run_state.gold)

func _set_gold(v: int) -> void:
	if run_state == null:
		return
	run_state.gold = maxi(0, v)

# -----------------------
# Phase 2: Targeting (Step 2.5)
# -----------------------

func _on_checker_clicked(checker_id: int) -> void:
	if not round_active:
		return
	if skill_tree_blocking:
		return
	if not targeting_active:
		return

	print("[Target] clicked checker_id=", checker_id)

	# Must be enemy checker
	if state.owner_of(checker_id) != targeting_enemy:
		return

	# Must be on-board, and must be on required half
	var pt: int = Rules.find_checker_point(state, checker_id)
	if pt == -1:
		return

	var half: int = 0 if pt <= 11 else 1
	if targeting_required_half != -1 and half != targeting_required_half:
		return

	# Hit up to N checkers from the TOP of the chosen stack
	var hits: int = mini(targeting_max_stack_hits, state.points[pt].size())
	for _k in range(hits):
		var st: PackedInt32Array = state.points[pt]
		if st.size() == 0:
			break

		var top_id: int = int(st[st.size() - 1])

		# Safety: ensure it's still an enemy checker
		if state.owner_of(top_id) != targeting_enemy:
			break

		Rules.send_checker_to_bar(state, top_id)

	# Optional extra damage (Mortar)
	if targeting_damage_enemy > 0 and run_state != null:
		deal_enemy_damage(targeting_damage_enemy, true)

	# Update visuals
	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	# End targeting + consume card
	_end_targeting(true)

func _end_targeting(consumed: bool) -> void:
	# Snapshot BEFORE clearing fields
	var consume_uid: int = targeting_consume_uid

	# End targeting mode
	targeting_active = false
	targeting_required_half = -1

	if board_input != null and board_input.has_method("set_enabled"):
		board_input.call("set_enabled", true)

	emit_signal("targeting_ended")

	# Consume AFTER ending targeting, BEFORE clearing uid
	if consumed and consume_uid != -1:
		emit_signal("card_consumed", consume_uid)

	# Clear targeting state
	targeting_consume_uid = -1
	targeting_card_uid = -1
	targeting_card_id = ""
	targeting_damage_enemy = 0
	targeting_max_stack_hits = 1

func _begin_targeting_send_to_bar(required_half: int, enemy: int, card_inst: CardInstance, damage_enemy: int, max_stack_hits: int = 1) -> void:
	targeting_active = true
	targeting_required_half = int(required_half)
	targeting_enemy = int(enemy)
	targeting_damage_enemy = int(damage_enemy)

	# Track which card should be consumed when targeting completes
	targeting_card_uid = card_inst.uid
	targeting_consume_uid = card_inst.uid # IMPORTANT
	targeting_card_id = card_inst.def.id if (card_inst != null and card_inst.def != null) else ""

	targeting_max_stack_hits = clampi(int(max_stack_hits), 1, 2)

	if board_input != null and board_input.has_method("set_enabled"):
		board_input.call("set_enabled", false)

	emit_signal("targeting_started")

# Call this from your Hand UI / card system:
func request_activate_card(card: CardInstance) -> void:
	if card == null or card.def == null:
		return
	if not round_active:
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return
	if state == null:
		return

	var eff: CardEffect = card.def.primary_effect()
	if eff == null:
		return

	var cost: int = int(card.def.ap_cost_activate)
	if ap_left < cost:
		return

	# Pattern check
	var p: int = state.turn
	var ctx: PatternContext = PatternContext.new(state, p)
	if not PatternMatcher.matches_all(card.def.pattern, ctx):
		return

	# Spend AP only after pattern passes
	ap_left -= cost

	# Delegate all effect behavior to CardEffectRunner (keeps this controller small)
	CardEffectRunner.activate(self, card, ctx)

func request_burn_card_for_pips(card: CardInstance) -> void:
	if card == null or card.def == null:
		return
	if not round_active:
		return
	if skill_tree_blocking:
		return
	if targeting_active:
		return
	if state == null:
		return

	var pip: int = int(card.def.pip_value)
	if pip == 0:
		return
	if absi(pip) > 6:
		return

	var cost: int = int(card.def.ap_cost_burn)
	if ap_left < cost:
		return

	ap_left -= cost

	if dice != null and dice.has_method("add_bonus_die"):
		dice.call("add_bonus_die", pip)

	_update_dice_ui()
	emit_signal("card_consumed", card.uid)

# -----------------------
# Debug handlers (optional)
# -----------------------

func _on_debug_force_dice(d1: int, d2: int) -> void:
	if dice != null and dice.has_method("force"):
		dice.call("force", d1, d2)
	_update_dice_ui()
	selected_from = -999
	_clear_targets()

func _on_debug_roll_random() -> void:
	if dice != null and dice.has_method("roll"):
		dice.call("roll")
	_update_dice_ui()
	selected_from = -999
	_clear_targets()

func _on_debug_point_delta(point_index: int, is_white: bool, delta: int) -> void:
	if state == null:
		return
	if point_index < 0 or point_index > 23:
		return
	if delta == 0:
		return

	var owner: int = BoardState.Player.WHITE if is_white else BoardState.Player.BLACK

	# If point contains opposing stack, don't mix owners
	if state.stack_count(point_index) > 0 and state.stack_owner(point_index) != owner:
		print("[Debug] Point %d owned by opponent; clear first." % point_index)
		return

	if delta > 0:
		for _i in range(delta):
			var id := state.create_checker(owner)
			state.points[point_index].append(id)
	else:
		var remove_count := -delta
		for _i in range(remove_count):
			if state.points[point_index].size() == 0:
				break
			if state.stack_owner(point_index) != owner:
				break
			var top_i := state.points[point_index].size() - 1
			var id2 := state.points[point_index][top_i]
			state.points[point_index].remove_at(top_i)
			state.checkers.erase(id2)

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999
	_clear_targets()

func _on_debug_point_clear(point_index: int) -> void:
	if state == null:
		return
	if point_index < 0 or point_index > 23:
		return

	var st := state.points[point_index]
	for k in range(st.size()):
		state.checkers.erase(st[k])
	state.points[point_index] = PackedInt32Array()

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999
	_clear_targets()

func _on_debug_setup_home_boards() -> void:
	if state == null:
		return

	# WHITE: points 17-21 (3 per point = 15)
	# BLACK: points 1-5   (3 per point = 15)
	var white_targets: Array[int] = [17, 18, 19, 20, 21]
	var black_targets: Array[int] = [1, 2, 3, 4, 5]

	var white_ids: Array[int] = []
	var black_ids: Array[int] = []

	for k in state.checkers.keys():
		var id := int(k)
		var info := state.checkers[id] as CheckerInfo
		if info.owner == BoardState.Player.WHITE:
			white_ids.append(id)
		else:
			black_ids.append(id)

	# Clear stacks
	for i in range(24):
		state.points[i] = PackedInt32Array()
	state.bar_white = PackedInt32Array()
	state.bar_black = PackedInt32Array()
	state.off_white = PackedInt32Array()
	state.off_black = PackedInt32Array()

	white_ids.sort()
	black_ids.sort()

	_place_ids_3_per_point(white_ids, white_targets)
	_place_ids_3_per_point(black_ids, black_targets)

	if board != null and board.has_method("sync_from_state_full"):
		board.call("sync_from_state_full", state)

	selected_from = -999
	_clear_targets()

func _place_ids_3_per_point(ids: Array[int], targets: Array[int]) -> void:
	var idx := 0
	for t in targets:
		for _n in range(3):
			if idx >= ids.size():
				return
			state.points[t].append(ids[idx])
			idx += 1

	# Dump extras on last target
	if ids.size() > idx and targets.size() > 0:
		var last_t := targets[targets.size() - 1]
		while idx < ids.size():
			state.points[last_t].append(ids[idx])
			idx += 1

func get_hand() -> Array[CardInstance]:
	return hand.duplicate()

func _reset_card_piles() -> void:
	draw_pile.clear()
	discard_pile.clear()

	if run_state == null:
		return

	draw_pile = run_state.deck.duplicate()
	draw_pile.shuffle()

func _draw_cards_into_hand(count: int) -> void:
	if count <= 0:
		return

	_ensure_hand_slots()
	var draws_left: int = count
	for i in range(hand.size()):
		if draws_left <= 0:
			break
		if hand[i] != null:
			continue
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()

		var id: String = String(draw_pile.pop_back())
		var def := CardDB.get_def(id)
		if def == null:
			push_warning("[RoundController] Deck id not found in CardDB: %s" % id)
			continue
		hand[i] = CardInstance.new(def)
		draws_left -= 1

	emit_signal("hand_changed", hand)

func _on_card_consumed_internal(uid: int) -> void:
	var removed: bool = false
	for j in range(hand.size()):
		if hand[j] != null and hand[j].uid == uid:
			if hand[j].def != null:
				discard_pile.append(String(hand[j].def.id))
			hand[j] = null
			removed = true
			break

	if removed:
		emit_signal("hand_changed", hand)

# --- DEBUG: mutate the hand directly (HandHUD will redraw via hand_changed) ---
# These helpers are for the DebugCardMenu.

func debug_clear_hand() -> void:
	_ensure_hand_slots()
	for i in range(hand.size()):
		hand[i] = null
	emit_signal("hand_changed", hand)

# Fill the hand with copies of a single CardDef.
# If count is -1, uses the exported hand_size.
func debug_fill_hand(def: CardDef, count: int = -1) -> void:
	if def == null:
		return
	var hs: int = count
	if hs < 0:
		hs = hand_size
	hs = maxi(0, hs)
	hand.clear()
	while hand.size() < hs:
		hand.append(null)
	for i: int in range(hs):
		hand[i] = CardInstance.new(def)
	emit_signal("hand_changed", hand)

# Replace a specific hand index with a new CardInstance created from def.
# If the hand is shorter than the requested index, it is expanded (filled with def).
func debug_set_hand_index(hand_index: int, def: CardDef) -> void:
	if def == null:
		return
	if hand_index < 0:
		return
	var desired: int = maxi(hand_size, hand_index + 1)
	while hand.size() < desired:
		hand.append(null)
	hand[hand_index] = CardInstance.new(def)
	emit_signal("hand_changed", hand)

func debug_remove_hand_index(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= hand.size():
		return
	hand[hand_index] = null
	emit_signal("hand_changed", hand)

func debug_append_card(def: CardDef) -> void:
	if def == null:
		return
	_ensure_hand_slots()
	for i in range(hand.size()):
		if hand[i] == null:
			hand[i] = CardInstance.new(def)
			emit_signal("hand_changed", hand)
			return
	emit_signal("hand_changed", hand)

func _ensure_hand_slots() -> void:
	if hand_size < 0:
		return
	if hand.size() > hand_size:
		hand.resize(hand_size)
	while hand.size() < hand_size:
		hand.append(null)

func _count_empty_hand_slots() -> int:
	_ensure_hand_slots()
	var empty: int = 0
	for ci in hand:
		if ci == null:
			empty += 1
	return empty
