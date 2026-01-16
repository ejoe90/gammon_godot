extends Node
class_name CardEffectRunner
# --------------------------------------------------------------------------
# Central place for ALL card effect logic.
#
# Goal: keep RoundController lean. RoundController checks turn/AP/pattern,
# then delegates here.
#
# Supported MVP effects:
# - START_TARGETED_SEND_TO_BAR (Ionic Crossbow): target enemy checker on opposite half -> send to bar.
# - ONE_MAN_ARMY: destroy one self checker adjacent to 4+ enemy stack; send all but one enemy to bar; HP changes.
# - START_TARGETED_MORTAR: target enemy checker on opposite half -> send one to bar + deal HP damage.
# --------------------------------------------------------------------------

static func activate(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	var eff: CardEffect = card.def.primary_effect()
	if eff == null:
		push_warning("[CardEffectRunner] Card has no primary effect: %s" % card.def.title)
		return
	eff.apply(round, card, ctx)


static func activate_legacy(round: RoundController, card: CardInstance, ctx: PatternContext, eff: CardEffect) -> void:
	match eff.kind:
		CardEffect.Kind.START_TARGETED_SEND_TO_BAR:
			_start_crossbow(round, card)
		CardEffect.Kind.ONE_MAN_ARMY:
			_apply_one_man_army(round, card, eff)
		CardEffect.Kind.START_TARGETED_MORTAR:
			_start_mortar(round, card, eff)
		CardEffect.Kind.SUBTERFUGE:
			_apply_subterfuge(round, card, eff)
		_:
			push_warning("[CardEffectRunner] Unhandled legacy effect kind: %s" % [str(eff.kind)])


# --------------------------------------------------------------------------
# Ionic Crossbow
# Uses the first RUN_SEQUENCE req to determine which half the pattern is in.
# Targets the opposite half.
# --------------------------------------------------------------------------
static func _start_crossbow(round: Node, card: CardInstance) -> void:
	var p: int = round.state.turn
	var ctx := PatternContext.new(round.state, p)

	# Find the start point of the first RUN_SEQUENCE requirement.
	var start_point: int = -1
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			start_point = PatternMatcher.find_run_sequence_start(r, ctx)
			break

	if start_point == -1:
		push_warning("[Crossbow] Could not determine run start for targeting.")
		return

	var src_half: int = 0 if start_point <= 11 else 1
	var tgt_half: int = 1 - src_half
	var enemy: int = BoardState.Player.BLACK if p == BoardState.Player.WHITE else BoardState.Player.WHITE

	round.begin_targeting_send_to_bar(tgt_half, enemy, card, 0) # no HP damage


# --------------------------------------------------------------------------
# Mortar
# Same targeting as Crossbow, but applies enemy HP damage in addition to
# sending a checker to the bar.
# --------------------------------------------------------------------------
static func _start_mortar(round: Node, card: CardInstance, eff: CardEffect) -> void:
	var p: int = round.state.turn
	var ctx := PatternContext.new(round.state, p)

	var start_point: int = -1
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			start_point = PatternMatcher.find_run_sequence_start(r, ctx)
			break

	if start_point == -1:
		push_warning("[Mortar] Could not determine run start for targeting.")
		return

	var src_half: int = 0 if start_point <= 11 else 1
	var tgt_half: int = 1 - src_half
	var enemy: int = BoardState.Player.BLACK if p == BoardState.Player.WHITE else BoardState.Player.WHITE

	round.begin_targeting_send_to_bar(tgt_half, enemy, card, int(eff.amount))


# --------------------------------------------------------------------------
# One Man Army
# Pattern: exactly 1 self checker adjacent to a stack of 4+ enemy checkers.
#
# Effect:
# - Destroy the self checker (remove from the game).
# - Send all but one enemy checker from that stack to the bar.
# - Player HP - eff.amount (expected 2).
# - Enemy HP - (# sent to bar).
# --------------------------------------------------------------------------
static func _apply_one_man_army(round: Node, card: CardInstance, eff: CardEffect) -> void:
	var self_p: int = round.state.turn
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
		push_warning("[OneManArmy] Pattern was ready but adjacency not found at click time.")
		return

	# Destroy the lone self checker
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
			round.call("deal_player_damage", int(eff.amount), false)
		else:
			round.run_state.player_hp -= int(eff.amount)
		if round != null and round.has_method("deal_enemy_damage"):
			round.call("deal_enemy_damage", sent, true)
		else:
			round.run_state.enemy_hp -= sent

	# Update visuals and consume card
	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)


static func _apply_subterfuge(round: Node, card: CardInstance, eff: CardEffect) -> void:
	var p: int = int(round.state.turn)
	var ctx := PatternContext.new(round.state, p)

	# Find the start of the matched mixed sequence
	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break
	if req == null:
		push_warning("[Subterfuge] No RUN_SEQUENCE_MIXED req on card.")
		return

	var start_point := PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[Subterfuge] Pattern ready but could not locate matched start.")
		return

	# Expect 3 points: left black stack, middle white single, right black stack
	var left_pt := start_point
	var mid_pt := start_point + 1
	var right_pt := start_point + 2

	# Pop top checker from left + right enemy stacks and send to bar
	var sent := 0
	for pt in [left_pt, right_pt]:
		var st: PackedInt32Array = round.state.points[pt]
		if st.size() == 0:
			continue
		var top_id := int(st[st.size() - 1])
		# Only send if it’s enemy (black)
		if round.state.owner_of(top_id) == BoardState.Player.BLACK:
			Rules.send_checker_to_bar(round.state, top_id)
			sent += 1

	# Deal 2 HP damage to black (enemy) if we sent at least one (or always; your choice)
	if round.run_state != null:
		if round != null and round.has_method("deal_enemy_damage"):
			round.call("deal_enemy_damage", 2, true)
		else:
			round.run_state.enemy_hp -= 2

	# Sync visuals
	if round.board != null and round.board.has_method("sync_from_state_full"):
		round.board.call("sync_from_state_full", round.state)

	round.emit_signal("card_consumed", card.uid)
