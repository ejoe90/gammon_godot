extends Resource
class_name AuxCardDef

@export var id: String
@export var display_name: String
@export_multiline var description: String

@export var base_ap_cost: int = 1
@export var base_cooldown_turns: int = 0
@export var max_uses_per_round: int = 999999 # set to 1 for “once per round”

# Preferred: resource-driven effect routing.
# If effect is set, AuxCardRunner will call effect.apply(...).
@export var effect: AuxEffect

# Legacy routing (kept for backward compatibility while migrating).
@export var effect_kind: String = ""         # e.g. "GAIN_GOLD", "ADD_BONUS_DIE"
@export var effect_params: Dictionary = {}   # e.g. {"amount": 10}


@export var icon: Texture2D
