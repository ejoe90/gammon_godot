extends CardActivationReq
class_name ActivationReqWhiteBar

@export var min_count: int = 3

func matches(round: RoundController, card: CardInstance, ctx: PatternContext) -> bool:
	if round == null or round.state == null:
		return false
	return int(round.state.bar_white.size()) >= int(min_count)
