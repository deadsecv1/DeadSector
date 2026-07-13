extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# Lets the player name-tag a case (Loot Bag / Pet Case) and pick a
# color for it - the tag then shows in small letters on the item's
# icon everywhere it appears (Stash, in-raid Backpack, Vicinity).

signal closed
signal saved

const MAX_TAG_LENGTH := 14

@onready var name_edit: LineEdit = $VBox/NameEdit
@onready var swatch_row: HBoxContainer = $VBox/SwatchRow
@onready var preview_icon = $VBox/PreviewBox/Icon
@onready var save_button: Button = $VBox/ButtonRow/SaveButton
@onready var clear_button: Button = $VBox/ButtonRow/ClearButton
@onready var cancel_button: Button = $VBox/CancelButton

var _current_item: Dictionary = {}
var _current_index: int = -1
var _current_source: String = ""
var _selected_color: Color = Color(1, 1, 1, 1)
var _swatch_buttons: Array = []

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	save_button.pressed.connect(_on_save)
	clear_button.pressed.connect(_on_clear)
	cancel_button.pressed.connect(func(): closed.emit())
	name_edit.text_changed.connect(func(_t): _update_preview())

	for i in range(GameManager.TAG_COLORS.size()):
		var col: Color = GameManager.TAG_COLORS[i]
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.toggle_mode = true
		swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1, 1, 1, 0.9)
		sb.set_border_width_all(0)
		swatch.add_theme_stylebox_override("normal", sb)
		var sb_sel := sb.duplicate()
		sb_sel.set_border_width_all(3)
		swatch.add_theme_stylebox_override("hover", sb)
		swatch.add_theme_stylebox_override("pressed", sb_sel)
		swatch.pressed.connect(func(): _select_color(col))
		swatch_row.add_child(swatch)
		_swatch_buttons.append({"btn": swatch, "color": col, "sb": sb, "sb_sel": sb_sel})

func open_for(index: int, source: String, item: Dictionary) -> void:
	_current_index = index
	_current_source = source
	_current_item = item
	name_edit.text = str(item.get("tag_text", ""))
	name_edit.max_length = MAX_TAG_LENGTH
	var existing_color = item.get("tag_color", null)
	_select_color(existing_color if existing_color is Color else GameManager.TAG_COLORS[0])
	_update_preview()
	visible = true

func _select_color(col: Color) -> void:
	_selected_color = col
	for entry in _swatch_buttons:
		var is_selected: bool = entry["color"].is_equal_approx(col)
		entry["btn"].button_pressed = is_selected
		entry["btn"].add_theme_stylebox_override("normal", entry["sb_sel"] if is_selected else entry["sb"])
	_update_preview()

func _update_preview() -> void:
	if preview_icon == null:
		return
	preview_icon.icon_key = _current_item.get("icon_key", "generic")
	preview_icon.icon_color = GameManager.get_display_color(_current_item)
	preview_icon.tag_text = name_edit.text
	preview_icon.tag_color = _selected_color
	preview_icon.queue_redraw()

func _on_save() -> void:
	_current_item["tag_text"] = name_edit.text.strip_edges()
	_current_item["tag_color"] = _selected_color
	GameManager.save_game()
	saved.emit()
	closed.emit()

func _on_clear() -> void:
	_current_item.erase("tag_text")
	_current_item.erase("tag_color")
	GameManager.save_game()
	saved.emit()
	closed.emit()
