extends Control

# Attach this to any small Control that should show the pet tooltip on
# hover - just set `pet_id` after attaching and Godot's tooltip system
# calls _make_custom_tooltip() automatically, same as ItemTooltipHost.gd
# does for items.

var pet_id: String = ""

func _make_custom_tooltip(_for_text: String) -> Control:
	if pet_id == "":
		return null
	return PetTooltip.build(pet_id)
