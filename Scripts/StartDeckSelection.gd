extends Control
class_name StartDeckSelection

signal selection_confirmed(selected_ids: Array[String])

const OFFER_COUNT: int = 15
const SELECT_COUNT: int = 10
const MIN_PER_FAMILY_OFFER: int = 2
const REQUIRED_PER_FAMILY: int = 1

const FAMILY_ORDER: Array[int] = [
    CardDef.Category.ECONOMY,
    CardDef.Category.TEMPO,
    CardDef.Category.DEFENSE,
    CardDef.Category.COMBAT,
]

@onready var card_grid: GridContainer = $Panel/Margin/VBox/CardGrid
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var confirm_button: Button = $Panel/Margin/VBox/ConfirmButton

var _offer_ids: Array[String] = []
var _selected_ids: Array[String] = []
var _id_to_button: Dictionary = {}

func _ready() -> void:
    visible = false
    confirm_button.pressed.connect(_on_confirm_pressed)

func open() -> void:
    visible = true
    _build_offer()
    _refresh_status()

func close() -> void:
    visible = false

func _build_offer() -> void:
    _offer_ids.clear()
    _selected_ids.clear()
    _id_to_button.clear()
    for child in card_grid.get_children():
        child.queue_free()

    var family_ids := _collect_family_ids()
    var chosen: Array[String] = []
    for family in FAMILY_ORDER:
        var pool_raw: Array = family_ids.get(family, [])
        var pool: Array[String] = []
        for id in pool_raw:
            pool.append(id as String)
        pool.shuffle()
        for i in range(mini(MIN_PER_FAMILY_OFFER, pool.size())):
            chosen.append(pool[i])

    var remaining_pool: Array[String] = _to_string_array(CardDB.all_ids())
    remaining_pool.shuffle()

    _offer_ids = _to_string_array(chosen)
    for id in remaining_pool:
        if _offer_ids.has(id):
            continue
        _offer_ids.append(id)
        if _offer_ids.size() >= OFFER_COUNT:
            break

    _offer_ids = _to_string_array(_offer_ids.slice(0, OFFER_COUNT))
    for id in _offer_ids:
        var def := CardDB.get_def(id)
        if def == null:
            continue
        var button := _make_card_button(def)
        card_grid.add_child(button)
        _id_to_button[id] = button

func _make_card_button(def: CardDef) -> Button:
    var button := Button.new()
    button.toggle_mode = true
    button.custom_minimum_size = Vector2(160, 220)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.size_flags_vertical = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.tooltip_text = "%s\n%s" % [def.title, def.tooltip_summary]

    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.anchor_right = 1.0
    box.anchor_bottom = 1.0
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    button.add_child(box)

    var art := TextureRect.new()
    art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.custom_minimum_size = Vector2(160, 170)
    art.texture = def.art_texture
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(art)

    var name_label := Label.new()
    name_label.text = "%s" % def.title
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(name_label)

    var family_label := Label.new()
    family_label.text = _family_name(def.category)
    family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    family_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
    family_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(family_label)

    button.pressed.connect(func(): _on_card_pressed(def.id))
    _update_button_state(button, false)
    return button

func _on_card_pressed(card_id: String) -> void:
    var button: Button = _id_to_button.get(card_id, null)
    if button == null:
        return

    if button.button_pressed:
        if _selected_ids.size() >= SELECT_COUNT and not _selected_ids.has(card_id):
            button.button_pressed = false
            return
        if not _selected_ids.has(card_id):
            _selected_ids.append(card_id)
    else:
        _selected_ids.erase(card_id)

    _update_button_state(button, button.button_pressed)
    _refresh_status()

func _refresh_status() -> void:
    var counts := _count_selected_by_family()
    var missing: Array[String] = []
    for family in FAMILY_ORDER:
        if int(counts.get(family, 0)) < REQUIRED_PER_FAMILY:
            missing.append(_family_name(family))

    var ready := _selected_ids.size() == SELECT_COUNT and missing.is_empty()
    confirm_button.disabled = not ready

    var missing_text := ""
    if not missing.is_empty():
        missing_text = " Missing: %s" % ", ".join(missing)

    status_label.text = "Selected %d/%d.%s" % [_selected_ids.size(), SELECT_COUNT, missing_text]

func _update_button_state(button: Button, selected: bool) -> void:
    if selected:
        button.self_modulate = Color(0.82, 1.0, 0.82)
    else:
        button.self_modulate = Color(1, 1, 1)

func _count_selected_by_family() -> Dictionary:
    var counts: Dictionary = {}
    for id in _selected_ids:
        var def := CardDB.get_def(id)
        if def == null:
            continue
        var cat := int(def.category)
        counts[cat] = int(counts.get(cat, 0)) + 1
    return counts

func _collect_family_ids() -> Dictionary:
    var by_family: Dictionary = {}
    for id in CardDB.all_ids():
        var def := CardDB.get_def(id)
        if def == null:
            continue
        var cat := int(def.category)
        if not by_family.has(cat):
            by_family[cat] = []
        by_family[cat].append(id)
    return by_family

func _family_name(category: int) -> String:
    match category:
        CardDef.Category.ECONOMY:
            return "Economy"
        CardDef.Category.TEMPO:
            return "Tempo"
        CardDef.Category.DEFENSE:
            return "Defense"
        CardDef.Category.COMBAT:
            return "Attack"
        _:
            return "Unknown"

func _to_string_array(source: Array) -> Array[String]:
    var output: Array[String] = []
    for item in source:
        output.append(item as String)
    return output

func _on_confirm_pressed() -> void:
    if _selected_ids.size() != SELECT_COUNT:
        return
    var counts := _count_selected_by_family()
    for family in FAMILY_ORDER:
        if int(counts.get(family, 0)) < REQUIRED_PER_FAMILY:
            return
    selection_confirmed.emit(_selected_ids.duplicate())
