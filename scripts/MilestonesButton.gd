extends Button

# The Milestones button - same permanent-border + idle-glow + orbiting
# sparkle treatment as Arena/Alpha Rewards/Bloodline/Salvaged Beasts,
# recolored gold for its own currency (Stones) (#46). Reuses
# Sfx.play_coin_hover() - the same gold/currency hover chime StoreButton
# already uses - rather than a new bespoke generator, since a fitting
# sound already existed.

const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")

var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14
const IDLE_GLOW_ALPHA := 0.18
const HOVER_GLOW_ALPHA := 0.55
const IDLE_SPARKLE_MULT := 0.35
const HOVER_SPARKLE_MULT := 1.0

@onready var glow: ColorRect = $Glow

func _ready() -> void:
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.5, 0.4, 0.05, IDLE_GLOW_ALPHA)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.95, 0.8, 0.35, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)

	var stars := Control.new()
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_script(TwinkleStarBorderScript)
	stars.star_color = Color(0.95, 0.8, 0.35, 1.0)
	stars.star_count = 4
	stars.min_size = 2.0
	stars.max_size = 3.5
	add_child(stars)

func _make_sparkle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(0.55, 1.3),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.2, 2.6),
	}

func _on_hover_start() -> void:
	hovering = true
	Sfx.play_coin_hover()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", HOVER_GLOW_ALPHA, 0.25)

func _on_hover_end() -> void:
	hovering = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", IDLE_GLOW_ALPHA, 0.3)

func _process(_delta: float) -> void:
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
		draw_circle(pos, sp["r"] * flicker * (0.75 if not hovering else 1.0), Color(0.95, 0.8, 0.35, 0.6 * flicker * mult))
