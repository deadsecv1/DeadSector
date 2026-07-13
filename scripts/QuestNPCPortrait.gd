extends Control

signal clicked

@export var glow_color: Color = Color(0.6, 0.3, 0.85, 1)
@export var npc_name: String = "Echo"
@export var teaser: String = "Got a job for you."
@export var model: String = "echo"
@export var has_active_quest: bool = false

var is_hovered: bool = false
var _talk_phase: float = 0.0
var _active_phase: float = 0.0

@onready var speech_bubble: PanelContainer = $SpeechBubble
@onready var speech_label: Label = $SpeechBubble/Margin/Label

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():
		is_hovered = true
		speech_bubble.visible = true
	)
	mouse_exited.connect(func():
		is_hovered = false
		speech_bubble.visible = false
	)
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit()
	)
	speech_label.text = teaser
	speech_bubble.visible = false
	set_process(true)

func _process(delta: float) -> void:
	if is_hovered:
		_talk_phase += delta * 12.0
	if has_active_quest:
		_active_phase += delta * 3.0
	queue_redraw()

func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx, ny) * size

func _draw() -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001

	# An active contract gets its own bright, fast pulsing ring on top
	# of the normal ambient glow - and an ACTIVE tag under the name -
	# so it's obvious at a glance which contact you actually have
	# unfinished business with right now.
	if has_active_quest:
		var active_pulse: float = 0.55 + 0.35 * sin(_active_phase)
		draw_circle(_p(0.5, 0.55), w * 0.62, Color(1.0, 0.85, 0.3, 0.10 + active_pulse * 0.08))
		draw_arc(_p(0.5, 0.55), w * 0.58, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.35 + active_pulse * 0.4), 2.5)

	var glow_pulse: float = (0.6 if is_hovered else 0.35) + 0.3 * sin(t * (2.0 if is_hovered else 1.0))
	for i in range(3):
		var r: float = w * (0.4 + i * 0.09)
		draw_circle(_p(0.5, 0.55), r, Color(glow_color.r, glow_color.g, glow_color.b, 0.06 + glow_pulse * 0.03))

	match model:
		"warden":
			_draw_warden()
		"sprocket":
			_draw_sprocket()
		"atlas":
			_draw_atlas()
		"reaper":
			_draw_reaper()
		_:
			_draw_echo()

	var name_col := glow_color if is_hovered else Color(0.7, 0.7, 0.72, 1)
	draw_string(ThemeDB.fallback_font, _p(0.5, 1.08) - Vector2(30, 0), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, name_col)
	if has_active_quest:
		var active_col := Color(1.0, 0.85, 0.3, 0.75 + 0.25 * sin(_active_phase))
		draw_string(ThemeDB.fallback_font, _p(0.5, 1.16) - Vector2(70, 0), "● Active Quest", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, active_col)

# --- Echo: the Guide - a slim robed figure holding a small glowing
# lantern/orb at chest height, watching more than acting.
func _draw_echo() -> void:
	var cloak := PackedVector2Array([
		_p(0.5, 0.24), _p(0.7, 0.42), _p(0.8, 0.95), _p(0.2, 0.95), _p(0.3, 0.42),
	])
	draw_colored_polygon(cloak, Color(0.04, 0.04, 0.05, 1))
	draw_circle(_p(0.5, 0.3), size.x * 0.13, Color(0.02, 0.02, 0.03, 1))
	var hood_shape := PackedVector2Array([
		_p(0.36, 0.26), _p(0.5, 0.16), _p(0.64, 0.26), _p(0.6, 0.42), _p(0.4, 0.42),
	])
	draw_colored_polygon(hood_shape, Color(0.05, 0.05, 0.06, 1))
	_draw_eyes_and_mouth()
	# The lantern - a small glowing orb held in front, Echo's signature.
	var orb_glow: float = 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.002)
	draw_circle(_p(0.5, 0.68), size.x * 0.05, Color(glow_color.r, glow_color.g, glow_color.b, 0.3 + orb_glow * 0.5))
	draw_circle(_p(0.5, 0.68), size.x * 0.025, Color(1, 1, 1, 0.8))

# --- Warden: broad, armored, a rifle strap across the chest.
func _draw_warden() -> void:
	var cloak := PackedVector2Array([
		_p(0.5, 0.22), _p(0.82, 0.44), _p(0.92, 0.95), _p(0.08, 0.95), _p(0.18, 0.44),
	])
	draw_colored_polygon(cloak, Color(0.06, 0.05, 0.05, 1))
	# Pauldrons - the broad-shoulder silhouette that reads as "combat".
	draw_colored_polygon(PackedVector2Array([_p(0.18, 0.4), _p(0.32, 0.36), _p(0.3, 0.5), _p(0.14, 0.52)]), Color(0.1, 0.06, 0.06, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.82, 0.4), _p(0.68, 0.36), _p(0.7, 0.5), _p(0.86, 0.52)]), Color(0.1, 0.06, 0.06, 1))
	draw_circle(_p(0.5, 0.3), size.x * 0.14, Color(0.02, 0.02, 0.03, 1))
	var hood_shape := PackedVector2Array([
		_p(0.35, 0.26), _p(0.5, 0.15), _p(0.65, 0.26), _p(0.6, 0.42), _p(0.4, 0.42),
	])
	draw_colored_polygon(hood_shape, Color(0.08, 0.06, 0.06, 1))
	_draw_eyes_and_mouth()
	# Rifle strap - a diagonal line across the torso.
	draw_line(_p(0.32, 0.42), _p(0.62, 0.75), Color(0.15, 0.12, 0.1, 1), size.x * 0.035)

