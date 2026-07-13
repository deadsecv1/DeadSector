extends CharacterBody2D

# The recruited Wandering Ghost - follows the player around for the
# rest of the raid (same loose-roam-and-catch-up pattern as Pet.gd).
# No combat, just company. If the raid ends in a successful
# extraction while this is still alive, GameManager marks the ghost
# as permanently recruited and he shows up in the Hideout from then on.

const ROAM_RADIUS := 90.0
const MAX_LEASH_DISTANCE := 320.0
const SPEED := 220.0

const CHAT_LINES := [
	"...", "it's quiet here.", "you're not alone.", "keep going.",
	"i remember this place.", "watch the corners.",
]

var player: Node2D
var roam_target: Vector2 = Vector2.ZERO
var roam_timer: float = 0.0
var bob_phase: float = 0.0
var chat_cooldown_until_ms: int = 0

func _ready() -> void:
	add_to_group("ghost_companion")
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_tree().get_first_node_in_group("gauntlet_player")
	z_index = 5
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.55, 1.0)
	bob_phase = randf_range(0.0, TAU)
	roam_timer = randf_range(0.0, 1.5)
	if player != null:
		_pick_new_roam_target()

func _pick_new_roam_target() -> void:
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(30.0, ROAM_RADIUS)
	roam_target = Vector2(cos(ang), sin(ang)) * dist
	roam_timer = randf_range(2.5, 5.0)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	roam_timer -= delta
	var target := player.global_position + roam_target
	var dist_to_player := global_position.distance_to(player.global_position)
	if roam_timer <= 0.0 or dist_to_player > MAX_LEASH_DISTANCE:
		_pick_new_roam_target()
		target = player.global_position + roam_target
	if dist_to_player > MAX_LEASH_DISTANCE:
		target = player.global_position

	var dist := global_position.distance_to(target)
	if dist > 14.0:
		var dir := (target - global_position).normalized()
		velocity = velocity.lerp(dir * SPEED * clamp(dist / 80.0, 0.3, 1.4), clamp(delta * 6.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 6.0, 0.0, 1.0))
	move_and_slide()

	bob_phase += delta * 1.4
	queue_redraw()
	_maybe_chat()

func _maybe_chat() -> void:
	if Time.get_ticks_msec() < chat_cooldown_until_ms:
		return
	if randf() > 0.002:
		return
	chat_cooldown_until_ms = Time.get_ticks_msec() + 45000
	var bubble := Label.new()
	bubble.text = CHAT_LINES[randi() % CHAT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 11)
	bubble.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -50)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tw.tween_callback(bubble.queue_free)

func _draw() -> void:
	var col := Color(0.7, 0.9, 0.95, 1)
	var bob: float = sin(bob_phase) * 2.5
	draw_circle(Vector2(0, -10 + bob), 9.0, col)
	var wisp_tail := PackedVector2Array([
		Vector2(-9, -6), Vector2(9, -6), Vector2(7, 10), Vector2(3, 4), Vector2(0, 12),
		Vector2(-3, 4), Vector2(-7, 10),
	])
	var offset_tail := PackedVector2Array()
	for p in wisp_tail:
		offset_tail.append(p + Vector2(0, bob))
	draw_colored_polygon(offset_tail, col)
	draw_circle(Vector2(-3, -12 + bob), 1.4, Color(0.05, 0.1, 0.1, 0.8))
	draw_circle(Vector2(3, -12 + bob), 1.4, Color(0.05, 0.1, 0.1, 0.8))
