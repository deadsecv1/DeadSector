extends Control

# A subtle meteor shower falling from the top of the title screen.
# Color is driven live from IntroCutscene (meteor_color), matching the
# same background contrast cycle everything else on this screen uses.
# Meteors actually collide with the title text's real bounding box and
# with the skyline's building rooftops (queried live from
# CutsceneSkyline.get_building_rects()) - on a hit, that meteor stops
# and explodes into a small burst instead of passing through.

const METEOR_COUNT := 14
const FALL_SPEED_MIN := 220.0
const FALL_SPEED_MAX := 380.0
const FALL_ANGLE := 0.32  # radians off vertical
const EXPLODE_DURATION := 0.35

var meteor_color: Color = Color(1, 1, 1, 0.16)
var title_rect: Rect2 = Rect2()
var skyline: Control = null

var meteors: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset_all)
	for i in range(METEOR_COUNT):
		meteors.append(_make_meteor())
	set_process(true)

func _make_meteor() -> Dictionary:
	var w: float = max(size.x, 1.0)
	return {
		"pos": Vector2(randf_range(0.0, w), randf_range(-500.0, -10.0)),
		"speed": randf_range(FALL_SPEED_MIN, FALL_SPEED_MAX),
		"len": randf_range(16.0, 34.0),
		"exploding": 0.0,
	}

func _reset_all() -> void:
	for m in meteors:
		_reset_meteor(m)

func _reset_meteor(m: Dictionary) -> void:
	var w: float = max(size.x, 1.0)
	m["pos"] = Vector2(randf_range(0.0, w), randf_range(-500.0, -10.0))
	m["speed"] = randf_range(FALL_SPEED_MIN, FALL_SPEED_MAX)
	m["len"] = randf_range(16.0, 34.0)
	m["exploding"] = 0.0

func _process(delta: float) -> void:
	var h: float = size.y
	var w: float = max(size.x, 1.0)
	var dir := Vector2(sin(FALL_ANGLE), cos(FALL_ANGLE))
	for m in meteors:
		if m["exploding"] > 0.0:
			m["exploding"] -= delta
			if m["exploding"] <= 0.0:
				_reset_meteor(m)
			continue
		m["pos"] += dir * m["speed"] * delta
		if title_rect.has_point(m["pos"]) or _hits_building(m["pos"]):
			m["exploding"] = EXPLODE_DURATION
			continue
		if m["pos"].y > h + 40.0 or m["pos"].x < -40.0 or m["pos"].x > w + 40.0:
			_reset_meteor(m)
	queue_redraw()

func _hits_building(pos: Vector2) -> bool:
	if skyline == null or not is_instance_valid(skyline) or not skyline.has_method("get_building_rects"):
		return false
	for rect in skyline.get_building_rects():
		if rect.has_point(pos):
			return true
	return false

func _draw() -> void:
	var dir := Vector2(sin(FALL_ANGLE), cos(FALL_ANGLE))
	for m in meteors:
		if m["exploding"] > 0.0:
			var t: float = 1.0 - (m["exploding"] / EXPLODE_DURATION)
			var radius: float = 3.0 + t * 12.0
			var a: float = meteor_color.a * (1.0 - t) * 2.0
			draw_circle(m["pos"], radius, Color(meteor_color.r, meteor_color.g, meteor_color.b, clamp(a, 0.0, 1.0)))
			continue
		var tail: Vector2 = m["pos"] - dir * m["len"]
		draw_line(m["pos"], tail, meteor_color, 1.4, true)