# --- Sprocket: smaller, hunched, forehead goggles, a mechanical claw.
func _draw_sprocket() -> void:
	var cloak := PackedVector2Array([
		_p(0.5, 0.3), _p(0.68, 0.46), _p(0.78, 0.9), _p(0.22, 0.9), _p(0.32, 0.46),
	])
	draw_colored_polygon(cloak, Color(0.05, 0.06, 0.05, 1))
	draw_circle(_p(0.5, 0.36), size.x * 0.115, Color(0.02, 0.02, 0.03, 1))
	# Goggles pushed up on the forehead.
	draw_circle(_p(0.44, 0.3), size.x * 0.035, Color(glow_color.r, glow_color.g, glow_color.b, 0.7))
	draw_circle(_p(0.56, 0.3), size.x * 0.035, Color(glow_color.r, glow_color.g, glow_color.b, 0.7))
	draw_line(_p(0.44, 0.3), _p(0.56, 0.3), Color(0.15, 0.15, 0.15, 1), size.x * 0.015)
	_draw_eyes_and_mouth(0.42)
	# A mechanical arm sticking out to the side - a simple jointed line.
	draw_line(_p(0.72, 0.5), _p(0.85, 0.6), Color(0.2, 0.2, 0.22, 1), size.x * 0.03)
	draw_line(_p(0.85, 0.6), _p(0.8, 0.72), Color(0.2, 0.2, 0.22, 1), size.x * 0.03)
	draw_circle(_p(0.8, 0.72), size.x * 0.022, Color(glow_color.r, glow_color.g, glow_color.b, 0.6))

# --- Atlas: wide-brimmed hat, a satchel strap, more traveler than fighter.
func _draw_atlas() -> void:
	var cloak := PackedVector2Array([
		_p(0.5, 0.3), _p(0.72, 0.46), _p(0.82, 0.95), _p(0.18, 0.95), _p(0.28, 0.46),
	])
	draw_colored_polygon(cloak, Color(0.05, 0.045, 0.04, 1))
	draw_circle(_p(0.5, 0.34), size.x * 0.115, Color(0.02, 0.02, 0.03, 1))
	# Wide-brimmed hat instead of a hood.
	draw_colored_polygon(PackedVector2Array([_p(0.22, 0.28), _p(0.78, 0.28), _p(0.68, 0.34), _p(0.32, 0.34)]), Color(0.08, 0.06, 0.04, 1))
	var hat_top := PackedVector2Array([_p(0.4, 0.28), _p(0.5, 0.16), _p(0.6, 0.28)])
	draw_colored_polygon(hat_top, Color(0.08, 0.06, 0.04, 1))
	_draw_eyes_and_mouth(0.4)
	# Satchel strap with a small pouch - carries the maps.
	draw_line(_p(0.34, 0.46), _p(0.64, 0.78), Color(0.25, 0.18, 0.1, 1), size.x * 0.03)
	draw_colored_polygon(PackedVector2Array([_p(0.58, 0.74), _p(0.7, 0.76), _p(0.68, 0.86), _p(0.56, 0.84)]), Color(0.22, 0.15, 0.08, 1))

# --- Reaper: tall, tattered, faceless - the one you meet last.
func _draw_reaper() -> void:
	var cloak := PackedVector2Array([
		_p(0.5, 0.18), _p(0.74, 0.4), _p(0.86, 0.86), _p(0.78, 0.95), _p(0.68, 0.82),
		_p(0.6, 0.95), _p(0.5, 0.82), _p(0.4, 0.95), _p(0.32, 0.82), _p(0.22, 0.95),
		_p(0.14, 0.86), _p(0.26, 0.4),
	])
	draw_colored_polygon(cloak, Color(0.03, 0.02, 0.03, 1))
	var hood_shape := PackedVector2Array([
		_p(0.33, 0.24), _p(0.5, 0.1), _p(0.67, 0.24), _p(0.6, 0.44), _p(0.4, 0.44),
	])
	draw_colored_polygon(hood_shape, Color(0.02, 0.015, 0.02, 1))
	# No visible face - just the glowing eyes in total dark.
	var eye_glow: float = (0.85 if is_hovered else 0.55) + 0.25 * sin(Time.get_ticks_msec() * 0.001)
	draw_circle(_p(0.455, 0.3), size.x * 0.014, Color(glow_color.r, glow_color.g, glow_color.b, eye_glow))
	draw_circle(_p(0.545, 0.3), size.x * 0.014, Color(glow_color.r, glow_color.g, glow_color.b, eye_glow))

func _draw_eyes_and_mouth(head_y: float = 0.31) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var eye_glow: float = (0.75 if is_hovered else 0.4) + 0.25 * sin(t * 0.9)
	var eye_r: float = size.x * (0.016 if is_hovered else 0.012)
	draw_circle(_p(0.455, head_y), eye_r, Color(glow_color.r, glow_color.g, glow_color.b, eye_glow))
	draw_circle(_p(0.545, head_y), eye_r, Color(glow_color.r, glow_color.g, glow_color.b, eye_glow))
	var mouth_open: float = (0.5 + 0.5 * sin(_talk_phase)) if is_hovered else 0.0
	var mouth_w: float = size.x * (0.03 + mouth_open * 0.015)
	draw_rect(Rect2(_p(0.5, head_y + 0.045) - Vector2(mouth_w * 0.5, 0), Vector2(mouth_w, size.x * (0.006 + mouth_open * 0.01))), Color(glow_color.r, glow_color.g, glow_color.b, 0.8))
