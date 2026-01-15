extends Control
class_name HandHUD

@export var round_controller_path: NodePath = NodePath("../../RoundController")
@export var card_list_path: NodePath = NodePath("CardList")
@export var card_button_scene: PackedScene
@export var self_player: int = BoardState.Player.WHITE

var round: RoundController
var card_list: Container

func _ready() -> void:
	round = _find_round_controller()
	if round == null:
		push_error("[HandHUD] Could not find RoundController.")
		return

	card_list = get_node_or_null(card_list_path) as Container
	if card_list == null:
		push_error("[HandHUD] Missing card list container at: %s" % str(card_list_path))
		return

	if card_button_scene == null:
		push_error("[HandHUD] card_button_scene is not set (assign CardSlotButton.tscn).")
		return

	# Listen for the RoundController to build/refresh the hand
	if round.has_signal("hand_changed"):
		round.hand_changed.connect(_on_hand_changed)

	# If the round already built a hand, draw it now
	if round.has_method("get_hand"):
		_on_hand_changed(round.get_hand())

func _on_hand_changed(hand: Array[CardInstance]) -> void:
	# Clear existing buttons
	for child in card_list.get_children():
		child.queue_free()

	# Build buttons for current hand
	for ci in hand:
		if ci == null or ci.def == null:
			continue
		var btn := card_button_scene.instantiate() as CardSlotButton
		card_list.add_child(btn)
		btn.setup(round, ci, self_player)

func _find_round_controller() -> RoundController:
	var rc := get_node_or_null(round_controller_path) as RoundController
	if rc != null:
		return rc

	var root := get_tree().current_scene
	if root != null:
		var found := root.find_child("RoundController", true, false) as RoundController
		if found != null:
			return found

	return null
	
	
func debug_set_hand_index(hand_index: int, def: CardDef) -> void:
	if round == null:
		round = _find_round_controller()
	if round == null or def == null:
		return

	if not round.has_method("debug_set_hand_index"):
		push_error("[HandHUD] RoundController missing debug_set_hand_index(hand_index, def).")
		return

	round.call("debug_set_hand_index", hand_index, def)

func debug_fill_hand(def: CardDef, hand_size: int = 5) -> void:
	if round == null:
		round = _find_round_controller()
	if round == null or def == null:
		return

	if not round.has_method("debug_fill_hand"):
		push_error("[HandHUD] RoundController missing debug_fill_hand(def, hand_size).")
		return

	round.call("debug_fill_hand", def, hand_size)

func debug_clear_hand() -> void:
	if round == null:
		round = _find_round_controller()
	if round == null:
		return

	if not round.has_method("debug_clear_hand"):
		push_error("[HandHUD] RoundController missing debug_clear_hand().")
		return

	round.call("debug_clear_hand")
