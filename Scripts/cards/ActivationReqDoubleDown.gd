extends CardActivationReq
class_name ActivationReqDoubleDown

func matches(round: RoundController, card: CardInstance, ctx: PatternContext) -> bool:
	if round == null:
		return false
	return bool(round.turn_double_down_ready)
