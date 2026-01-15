extends CardActivationReq
class_name ActivationReqQuickStrike

func matches(round: RoundController, card: CardInstance, ctx: PatternContext) -> bool:
	if round == null:
		return false
	return bool(round.quick_strike_ready)
