extends PanelContainer

# A drop-in PanelContainer that shows the standard rich item tooltip
# (icon, name, rarity, stats, weapon effects, description, value) on
# hover - just set `item` and Godot's built-in tooltip system handles
# the rest via _make_custom_tooltip(). Used anywhere a shop/market row
# needs the same hover detail Stash tiles already have, without every
# screen re-implementing its own tooltip.

var item: Dictionary = {}

func set_item(new_item: Dictionary) -> void:
	item = new_item
	# A non-empty tooltip_text is what tells Godot's hover system this
	# control has a tooltip at all - _make_custom_tooltip() below then
	# replaces that plain text with the real rich tooltip.
	tooltip_text = " "

func _make_custom_tooltip(_for_text: String) -> Control:
	if item.is_empty():
		return null
	return ItemTooltip.build(item)
