extends Node2D

const DURATION := 2.5
var _life: float = 0.0
var _radius: float = randf_range(14.0, 20.0)

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_life += delta
	if _life > DURATION - 0.8:
		modulate.a = clamp((DURATION - _life) / 0.8, 0.0, 1.0)
	if _life >= DURATION:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(0.08, 0.05, 0.04, 0.55))
	draw_circle(Vector2.ZERO, _radius * 0.6, Color(0.2, 0.08, 0.04, 0.4))
	var flicker: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	draw_circle(Vector2.ZERO, _radius * 0.3, Color(0.9, 0.4, 0.15, 0.15 * flicker))
