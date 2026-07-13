extends Control

# Rising embers/sparks drifting up the screen, like distant fires -
# purely procedural (random dots with drift + flicker), no particle
# textures or image assets needed.

var embers: Array = []
const EMBER_COUNT := 45

func _ready() -> void:
	resized.connect(_init_embers)
	_init_embers()
	set_process(true)

func _init_embers() -> void:
	embers.clear()
	for i in range(EMBER_COUNT):
		embers.append(_make_ember(true))

func _make_ember(random_y: bool) -> Dictionary:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	return {
		"x": randf_range(0.0, w),
		"y": randf_range(0.0, h) if random_y else h + randf_range(0.0, 40.0),
		"speed": randf_range(14.0, 38.0),
		"drift": randf_range(-8.0, 8.0),
		"size": randf_range(1.2, 3.2),
		"phase": randf_range(0.0, TAU),
		"hue": randf_range(0.0, 1.0),
	}

func _process(delta: float) -> void:
	for e in embers:
		e["y"] -= e["speed"] * delta
		e["x"] += e["drift"] * delta * 0.2
		if e["y"] < -10.0:
			var fresh: Dictionary = _make_ember(false)
			e["x"] = fresh["x"]
			e["y"] = fresh["y"]
			e["speed"] = fresh["speed"]
			e["drift"] = fresh["drift"]
			e["size"] = fresh["size"]
			e["phase"] = fresh["phase"]
			e["hue"] = fresh["hue"]
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for e in embers:
		var flicker: float = 0.5 + 0.5 * sin(t * 3.0 + e["phase"])
		var col: Color = Color(0.95, 0.5 + e["hue"] * 0.3, 0.15, 0.35 + flicker * 0.4)
		draw_circle(Vector2(e["x"], e["y"]), e["size"], col)
