extends Control

# Attach this to any small Control that should show the game's rich
# item tooltip (icon, name, rarity, stats) on hover - just set `item`
# after attaching and Godot's tooltip system calls
# _make_custom_tooltip() automatically the same way it already does for
# Stash/Backpack tiles and equipment slots.

var item: Dictionary = {}

func _make_custom_tooltip(_for_text: String) -> Control:
	return ItemTooltip.build(item)
