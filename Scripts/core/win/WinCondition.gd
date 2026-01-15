extends Resource
class_name WinCondition

@export var id: String = "win_condition"

# Use Variant to avoid dependency issues during class registration.
func check(_state: Variant) -> bool:
	return false
