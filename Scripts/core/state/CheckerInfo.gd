extends RefCounted
class_name CheckerInfo

var id: int
var owner: int # BoardState.Player.WHITE / BLACK

# Expand later for per-checker effects:
var tags: Dictionary = {}       # e.g. {"poisoned": true}
var stacks: Dictionary = {}     # e.g. {"shield": 2}
var modifiers: Dictionary = {}  # e.g. {"atk": +1}

func _init(_id: int, _owner: int) -> void:
	id = _id
	owner = _owner
