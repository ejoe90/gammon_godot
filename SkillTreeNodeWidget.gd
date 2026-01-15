extends Control
class_name SkillTreeNodeWidget

signal pressed(node_id: String)

@export var node_id: String = ""   # must match SkillTreeDefs ids

@onready var btn: Button = $Button
@onready var name_label: Label = $Name
@onready var badge: Label = get_node_or_null("Badge") as Label
@onready var lock_overlay: ColorRect = get_node_or_null("LockOverlay") as ColorRect

func _ready() -> void:
	if not btn.pressed.is_connected(Callable(self, "_on_pressed")):
		btn.pressed.connect(Callable(self, "_on_pressed"))

func set_text(title: String, subtitle: String = "") -> void:
	if name_label != null:
		name_label.text = title if subtitle == "" else ("%s\n%s" % [title, subtitle])

func set_state(owned: bool, available: bool) -> void:
	# owned: already taken/maxed
	# available: can be picked now
	if owned:
		btn.disabled = true
		modulate = Color(1, 1, 1, 1)
		if lock_overlay: lock_overlay.visible = false
	elif available:
		btn.disabled = false
		modulate = Color(1, 1, 1, 1)
		if lock_overlay: lock_overlay.visible = false
	else:
		btn.disabled = true
		modulate = Color(1, 1, 1, 0.25)
		if lock_overlay: lock_overlay.visible = true

func set_badge(t: String) -> void:
	if badge != null:
		badge.text = t

func _on_pressed() -> void:
	if node_id != "":
		emit_signal("pressed", node_id)
