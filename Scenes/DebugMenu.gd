## res://scripts/view/ui/DebugMenu.gd
#extends CanvasLayer
#class_name DebugMenu
#
#signal request_point_delta(point_index: int, is_white: bool, delta: int)
#signal request_point_clear(point_index: int)
#signal request_force_dice(d1: int, d2: int)
#signal request_roll_random()
#signal request_setup_home_boards()
#
#
#@export var toggle_action: StringName = &"debug_toggle" # optional; fallback uses F1 in _unhandled_input
#
#@onready var point_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PointSpin
#@onready var player_opt: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/PlayerOpt
#@onready var add_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/AddBtn
#@onready var sub_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/SubBtn
#@onready var clear_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/ClearBtn
#
#@onready var die1_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/Die1Spin
#@onready var die2_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/Die2Spin
#@onready var force_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/ForceDiceBtn
#@onready var roll_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer5/RollBtn
#@onready var home_setup_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/HomeSetupBtn
#
#
#func _ready() -> void:
	#visible = false
#
	#player_opt.clear()
	#player_opt.add_item("White", 0)
	#player_opt.add_item("Black", 1)
	#player_opt.select(0)
#
	#add_btn.pressed.connect(_on_add_pressed)
	#sub_btn.pressed.connect(_on_sub_pressed)
	#clear_btn.pressed.connect(_on_clear_pressed)
#
	#force_btn.pressed.connect(_on_force_dice_pressed)
	#roll_btn.pressed.connect(func() -> void:
		#emit_signal("request_roll_random")
	#)
	#
	#home_setup_btn.pressed.connect(func() -> void:
		#emit_signal("request_setup_home_boards")
	#)
#
#
#func _unhandled_input(event: InputEvent) -> void:
	## Simple F1 toggle; works without needing InputMap setup
	#if event is InputEventKey and event.pressed and not event.echo:
		#var ek := event as InputEventKey
		#if ek.keycode == KEY_F1:
			#visible = not visible
			## prevent accidental clicks passing through if menu is open
			#get_viewport().set_input_as_handled()
#
#func _is_white_selected() -> bool:
	#return player_opt.selected == 0
#
#func _on_add_pressed() -> void:
	#emit_signal("request_point_delta", int(point_spin.value), _is_white_selected(), +1)
#
#func _on_sub_pressed() -> void:
	#emit_signal("request_point_delta", int(point_spin.value), _is_white_selected(), -1)
#
#func _on_clear_pressed() -> void:
	#emit_signal("request_point_clear", int(point_spin.value))
#
#func _on_force_dice_pressed() -> void:
	#emit_signal("request_force_dice", int(die1_spin.value), int(die2_spin.value))



##################

# res://scripts/view/ui/DebugMenu.gd
extends CanvasLayer
class_name DebugMenu

const SPACE_BAR_BLACK: int = -2
const SPACE_BAR_WHITE: int = -1

signal request_point_delta(point_index: int, is_white: bool, delta: int)
signal request_point_clear(point_index: int)
signal request_force_dice(d1: int, d2: int)
signal request_roll_random()
signal request_setup_home_boards()


@export var toggle_action: StringName = &"debug_toggle" # optional; fallback uses F1 in _unhandled_input

@onready var space_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var point_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PointSpin
@onready var player_opt: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/PlayerOpt
@onready var add_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/AddBtn
@onready var sub_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/SubBtn
@onready var clear_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/ClearBtn

@onready var die1_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/Die1Spin
@onready var die2_spin: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/Die2Spin
@onready var force_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/ForceDiceBtn
@onready var roll_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer5/RollBtn
@onready var home_setup_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/HomeSetupBtn


func _ready() -> void:
	visible = false

	# Allow selecting points (0..23) and bars (-1 white bar, -2 black bar)
	point_spin.min_value = float(SPACE_BAR_BLACK)
	point_spin.max_value = 23.0
	space_label.text = "Space"

	player_opt.clear()
	player_opt.add_item("White", 0)
	player_opt.add_item("Black", 1)
	player_opt.select(0)

	add_btn.pressed.connect(_on_add_pressed)
	sub_btn.pressed.connect(_on_sub_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)

	force_btn.pressed.connect(_on_force_dice_pressed)
	roll_btn.pressed.connect(func() -> void:
		emit_signal("request_roll_random")
	)
	
	home_setup_btn.pressed.connect(func() -> void:
		emit_signal("request_setup_home_boards")
	)



func set_selected_space(space_index: int, bar_player: int = -1) -> void:
	# space_index: 0..23 points, SPACE_BAR_WHITE (-1), SPACE_BAR_BLACK (-2)
	point_spin.value = float(space_index)
	if space_index == SPACE_BAR_WHITE:
		player_opt.select(0)
		space_label.text = "Space (White Bar)"
	elif space_index == SPACE_BAR_BLACK:
		player_opt.select(1)
		space_label.text = "Space (Black Bar)"
	else:
		space_label.text = "Space"

func _unhandled_input(event: InputEvent) -> void:
	# Simple F1 toggle; works without needing InputMap setup
	if event is InputEventKey and event.pressed and not event.echo:
		var ek := event as InputEventKey
		if ek.keycode == KEY_F1:
			visible = not visible
			# prevent accidental clicks passing through if menu is open
			get_viewport().set_input_as_handled()

func _is_white_selected() -> bool:
	return player_opt.selected == 0

func _on_add_pressed() -> void:
	emit_signal("request_point_delta", int(point_spin.value), _is_white_selected(), +1)

func _on_sub_pressed() -> void:
	emit_signal("request_point_delta", int(point_spin.value), _is_white_selected(), -1)

func _on_clear_pressed() -> void:
	emit_signal("request_point_clear", int(point_spin.value))

func _on_force_dice_pressed() -> void:
	emit_signal("request_force_dice", int(die1_spin.value), int(die2_spin.value))
