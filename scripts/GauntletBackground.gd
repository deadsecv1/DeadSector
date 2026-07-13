extends Control

# A moody, dynamic backdrop for Bloodline - similar spirit to the Main
# Menu's skyline (silhouettes + flickering lights + drifting particles)
# but with its own crimson/purple ruin theme instead of a warm city,
# and it actually parallax-shifts as the player moves through the level
# instead of sitting static.

var rng := RandomNumberGenerator.new()
var time := 0.0
var player_ref: Node = null
var scroll_x: float = 0.0

var spires: Array = []      # {x, w, h, shade}
var windows: Array = []     # {x, y, w, h, phase, speed}
var embers: Array = []      # {x, y, speed, drift, r, phase}
var fog_patches: Array = [] # {x, y, r, drift, phase}
var wanderers: Array = []   # {x, y, speed, scale, phase} - drifting red silhouette figures

func _ready() -> void:
	resized.connect(_regenerate)
	_regenerate()
	player_ref = get_tree().get_first_node_in_group("gauntlet_player")
	set_process(true)

func _process(delta: float) -> void:
	time += delta
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("gauntlet_player")
	if player_ref != null and is_instance_valid(player_ref):
		# Parallax: the background trails the player's X position at a
		# fraction of real speed, giving a real sense of depth instead
		# of a flat static backdrop.
		scroll_x = player_ref.global_position.x * 0.08

	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for e in embers:
		e["y"] -= e["speed"] * delta
		e["x"] += e["drift"] * delta
		if e["y"] < -10.0:
			e["y"] = h + randf_range(0.0, 20.0)
			e["x"] = randf_range(0.0, w)
	for f in fog_patches:
		f["x"] += f["drift"] * delta
		if f["drift"] >= 0.0 and f["x"] - f["r"] > w:
			f["x"] = -f["r"]
		elif f["drift"] < 0.0 and f["x"] + f["r"] < 0.0:
			f["x"] = w + f["r"]
	for fig in wanderers:
		fig["x"] += fig["speed"] * delta
		if fig["speed"] >= 0.0 and fig["x"] - 40.0 > w:
			fig["x"] = -40.0
		elif fig["speed"] < 0.0 and fig["x"] + 40.0 < 0.0:
			fig["x"] = w + 40.0
	queue_redraw()

