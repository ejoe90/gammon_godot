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
var _distant_threat_material: ShaderMaterial = null
var _distant_threat_label: Label = null

const ZERO_SUM_SHADER_PATH := "res://Shaders/zero_sum_overlay.gdshader"
const DISTANT_THREAT_SHADER_PATH := "res://Shaders/distant_threat_glow.gdshader"

func _ready() -> void:
	if click_area != null:
		click_area.input_pickable = true
		click_area.input_event.connect(Callable(self, "_on_click_area_input_event"))
	_ensure_distant_threat_label()

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

func set_distant_threat_state(enabled: bool, turns_left: int) -> void:
	if sprite == null:
		return

	_ensure_distant_threat_label()

	if not enabled:
		if sprite.material == _distant_threat_material:
			sprite.material = null
		_distant_threat_material = null
		if _distant_threat_label != null:
			_distant_threat_label.visible = false
		return

	if _distant_threat_material == null:
		var shader: Shader = load(DISTANT_THREAT_SHADER_PATH) as Shader
		if shader == null:
			push_warning("[CheckerSprite] Missing shader: %s" % DISTANT_THREAT_SHADER_PATH)
			return
		_distant_threat_material = ShaderMaterial.new()
		_distant_threat_material.shader = shader

	sprite.material = _distant_threat_material
	if _distant_threat_label != null:
		_distant_threat_label.text = str(maxi(1, turns_left))
		_distant_threat_label.visible = true

func _ensure_distant_threat_label() -> void:
	if _distant_threat_label != null:
		return
	var existing: Label = get_node_or_null("DistantThreatLabel") as Label
	if existing != null:
		_distant_threat_label = existing
		return
	var label := Label.new()
	label.name = "DistantThreatLabel"
	label.text = ""
	label.z_index = 2000
	label.scale = Vector2(0.75, 0.75)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-10, -18)
	label.visible = false
	add_child(label)
	_distant_threat_label = label

func _on_click_area_input_event(_vp: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", checker_id)
