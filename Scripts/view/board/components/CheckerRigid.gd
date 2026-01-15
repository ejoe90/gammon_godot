extends RigidBody2D
class_name CheckerRigid

@export var play_animation_name: StringName = &"idle"

@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D

func _ready() -> void:
	anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null:
		anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null:
		anim_sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D

	if anim_sprite == null:
		push_error("[CheckerRigid] AnimatedSprite2D not found.")
		return

	var frames := anim_sprite.sprite_frames
	if frames == null:
		push_error("[CheckerRigid] AnimatedSprite2D has no SpriteFrames assigned.")
		return

	# Pick a valid animation name
	var anim_to_play: StringName = play_animation_name
	if not frames.has_animation(String(anim_to_play)):
		var names: PackedStringArray = frames.get_animation_names()
		if names.size() == 0:
			push_error("[CheckerRigid] SpriteFrames has no animations.")
			return
		anim_to_play = StringName(names[0])  # first available animation
		print("[CheckerRigid] play_animation_name missing; using:", anim_to_play)

	anim_sprite.play(anim_to_play)

func configure_physics() -> void:
	lock_rotation = true
	angular_damp = 20.0
	linear_damp = 6.0
	can_sleep = true
	sleeping = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

func set_color_animation(is_white: bool) -> void:
	if anim_sprite == null:
		return
	var target: StringName = &"white" if is_white else &"black"
	# don’t restart every time
	if anim_sprite.animation != target or not anim_sprite.is_playing():
		anim_sprite.play(target)
