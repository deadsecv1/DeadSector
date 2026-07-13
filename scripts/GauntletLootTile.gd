extends PanelContainer

# Attached dynamically (via set_script) to each carried-loot tile in the
# Gauntlet's inventory grid, so it can be dragged onto a doll slot to
# equip - same drag payload shape EquipSlot.gd already expects from the
# Stash/in-raid Backpack, just tagged as "gauntlet_carried" instead.
var tile_index: int = -1
var tile_item: Dictionary = {}

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate.a = 0.85
	var lbl := Label.new()
	lbl.text = str(tile_item.get("name", "?"))
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	preview.add_child(lbl)
	set_drag_preview(preview)
	return {"source": "gauntlet_carried", "index": tile_index}
