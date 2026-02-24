extends Control
class_name StatsHUD

@export var round_controller_path: NodePath = NodePath("../..")
@export var poll_interval: float = 0.10

@onready var player_hp_label: Label = get_node_or_null("Bar/MarginContainer/Row/PlayerHPLabel") as Label
@onready var gold_label: Label = get_node_or_null("Bar/MarginContainer/Row/GoldLabel") as Label
@onready var ap_label: Label = get_node_or_null("Bar/MarginContainer/Row/APLabel") as Label
@onready var defense_label: Label = get_node_or_null("Bar/MarginContainer/Row/DefenseLabel") as Label
@onready var enemy_hp_label: Label = get_node_or_null("Bar/MarginContainer/Row/EnemyHPLabel") as Label
@onready var enemy_attack_mult_label: Label = get_node_or_null("Bar/MarginContainer/Row/EnemyAttackMultLabel") as Label
@onready var pips_white_label: Label = get_node_or_null("Bar/MarginContainer/Row/PipsWhiteLabel") as Label
@onready var pips_black_label: Label = get_node_or_null("Bar/MarginContainer/Row/PipsBlackLabel") as Label

var _accum: float = 0.0
var _round: RoundController

func _ready() -> void:
	_round = get_node_or_null(round_controller_path) as RoundController

	if _round == null:
		var cs := get_tree().current_scene
		if cs != null:
			var n := cs.find_child("RoundController", true, false)
			_round = n as RoundController

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
		if player_hp_label != null:
			player_hp_label.text = "Player HP: %d/%d" % [rs.player_hp, rs.player_max_hp]
		if gold_label != null:
			gold_label.text = "Gold: %d" % rs.gold
		if ap_label != null:
			var base_atk: int = int(rs.base_attack_power)
			var mult: int = maxi(1, int(rs.player_attack_mult))
			ap_label.text = "ATK: +%d x%d" % [base_atk, mult]
		if defense_label != null:
			var base_def: int = int(rs.base_defense_power)
			defense_label.text = "DEF: +%d" % base_def
		if enemy_hp_label != null:
			enemy_hp_label.text = "Enemy HP: %d/%d" % [rs.enemy_hp, rs.enemy_max_hp]
		if enemy_attack_mult_label != null:
			enemy_attack_mult_label.text = "Enemy ATK x%d" % _black_attack_multiplier()
	else:
		if player_hp_label != null:
			player_hp_label.text = "Player HP: -"
		if gold_label != null:
			gold_label.text = "Gold: -"
		if ap_label != null:
			ap_label.text = "ATK: -"
		if defense_label != null:
			defense_label.text = "DEF: -"
		if enemy_hp_label != null:
			enemy_hp_label.text = "Enemy HP: -"
		if enemy_attack_mult_label != null:
			enemy_attack_mult_label.text = "Enemy ATK x-"

	if _round.state == null:
		if pips_white_label != null:
			pips_white_label.text = "Pips W: -"
		if pips_black_label != null:
			pips_black_label.text = "Pips B: -"
	else:
		if pips_white_label != null:
			pips_white_label.text = "Pips W: %d" % _round.get_pips_remaining(BoardState.Player.WHITE)
		if pips_black_label != null:
			pips_black_label.text = "Pips B: %d" % _round.get_pips_remaining(BoardState.Player.BLACK)

func _black_attack_multiplier() -> int:
	if _round == null:
		return 1
	if _round.ai == null or _round.ai.advantage == null:
		return 1
	return maxi(1, int(_round.ai.advantage.damage_multiplier(_round.black_turn_index)))
