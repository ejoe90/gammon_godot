extends Control
class_name EndRoundShop

signal finished()

@onready var heal_btn: Button = $Panel/VBox/HealBtn
@onready var gold_btn: Button = $Panel/VBox/GoldBtn
@onready var card_btn: Button = $Panel/VBox/CardBtn
@onready var continue_btn: Button = $Panel/VBox/ContinueBtn

var run_state: RunState

func _ready() -> void:
	visible = false
	heal_btn.pressed.connect(_on_heal)
	gold_btn.pressed.connect(_on_gold)
	card_btn.pressed.connect(_on_card)
	continue_btn.pressed.connect(func():
		visible = false
		emit_signal("finished")
	)

func open(rs: RunState) -> void:
	run_state = rs
	visible = true

func _on_heal() -> void:
	if run_state == null: return
	run_state.player_hp = min(run_state.player_max_hp, run_state.player_hp + 5)

func _on_gold() -> void:
	if run_state == null: return
	if run_state.has_method("add_gold"):
		run_state.call("add_gold", 10, true)
	else:
		run_state.gold += 10

func _on_card() -> void:
	if run_state == null: return

	var id := CardDB.random_id()
	if id == "":
		return

	run_state.deck.append(id)
	print("[Shop] Added card to deck:", id)
