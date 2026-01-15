# res://Scripts/cards/effects/EffectTargetedSendToBar.gd
extends CardEffect
class_name EffectTargetedSendToBar

@export var enemy_damage: int = 0
@export var restrict_to_opposite_half: bool = true
@export var max_stack_hits: int = 1


func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	if round == null or round.state == null:
		return

	var self_p: int = int(round.state.turn)
	var enemy_p: int = BoardState.Player.BLACK if self_p == BoardState.Player.WHITE else BoardState.Player.WHITE

	# -1 means "no restriction: allow targeting anywhere on the board"
	var required_half: int = -1

	if restrict_to_opposite_half:
		var start_point: int = _find_source_pattern_start(card, ctx)
		if start_point != -1:
			var src_half: int = 0 if start_point <= 11 else 1
			required_half = 1 - src_half
		else:
			push_warning("[EffectTargetedSendToBar] Could not determine source half from pattern; allowing full-board targeting.")
			required_half = -1

	round._begin_targeting_send_to_bar(required_half, enemy_p, card, int(enemy_damage), int(max_stack_hits))


func _find_source_pattern_start(card: CardInstance, ctx: PatternContext) -> int:
	if card == null or card.def == null:
		return -1

	for r: PatternReq in card.def.pattern:
		if r != null and r.kind == PatternReq.Kind.RUN_SEQUENCE:
			return PatternMatcher.find_run_sequence_start(r, ctx)

	return -1
