extends AuxEffect
class_name AuxEffectNotice

@export_multiline var message: String = "Aux effect not implemented."

func apply(round, def, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round != null and round.has_method("show_notice"):
		round.call("show_notice", message)
