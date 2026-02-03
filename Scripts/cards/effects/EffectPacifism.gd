extends CardEffect
class_name EffectPacifism

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break

	if req == null:
		push_warning("[EffectPacifism] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectPacifism] Pattern ready but could not locate matched start.")
		return

	var checker_ids: Array[int] = []
	for offset in range(req.mix_owners.size()):
		var point_i := start_point + offset
		if point_i < 0 or point_i > 23:
			continue
		var st: PackedInt32Array = round.state.points[point_i]
		for checker_id in st:
			checker_ids.append(int(checker_id))

	if checker_ids.is_empty():
		push_warning("[EffectPacifism] No checkers found for pacifism.")
		return

	if round.has_method("activate_pacifism"):
		round.call("activate_pacifism", checker_ids, card)
