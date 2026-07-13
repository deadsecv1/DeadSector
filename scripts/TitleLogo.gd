extends Control

# Draws the "DEAD SECTOR" title with an animated glitch/chromatic-aberration
# treatment (red/cyan offset layers + scanline sweep + subtle jitter) for a
# distinctive sci-fi HUD look. Used on both the Main Menu and the intro
# cutscene, since both scenes share this same script. Set as an autoload-
# free preload rather than a scene ext_resource since the text itself is
# hand-drawn in _draw(), not a Label node.
const TITLE_FONT := preload("res://assets/fonts/GaliverSans-Bold.ttf")

var time: float = 0.0
var glitch_timer: float = 0.0
var glitch_offset: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)

func _process(delta: float) -> void:
	time += delta
	glitch_timer -= delta
	if glitch_timer <= 0.0:
		glitch_timer = randf_range(1.8, 4.0)
		glitch_offset = randf_range(2.0, 5.0)
	else:
		glitch_offset = lerp(glitch_offset, 0.0, delta * 10.0)
	queue_redraw()

func _draw() -> void:
	var font := TITLE_FONT
	var font_size := 56
	var text := "D E A D   S E C T O R"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((size.x - text_size.x) / 2.0, size.y * 0.5 + text_size.y * 0.3)

	# Chromatic aberration glitch layers.
	draw_string(font, pos + Vector2(-glitch_offset, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.2, 0.2, 0.55))
	draw_string(font, pos + Vector2(glitch_offset, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.2, 0.85, 1, 0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.95, 0.95, 1))

	# Thin sweeping scanline through the text.
	var scan_y: float = pos.y - text_size.y + fmod(time * 26.0, text_size.y * 1.4)
	draw_line(Vector2(pos.x - 10, scan_y), Vector2(pos.x + text_size.x + 10, scan_y), Color(1, 1, 1, 0.18), 1.5)

	# Accent underline.
	draw_line(Vector2(pos.x, pos.y + 8), Vector2(pos.x + text_size.x, pos.y + 8), Color(1, 0.36, 0.2, 0.7), 2.0)
