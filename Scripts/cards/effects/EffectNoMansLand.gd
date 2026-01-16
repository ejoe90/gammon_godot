extends CardEffect
class_name EffectNoMansLand

@export var uses: int = 5

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null:
		return

	var match := _find_no_mans_land(round.state)
	if match.is_empty():
		push_warning("[EffectNoMansLand] Pattern ready but could not locate matched gap.")
		return

	if round.has_method("activate_no_mans_land"):
		round.call(
			"activate_no_mans_land",
			int(match["left"]),
			int(match["gap"]),
			int(match["right"]),
			int(match["left_owner"]),
			int(match["right_owner"]),
			uses,
			card
		)

func _find_no_mans_land(state: BoardState) -> Dictionary:
	for gap in range(1, 23):
		if state.points[gap].size() != 0:
			continue
		var left: int = gap - 1
		var right: int = gap + 1
		if left < 0 or right > 23:
			continue

		var left_count: int = state.stack_count(left)
		var right_count: int = state.stack_count(right)
		if left_count < 2 or right_count < 2:
			continue

		var left_owner: int = state.stack_owner(left)
		var right_owner: int = state.stack_owner(right)
		if left_owner == -1 or right_owner == -1:
			continue
		if left_owner == right_owner:
			continue
		if not _owners_are_white_black(left_owner, right_owner):
			continue

		return {
			"left": left,
			"gap": gap,
			"right": right,
			"left_owner": left_owner,
			"right_owner": right_owner,
		}

	return {}

func _owners_are_white_black(left_owner: int, right_owner: int) -> bool:
	return (left_owner == BoardState.Player.WHITE and right_owner == BoardState.Player.BLACK) \
		or (left_owner == BoardState.Player.BLACK and right_owner == BoardState.Player.WHITE)
