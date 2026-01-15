extends Resource
class_name CardEffect

# Always append new kinds; do not reorder or older .tres will break
enum Kind {
	NONE,
	START_TARGETED_SEND_TO_BAR,   # Ionic Crossbow
	ONE_MAN_ARMY,                 # One Man Army
	START_TARGETED_MORTAR,
	SUBTERFUGE
}

@export var kind: Kind = Kind.NONE
@export var amount: int = 0

# NEW: Resource-based entry point.
# New effect resources override this.
# Old effect resources will fall back to legacy behavior.
func apply(round: RoundController, card: CardInstance, ctx: PatternContext) -> void:
	CardEffectRunner.activate_legacy(round, card, ctx, self)
