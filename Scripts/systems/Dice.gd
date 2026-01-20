extends Node
class_name Dice

# dice: list of dice sources rolled/added this turn (primarily for UI display)
# remaining: list of dice pips still to use this turn
var dice: Array[int] = []
var remaining: Array[int] = []

# Parallel arrays that track whether each die is a "bonus" die.
# Bonus dice are usually displayed differently and can be excluded from some modifiers.
var dice_is_bonus: Array[bool] = []
var remaining_is_bonus: Array[bool] = []

# Apply a pip bonus to dice/remaining values.
# By default this affects ALL dice (including bonus dice).
# Some upgrades may choose to exclude bonus dice by passing include_bonus=false.
func apply_pip_bonus(pip_bonus: int, include_bonus: bool = true) -> void:
	if pip_bonus == 0:
		return

	# Display list
	for i in range(dice.size()):
		if not include_bonus and i < dice_is_bonus.size() and dice_is_bonus[i]:
			continue
		dice[i] = int(dice[i]) + int(pip_bonus)

	# Consumable list
	for i in range(remaining.size()):
		if not include_bonus and i < remaining_is_bonus.size() and remaining_is_bonus[i]:
			continue
		remaining[i] = int(remaining[i]) + int(pip_bonus)

func _set_regular_roll(d1: int, d2: int) -> void:
	dice = [d1, d2]
	dice_is_bonus = [false, false]

	remaining.clear()
	remaining_is_bonus.clear()
	if d1 == d2:
		remaining = [d1, d1, d1, d1]
		remaining_is_bonus = [false, false, false, false]
	else:
		remaining = [d1, d2]
		remaining_is_bonus = [false, false]

# Adds a single die to the current turn.
# Value may be negative for "move backward".
# 0 is ignored. Magnitude is clamped to 1..6.
func add_bonus_die(pip: int) -> void:
	# Expect pip in [-6..-1] or [1..6]
	if pip == 0:
		return
	if absi(pip) > 6:
		return
	# For UI purposes, keep a record of added dice in the display list.
	dice.append(pip)
	dice_is_bonus.append(true)
	remaining.append(pip)
	remaining_is_bonus.append(true)

func roll() -> void:
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	_set_regular_roll(d1, d2)

func roll_with_sides(sides: int) -> void:
	sides = clampi(sides, 1, 6)
	var d1 := randi_range(1, sides)
	var d2 := randi_range(1, sides)
	_set_regular_roll(d1, d2)

func has_moves() -> bool:
	return remaining.size() > 0

func consume_die(die: int) -> bool:
	var idx := remaining.find(die)
	if idx == -1:
		# fallback if something passed magnitude only
		idx = remaining.find(absi(die))
	if idx == -1:
		return false
	remaining.remove_at(idx)
	if idx < remaining_is_bonus.size():
		remaining_is_bonus.remove_at(idx)
	return true

func clear_remaining() -> void:
	remaining.clear()
	remaining_is_bonus.clear()


func duplicate_all() -> void:
	# Duplicates the current dice pool (both UI list and remaining moves),
	# preserving bonus-die flags. This can create values > 6 after pip boosts.
	var d_n: int = dice.size()
	for i in range(d_n):
		dice.append(int(dice[i]))
		var isb: bool = (i < dice_is_bonus.size() and bool(dice_is_bonus[i]))
		dice_is_bonus.append(isb)

	var r_n: int = remaining.size()
	for i in range(r_n):
		remaining.append(int(remaining[i]))
		var isb_r: bool = (i < remaining_is_bonus.size() and bool(remaining_is_bonus[i]))
		remaining_is_bonus.append(isb_r)

func force(d1: int, d2: int) -> void:
	d1 = clampi(d1, 1, 6)
	d2 = clampi(d2, 1, 6)
	_set_regular_roll(d1, d2)
