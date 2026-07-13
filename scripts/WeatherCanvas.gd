extends Control

# Pure rendering for WeatherOverlay - kept separate since CanvasLayer
# itself can't draw, only a Control/CanvasItem child can.
# Weather values mirror WeatherOverlay.Weather: 0=CLEAR, 1=RAIN

var overlay: Node = null

func _ready() -> void:
	overlay = get_parent()

func _draw() -> void:
	if overlay == null or overlay.weather != 1:
		return
	for p in overlay.particles:
		var from := Vector2(p["x"], p["y"])
		var to := from + Vector2(-6, p["len"])
		draw_line(from, to, Color(0.6, 0.7, 0.85, 0.35), 1.5)
