extends Node


const CATALOG_PATH := "res://Resources/cards/card_catalog.tres"

var _by_id: Dictionary = {}          # String -> CardDef
var _ids: Array[String] = []         # all ids (stable order)

func _ready() -> void:
	randomize()
	reload()

func reload() -> void:
	_by_id.clear()
	_ids.clear()

	var catalog := load(CATALOG_PATH) as CardCatalog
	if catalog == null:
		push_error("[CardDB] Missing catalog at: %s" % CATALOG_PATH)
		return

	for def in catalog.cards:
		if def == null:
			continue
		var id := def.id.strip_edges()
		if id == "":
			push_warning("[CardDB] CardDef missing id (title=%s)" % def.title)
			continue
		if _by_id.has(id):
			push_warning("[CardDB] Duplicate card id: %s (keeping first)" % id)
			continue

		_by_id[id] = def
		_ids.append(id)

	print("[CardDB] Loaded %d cards." % _ids.size())

func has_id(id: String) -> bool:
	return _by_id.has(id)

func get_def(id: String) -> CardDef:
	return _by_id.get(id, null)

func all_ids() -> Array[String]:
	return _ids.duplicate()

func random_id(category: int = -1) -> String:
	var pool: Array[String] = []
	if category == -1:
		pool = _ids
	else:
		for id in _ids:
			var def := _by_id[id] as CardDef
			if def != null and int(def.category) == category:
				pool.append(id)

	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
