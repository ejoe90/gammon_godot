extends Resource
class_name PatternReq

# --------------------------------------------------------------------------
# PATTERN REQ BASICS
# Each card pattern describes a board configuration that "activates" the card.
# Only two kinds are used for MVP:
#   RUN_SEQUENCE – a chain of owned stacks (ex: 1-2-1 or 1-2-3)
#   ADJACENT_PAIR – two neighboring stacks meeting A/B conditions
# --------------------------------------------------------------------------

enum Kind {
	RUN_SEQUENCE,   # For sequential same-side stacks
	ADJACENT_PAIR,
	RUN_SEQUENCE_MIXED,
	ACROSS_PAIR,  # For neighbor relationships (1 next to 4+ enemy)
	ACROSS_ADJACENT_PAIR
}

@export var kind: Kind = Kind.RUN_SEQUENCE

# --------------------------------------------------------------------------
# Shared base filters
# --------------------------------------------------------------------------
@export var owner_a: int = 0      # 0 = WHITE, 1 = BLACK, etc.
@export var owner_b: int = 1
@export var min_count_a: int = 1
@export var max_count_a: int = 15
@export var min_count_b: int = 1
@export var max_count_b: int = 15
@export var require_empty_a: bool = false
@export var require_empty_b: bool = false

# --------------------------------------------------------------------------
# RUN_SEQUENCE parameters
# --------------------------------------------------------------------------
@export var seq_counts: PackedInt32Array = PackedInt32Array([1, 2, 1])
@export var seq_allow_reverse: bool = false      # Allow 1-2-3 or 3-2-1
@export var seq_same_half_only: bool = true      # Disallow crossing 11/12
@export var seq_max_gap: int = 0                 # 0 = consecutive points

# --------------------------------------------------------------------------
# ADJACENT_PAIR parameter
# --------------------------------------------------------------------------
@export var adj_either_order: bool = true


# RUN_SEQUENCE_MIXED
# A 3-step (or N-step) sequence where each step can have its own owner and min/max.
# Example Subterfuge:
#  owners = [BLACK, WHITE, BLACK]
#  mins   = [2,     1,     2]
#  maxs   = [15,    1,     15]
@export var mix_owners: PackedInt32Array = PackedInt32Array()
@export var mix_mins: PackedInt32Array = PackedInt32Array()
@export var mix_maxs: PackedInt32Array = PackedInt32Array()
@export var mix_allow_reverse: bool = false
@export var mix_same_half_only: bool = true
@export var mix_max_gap: int = 0
