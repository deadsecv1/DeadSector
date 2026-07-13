extends Button

# The "Store" button - gold/premium themed, a gentle glow on hover with
# a few slow-drifting coin sparkles. Deliberately much calmer than the
# Event button - no continuous pulsing.

var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 8

@onready var glow: ColorRect = $Glow

func _ready() -> void:
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.9, 0.75, 0.3, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())

func _make_sparkle() -> Dictionary:
	return {
		"x": randf_range(0.0, 1.0), "y": randf_range(0.0, 1.0),
		"phase": randf_range(0.0, TAU), "r": randf_range(1.0, 2.2),
	}

func _on_hover_start() -> void:
	hovering = true
	Sfx.play_coin_hover()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.4, 0.25)

func _on_hover_end() -> void:
	hovering = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.0, 0.3)

func _process(_delta: float) -> void:
	if hovering:
		queue_redraw()

func _draw() -> void:
	if not hovering:
		return
	var t := Time.get_ticks_msec() * 0.001
	for sp in sparkles:
		var pos := Vector2(sp["x"], sp["y"]) * size
		var flicker: float = 0.4 + 0.6 * sin(t * 1.4 + sp["phase"])
		draw_circle(pos, sp["r"] * (0.6 + flicker * 0.5), Color(1.0, 0.85, 0.45, 0.5 * flicker))
