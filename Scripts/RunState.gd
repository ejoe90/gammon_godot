extends RefCounted
class_name RunState

enum GoldConvertMode { GOLD, HP, PIPS }

var round_index: int = 0        # 0-based
var gold: int = 0

var player_max_hp: int = 20
var player_hp: int = 20

var enemy_max_hp: int = 20
var enemy_hp: int = 20

# Placeholder for later:
var deck: Array[String] = []    # card IDs

var player_attack_mult: int = 1

# Added by Attack skill tree
var base_attack_power: int = 0
var enemy_drain_per_turn: int = 0
# Attack aux tier4-A mechanic: if true, Attack Boost converts damage into gold.
var attack_convert_to_gold: bool = false

# Pip aux tier3-B1 mechanic: if true, Pip Boost converts dice pips into HP on use.
var pip_convert_to_hp: bool = false

# Gold aux tier4-B mechanic: multiplier value (starts at 1).
var gold_mult: int = 1
# Gold aux tier4-A mechanic: conversion target when using Gold Boost.
var gold_convert_mode: int = GoldConvertMode.GOLD

@export var skill_state: RunSkillState = RunSkillState.new()

func _gold_mult_active() -> bool:
	if skill_state == null:
		return false
	var mod: Dictionary = skill_state.get_aux_mod("aux_gold_boost")
	return bool(mod.get("gold_mult_enabled", false))

func add_gold(amount: int, apply_multiplier: bool = true) -> int:
	var v: int = int(amount)
	if v <= 0:
		return 0
	if apply_multiplier and _gold_mult_active():
		v *= maxi(1, int(gold_mult))
	gold += v
	return v

func add_player_hp(delta: int) -> int:
	var before := int(player_hp)
	player_hp = clampi(before + int(delta), 0, int(player_max_hp))
	return int(player_hp) - before

func add_player_hp_overcap(delta: int) -> int:
	# Like add_player_hp, but allows HP to exceed player_max_hp (overcap healing).
	var before := int(player_hp)
	player_hp = maxi(0, before + int(delta))
	return int(player_hp) - before

func cycle_gold_convert_mode() -> int:
	gold_convert_mode = int(gold_convert_mode) + 1
	if gold_convert_mode > GoldConvertMode.PIPS:
		gold_convert_mode = GoldConvertMode.GOLD
	return int(gold_convert_mode)

func toggle_attack_convert_to_gold() -> bool:
	attack_convert_to_gold = not bool(attack_convert_to_gold)
	return bool(attack_convert_to_gold)

func toggle_pip_convert_to_hp() -> bool:
	pip_convert_to_hp = not bool(pip_convert_to_hp)
	return bool(pip_convert_to_hp)
