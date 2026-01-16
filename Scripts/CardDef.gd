extends Resource
class_name CardDef

enum Category { ECONOMY, COMBAT, TEMPO, DEFENSE }

@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.ECONOMY

# Card pip value (used for burn-for-pips mode).
# Should be in [-6..-1] or [1..6]. (0 is invalid.)
@export var pip_value: int = 1

# AP costs
@export_range(0, 10) var ap_cost_activate: int = 1
@export_range(0, 10) var ap_cost_burn: int = 1

# Pattern requirements: all must match to Activate.
@export var pattern: Array[PatternReq] = []

# Primary effect (preferred). If older .tres still use effects[],
# primary_effect() falls back to effects[0].
@export var effect: CardEffect

# Legacy support (older resources may still use this)
@export var effects: Array[CardEffect] = []

# Optional art
@export var art_texture: Texture2D

@export var activation_req: CardActivationReq


func primary_effect() -> CardEffect:
	if effect != null:
		return effect
	if effects.size() > 0:
		return effects[0]
	return null
