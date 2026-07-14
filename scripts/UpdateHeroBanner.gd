extends Control

# The "hero asset" for the What's New Spotlight panel - a small looping
# animated banner instead of a static image (no external art needed).
# Themed per-update via hero_color/hero_label; currently used for the
# Arena update's grid-floor motif.

@export var hero_color: Color = Color(0.65, 0.4, 0.95, 1)
@export var hero_label: String = "ARENA"

var _time: float = 0.0
var _sweep_x: float = 0.0

func _ready() -> void:
	set_process(true)
	var sparkles := CPUParticles2D.new()
	sparkles.z_index = 1
	sparkles.emitting = true
	sparkles.amount = 18
	sparkles.lifetime = 2.4
	sparkles.direction = Vector2.ZERO
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 3.0
	sparkles.initial_velocity_max = 12.0
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.2
	sparkles.color = Color(hero_color.r, hero_color.g, hero_color.b, 0.7)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(sparkles)
	resized.connect(func():
		sparkles.position = size / 2.0
		sparkles.emission_rect_extents = Vector2(max(size.x * 0.48, 4.0), max(size.y * 0.4, 4.0))
	)
	sparkles.position = size / 2.0
	sparkles.emission_rect_extents = Vector2(max(size.x * 0.48, 4.0), max(size.y * 0.4, 4.0))

func _process(delta: float) -> void:
	_time += delta
	_sweep_x = fmod(_sweep_x + delta * 60.0, size.x + 160.0)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.08, 1))

	# Grid floor motif, nodding to The Grid's tile floor.
	var grid_color := Color(hero_color.r, hero_color.g, hero_color.b, 0.14)
	var step := 22.0
	var x := fmod(_sweep_x * 0.15, step)
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), grid_color, 1.0)
		x += step
	var y := 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), grid_color, 1.0)
		y += step

	# A soft glow band that slowly sweeps across, like a scanning light.
	var sweep_alpha := 0.16
	draw_rect(Rect2(Vector2(_sweep_x - 80.0, 0), Vector2(160.0, h)), Color(hero_color.r, hero_color.g, hero_color.b, sweep_alpha))

	# Vignette edges so the banner blends into the panel around it.
	draw_rect(Rect2(0, 0, w, h * 0.22), Color(0.05, 0.03, 0.08, 0.6))
	draw_rect(Rect2(0, h * 0.78, w, h * 0.22), Color(0.05, 0.03, 0.08, 0.6))

	# Pulsing label + a ring behind it, same "signature" language as the
	# Arena button/icons elsewhere.
	var pulse: float = 0.7 + 0.3 * sin(_time * 2.2)
	var center := Vector2(w / 2.0, h / 2.0)
	draw_arc(center, min(w, h) * 0.28, 0.0, TAU, 28, Color(hero_color.r, hero_color.g, hero_color.b, 0.5 * pulse), 2.0, true)
	var font := ThemeDB.fallback_font
	var font_size := int(h * 0.34)
	var text_size := font.get_string_size(hero_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := center - text_size / 2.0 + Vector2(0, text_size.y * 0.32)
	draw_string(font, text_pos + Vector2(2, 2), hero_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.6))
	draw_string(font, text_pos, hero_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(hero_color.r * 0.6 + 0.4, hero_color.g * 0.6 + 0.4, hero_color.b * 0.6 + 0.4, 1) * Color(1, 1, 1, 0.85 + 0.15 * pulse))
