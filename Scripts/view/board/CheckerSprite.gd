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
var _pacifism_label: Label = null
var _chain_reaction_label: Label = null
var _stealth_label: Label = null
var _stockpile_label: Label = null

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

func set_pacifism_state(enabled: bool) -> void:
	_ensure_pacifism_label()
	if _pacifism_label != null:
		_pacifism_label.visible = enabled

func set_chain_reaction_state(enabled: bool) -> void:
	_ensure_chain_reaction_label()
	if _chain_reaction_label != null:
		_chain_reaction_label.visible = enabled

func set_stealth_state(enabled: bool) -> void:
	_ensure_stealth_label()
	if _stealth_label != null:
		_stealth_label.visible = enabled

func set_stockpile_state(enabled: bool) -> void:
	_ensure_stockpile_label()
	if _stockpile_label != null:
		_stockpile_label.visible = enabled

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

func _ensure_pacifism_label() -> void:
	if _pacifism_label != null:
		return
	var existing: Label = get_node_or_null("PacifismLabel") as Label
	if existing != null:
		_pacifism_label = existing
		return
	var label := Label.new()
	label.name = "PacifismLabel"
	label.text = "P"
	label.z_index = 2001
	label.scale = Vector2(0.75, 0.75)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-6, -4)
	label.visible = false
	add_child(label)
	_pacifism_label = label

func _ensure_chain_reaction_label() -> void:
	if _chain_reaction_label != null:
		return
	var existing: Label = get_node_or_null("ChainReactionLabel") as Label
	if existing != null:
		_chain_reaction_label = existing
		return
	var label := Label.new()
	label.name = "ChainReactionLabel"
	label.text = "x"
	label.z_index = 2002
	label.scale = Vector2(0.75, 0.75)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(6, -18)
	label.visible = false
	add_child(label)
	_chain_reaction_label = label

func _ensure_stealth_label() -> void:
	if _stealth_label != null:
		return
	var existing: Label = get_node_or_null("StealthLabel") as Label
	if existing != null:
		_stealth_label = existing
		return
	var label := Label.new()
	label.name = "StealthLabel"
	label.text = "<->"
	label.z_index = 2003
	label.scale = Vector2(0.65, 0.65)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-14, -4)
	label.visible = false
	add_child(label)
	_stealth_label = label

func _ensure_stockpile_label() -> void:
	if _stockpile_label != null:
		return
	var existing: Label = get_node_or_null("StockpileLabel") as Label
	if existing != null:
		_stockpile_label = existing
		return
	var label := Label.new()
	label.name = "StockpileLabel"
	label.text = "S"
	label.z_index = 2004
	label.scale = Vector2(0.7, 0.7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(10, -4)
	label.visible = false
	add_child(label)
	_stockpile_label = label

func _on_click_area_input_event(_vp: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", checker_id)
