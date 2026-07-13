extends Control

# A small circular badge in the corner of an item tile, marking it as
# an openable case (a Loot Bag or Pet Case) - distinguishable from
# regular gear at a glance, in the Stash, in-raid Backpack, and
# Vicinity alike (InventoryTile.gd is shared by all three).

@export var badge_color: Color = Color(0.9, 0.75, 0.3, 1)

func _draw() -> void:
	var r: float = size.x / 2.0
	var center := Vector2(r, r)
	draw_circle(center, r, Color(0.08, 0.08, 0.08, 0.9))
	draw_circle(center, r, badge_color, false, r * 0.22)
	# A tiny "?" mark - reads as "open me" at a glance without needing
	# a full icon drawn at this size.
	var font := ThemeDB.fallback_font
	var text := "?"
	var fsize: int = max(8, int(size.x * 0.62))
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	draw_string(font, center - text_size / 2.0 + Vector2(0, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, badge_color)
