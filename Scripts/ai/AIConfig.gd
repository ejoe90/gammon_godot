extends Resource
class_name AIConfig

@export_range(0.0, 1.0, 0.01) var aggression: float = 0.65
@export_range(0.0, 0.5, 0.01) var randomness: float = 0.08

@export var time_budget_ms: float = 6.0
@export var beam_width: int = 40
@export var max_sequences: int = 2000

# Offense
@export var w_hit: float = 30.0
@export var w_bearoff: float = 45.0
@export var w_race: float = 0.8

# Defense
@export var w_own_blots: float = 18.0
@export var w_on_bar: float = 26.0

# Board structure
@export var w_make_point: float = 6.0
@export var w_prime: float = 2.0

@export var debug_print_top: int = 0
