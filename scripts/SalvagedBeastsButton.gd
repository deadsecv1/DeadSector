extends Button

# The "Salvaged Beasts" (Companions) button - pulses continuously, and
# always has a faint ambient orange glow + drifting sparkles even when
# not hovered, intensifying further on hover (matches the Spectral
# Tide button's treatment).

var pulse_time: float = 0.0
var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14
const IDLE_GLOW_ALPHA := 0.18
const HOVER_GLOW_ALPHA := 0.55
const IDLE_SPARKLE_MULT := 0.35
const HOVER_SPARKLE_MULT := 1.0

@onready var glow: ColorRect = $Glow
var glow_base_position: Vector2

func _ready() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = -6.0
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.95, 0.55, 0.1, IDLE_GLOW_ALPHA)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())
	glow_base_position = glow.position

func _make_sparkle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(0.55, 1.3),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.2, 2.6),
	}

func _on_hover_start() -> void:
	hovering = true
	text = "Salvaged Beasts"
	Sfx.play_pet_hover()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", HOVER_GLOW_ALPHA, 0.25)

func _on_hover_end() -> void:
	hovering = false
	text = "Companions Are Here!"
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
	glow.position = glow_base_position + Vector2(sin(t * 4.3) * 1.8, cos(t * 5.7) * 1.8)
	queue_redraw()

func _draw() -> void:
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
		draw_circle(pos, sp["r"] * flicker * (0.75 if not hovering else 1.0), Color(1.0, 0.6, 0.15, 0.6 * flicker * mult))
