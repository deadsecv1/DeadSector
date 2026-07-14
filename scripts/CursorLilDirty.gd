extends Control

# A tiny cameo of Lil Dirty that follows your cursor on the title screen,
# purely for fun. Wiggles harder the faster you move the mouse, and if
# you drag him into a screen edge he "hits the wall" - a blood splatter,
# a quiet "ouch" thud, and a pleading speech bubble, on a cooldown so it
# doesn't spam. Uses his real Hideout sprite (assets/npcs/lildirty.png)
# instead of a hand-drawn silhouette, so it actually looks like him.
# Fades away the moment the player actually starts the game.

const BloodSplatterScene := preload("res://scenes/BloodSplatter.tscn")
const LilDirtyTexture := preload("res://assets/npcs/lildirty.png")

const EDGE_MARGIN := 46.0
const HIT_COOLDOWN := 1.1
const FOLLOW_LERP := 0.22
const CURSOR_OFFSET := Vector2(18, 20)
# Deliberately modest - this is a small cursor cameo, not a full character.
const BODY_SCALE := 1.3

const PLEADING_LINES := [
	"Please dont hurt me bro",
	"Mercy!! I'll wash off the dirtyness, I swear!",
	"Jay please make it stop!!",
	"Tell James I said sorry for everything",
	"Not the face man, not the face",
	"Glenn warned me this would happen to me",
	"I'll tell Clarity Interactive whatever you want, just stop",
	"The dirtyness is a lifestyle, not a crime!!",
	"James saw nothing, I saw nothing, nobody saw anything",
	"Ok ok ok I get it, less dirtyness, I hear you",
	"Ask Glenn, he'll vouch for me!! GLENN",
	"Jay c'mon man we go way back",
]

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

# Real sprite (his actual Hideout look) plus a small shadow and gun -
# same pieces as the Hideout NPC, just recomposed around his own origin
# and scaled down for a cursor-following cameo.
func _build_character() -> void:
	body = Node2D.new()
	add_child(body)

	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.25)
	shadow.position = Vector2(0, 18) * BODY_SCALE
	shadow.polygon = _poly([-10, 0, 10, 0, 8, 6, -8, 6])
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = LilDirtyTexture
	sprite.scale = Vector2(BODY_SCALE, BODY_SCALE)
	body.add_child(sprite)

	var gun := Polygon2D.new()
	gun.polygon = _poly([-3, -2, 9, -2, 9, 1, -3, 1, -3, 5, -5, 5, -5, -2])
	gun.color = Color(0.12, 0.12, 0.13, 1)
	gun.position = Vector2(11, 8) * BODY_SCALE
	gun.scale = Vector2(BODY_SCALE, BODY_SCALE)
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
	splatter.particle_count = 16
	splatter.size_mult = 2.0
	splatter.distance_mult = 1.8
	get_tree().current_scene.add_child(splatter)
	splatter.global_position = position
	Sfx.play_lildirty_ouch()
	_show_ouch_bubble()

func _show_ouch_bubble() -> void:
	var bubble := Label.new()
	bubble.text = PLEADING_LINES[randi() % PLEADING_LINES.size()]
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
