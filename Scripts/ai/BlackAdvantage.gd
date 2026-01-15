extends Resource
class_name BlackAdvantage

@export var base_hit_damage: int = 1
@export var bearoff_damage: int = 5

@export_range(0.5, 1.0, 0.01) var bearoff_home_fraction: float = 0.75
@export var damage_double_every_n_turns: int = 3
@export var speed_every_n_turns: int = 4

func damage_multiplier(black_turn_index: int) -> int:
	var t := maxi(1, int(black_turn_index))
	var n := maxi(1, int(damage_double_every_n_turns))
	return 1 << int((t - 1) / n)

func extra_dice_count(black_turn_index: int) -> int:
	var t := maxi(1, int(black_turn_index))
	var n := maxi(1, int(speed_every_n_turns))
	return int(t / n)

func hit_damage(black_turn_index: int) -> int:
	return int(base_hit_damage) * damage_multiplier(black_turn_index)

func bearoff_total_damage(borne_off_count: int, black_turn_index: int = 1) -> int:
	return int(bearoff_damage) * int(borne_off_count)
