extends CardEffect
class_name EffectDepthCharge

@export var enemy_damage: int = 4
@export var hits_per_stack: int = 2

# This card is explicitly "hit BLACK stacks / damage BLACK"
@export var target_owner: int = BoardState.Player.BLACK

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	# Find the mixed-sequence requirement for this card
	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[DepthCharge] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	# Locate the first matched start for the sequence on the current board
	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[DepthCharge] Pattern ready but could not locate matched start.")
		return

	# Pattern points (length 4):
	# [0]=white single, [1]=black 2+, [2]=black 2+, [3]=white single
	var black_a: int = start_point + 1
	var black_b: int = start_point + 2

	_hit_top_n_to_bar(round, black_a, hits_per_stack)
	_hit_top_n_to_bar(round, black_b, hits_per_stack)

	# Deal 4 HP damage to black
	if round.run_state != null:
	
		round.deal_enemy_damage(4)


	# Sync visuals + consume card
	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)


func _hit_top_n_to_bar(round: RoundController, pt: int, n: int) -> void:
	if pt < 0 or pt > 23:
		return

	for _i in range(n):
		var st: PackedInt32Array = round.state.points[pt]
		if st.size() == 0:
			return

		var top_id: int = int(st[st.size() - 1])
		if round.state.owner_of(top_id) != target_owner:
			return

		Rules.send_checker_to_bar(round.state, top_id)
