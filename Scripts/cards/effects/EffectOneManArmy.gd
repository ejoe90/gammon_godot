extends CardEffect
class_name EffectOneManArmy

@export var self_hp_damage: int = 2

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	var self_p: int = int(round.state.turn)
	var enemy_p: int = BoardState.Player.BLACK if self_p == BoardState.Player.WHITE else BoardState.Player.WHITE

	var self_pt: int = -1
	var enemy_pt: int = -1

	for i in range(24):
		if round.state.stack_owner(i) == self_p and round.state.stack_count(i) == 1:
			for nb in [i - 1, i + 1]:
				if nb < 0 or nb > 23:
					continue
				if round.state.stack_owner(nb) == enemy_p and round.state.stack_count(nb) >= 4:
					self_pt = i
					enemy_pt = nb
					break
		if self_pt != -1:
			break

	if self_pt == -1:
		push_warning("[EffectOneManArmy] Pattern ready but adjacency not found at click time.")
		return

	# Destroy lone self checker
	var self_stack: PackedInt32Array = round.state.points[self_pt]
	var self_id: int = int(self_stack[self_stack.size() - 1])
	Rules.destroy_checker(round.state, self_id)

	# Send all but one enemy checker to bar
	var sent: int = 0
	while round.state.points[enemy_pt].size() > 1:
		var st: PackedInt32Array = round.state.points[enemy_pt]
		var enemy_id: int = int(st[st.size() - 1])
		Rules.send_checker_to_bar(round.state, enemy_id)
		sent += 1

	if round.run_state != null:
		if round.has_method("deal_player_damage"):
			round.call("deal_player_damage", int(self_hp_damage), false)
		else:
			round.run_state.player_hp -= int(self_hp_damage)
		round.deal_enemy_damage(sent)

	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
