extends CanvasLayer

# Simplified per feedback: no more Fog/Snow/Storm rotation - just an
# occasional rain shower, roughly once every 2-4 raids, nothing more.
# When it doesn't roll rain, nothing happens at all (no weather).

enum Weather { CLEAR, RAIN }

var weather: int = Weather.CLEAR
var particles: Array = []
const PARTICLE_COUNT := 140

@onready var canvas: Control = $Canvas

func _ready() -> void:
	layer = 85
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_weather()
	_init_particles()
	set_process(true)

func _roll_weather() -> void:
	# Roughly 1-in-3 raids get rain, landing in the "every 2 to 4 raids" range.
	weather = Weather.RAIN if randf() < 0.33 else Weather.CLEAR

func _init_particles() -> void:
	particles.clear()
	if weather == Weather.CLEAR:
		return
	var w: float = get_viewport().get_visible_rect().size.x
	var h: float = get_viewport().get_visible_rect().size.y
	for i in range(PARTICLE_COUNT):
		particles.append(_make_particle(w, h, true))

func _make_particle(w: float, h: float, random_y: bool) -> Dictionary:
	return {
		"x": randf_range(0.0, w), "y": randf_range(0.0, h) if random_y else -20.0,
		"speed": randf_range(700.0, 1100.0), "len": randf_range(14.0, 26.0),
	}

func _process(delta: float) -> void:
	if weather != Weather.RAIN:
		return
	var w: float = get_viewport().get_visible_rect().size.x
	var h: float = get_viewport().get_visible_rect().size.y
	for p in particles:
		p["y"] += p["speed"] * delta
		p["x"] -= 60.0 * delta
		if p["y"] > h:
			var fresh := _make_particle(w, h, false)
			p["x"] = fresh["x"]; p["y"] = fresh["y"]; p["speed"] = fresh["speed"]; p["len"] = fresh["len"]
	canvas.queue_redraw()

func get_weather_name() -> String:
	return "Rain" if weather == Weather.RAIN else "Clear"
