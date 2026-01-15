extends Resource
class_name CardActivationReq

func matches(round: RoundController, card: CardInstance, ctx: PatternContext) -> bool:
	return true
