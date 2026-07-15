extends Button

# Same hover treatment as the "New Event!" button (scale bounce, glow,
# orbiting sparkles) - just recolored black for the standard Main Menu
# buttons, and with no sound and no constant pulsing/tilt.
#
# Optionally swaps text on hover if both fields below are filled in -
# leave them blank for buttons that should just keep their static label.

@export var idle_text: String = ""
@export var hover_text: String = ""
# Main Menu buttons keep the scale bounce; everywhere else (Rose's
# panel, Plushies, the reveal popup, ...) it was pushing buttons
# outside their own panel's bounds in tighter layouts - default true
# so every existing MainMenu.tscn usage is untouched, explicitly set
# false per-instance on the panels that shouldn't scale.
@export var scale_on_hover: bool = true

var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14

@onready var glow: ColorRect = $Glow

func _ready() -> void:
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.03, 0.03, 0.03, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())
	if idle_text != "":
		text = idle_text

func _make_sparkle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(0.55, 1.3),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.2, 2.6),
	}

func _on_hover_start() -> void:
	hovering = true
	if hover_text != "":
		text = hover_text
	if scale_on_hover:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.55, 0.25)

func _on_hover_end() -> void:
	hovering = false
	if idle_text != "":
		text = idle_text
	if scale_on_hover:
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
		draw_circle(pos, sp["r"] * flicker, Color(0.03, 0.03, 0.03, 0.6 * flicker))
