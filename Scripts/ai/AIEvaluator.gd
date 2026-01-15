extends RefCounted
class_name AIEvaluator

static func score(adapter, seq: Array, cfg: AIConfig, adv: BlackAdvantage, black_turn_index: int) -> float:
	var f: Dictionary = adapter.features()

	var black_blots := int(f.get("black_blots", 0))
	var black_on_bar := int(f.get("black_on_bar", 0))
	var black_points_made := int(f.get("black_points_made", 0))
	var white_points_made := int(f.get("white_points_made", 0))
	var black_pip := float(f.get("black_pip_count", 0.0))

	var hits := 0
	var bearoffs := 0
	for mv in seq:
		if typeof(mv) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = mv
		if bool(m.get("hit", false)):
			hits += 1
		if int(m.get("to", -999)) == -2:
			bearoffs += 1

	var dmg_mult := adv.damage_multiplier(black_turn_index)

	var A := clampf(cfg.aggression, 0.0, 1.0)
	var offense_scale := lerpf(0.7, 1.3, A)
	var defense_scale := lerpf(1.3, 0.7, A)

	var s := 0.0

	# offense
	s += offense_scale * cfg.w_hit * float(hits) * float(dmg_mult)
	s += offense_scale * cfg.w_bearoff * float(bearoffs)
	s += offense_scale * cfg.w_make_point * float(black_points_made)

	# racing (lower pip count better)
	s += offense_scale * cfg.w_race * (-black_pip)

	# defense
	s -= defense_scale * cfg.w_own_blots * float(black_blots)
	s -= defense_scale * cfg.w_on_bar * float(black_on_bar)

	# opponent structure is bad for us
	s -= 1.2 * float(white_points_made)

	# tiny noise for variability
	if cfg.randomness > 0.0:
		s += randf_range(-cfg.randomness, cfg.randomness)

	return s
