extends Resource
class_name AuxEffect

# Base class for aux card effects.
# Implement apply() in subclasses.

# ctx is optional contextual data (e.g. use_index for scaling effects).
func apply(round, def, mod: Dictionary, ctx: Dictionary = {}) -> void:
	push_warning("[AuxEffect] apply() not implemented for %s" % [self])
