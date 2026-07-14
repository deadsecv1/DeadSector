extends Control

# A reusable black, dystopian-themed drifting particle background -
# dust motes and faint embers rising slowly through near-total darkness.
# Meant to sit behind UI panels (Stash, Traders, Quests, etc.) for a
# consistent atmosphere across every screen, without competing with the
# Spectral Tide's green/blue soul mist or the Store's gold sparkle.

var particles: Array = []
const PARTICLE_COUNT := 85

func _ready() -> void:
	resized.connect(_init_particles)
	_init_particles()
	set_process(true)

func _init_particles() -> void:
	particles.clear()
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for i in range(PARTICLE_COUNT):
		particles.append(_make_particle(w, h, true))

func _make_particle(w: float, h: float, random_y: bool) -> Dictionary:
	return {
		"x": randf_range(0.0, w),
		"y": randf_range(0.0, h) if random_y else h + randf_range(0.0, 30.0),
		"speed": randf_range(8.0, 26.0),
		"drift": randf_range(-7.0, 7.0),
		"r": randf_range(0.8, 2.8),
		"phase": randf_range(0.0, TAU),
		"ember": randf() < 0.25,
	}

func _process(delta: float) -> void:
	# Godot doesn't skip _process() for an invisible node on its own, and
	# this is instanced ~20 times across MainMenu's permanent hidden
	# sub-panels - without this check, all ~20 update and redraw their
	# full particle count every frame regardless of whether their parent
	# panel is actually the one currently shown. is_visible_in_tree()
	# (not just `visible`) since it's the PARENT panel that toggles, not
	# this node's own visibility.
	if not is_visible_in_tree():
		return
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for p in particles:
		p["y"] -= p["speed"] * delta
		p["x"] += p["drift"] * delta * 0.2
		if p["y"] < -10.0:
			var fresh := _make_particle(w, h, false)
			p["x"] = fresh["x"]
			p["y"] = fresh["y"]
			p["speed"] = fresh["speed"]
			p["drift"] = fresh["drift"]
			p["r"] = fresh["r"]
			p["phase"] = fresh["phase"]
			p["ember"] = fresh["ember"]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.085, 0.09, 1))
	var t := Time.get_ticks_msec() * 0.001
	for p in particles:
		var flicker: float = 0.4 + 0.6 * sin(t * 2.2 + p["phase"])
		var col: Color
		if p["ember"]:
			col = Color(0.85, 0.45, 0.15, 0.25 + flicker * 0.3)
		else:
			col = Color(0.5, 0.5, 0.5, 0.12 + flicker * 0.15)
		draw_circle(Vector2(p["x"], p["y"]), p["r"] * (0.7 + flicker * 0.4), col)
