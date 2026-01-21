# res://Scripts/CardSlotButton.gd
extends Button
class_name CardSlotButton

@export var self_player: int = BoardState.Player.WHITE
@export var poll_interval: float = 0.10

# Primed overlay tuning (requires a ColorRect child named "PrimeGlow")
@export_range(0.0, 3.0) var primed_alpha_low: float = 0.35
@export_range(0.0, 10.0) var primed_alpha_high: float = 0.95
@export var primed_pulse_seconds: float = 1.1

@onready var art: TextureRect = get_node_or_null("Art") as TextureRect
@onready var prime_glow: ColorRect = get_node_or_null("PrimeGlow") as ColorRect

var round: RoundController = null
var card: CardInstance = null

var _accum: float = 0.0
var _primed_last: bool = false
var _prime_tween: Tween = null

var _targeting: bool = false
var _wired: bool = false

func setup(rc: RoundController, ci: CardInstance, p: int) -> void:
	round = rc
	card = ci
	self_player = p
	

	if not _wired:
		_wired = true
		pressed.connect(_on_pressed)
		gui_input.connect(_on_gui_input)
		
		if round != null:
			if round.has_signal("targeting_started"):
				round.targeting_started.connect(func(): _refresh())
			if round.has_signal("targeting_ended"):
				round.targeting_ended.connect(func(): _refresh())
			if round.has_signal("card_consumed"):
				round.card_consumed.connect(_on_card_consumed)

	if art != null:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_art_texture()
		_ensure_invert_material()

	if prime_glow != null:
		prime_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prime_glow.visible = false
		prime_glow.modulate.a = 0.0

		# Ensure additive blend so it looks like energy on top of the card
		var cim := prime_glow.material as CanvasItemMaterial
		if cim == null:
			cim = CanvasItemMaterial.new()
			prime_glow.material = cim
		cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Optional: refresh on targeting changes

	
	
	print("[CardSlotButton] Art=", art, " PrimeGlow=", prime_glow, " card=", (card.def.id if card and card.def else "nil"))
	
	
	#if prime_glow != null:
		#prime_glow.visible = true
		#prime_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		#prime_glow.color = Color(0.7, 0.2, 1.0, 1.0)   # IMPORTANT: alpha 1
		#prime_glow.modulate = Color(1, 1, 1, 1.0)     # alpha 1
		#prime_glow.z_index = 999


	_refresh()
	
	
	set_card_instance(ci)
	
func set_card_instance(ci: CardInstance) -> void:
	card = ci
	visible = true
	disabled = false
	_targeting = false
	_refresh()
	
	

func clear_card() -> void:
	card = null
	visible = true
	disabled = true
	text = "(empty)"
	

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
	# Make sure you're seeing the TextureRect art (not the Button icon)
	icon = null

func _ensure_invert_material() -> void:
	if art == null:
		return

	# Prefer the sepia-capable glow shader so we can oscillate the card art.
	var shader: Shader = load("res://Shaders/card_invert_glow.gdshader") as Shader
	if shader == null:
		# If no shader exists, we can still function; invert just won't happen
		push_warning("[CardSlotButton] No invert shader found (card_invert_glow.gdshader).")
		return

	var sm := art.material as ShaderMaterial
	if sm == null or sm.shader != shader:
		sm = ShaderMaterial.new()
		sm.shader = shader
		art.material = sm

	if sm.has_shader_parameter("sepia_speed"):
		sm.set_shader_parameter("sepia_speed", 1.0)
	if sm.has_shader_parameter("sepia_max"):
		sm.set_shader_parameter("sepia_max", 1.0)

func _set_invert(amount: float) -> void:
	if art == null:
		return
	var sm := art.material as ShaderMaterial
	if sm == null:
		return
	# Both invert shaders use "invert_amount"
	sm.set_shader_parameter("invert_amount", clamp(amount, 0.0, 1.0))

func _set_primed_visual(on: bool) -> void:
	if prime_glow == null:
		return

	if on == _primed_last:
		return
	_primed_last = on

	if _prime_tween != null:
		_prime_tween.kill()
		_prime_tween = null

	if not on:
		prime_glow.visible = false
		prime_glow.modulate.a = 0.0
		return

	prime_glow.visible = true
	prime_glow.modulate.a = primed_alpha_low

	_prime_tween = create_tween().set_loops()
	_prime_tween.tween_property(prime_glow, "modulate:a", primed_alpha_high, primed_pulse_seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prime_tween.tween_property(prime_glow, "modulate:a", primed_alpha_low, primed_pulse_seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _refresh() -> void:
	if round == null or card == null or card.def == null or round.state == null:
		disabled = true
		text = "(no card)"
		tooltip_text = ""
		_set_invert(0.0)
		_set_primed_visual(false)
		return

	_apply_art_texture()

	var ctx := PatternContext.new(round.state, self_player)
	var pattern_ok: bool = PatternMatcher.matches_all(card.def.pattern, ctx)
	if card.def.activation_req != null:
		pattern_ok = pattern_ok and card.def.activation_req.matches(round, card, ctx)
	var your_turn: bool = (round.state.turn == self_player)

	var cost_act: int = int(card.def.ap_cost_activate)
	var cost_burn: int = int(card.def.ap_cost_burn)
	var can_pay_act: bool = (round.ap_left >= cost_act)
	var can_pay_burn: bool = (round.ap_left >= cost_burn)

	var pip: int = int(card.def.pip_value)
	var pip_ok: bool = (pip != 0 and abs(pip) <= 6)

	var ready_activate: bool = (pattern_ok and your_turn and can_pay_act)
	var ready_burn: bool = (your_turn and can_pay_burn and pip_ok)

	# Default invert behavior (READY = inverted)
	_set_invert(1.0 if pattern_ok else 0.0)

	# Default enable/disable (normal mode)
	disabled = not (ready_activate or ready_burn)

	# Status text/tooltip (hidden if art exists)
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
	text = "" if (card.def.art_texture != null) else status

	# Targeting/primed visuals:
	# - If THIS card is primed: keep inverted + pulse overlay
	# - If another card is primed: disable this card (but keep its invert state)
	var primed_by_me: bool = false
	if round.targeting_active:
		# Requires RoundController.targeting_card_uid to exist
		primed_by_me = (int(round.targeting_card_uid) == card.uid)

		# Freeze interaction while targeting is active
		disabled = true

		if primed_by_me:
			_set_invert(1.0) # keep inverted while primed
			_set_primed_visual(true)
			tooltip_text = "TARGET: click an enemy stack" + summary
			text = "" if (card.def.art_texture != null) else "TARGET"
			return
		else:
			_set_primed_visual(false)
			return

	# Not targeting
	_set_primed_visual(false)

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
		if _prime_tween != null:
			_prime_tween.kill()
			_prime_tween = null
		_set_primed_visual(false)
		_set_invert(0.0)
		visible = false
		disabled = true
