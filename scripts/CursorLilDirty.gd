extends Control

# A tiny cameo of Lil Dirty that follows your cursor on the title screen,
# purely for fun. Wiggles harder the faster you move the mouse, and if
# you drag him into a screen edge he "hits the wall" - a small blood
# splatter and a pleading speech bubble, on a cooldown so it doesn't spam.
# Fades away the moment the player actually starts the game.

const BloodSplatterScene := preload("res://scenes/BloodSplatter.tscn")

const EDGE_MARGIN := 46.0
const HIT_COOLDOWN := 1.1
const FOLLOW_LERP := 0.22
const CURSOR_OFFSET := Vector2(22, 26)

var body: Node2D
var _hit_cooldown: float = 0.0
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _mouse_speed: float = 0.0
var _wiggle_time: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_last_mouse_pos = get_global_mouse_position()
	position = _last_mouse_pos + CURSOR_OFFSET
	_target_pos = position
	_build_character()
	set_process(true)

# Rebuilds Lil Dirty's exact Hideout silhouette (body/head/vest/hat/gun)
# from the same polygon shapes, just scaled up and re-centered on his
# own origin instead of relative to a table.
func _build_character() -> void:
	body = Node2D.new()
	body.scale = Vector2(2.3, 2.3)
	add_child(body)

	var parts := [
		{"color": Color(0.16, 0.16, 0.18, 1), "pos": Vector2(0, 0), "poly": _poly([-9, -3, 9, -3, 8, 6, 0, 10, -8, 6])},
		{"color": Color(0.18, 0.32, 0.15, 1), "pos": Vector2(0, 0), "poly": _poly([-12, 0, 12, 0, 10.39, 7, 6, 12.12, 0, 14, -6, 12.12, -10.39, 7])},
		{"color": Color(0.28, 0.24, 0.1, 1), "pos": Vector2(0, 0), "poly": _poly([-2, -4, 2, -4, 2, 9, -2, 9])},
		{"color": Color(0.6, 0.45, 0.35, 1), "pos": Vector2(0, -27.5), "poly": _poly([8, 0, 6.47, 4.7, 2.47, 7.61, -2.47, 7.61, -6.47, 4.7, -8, 0, -6.47, -4.7, -2.47, -7.61, 2.47, -7.61, 6.47, -4.7])},
		{"color": Color(0.12, 0.22, 0.1, 1), "pos": Vector2(0, -33.5), "poly": _poly([-8, -1, 8, -1, 9, 2, 10, 4, -10, 4, -9, 2])},
	]
	for p in parts:
		var poly := Polygon2D.new()
		poly.polygon = p["poly"]
		poly.color = p["color"]
		poly.position = p["pos"]
		body.add_child(poly)

	var gun := Polygon2D.new()
	gun.polygon = _poly([-3, -2, 9, -2, 9, 1, -3, 1, -3, 5, -5, 5, -5, -2])
	gun.color = Color(0.12, 0.12, 0.13, 1)
	gun.position = Vector2(11, 2.5)
	gun.rotation = 0.3
	body.add_child(gun)

# Converts a flat [x1, y1, x2, y2, ...] list into real Vector2 pairs -
# PackedVector2Array(...) only accepts flat numbers like that inside
# .tscn resource text, not from GDScript code, which needs actual
# Vector2 objects.
func _poly(flat: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(Vector2(flat[i], flat[i + 1]))
	return pts

func _process(delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var moved: Vector2 = mouse_pos - _last_mouse_pos
	_mouse_speed = lerp(_mouse_speed, moved.length() / max(delta, 0.001), 0.4)
	_last_mouse_pos = mouse_pos

	_target_pos = mouse_pos + CURSOR_OFFSET
	position = position.lerp(_target_pos, FOLLOW_LERP)

	_wiggle_time += delta * (8.0 + min(_mouse_speed * 0.02, 10.0))
	var wiggle_amount: float = clamp(_mouse_speed * 0.0009, 0.0, 0.4)
	body.rotation = sin(_wiggle_time) * wiggle_amount
	body.position.y = sin(_wiggle_time * 1.3) * min(_mouse_speed * 0.01, 3.0)

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
		return

	var vp_size: Vector2 = get_viewport_rect().size
	if position.x <= EDGE_MARGIN or position.x >= vp_size.x - EDGE_MARGIN or position.y <= EDGE_MARGIN or position.y >= vp_size.y - EDGE_MARGIN:
		_hit_wall()

func _hit_wall() -> void:
	_hit_cooldown = HIT_COOLDOWN
	var splatter = BloodSplatterScene.instantiate()
	get_tree().current_scene.add_child(splatter)
	splatter.global_position = position
	_show_ouch_bubble()

func _show_ouch_bubble() -> void:
	var bubble := Label.new()
	bubble.text = "Please dont hurt me bro"
	bubble.add_theme_font_size_override("font_size", 13)
	bubble.add_theme_color_override("font_color", Color(1, 0.9, 0.9, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-70, -55)
	bubble.custom_minimum_size = Vector2(140, 0)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bubble.queue_free)

# Called by IntroCutscene the moment the player actually presses start -
# fades out rather than just vanishing.
func dismiss() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	queue_free()
