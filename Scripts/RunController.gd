extends Node
class_name RunController

# Scene expectations (RunController root scene):
# - Child: Round (instanced scene whose root has RoundController.gd)
# - Child: HUD (CanvasLayer or Control)
#     - EndRoundShop (optional, Control with script EndRoundShop.gd)

@onready var round: Node = $Round
@onready var shop: Node = get_node_or_null("HUD/EndRoundShop")
@onready var deck_select: Node = get_node_or_null("HUD/StartDeckSelection")

var run_state: RunState
var _awaiting_deck_selection: bool = false

const TOTAL_ROUNDS: int = 12
const ROUND_WIN_REWARD_GOLD: int = 10

const PLAYER_BASE_HP: int = 20
const ENEMY_BASE_HP: int = 20

func _ready() -> void:
	set_process_unhandled_input(true) # debug convenience: allow cycling gold convert mode

	# Connect round signals (RoundController emits these)
	if round != null:
		if round.has_signal("round_won"):
			round.connect("round_won", Callable(self, "_on_round_won"))
		if round.has_signal("round_lost"):
			round.connect("round_lost", Callable(self, "_on_round_lost"))
		if round.has_signal("round_restarted"):
			round.connect("round_restarted", Callable(self, "_on_round_restarted"))

	# Connect shop finished (EndRoundShop emits this)
	if shop != null and shop.has_signal("finished"):
		shop.connect("finished", Callable(self, "_on_shop_finished"))

	if deck_select != null and deck_select.has_signal("selection_confirmed"):
		deck_select.connect("selection_confirmed", Callable(self, "_on_deck_selection_confirmed"))

	_start_new_run()
	_maybe_start_round()

func _start_new_run() -> void:
	run_state = RunState.new()
	run_state.round_index = 0
	run_state.gold = 0

	run_state.player_max_hp = PLAYER_BASE_HP
	run_state.player_hp = PLAYER_BASE_HP

	run_state.enemy_max_hp = ENEMY_BASE_HP
	run_state.enemy_hp = ENEMY_BASE_HP

	# placeholder deck container (safe if RunState already defines it)
	if "deck" in run_state:
		run_state.deck.clear()
	_awaiting_deck_selection = false
	if deck_select != null and deck_select.has_method("open"):
		_awaiting_deck_selection = true
		_set_overlay_visibility(false)
		deck_select.call("open")
	else:
		_assign_default_deck()
		_set_overlay_visibility(true)


func _start_current_round() -> void:
	if run_state.round_index >= TOTAL_ROUNDS:
		print("[RunController] RUN COMPLETE")
		# MVP behavior: restart run immediately
		_start_new_run()
		_start_current_round()
		return

	# Each round, you usually want a fresh enemy baseline (MVP)
	run_state.enemy_hp = run_state.enemy_max_hp

	if round != null and round.has_method("start_round"):
		round.call("start_round", run_state)
	else:
		push_error("[RunController] Round child missing start_round(run_state).")

func _maybe_start_round() -> void:
	if not _awaiting_deck_selection:
		_start_current_round()

func _assign_default_deck() -> void:
	# Use the entire available card catalog for the starting deck.
	var available_ids := CardDB.all_ids()
	if available_ids.is_empty():
		push_warning("[RunController] No card IDs found in CardDB; starting deck is empty.")
		run_state.deck = []
		return
	run_state.deck = available_ids

func _on_round_won() -> void:
	# Reward for winning round
	if run_state.has_method("add_gold"):
		run_state.call("add_gold", ROUND_WIN_REWARD_GOLD, true)
	else:
		run_state.gold += ROUND_WIN_REWARD_GOLD

	# If this was the final round, end run
	if run_state.round_index == TOTAL_ROUNDS - 1:
		print("[RunController] FINAL ROUND WON — RUN COMPLETE")
		_start_new_run()
		_maybe_start_round()
		return

	# Open end-of-round shop before advancing
	if shop != null and shop.has_method("open"):
		shop.call("open", run_state)
	else:
		# If no shop exists yet, just advance
		_on_shop_finished()

func _on_shop_finished() -> void:
	run_state.round_index += 1
	_start_current_round()

func _on_round_lost() -> void:
	print("[RunController] RUN FAILED (round %d)" % run_state.round_index)
	# MVP behavior: restart run immediately
	_start_new_run()
	_maybe_start_round()

func _on_round_restarted() -> void:
	# No-op for MVP (useful hook later if you want to refund/penalize)
	pass

func _on_deck_selection_confirmed(selected_ids: Array[String]) -> void:
	if run_state == null:
		return
	run_state.deck = selected_ids
	_awaiting_deck_selection = false
	if deck_select != null and deck_select.has_method("close"):
		deck_select.call("close")
	_set_overlay_visibility(true)
	_maybe_start_round()

func _set_overlay_visibility(visible: bool) -> void:
	if round != null and round.has_method("set_overlay_visibility"):
		round.call("set_overlay_visibility", visible)

func _unhandled_input(event: InputEvent) -> void:
	# Debug: F2 cycles Gold Boost conversion mode (requires tier4-A to actually convert).
	if event is InputEventKey and event.pressed and not event.echo:
		var ek := event as InputEventKey
		if ek.keycode == KEY_F2 and run_state != null:
			var m := int(run_state.cycle_gold_convert_mode())
			var label := "GOLD" if m == RunState.GoldConvertMode.GOLD else ("HP" if m == RunState.GoldConvertMode.HP else "PIPS")
			print("[RunController] Gold Boost convert mode:", label)
		if ek.keycode == KEY_F3 and run_state != null:
			# Debug: F3 toggles Attack Boost conversion-to-gold (requires tier4-A to actually convert).
			var mod: Dictionary = run_state.skill_state.get_aux_mod("aux_attack_boost") if run_state.skill_state != null else {}
			if bool(mod.get("attack_convert_enabled", false)):
				var on: bool = run_state.toggle_attack_convert_to_gold()
				print("[RunController] Attack Boost convert-to-gold:", "ON" if on else "OFF")
			else:
				print("[RunController] Attack Boost convert-to-gold is locked (need tier 4A).")

		if ek.keycode == KEY_F6 and run_state != null:
			# Debug: F6 toggles Pip Boost conversion-to-HP (requires tier3-B1 to actually convert).
			var mod_p: Dictionary = run_state.skill_state.get_aux_mod("aux_pip_boost") if run_state.skill_state != null else {}
			if bool(mod_p.get("pip_hp_convert_enabled", false)):
				var on_p: bool = run_state.toggle_pip_convert_to_hp()
				print("[RunController] Pip Boost convert-to-HP:", "ON" if on_p else "OFF")
			else:
				print("[RunController] Pip Boost convert-to-HP is locked (need tier 3B1).")

		# Debug: F4 force-opens the Skill Tree (ignores pips thresholds).
		# - Tap F4: open with 2 picks (fast testing)
		# - Shift+F4: open with max picks
		if ek.keycode == KEY_F4:
			var picks := 2
			if ek.shift_pressed:
				picks = 99
			if round != null and round.has_method("debug_open_skill_tree"):
				round.call("debug_open_skill_tree", picks)
			else:
				print("[RunController] Round missing debug_open_skill_tree().")

		# Debug: F5 resets aux cooldowns + per-round use counters (fast testing).
		if ek.keycode == KEY_F5:
			if round != null and round.has_method("debug_reset_aux_cooldowns"):
				round.call("debug_reset_aux_cooldowns")
				print("[RunController] Aux cooldowns reset.")
			else:
				print("[RunController] Round missing debug_reset_aux_cooldowns().")
