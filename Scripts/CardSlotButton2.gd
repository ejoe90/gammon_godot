extends Button
class_name CardSlotButton2

@export var self_player: int = BoardState.Player.WHITE
@export var poll_interval: float = 0.10

# Visual tuning
@export var invert_on_pattern_ok: bool = true
@export_range(0.0, 1.0) var invert_amount_wait: float = 0.65   # pattern met but not fully ready
@export_range(0.0, 1.0) var invert_amount_ready: float = 1.0   # fully ready to activate

@onready var art: TextureRect = get_node_or_null("Art") as TextureRect

var round: RoundController
var card: CardInstance
var _accum: float = 0.0
var _targeting: bool = false

func setup(rc: RoundController, ci: CardInstance, p: int) -> void:
	round = rc
	card = ci
	self_player = p

	pressed.connect(_on_pressed)
	gui_input.connect(_on_gui_input)

	if art != null:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_art_texture()
		_ensure_invert_material()

	if round != null:
		if round.has_signal("targeting_started"):
			round.targeting_started.connect(func(): _targeting = true; _refresh())
		if round.has_signal("targeting_ended"):
			round.targeting_ended.connect(func(): _targeting = false; _refresh())
		if round.has_signal("card_consumed"):
			round.card_consumed.connect(_on_card_consumed)

	_refresh()

func _process(delta: float) -> void:
	if round == null or card == null:
		return
	_accum += delta
	if _accum >= poll_interval:
		_accum = 0.0
		_refresh()

func _apply_art_texture() -> void:
	if art == null or card == null or card.def == null:
		return
	art.texture = card.def.art_texture

func _ensure_invert_material() -> void:
	if art == null:
		return
	if art.material is ShaderMaterial:
		return

	var sh := load("res://Shaders/invert_card.gdshader") as Shader
	if sh == null:
		push_error("[CardSlotButton] Missing shader: res://Shaders/invert_card.gdshader")
		return

	var mat := ShaderMaterial.new()
	mat.shader = sh
	art.material = mat

func _set_invert(amount: float) -> void:
	if art == null:
		return
	var sm := art.material as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("invert_amount", clamp(amount, 0.0, 1.0))

func _refresh() -> void:
	if round == null or card == null or card.def == null or round.state == null:
		disabled = true
		text = "(no card)"
		tooltip_text = ""
		_set_invert(0.0)
		return

	# Keep the art in sync in case this button is reused
	_apply_art_texture()

	var ctx: PatternContext = PatternContext.new(round.state, self_player)

	var pattern_ok: bool = PatternMatcher.matches_all(card.def.pattern, ctx)
	var your_turn: bool = (round.state.turn == self_player)

	var cost_act: int = int(card.def.ap_cost_activate)
	var cost_burn: int = int(card.def.ap_cost_burn)
	var can_pay_act: bool = (round.ap_left >= cost_act)
	var can_pay_burn: bool = (round.ap_left >= cost_burn)

	var pip: int = int(card.def.pip_value)
	var pip_ok: bool = (pip != 0 and abs(pip) <= 6)
	var ready_burn: bool = (your_turn and can_pay_burn and pip_ok)

	if _targeting or round.targeting_active:
		disabled = true
		text = "TARGET"
		var summary: String = ""
		if card.def.tooltip_summary.strip_edges() != "":
			summary = "\nEffect: %s" % card.def.tooltip_summary.strip_edges()
		tooltip_text = "TARGET: click an enemy checker" + summary
		_set_invert(0.0)
		return

	var ready_activate: bool = (pattern_ok and your_turn and can_pay_act)
	disabled = not (ready_activate or ready_burn)

	# Text + tooltip (you can later replace this with a small overlay label if you want)
	var base: String = "%s  (pip %+d)  AP:%d" % [card.def.title, pip, cost_act]
	var status: String = ""
	if ready_activate and ready_burn:
		status = "READY  | LMB=Activate  RMB=Burn | " + base
	elif ready_activate:
		status = "READY  | LMB=Activate | " + base
	elif ready_burn:
		status = "BURN OK | RMB=Burn | " + base
	elif pattern_ok and not your_turn:
		status = "PATTERN OK (wait turn) | " + base
	elif your_turn and pattern_ok and not can_pay_act:
		status = "NO AP (activate) | " + base
	elif your_turn and not can_pay_burn:
		status = "NO AP (burn) | " + base
	else:
		status = "LOCKED | " + base

	var summary: String = ""
	if card.def.tooltip_summary.strip_edges() != "":
		summary = "\nEffect: %s" % card.def.tooltip_summary.strip_edges()

	tooltip_text = status + summary
	# Hide big text when art exists
	text = "" if (card.def.art_texture != null) else status

	# Invert logic (for ALL cards)
	if invert_on_pattern_ok and pattern_ok:
		_set_invert(invert_amount_ready if ready_activate else invert_amount_wait)
	else:
		_set_invert(0.0)

func _on_pressed() -> void:
	if round == null or card == null:
		return
	round.request_activate_card(card)
	_refresh()

func _on_gui_input(event: InputEvent) -> void:
	if round == null or card == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			round.request_burn_card_for_pips(card)
			_refresh()

func _on_card_consumed(uid: int) -> void:
	if card != null and uid == card.uid:
		visible = false
		disabled = true
