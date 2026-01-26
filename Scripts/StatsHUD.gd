extends Control
class_name StatsHUD

@export var round_controller_path: NodePath = NodePath("../..")
@export var poll_interval: float = 0.10

@onready var round_label: Label = get_node_or_null("RoundLabel") as Label
@onready var player_hp_label: Label = get_node_or_null("PlayerHPLabel") as Label
@onready var enemy_hp_label: Label = get_node_or_null("EnemyHPLabel") as Label
@onready var gold_label: Label = get_node_or_null("GoldLabel") as Label
@onready var ap_label: Label = get_node_or_null("APLabel") as Label
@onready var defense_label: Label = get_node_or_null("DefenseLabel") as Label
@onready var gold_mult_label: Label = get_node_or_null("GoldMultLabel") as Label

# NEW: pip labels (must exist as children of StatsHUD scene)
@onready var pips_white_label: Label = get_node_or_null("PipsWhite") as Label
@onready var pips_black_label: Label = get_node_or_null("PipsBlack") as Label

@onready var pip_hp_label: Label = get_node_or_null("PipHPLabel") as Label



var _accum: float = 0.0
var _round: RoundController

func _ready() -> void:
	_round = get_node_or_null(round_controller_path) as RoundController

	# Fallback: search the current scene tree (handles path mistakes / instancing order)
	if _round == null:
		var cs := get_tree().current_scene
		if cs != null:
			# If the node is literally named "RoundController"
			var n := cs.find_child("RoundController", true, false)
			_round = n as RoundController
	# If still null, report
	if _round == null:
		push_error("[StatsHUD] Could not find RoundController at: " + str(round_controller_path))

func _process(delta: float) -> void:
	_accum += delta
	if _accum < poll_interval:
		return
	_accum = 0.0
	_refresh()

func _refresh() -> void:
	if _round == null:
		return

	var rs: RunState = _round.run_state
	if rs != null:
		var black_mult: int = _black_attack_multiplier()
		if round_label != null:
			round_label.text = "Round: %d" % (rs.round_index + 1)
		if player_hp_label != null:
			player_hp_label.text = "Player HP: %d/%d" % [rs.player_hp, rs.player_max_hp]
		if enemy_hp_label != null:
			enemy_hp_label.text = "Enemy HP: %d/%d  ATK x%d" % [rs.enemy_hp, rs.enemy_max_hp, black_mult]
		if gold_label != null:
			gold_label.text = "Gold: %d" % rs.gold
		if gold_mult_label != null:
			gold_mult_label.text = "Gold x%d" % maxi(1, int(rs.round_gold_mult))
	else:
		if round_label != null:
			round_label.text = "Round: -"
		if player_hp_label != null:
			player_hp_label.text = "Player HP: -"
		if enemy_hp_label != null:
			enemy_hp_label.text = "Enemy HP: -"
		if gold_label != null:
			gold_label.text = "Gold: -"
		if gold_mult_label != null:
			gold_mult_label.text = "Gold x-"

	if ap_label != null:
		var mult: int = 1
		var base_atk: int = 0
		var base_def: int = 0
		var drain: int = 0
		var atk_conv: bool = false
		if _round.run_state != null:
			mult = maxi(1, int(_round.run_state.player_attack_mult))
			base_atk = int(_round.run_state.base_attack_power)
			base_def = int(_round.run_state.base_defense_power)
			drain = int(_round.run_state.enemy_drain_per_turn)
			atk_conv = bool(_round.run_state.attack_convert_to_gold)

		var extra := "  Base +%d  Drain %d" % [base_atk, drain]
		if atk_conv:
			extra += "  (A→G ON)"
		ap_label.text = "AP: %d/%d  ATK x%d%s" % [_round.ap_left, _round.base_ap_per_turn, mult, extra]

		if defense_label != null:
			defense_label.text = "DEF: +%d" % base_def

	# NEW: Pip Boost convert-to-HP toggle status (F6)
	if pip_hp_label != null:
		var unlocked_p: bool = false
		var on_p: bool = false
		if _round.run_state != null and _round.run_state.skill_state != null:
			var m_p: Dictionary = _round.run_state.skill_state.get_aux_mod("aux_pip_boost")
			unlocked_p = bool(m_p.get("pip_hp_convert_enabled", false))
			on_p = bool(_round.run_state.pip_convert_to_hp)
		if not unlocked_p:
			pip_hp_label.text = "Pip→HP: LOCKED (F6)"
		else:
			pip_hp_label.text = "Pip→HP: %s (F6)" % ("ON" if on_p else "OFF")

	# NEW: pips
	var s: BoardState = _round.state
	if s == null:
		if pips_white_label != null:
			pips_white_label.text = "Pips (White): -"
		if pips_black_label != null:
			pips_black_label.text = "Pips (Black): -"
	else:
		var w: int = _pips_remaining_for(s, BoardState.Player.WHITE)
		var b: int = _pips_remaining_for(s, BoardState.Player.BLACK)

		if pips_white_label != null:
			pips_white_label.text = "Pips (White): %d" % w
		if pips_black_label != null:
			pips_black_label.text = "Pips (Black): %d" % b

func _pips_remaining_for(s: BoardState, player: int) -> int:
	var total: int = 0

	# On-board pips
	for i in range(24):
		var st: PackedInt32Array = s.points[i]
		for cid in st:
			var id: int = int(cid)
			if s.owner_of(id) != player:
				continue

			# Assumption:
			# WHITE bears off past 23 (moves 0 -> 23)
			# BLACK bears off past 0  (moves 23 -> 0)
			if player == BoardState.Player.WHITE:
				total += (24 - i) # point 23 => 1, point 0 => 24
			else:
				total += (i + 1)  # point 0 => 1, point 23 => 24

	# Bar pips (approx; re-enter then bear off)
	if player == BoardState.Player.WHITE:
		for _c in s.bar_white:
			total += 25
	else:
		for _c in s.bar_black:
			total += 25

	return total

func _black_attack_multiplier() -> int:
	if _round == null:
		return 1
	if _round.ai == null or _round.ai.advantage == null:
		return 1
	return maxi(1, int(_round.ai.advantage.damage_multiplier(_round.black_turn_index)))
