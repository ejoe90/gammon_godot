extends Control
class_name DiceUI

@onready var rolled_label: Label = $RolledLabel
@onready var remaining_label: Label = $RemainingLabel

# `*_is_bonus` are optional parallel arrays that mark bonus dice.
# Bonus dice are rendered with parentheses, e.g. "(5)".
func set_dice(rolled: Array[int], remaining: Array[int], rolled_is_bonus: Array = [], remaining_is_bonus: Array = []) -> void:
	rolled_label.text = "Rolled: " + _fmt(rolled, rolled_is_bonus)
	remaining_label.text = "Remaining: " + _fmt(remaining, remaining_is_bonus)

func _fmt(a: Array[int], is_bonus: Array = []) -> String:
	if a.is_empty():
		return "-"
	var parts: Array[String] = []
	for i in range(a.size()):
		var v: int = int(a[i])
		var s := str(v)
		if i < is_bonus.size() and bool(is_bonus[i]):
			s = "(" + s + ")"
		parts.append(s)
	return ", ".join(parts)
