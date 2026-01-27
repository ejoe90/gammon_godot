extends Control
class_name DeckStatusHUD

@export var round_controller_path: NodePath = NodePath("../..")
@export var poll_interval: float = 0.2

@onready var discard_header: Label = $Panel/MarginContainer/VBox/Columns/Discard/DiscardHeader
@onready var draw_header: Label = $Panel/MarginContainer/VBox/Columns/Draw/DrawHeader
@onready var discard_text: RichTextLabel = $Panel/MarginContainer/VBox/Columns/Discard/Scroll/DiscardText
@onready var draw_text: RichTextLabel = $Panel/MarginContainer/VBox/Columns/Draw/Scroll/DrawText

var _round: RoundController = null
var _accum: float = 0.0

func _ready() -> void:
	_round = get_node_or_null(round_controller_path) as RoundController
	if _round == null:
		push_error("[DeckStatusHUD] Could not find RoundController at: " + str(round_controller_path))
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < poll_interval:
		return
	_accum = 0.0
	_refresh()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_accum = 0.0
	_refresh()

func close() -> void:
	visible = false

func _refresh() -> void:
	if _round == null:
		return

	var discard_list: Array[String] = _round.discard_pile.duplicate()
	var draw_list: Array[String] = _round.draw_pile.duplicate()

	discard_header.text = "Discard Pile (%d)" % discard_list.size()
	draw_header.text = "Draw Pile (%d)" % draw_list.size()

	discard_text.text = _format_counts(_count_cards(discard_list))
	draw_text.text = _format_counts(_count_cards(draw_list))

func _count_cards(card_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for id in card_ids:
		var key := String(id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts

func _format_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "(empty)"

	var entries: Array[Dictionary] = []
	for id in counts.keys():
		var def := CardDB.get_def(String(id))
		var name := def.title if def != null and def.title != "" else String(id)
		entries.append({"name": name, "id": String(id), "count": int(counts[id])})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var name_a: String = a["name"]
		var name_b: String = b["name"]
		if name_a == name_b:
			return String(a["id"]) < String(b["id"])
		return name_a < name_b
	)

	var lines: Array[String] = []
	for entry in entries:
		var count: int = int(entry["count"])
		var label: String = entry["name"]
		if count > 1:
			label = "%s x%d" % [label, count]
		lines.append(label)

	return "\n".join(lines)
