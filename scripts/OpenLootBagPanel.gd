extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()
signal bag_opened

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var open_button: Button = $VBox/OpenButton
@onready var bag_preview: Control = $VBox/BagPreview
@onready var result_scroll: ScrollContainer = $VBox/ResultScroll
@onready var result_area: Control = $VBox/ResultScroll/ResultArea
@onready var status_label: Label = $VBox/StatusLabel
@onready var close_button: Button = $VBox/CloseButton

var bag_index: int = -1
var bag_source: String = ""
var bag_item: Dictionary = {}

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	open_button.pressed.connect(_on_open)
	close_button.pressed.connect(func(): closed.emit())

func open_for(index: int, source: String, item: Dictionary = {}) -> void:
	bag_index = index
	bag_source = source
	bag_item = item
	open_button.visible = true
	open_button.disabled = false
	status_label.text = "A sealed Loot Bag. Open it?"
	for c in result_area.get_children():
		c.queue_free()
	_show_bag_preview()
	visible = true

# Shows the actual bag before it's opened, instead of nothing at all -
# common/rare are a plain sackcloth brown, legendary and up use the real
# rarity color, and mythic/exotic/multiversal additionally get the
# shimmering gradient border used everywhere else that tier shows up.
func _show_bag_preview() -> void:
	for c in bag_preview.get_children():
		c.queue_free()
	var rarity: String = str(bag_item.get("rarity", "common"))
	var color: Color = GameManager.get_lootbag_color(rarity)

	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	if not gradient_colors.is_empty():
		var grad := Gradient.new()
		for i in range(gradient_colors.size()):
			grad.add_point(float(i) / float(gradient_colors.size() - 1), gradient_colors[i])
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = grad
		grad_tex.fill_from = Vector2(0, 0)
		grad_tex.fill_to = Vector2(1, 1)
		var glow := TextureRect.new()
		glow.texture = grad_tex
		glow.anchor_left = 0.5
		glow.anchor_right = 0.5
		glow.offset_left = -46.0
		glow.offset_right = 46.0
		glow.offset_top = 0.0
		glow.offset_bottom = 92.0
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bag_preview.add_child(glow)

	var icon_box := Control.new()
	icon_box.anchor_left = 0.5
	icon_box.anchor_right = 0.5
	icon_box.offset_left = -38.0
	icon_box.offset_right = 38.0
	icon_box.offset_top = 4.0
	icon_box.offset_bottom = 84.0
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "lootbag"
	icon.icon_color = color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon)
	bag_preview.add_child(icon_box)

	var name_lbl := Label.new()
	name_lbl.text = str(bag_item.get("name", "Loot Bag"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.anchor_right = 1.0
	name_lbl.position = Vector2(0, 90)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", color)
	bag_preview.add_child(name_lbl)

func _on_open() -> void:
	open_button.disabled = true
	var contents: Dictionary
	match bag_source:
		"stash":
			contents = GameManager.open_stash_loot_bag(bag_index)
		"vicinity":
			contents = GameManager.open_vicinity_loot_bag(bag_index)
		_:
			contents = GameManager.open_carried_loot_bag(bag_index)

	if contents.is_empty():
		status_label.text = "Nothing happened..."
		return
	bag_opened.emit()
	open_button.visible = false
	bag_preview.visible = false
	status_label.text = "Opening..."
	_play_reveal(contents)

# Items wrap into a grid (was a single ever-growing row before, which
# ran items straight off the edge of the panel for anything with more
# than ~4 items - a 20-item Alpha Chest was mostly invisible). The
# result area also grows to fit every row, and sits in a ScrollContainer
# now so anything still too tall can be scrolled to instead of clipped.
const GRID_COLS := 4
const CELL_W := 90.0
const CELL_H := 100.0

func _play_reveal(contents: Dictionary) -> void:
	var items: Array = contents.get("items", [])
	var currency: Dictionary = contents.get("currency", {})
	var row_count: int = int(ceil(float(max(1, items.size())) / float(GRID_COLS)))
	result_area.custom_minimum_size = Vector2(GRID_COLS * CELL_W, float(row_count) * CELL_H + 50.0)

	var i := 0
	for item in items:
		var col: int = i % GRID_COLS
		@warning_ignore("integer_division")
		var row: int = i / GRID_COLS
		var cell_pos := Vector2(14.0 + float(col) * CELL_W, 14.0 + float(row) * CELL_H)

		var icon = ItemIconScene.instantiate()
		icon.icon_key = item.get("icon_key", "generic")
		icon.icon_color = GameManager.get_display_color(item)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.position = cell_pos
		icon.modulate.a = 0.0
		icon.scale = Vector2(0.3, 0.3)
		icon.pivot_offset = Vector2(28, 28)
		result_area.add_child(icon)

		var lbl := Label.new()
		lbl.text = item.get("name", "?")
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.position = cell_pos + Vector2(-16.0, 62.0)
		lbl.custom_minimum_size = Vector2(90, 28)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		result_area.add_child(lbl)

		_spawn_burst(cell_pos + Vector2(28, 28), GameManager.get_display_color(item))

		var tw := icon.create_tween()
		tw.tween_interval(float(i) * 0.12)
		tw.tween_property(icon, "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(icon, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

	var cur_parts: Array = []
	for cur in currency:
		cur_parts.append("+%d %s" % [int(currency[cur]), String(cur).capitalize()])
	var cur_lbl := Label.new()
	cur_lbl.text = ", ".join(cur_parts)
	cur_lbl.add_theme_font_size_override("font_size", 13)
	cur_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4, 1))
	cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur_lbl.anchor_right = 1.0
	cur_lbl.position = Vector2(0, float(row_count) * CELL_H + 18.0)
	result_area.add_child(cur_lbl)

	await get_tree().create_timer(0.5 + float(items.size()) * 0.12).timeout
	var overflow_count: int = int(contents.get("overflow_count", 0))
	if overflow_count > 0:
		status_label.text = "Backpack was full - %d item(s) left in Vicinity to grab" % overflow_count
	else:
		status_label.text = "All loot collected into your Backpack!"
	Sfx.play_loot_pickup()

func _spawn_burst(at_pos: Vector2, color: Color) -> void:
	for j in range(8):
		var chip := ColorRect.new()
		chip.size = Vector2(4, 4)
		chip.color = color
		chip.position = at_pos
		result_area.add_child(chip)
		var ang := randf_range(0.0, TAU)
		var dist := randf_range(20.0, 46.0)
		var target := at_pos + Vector2(cos(ang), sin(ang)) * dist
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(chip.queue_free)
