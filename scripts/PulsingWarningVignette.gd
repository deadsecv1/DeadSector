extends Control

# A slow, breathing red glow at a panel's edges - deliberately NOT the
# sparkle/particle language used everywhere else in the game. Delete
# and Wipe confirmations exist specifically to make the player pause
# before an irreversible action; cheerful decoration there would work
# against the screen's own purpose, so this is a "danger" cue instead.

@export var vignette_color: Color = Color(0.9, 0.15, 0.1, 1.0)
const BAND := 22.0

func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	var pulse: float = 0.22 + 0.14 * sin(t * 1.1)
	var c := vignette_color
	draw_rect(Rect2(0, 0, w, BAND), Color(c.r, c.g, c.b, pulse))
	draw_rect(Rect2(0, h - BAND, w, BAND), Color(c.r, c.g, c.b, pulse))
	draw_rect(Rect2(0, 0, BAND, h), Color(c.r, c.g, c.b, pulse * 0.6))
	draw_rect(Rect2(w - BAND, 0, BAND, h), Color(c.r, c.g, c.b, pulse * 0.6))
