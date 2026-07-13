extends Button

# The "Alpha Rewards" button - sits at an angle, pulses continuously to
# grab attention, and always has a faint ambient white/black glow +
# drifting sparkles even when not hovered, intensifying further on hover
# (matches the Spectral Tide / Salvaged Beasts / Bloodline buttons'
# treatment). This one's time-limited (see GameManager.
# alpha_rewards_available()), so it earns the same "don't miss this"
# visual language as the other event buttons more than any plain menu
# entry would.

var pulse_time: float = 0.0
var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14
const IDLE_GLOW_ALPHA := 0.18
const HOVER_GLOW_ALPHA := 0.55
const IDLE_SPARKLE_MULT := 0.35
const HOVER_SPARKLE_MULT := 1.0

# The native Button font_color/font_hover_color are set fully transparent
# in the scene - Godot's built-in Button text only supports a single flat
# color, no gradient, so the text itself is hand-drawn here instead, one
# character at a time, interpolating left-to-right from white to black.
# Applies to whatever `text` currently is, so it covers all three states
# (idle "Alpha Rewards", hover "Claim Now!"/"Already Claimed") for free.
const GRADIENT_START := Color(1.0, 1.0, 1.0, 1.0)
const GRADIENT_END := Color(0.05, 0.05, 0.05, 1.0)

@onready var glow: ColorRect = $Glow
var glow_base_position: Vector2

func _ready() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = -7.0
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	text = "Alpha Rewards"
	glow.color = Color(1.0, 1.0, 1.0, IDLE_GLOW_ALPHA)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_base_position = glow.position
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())

func _make_sparkle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(0.55, 1.3),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.2, 2.6),
	}

func _on_hover_start() -> void:
	hovering = true
	text = "Already Claimed" if GameManager.alpha_rewards_claimed else "Claim Now!"
	Sfx.play_coin_hover()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", HOVER_GLOW_ALPHA, 0.25)

func _on_hover_end() -> void:
	hovering = false
	text = "Alpha Rewards"
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", IDLE_GLOW_ALPHA, 0.3)

func _process(delta: float) -> void:
	if not hovering:
		pulse_time += delta * 6.0
		var s: float = 1.0 + sin(pulse_time) * 0.06
		scale = Vector2(s, s)
	var t := Time.get_ticks_msec() * 0.001
	glow.position = glow_base_position + Vector2(sin(t * 4.7) * 1.8, cos(t * 5.3) * 1.8)
	queue_redraw()

func _draw() -> void:
	_draw_gradient_text()
	var t := Time.get_ticks_msec() * 0.001
	var center := size / 2.0
	var radius: float = size.x * 0.5
	var mult: float = HOVER_SPARKLE_MULT if hovering else IDLE_SPARKLE_MULT
	for i in range(sparkles.size()):
		if not hovering and i % 2 == 1:
			continue
		var sp = sparkles[i]
		var ang: float = sp["ang"] + t * sp["speed"]
		var d: float = radius * sp["dist"]
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * d
		var flicker: float = 0.4 + 0.6 * sin(t * 3.0 + sp["phase"])
		var base_col: Color = Color(1.0, 1.0, 1.0, 1.0) if i % 2 == 0 else Color(0.05, 0.05, 0.05, 1.0)
		draw_circle(pos, sp["r"] * flicker * (0.75 if not hovering else 1.0), Color(base_col.r, base_col.g, base_col.b, 0.6 * flicker * mult))

func _draw_gradient_text() -> void:
	if text == "":
		return
	var font: Font = get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size: int = get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 13
	var total_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x: float = (size.x - total_width) / 2.0
	var baseline_y: float = size.y / 2.0 + font_size * 0.35
	for i in range(text.length()):
		var ch: String = text[i]
		var char_w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var frac: float = float(i) / float(max(1, text.length() - 1))
		var col: Color = GRADIENT_START.lerp(GRADIENT_END, frac)
		draw_string(font, Vector2(x, baseline_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		x += char_w
