extends RefCounted
class_name CardInstance

static var _next_uid: int = 1

var uid: int
var def: CardDef

func _init(card_def: CardDef) -> void:
	def = card_def
	uid = _next_uid
	_next_uid += 1
