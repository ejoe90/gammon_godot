extends Control
class_name SkillTreeNode

signal pressed(node_id: String)

@onready var btn: Button = $Button
@onready var name_label: Label = $Name

var node_id: String = ""
var _state: int = 0 # 0 locked, 1 available, 2 owned

func setup(id: String, display_name: String) -> void:
	node_id = id
	if name_label != null:
		name_label.text = display_name
	if not btn.pressed.is_connected(Callable(self, "_on_pressed")):
		btn.pressed.connect(Callable(self, "_on_pressed"))

func set_state(new_state: int) -> void:
	_state = new_state
	match _state:
		0:
			btn.disabled = true
			modulate = Color(1, 1, 1, 0.25)
		1:
			btn.disabled = false
			modulate = Color(1, 1, 1, 1.0)
		2:
			btn.disabled = true
			modulate = Color(1, 1, 1, 1.0)

func _on_pressed() -> void:
	emit_signal("pressed", node_id)
