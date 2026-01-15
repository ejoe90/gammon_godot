extends Node
class_name AIController

@export var config: AIConfig
@export var advantage: BlackAdvantage

# Returns an Array of move Dictionaries. Each move includes keys: from,to,hit and "die".
func choose_move_sequence(src_state: BoardState, dice_values: Array[int], black_turn_index: int) -> Array:
	if config == null:
		config = AIConfig.new()
	if advantage == null:
		advantage = BlackAdvantage.new()

	var root = BackgammonBoardAdapter.new(src_state, float(advantage.bearoff_home_fraction))

	var candidates: Array = MoveEnumerator.enumerate_best_sequences(
		root,
		dice_values,
		BoardState.Player.BLACK,
		config,
		advantage,
		black_turn_index
	)

	if candidates.is_empty():
		return []

	if int(config.debug_print_top) > 0:
		var n: int = mini(int(config.debug_print_top), candidates.size())
		for i in range(n):
			var c: Dictionary = candidates[i] as Dictionary
			print("[AI] #", i, " score=", c.get("score"), " used=", c.get("used"), " seq=", c.get("seq"))

	var best: Dictionary = candidates[0] as Dictionary
	return best.get("seq", [])
