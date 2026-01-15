extends RefCounted
class_name MoveEnumerator

static func _unique_indices_for_values(vals: Array) -> Array:
	var seen := {}
	var out: Array = []
	for i in range(vals.size()):
		var v := int(vals[i])
		if not seen.has(v):
			seen[v] = true
			out.append(i)
	return out

static func enumerate_best_sequences(
		root,
		dice: Array,
		player: int,
		cfg: AIConfig,
		adv: BlackAdvantage,
		black_turn_index: int
	) -> Array:
	var start_usec := Time.get_ticks_usec()
	var budget_usec := int(maxf(0.0, cfg.time_budget_ms) * 1000.0)

	var beam: Array = [{
		"seq": [],
		"adapter": root,
		"score": 0.0,
		"used": 0,
		"remaining": dice.duplicate()
	}]

	var best_used := 0

	while beam.size() > 0:
		if budget_usec > 0 and (Time.get_ticks_usec() - start_usec) > budget_usec:
			break

		var next_beam: Array = []

		for node_v in beam:
			var node: Dictionary = node_v as Dictionary
			var remaining: Array = node.get("remaining", [])
			if remaining.is_empty():
				next_beam.append(node)
				continue

			var any_expanded := false
			var pick_idxs := _unique_indices_for_values(remaining)

			for idx_v in pick_idxs:
				var idx := int(idx_v)
				var die := int(remaining[idx])

				var adapter = node.get("adapter")
				var moves: Array = adapter.legal_moves_for_die(die, player)
				if moves.is_empty():
					continue

				any_expanded = true
				for mv in moves:
					if typeof(mv) != TYPE_DICTIONARY:
						continue
					var m: Dictionary = mv

					var m2: Dictionary = m.duplicate(true)
					m2["die"] = die

					var a2 = adapter.clone()
					a2.apply_move(m2, player)

					var rem2 := remaining.duplicate()
					rem2.remove_at(idx)

					var seq2: Array = (node.get("seq", []) as Array).duplicate()
					seq2.append(m2)

					var s := AIEvaluator.score(a2, seq2, cfg, adv, black_turn_index)

					next_beam.append({
						"seq": seq2,
						"adapter": a2,
						"score": s,
						"used": int(node.get("used", 0)) + 1,
						"remaining": rem2
					})

			if not any_expanded:
				next_beam.append(node)

		# enforce "use as many dice as possible"
		for n_v in next_beam:
			var n: Dictionary = n_v as Dictionary
			best_used = maxi(best_used, int(n.get("used", 0)))

		var filtered: Array = []
		for n_v in next_beam:
			var n: Dictionary = n_v as Dictionary
			if int(n.get("used", 0)) == best_used:
				filtered.append(n)

		filtered.sort_custom(func(a, b): return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0)))
		if filtered.size() > cfg.beam_width:
			filtered.resize(cfg.beam_width)

		beam = filtered

		if beam.size() > cfg.max_sequences:
			beam.resize(cfg.max_sequences)

	beam.sort_custom(func(a, b): return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0)))
	return beam
