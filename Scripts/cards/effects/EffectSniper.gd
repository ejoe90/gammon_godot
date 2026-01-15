extends CardEffect
class_name EffectSniper

@export var damage_to_black: int = 3

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null:
		return

	var state: BoardState = round.state

	# Find the first valid across pair:
	# point i has exactly 1 WHITE, point (23-i) has exactly 1 BLACK
	var white_pt: int = -1
	var black_pt: int = -1

	for i in range(24):
		var st_w: PackedInt32Array = state.points[i]
		if st_w.size() != 1:
			continue
		if state.owner_of(int(st_w[0])) != BoardState.Player.WHITE:
			continue

		var j: int = 23 - i
		var st_b: PackedInt32Array = state.points[j]
		if st_b.size() != 1:
			continue
		if state.owner_of(int(st_b[0])) != BoardState.Player.BLACK:
			continue

		white_pt = i
		black_pt = j
		break

	if black_pt == -1:
		push_warning("[Sniper] Pattern was ready but no valid across pair found at click time.")
		return

	# Send the black checker to the bar
	var st: PackedInt32Array = state.points[black_pt]
	var black_id: int = int(st[st.size() - 1])
	Rules.send_checker_to_bar(state, black_id)

	# Deal 3 HP damage to black (enemy)
	if round.run_state != null:
		round.deal_enemy_damage(damage_to_black)

	# Refresh visuals
	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", state)

	# Consume the card
	round.emit_signal("card_consumed", card.uid)
