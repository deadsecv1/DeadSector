extends Control

# Draws a simple front-facing humanoid silhouette behind the equipment
# slot buttons, so Head/Body/Weapon/Accessory line up with body parts.
# Scales automatically to whatever size this Control is given (designed at
# a 300-wide reference canvas).

func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _s() -> float:
	return size.x / 300.0

func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _s()

func _draw() -> void:
	var skin := Color(0.8, 0.62, 0.48, 1)
	var shirt := Color(0.22, 0.4, 0.68, 1)
	var pants := Color(0.2, 0.2, 0.25, 1)
	var hair_col: Color = GameManager.HAIR_COLORS[GameManager.player_hair_color_idx] if GameManager.player_hair_color_idx < GameManager.HAIR_COLORS.size() else Color(0.22, 0.14, 0.1, 1)
	var s := _s()

	# Soft ground shadow so the silhouette doesn't look like it's floating.
	draw_colored_polygon(PackedVector2Array([_p(90, 300), _p(210, 300), _p(200, 312), _p(100, 312)]), Color(0, 0, 0, 0.25))

	# Head
	draw_circle(_p(150, 55), 38 * s, skin)
	draw_circle(_p(150, 62), 34 * s, skin.darkened(0.08))
	draw_circle(_p(150, 55), 38 * s, skin)
	# Hair - reflects the player's actual chosen color.
	draw_circle(_p(138, 40), 26 * s, hair_col)

	# Torso, with a lighter highlight down the front for some depth.
	var torso := PackedVector2Array([
		_p(95, 100), _p(205, 100), _p(220, 150),
		_p(200, 235), _p(100, 235), _p(80, 150)
	])
	draw_colored_polygon(torso, shirt)
	draw_colored_polygon(PackedVector2Array([_p(135, 108), _p(165, 108), _p(160, 228), _p(140, 228)]), shirt.lightened(0.12))

	# Glow accent on the chest, matching the creation screen's choice.
	var glow_idx: int = GameManager.player_glow_color_idx
	if glow_idx >= 0 and glow_idx < GameManager.GLOW_COLORS.size():
		var glow_col: Color = GameManager.GLOW_COLORS[glow_idx]["color"]
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
		draw_rect(Rect2(_p(140, 140), Vector2(20, 40) * s), Color(glow_col.r, glow_col.g, glow_col.b, glow_col.a * pulse))

	# Arms
	var left_arm := PackedVector2Array([
		_p(80, 115), _p(100, 110), _p(95, 210), _p(70, 205)
	])
	draw_colored_polygon(left_arm, shirt)
	var right_arm := PackedVector2Array([
		_p(220, 115), _p(200, 110), _p(205, 210), _p(230, 205)
	])
	draw_colored_polygon(right_arm, shirt)

	# Legs, with a subtle inner shadow for a less flat look.
	var left_leg := PackedVector2Array([
		_p(105, 230), _p(140, 230), _p(135, 295), _p(108, 295)
	])
	draw_colored_polygon(left_leg, pants)
	var right_leg := PackedVector2Array([
		_p(160, 230), _p(195, 230), _p(192, 295), _p(165, 295)
	])
	draw_colored_polygon(right_leg, pants)
	draw_line(_p(122, 232), _p(120, 293), pants.darkened(0.3), 2.0 * s)
	draw_line(_p(178, 232), _p(180, 293), pants.darkened(0.3), 2.0 * s)

	# Boots
	var boot_color := Color(0.12, 0.09, 0.07, 1)
	draw_rect(Rect2(_p(105, 293), Vector2(33, 12) * s), boot_color)
	draw_rect(Rect2(_p(162, 293), Vector2(33, 12) * s), boot_color)
