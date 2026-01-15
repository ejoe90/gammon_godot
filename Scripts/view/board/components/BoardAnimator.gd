# res://scripts/view/board/components/BoardAnimator.gd
extends Node
class_name BoardAnimator

func fly_to(node: Node2D, end_pos: Vector2, t: float, done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(node, "global_position", end_pos, t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if done.is_valid(): done.call()
	)

func fly_to_with_bounce(
	node: Node2D,
	end_pos: Vector2,
	bounce_dir: Vector2,
	move_time: float,
	bounce_px: float,
	bounce_time: float,
	done: Callable
) -> void:
	var overshoot_pos := end_pos + bounce_dir * bounce_px

	var tw := create_tween()
	tw.set_parallel(false)

	# 1) arrive
	tw.tween_property(node, "global_position", end_pos, move_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2) overshoot
	tw.tween_property(node, "global_position", overshoot_pos, bounce_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3) settle
	tw.tween_property(node, "global_position", end_pos, bounce_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	tw.finished.connect(func() -> void:
		if done.is_valid(): done.call()
	)
