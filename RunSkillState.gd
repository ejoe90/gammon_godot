extends Resource
class_name RunSkillState

@export var node_levels: Dictionary = {}     # node_id -> int
@export var aux_unlocked: Dictionary = {}    # aux_id -> copies (int)
@export var aux_mods: Dictionary = {}        # aux_id -> Dictionary of modifiers

func get_node_level(node_id: String) -> int:
	return int(node_levels.get(node_id, 0))

func inc_node_level(node_id: String, delta: int = 1) -> int:
	var v := get_node_level(node_id) + delta
	node_levels[node_id] = v
	return v

func get_aux_copies(aux_id: String) -> int:
	return int(aux_unlocked.get(aux_id, 0))

func add_aux_copies(aux_id: String, delta: int) -> int:
	var v := maxi(0, get_aux_copies(aux_id) + delta)
	aux_unlocked[aux_id] = v
	return v

func get_aux_mod(aux_id: String) -> Dictionary:
	return aux_mods.get(aux_id, {}) as Dictionary

func set_aux_mod(aux_id: String, mod: Dictionary) -> void:
	aux_mods[aux_id] = mod
