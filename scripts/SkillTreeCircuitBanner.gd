extends Control

# A small looping animated banner for the Skill Tree header - a
# procedurally-drawn circuit of nodes and traces, echoing the tree
# below without literally repeating it. Same "no external art needed"
# technique as UpdateHeroBanner.gd, different visual language: fixed
# node/edge layout with traveling light pulses instead of a sweeping
# scanline, since this one's meant to feel like dormant circuitry
# waiting to be lit up, not an active arena.

@export var line_color: Color = Color(0.55, 0.78, 1.0, 1)

var _time: float = 0.0
var _nodes: Array = []
var _edges: Array = []
var _pulses: Array = []
var _next_pulse_at: float = 0.0

func _ready() -> void:
	set_process(true)
	resized.connect(_layout_circuit)
	_layout_circuit()

func _layout_circuit() -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	if w <= 1.0:
		return
	_nodes.clear()
	var cols := 9
	for i in range(cols):
		var nx: float = (float(i) + 0.5) / float(cols) * w
		var ny: float = h * 0.5 + sin(i * 1.7) * h * 0.28
		_nodes.append(Vector2(nx, ny))
	_edges.clear()
	for i in range(_nodes.size() - 1):
		_edges.append([i, i + 1])
	# A few extra cross-links so it reads as a circuit, not a single wire.
	for i in range(0, _nodes.size() - 2, 2):
		_edges.append([i, i + 2])

func _process(delta: float) -> void:
	_time += delta
	_next_pulse_at -= delta
	if _next_pulse_at <= 0.0 and not _edges.is_empty():
		# Tightened from (0.35, 0.9) - the old range often left 0-1 pulses
		# alive at any given moment, reading as inert rather than dormant.
		_next_pulse_at = randf_range(0.18, 0.45)
		_pulses.append({"edge": _edges[randi() % _edges.size()], "t": 0.0})
	for p in _pulses:
		p["t"] += delta * 1.3
	_pulses = _pulses.filter(func(p): return p["t"] < 1.0)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0 or _nodes.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.07, 1))

	for e in _edges:
		draw_line(_nodes[e[0]], _nodes[e[1]], Color(line_color.r, line_color.g, line_color.b, 0.18), 1.5)

	for p in _pulses:
		var e: Array = p["edge"]
		var a: Vector2 = _nodes[e[0]]
		var b: Vector2 = _nodes[e[1]]
		var pos: Vector2 = a.lerp(b, p["t"])
		var fade: float = 1.0 - p["t"]
		draw_circle(pos, 3.5, Color(line_color.r, line_color.g, line_color.b, 0.9 * fade))
		draw_circle(pos, 7.0, Color(line_color.r, line_color.g, line_color.b, 0.3 * fade))

	for i in range(_nodes.size()):
		var twinkle: float = 0.5 + 0.5 * sin(_time * 1.4 + i * 0.9)
		draw_circle(_nodes[i], 2.5, Color(line_color.r, line_color.g, line_color.b, 0.5 + 0.4 * twinkle))
