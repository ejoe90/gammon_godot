extends Node2D
class_name CheckerSprite

signal clicked(checker_id: int)

@export var tex_white: Texture2D
@export var tex_black: Texture2D
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var click_area_path: NodePath = NodePath("ClickArea")

@onready var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D
@onready var click_area: Area2D = get_node_or_null(click_area_path) as Area2D

var checker_id: int = -1
var _zero_sum_material: ShaderMaterial = null

const ZERO_SUM_SHADER_PATH := "res://Shaders/zero_sum_overlay.gdshader"

func _ready() -> void:
	if click_area != null:
		click_area.input_pickable = true
		click_area.input_event.connect(Callable(self, "_on_click_area_input_event"))

func set_checker_id(id: int) -> void:
	checker_id = id
	set_meta("checker_id", id)

func set_color(is_white: bool) -> void:
	if sprite == null:
		return
	sprite.texture = tex_white if is_white else tex_black

func set_zero_sum_state(enabled: bool, overlay_color: Color) -> void:
	if sprite == null:
		return

	if not enabled:
		if sprite.material == _zero_sum_material:
			sprite.material = null
		_zero_sum_material = null
		return

	if _zero_sum_material == null:
		var shader: Shader = load(ZERO_SUM_SHADER_PATH) as Shader
		if shader == null:
			push_warning("[CheckerSprite] Missing shader: %s" % ZERO_SUM_SHADER_PATH)
			return
		_zero_sum_material = ShaderMaterial.new()
		_zero_sum_material.shader = shader

	sprite.material = _zero_sum_material
	_zero_sum_material.set_shader_parameter("overlay_color", overlay_color)

func _on_click_area_input_event(_vp: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", checker_id)