func _regenerate() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	spires.clear()
	windows.clear()
	embers.clear()
	fog_patches.clear()
	wanderers.clear()

	rng.seed = 4242
	# Generate a wide strip (3x screen width) so parallax scrolling has
	# room to move without ever showing empty space at the edges.
	var strip_w: float = w * 3.0
	var x := 0.0
	while x < strip_w:
		var sw: float = rng.randf_range(50, 140)
		var sh: float = rng.randf_range(0.2, 0.55) * h
		# Shade varies per spire - some lean pure black, some lean a
		# darker crimson - so the skyline isn't one flat silhouette
		# color end to end.
		var shade: float = rng.randf_range(0.0, 1.0)
		spires.append({"x": x, "w": sw, "h": sh, "shade": shade})
		var win_rows: int = int(sh / 26.0)
		var win_cols: int = max(1, int(sw / 22.0))
		for row in range(win_rows):
			for col in range(win_cols):
				if rng.randf() < 0.4:
					windows.append({
						"x": x + 6 + col * 22.0, "y": h - sh + 8 + row * 26.0,
						"w": 8.0, "h": 12.0, "phase": rng.randf_range(0.0, TAU),
						"speed": rng.randf_range(0.4, 1.4),
					})
		x += sw + rng.randf_range(10, 40)

	for i in range(50):
		embers.append({
			"x": randf_range(0.0, w), "y": randf_range(0.0, h),
			"speed": randf_range(6.0, 20.0), "drift": randf_range(-6.0, 6.0),
			"r": randf_range(0.8, 2.4), "phase": randf_range(0.0, TAU),
		})

	# Soft black fog patches drifting slowly through the lower half -
	# gives the backdrop real black areas instead of it reading as one
	# flat red wash.
	for i in range(6):
		fog_patches.append({
			"x": randf_range(0.0, w), "y": randf_range(h * 0.35, h * 0.95),
			"r": randf_range(90.0, 200.0), "drift": randf_range(-10.0, 10.0),
			"phase": randf_range(0.0, TAU),
		})

	# Low-opacity red silhouette figures that drift past in the mid
	# distance - purely atmospheric, not interactable or attackable,
	# just bodies moving through the ruin behind the fight.
	for i in range(5):
		var dir: float = 1.0 if randf() < 0.5 else -1.0
		wanderers.append({
			"x": randf_range(0.0, w), "y": h - randf_range(20.0, 90.0),
			"speed": dir * randf_range(12.0, 30.0), "scale": randf_range(0.7, 1.3),
			"phase": randf_range(0.0, TAU),
		})

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	# Deep crimson-to-black sky gradient - darker overall than before,
	# with a near-pure-black band at the very top so the sky doesn't
	# read as a flat red wash.
	var steps := 10
	for i in range(steps):
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var col: Color = Color(0.01, 0.005, 0.008, 1).lerp(Color(0.11, 0.02, 0.03, 1), sin(t0 * PI))
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1), col)

	# Soft black fog patches - drawn as several overlapping low-alpha
	# circles so the edges feather instead of showing a hard disc.
	for f in fog_patches:
		var fx: float = f["x"]
		var fy: float = f["y"]
		var r: float = f["r"]
		draw_circle(Vector2(fx, fy), r, Color(0, 0, 0, 0.10))
		draw_circle(Vector2(fx, fy), r * 0.65, Color(0, 0, 0, 0.12))
		draw_circle(Vector2(fx, fy), r * 0.35, Color(0, 0, 0, 0.14))

	# Parallax-shifted spire silhouettes.
	var offset: float = fmod(scroll_x, w * 3.0)
	for spire in spires:
		var sx: float = fmod(spire["x"] - offset, w * 3.0)
		if sx < -200:
			sx += w * 3.0
		if sx > w + 200:
			continue
		var shade: float = spire.get("shade", 0.5)
		var spire_color: Color = Color(0.02, 0.005, 0.01, 1).lerp(Color(0.09, 0.03, 0.04, 1), shade)
		draw_rect(Rect2(sx, h - spire["h"], spire["w"], spire["h"]), spire_color)

	for win in windows:
		var wx: float = fmod(win["x"] - offset, w * 3.0)
		if wx < -20 or wx > w + 20:
			continue
		var flicker: float = 0.5 + 0.5 * sin(time * win["speed"] + win["phase"])
		if flicker > 0.35:
			draw_rect(Rect2(wx, win["y"], win["w"], win["h"]), Color(0.75, 0.15, 0.2, 0.35 + flicker * 0.4))

	# Drifting red silhouette figures - low-opacity humanoid shapes
	# walking through the mid-ground. Purely visual: not a real node,
	# nothing to hit, nothing that hits back.
	for fig in wanderers:
		var fs: float = fig["scale"]
		var fx: float = fig["x"]
		var fy: float = fig["y"]
		var bob: float = sin(time * 2.2 + fig["phase"]) * 2.0 * fs
		var col := Color(0.55, 0.05, 0.08, 0.16)
		# Head
		draw_circle(Vector2(fx, fy - 34.0 * fs + bob), 7.0 * fs, col)
		# Torso
		draw_rect(Rect2(fx - 6.0 * fs, fy - 26.0 * fs + bob, 12.0 * fs, 22.0 * fs), col)
		# Legs (slight offset to suggest a stride)
		draw_rect(Rect2(fx - 5.0 * fs, fy - 4.0 * fs + bob, 4.0 * fs, 16.0 * fs), col)
		draw_rect(Rect2(fx + 1.0 * fs, fy - 4.0 * fs - bob, 4.0 * fs, 16.0 * fs), col)

	# Drifting embers, not parallax-shifted (they're close/foreground).
	for e in embers:
		var glow: float = 0.5 + 0.5 * sin(time * 1.5 + e["phase"])
		draw_circle(Vector2(e["x"], e["y"]), e["r"], Color(0.9, 0.35, 0.2, 0.3 + glow * 0.35))

	# Ground haze near the bottom.
	draw_rect(Rect2(0, h - 60, w, 60), Color(0.1, 0.02, 0.03, 0.3))
