extends Control
class_name RoundEndOverlay

signal restart_pressed()
signal next_pressed()

@onready var title_label: Label = $Panel/TitleLabel
@onready var restart_btn: Button = $Panel/RestartBtn
@onready var next_btn: Button = $Panel/NextBtn

func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(func(): emit_signal("restart_pressed"))
	next_btn.pressed.connect(func(): emit_signal("next_pressed"))

func show_result(text: String) -> void:
	title_label.text = text
	visible = true

func hide_overlay() -> void:
	visible = false
