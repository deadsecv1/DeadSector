extends Control

# Special presentation for the "Tech Test Veteran" title specifically -
# per-word blue-to-purple gradient, a soft pulsing outline glow, a thin
# comet-trail line tracing around it (reusing GlowTraceBorder.gd), and a
# few small drifting particles (reusing TooltipParticles.gd). The text
# itself is still real Label nodes with real font colors - just colored
# and outlined, never an image - so it stays perfectly readable.

const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")

const WORDS := ["Tech", "Test", "Veteran"]
const START_COLOR := Color(0.55, 0.75, 1.0, 1)   # blue
const END_COLOR := Color(0.78, 0.5, 0.95, 1)     # purple

var _glow_labels: Array = []
var _time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(150, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var particles := Control.new()
	particles.anchor_right = 1.0
	particles.anchor_bottom = 1.0
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particles.set_script(TooltipParticlesScript)
	particles.particle_color = Color(0.7, 0.65, 1.0, 0.7)
	particles.intensity = 6
	add_child(particles)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = Color(0.72, 0.6, 1.0, 0.9)
	trace.trace_speed = 45.0
	trace.trace_segments = 10
	trace.trace_segment_gap = 3.0
	trace.trace_width = 1.2
	add_child(trace)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	for i in range(WORDS.size()):
		var t: float = float(i) / float(max(1, WORDS.size() - 1))
		var col: Color = START_COLOR.lerp(END_COLOR, t)
		var lbl := Label.new()
		lbl.text = WORDS[i]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", col)
		lbl.add_theme_color_override("font_outline_color", Color(col.r, col.g, col.b, 0.5))
		lbl.add_theme_constant_override("outline_size", 3)
		row.add_child(lbl)
		_glow_labels.append(lbl)

	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
	for i in range(_glow_labels.size()):
		var lbl: Label = _glow_labels[i]
		var t: float = float(i) / float(max(1, _glow_labels.size() - 1))
		var col: Color = START_COLOR.lerp(END_COLOR, t)
		lbl.add_theme_color_override("font_outline_color", Color(col.r, col.g, col.b, 0.35 + 0.45 * pulse))
