extends Label

# A clean, minimal "1.0 Released" announcement - just text, gently
# pulsing in brightness so it catches the eye without ever feeling like
# an ad or a loud banner. No border, no background panel - the kind of
# understated touch a shipped game uses rather than a work-in-progress one.
#
# Positioned dynamically at runtime, overlapping the "OR" at the end of
# "SECTOR" - the logo is hand-drawn with draw_string() rather than a
# real Label, so its exact width isn't known until it's measured the
# same way the logo itself measures it.

@onready var title_label: Control = get_node("../VBoxContainer/TitleLabel")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0
	rotation_degrees = -9.0
	_position_near_title()
	var tw := create_tween()
	tw.bind_node(self)
	tw.set_loops()
	tw.tween_property(self, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate:a", 0.55, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _position_near_title() -> void:
	# Same measurement TitleLogo.gd itself uses, so this lines up with
	# the real rendered text width instead of a guessed pixel offset.
	var font := ThemeDB.fallback_font
	var font_size := 56
	var text_str := "D E A D   S E C T O R"
	var text_size: Vector2 = font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# The logo's own baseline point (matches TitleLogo.gd's `pos` exactly).
	var baseline := Vector2(
		(title_label.size.x - text_size.x) / 2.0,
		title_label.size.y * 0.5 + text_size.y * 0.3
	)
	# Land squarely on the last character ("R"), vertically centered on
	# the text's cap-height rather than sitting above it.
	var target := baseline + Vector2(text_size.x * 0.97, -text_size.y * 0.45)
	global_position = title_label.global_position + target - Vector2(size.x * 0.5, size.y * 0.5)
