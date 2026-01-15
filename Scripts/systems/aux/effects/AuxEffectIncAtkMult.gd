extends AuxEffect
class_name AuxEffectIncAtkMult

@export var delta: int = 1

func apply(round, def, mod: Dictionary, ctx: Dictionary = {}) -> void:
	if round == null:
		return
	var rs = round.run_state
	if rs == null:
		return

	var d: int = int(delta) + int(mod.get("atk_mult_delta", 0))
	rs.player_attack_mult = maxi(1, int(rs.player_attack_mult) + d)

	if round.has_method("show_notice"):
		round.call("show_notice", "Attack x%d for this run." % int(rs.player_attack_mult))
