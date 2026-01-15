extends Node
class_name AuxCardDB

const CATALOG_PATH: String = "res://Resources/aux_cards/aux_card_catalog.tres"

static var _defs: Dictionary = {}
static var _catalog: AuxCardCatalog = null

static func _ensure() -> void:
	if _defs.size() > 0:
		return

	_catalog = load(CATALOG_PATH) as AuxCardCatalog
	if _catalog == null:
		push_warning("[AuxCardDB] Missing catalog at %s. No aux cards loaded." % CATALOG_PATH)
		return

	for d in _catalog.aux_cards:
		var def: AuxCardDef = d as AuxCardDef
		if def == null:
			continue
		if def.id == "":
			continue
		if _defs.has(def.id):
			push_warning("[AuxCardDB] Duplicate aux id in catalog: %s" % def.id)
		_defs[def.id] = def

static func get_def(aux_id: String) -> AuxCardDef:
	_ensure()
	return _defs.get(aux_id, null) as AuxCardDef

static func all_defs() -> Array[AuxCardDef]:
	_ensure()
	var arr: Array[AuxCardDef] = []
	for k in _defs.keys():
		arr.append(_defs[k])
	return arr

static func compute_ap_cost(def: AuxCardDef, skill_state: RunSkillState) -> int:
	var cost := def.base_ap_cost
	if skill_state != null:
		var mod := skill_state.get_aux_mod(def.id)
		cost += int(mod.get("ap_cost_delta", 0))
	return maxi(0, cost)

static func compute_cooldown(def: AuxCardDef, skill_state: RunSkillState) -> int:
	var cd := def.base_cooldown_turns
	if skill_state != null:
		var mod := skill_state.get_aux_mod(def.id)
		cd += int(mod.get("cooldown_delta", 0))
	return maxi(0, cd)
