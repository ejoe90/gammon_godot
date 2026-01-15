extends RefCounted
class_name PatternContext

var state: BoardState
var self_player: int

# Updated by RoundController as gameplay occurs
var last_move_hit: bool = false
var hits_this_turn: int = 0

func _init(s: BoardState, p: int) -> void:
	state = s
	self_player = p
