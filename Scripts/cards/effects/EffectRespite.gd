extends CardEffect
class_name EffectRespite

func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null or card == null or card.def == null:
		return

	var req: PatternReq = null
	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE_MIXED:
			req = r
			break

	if req == null:
		push_warning("[EffectRespite] No RUN_SEQUENCE_MIXED PatternReq on card.")
		return

	var start_point: int = PatternMatcher.find_run_sequence_mixed_start(req, ctx)
	if start_point == -1:
		push_warning("[EffectRespite] Pattern ready but could not locate matched start.")
		return

	var points := PackedInt32Array([start_point, start_point + 1, start_point + 2, start_point + 3])
	if round.has_method("activate_respite"):
		round.call("activate_respite", points, card)
