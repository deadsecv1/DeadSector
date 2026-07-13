extends Button

# The Arena button - same base hover treatment (scale bounce, glow,
# orbiting sparkles) as the other plain Main Menu buttons (Data, etc.),
# plus a ring of purple twinkling stars around its border, the same
# technique RankedButton.gd uses, since this is also a PvP entry point.

const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")

var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14

@onready var glow: ColorRect = $Glow

func _ready() -> void:
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.35, 0.1, 0.45, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())

	var stars := Control.new()
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_script(TwinkleStarBorderScript)
	stars.star_color = Color(0.75, 0.4, 0.95, 1.0)
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
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.55, 0.25)

func _on_hover_end() -> void:
	hovering = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.0, 0.3)

func _process(_delta: float) -> void:
	if hovering:
		queue_redraw()

func _draw() -> void:
	if not hovering:
		return
	var t := Time.get_ticks_msec() * 0.001
	var center := size / 2.0
	var radius: float = size.x * 0.5
	for sp in sparkles:
		var ang: float = sp["ang"] + t * sp["speed"]
		var d: float = radius * sp["dist"]
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * d
		var flicker: float = 0.4 + 0.6 * sin(t * 3.0 + sp["phase"])
		draw_circle(pos, sp["r"] * flicker, Color(0.75, 0.4, 0.95, 0.6 * flicker))
