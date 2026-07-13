extends CharacterBody2D

# A Pet companion - follows the player, and now actually fights: it
# periodically zaps the nearest enemy in range. Speed varies per pet
# (some are noticeably quicker followers than others). Occasionally
# throws up a chat bubble while in combat, at most once a minute.

@export var pet_id: String = ""
const ROAM_RADIUS := 110.0
const MAX_LEASH_DISTANCE := 260.0
const BASE_SPEED := 260.0
const ATTACK_RANGE := 220.0
const ATTACK_COOLDOWN := 1.4
const ATTACK_DAMAGE := 4

const CHAT_LINES := [
	"On it!", "Got your back!", "Yip!", "Take this!", "Hah!",
	"Not today.", "Grr...", "Stay close!", "I see it!", "Right behind you.",
]

var player: Node2D
var speed_mult: float = 1.0
var attack_timer: float = 0.0
var chat_cooldown_until_ms: int = 0
var roam_target: Vector2 = Vector2.ZERO
var roam_timer: float = 0.0

# --- Loom-weaver spider mode: the standard 4-legged critter body is
# hidden and replaced with a procedurally drawn 10-legged spider with
# an animated gait and a faint drifting web-thread particle trail.
var is_spider: bool = false
var spider_color: Color = Color(0.14, 0.08, 0.18, 1)
var leg_phase: float = 0.0
var web_particles: CPUParticles2D

@onready var body: Polygon2D = $Body
@onready var head: Polygon2D = $Head
@onready var leg_fl: Polygon2D = $LegFrontLeft
@onready var leg_fr: Polygon2D = $LegFrontRight
@onready var leg_bl: Polygon2D = $LegBackLeft
@onready var leg_br: Polygon2D = $LegBackRight
@onready var tail: Polygon2D = $TailBack

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_tree().get_first_node_in_group("gauntlet_player")
	var pet: Dictionary = GameManager.get_pet_data(pet_id)
	var base_color: Color = pet.get("color", Color(0.6, 0.6, 0.6, 1))
	var dark_color := Color(base_color.r * 0.75, base_color.g * 0.75, base_color.b * 0.75, 1.0)
	speed_mult = float(pet.get("speed_mult", 1.0))
	z_index = 5
	attack_timer = randf_range(0.0, ATTACK_COOLDOWN)
	roam_timer = randf_range(0.0, 1.5)
	if pet_id == GameManager.LOOM_WEAVER_PET_ID:
		is_spider = true
		spider_color = base_color
		for n in [body, head, tail, leg_fl, leg_fr, leg_bl, leg_br]:
			n.visible = false
		_setup_web_trail()
		set_process(true)
	else:
		body.color = base_color
		head.color = base_color
		tail.color = base_color
		leg_fl.color = dark_color
		leg_fr.color = dark_color
		leg_bl.color = dark_color
		leg_br.color = dark_color
	if player != null:
		_pick_new_roam_target()

func _setup_web_trail() -> void:
	web_particles = CPUParticles2D.new()
	web_particles.amount = 16
	web_particles.lifetime = 1.1
	web_particles.direction = Vector2.ZERO
	web_particles.spread = 180.0
	web_particles.gravity = Vector2(0, 6)
	web_particles.initial_velocity_min = 2.0
	web_particles.initial_velocity_max = 8.0
	web_particles.scale_amount_min = 0.8
	web_particles.scale_amount_max = 1.8
	web_particles.color = Color(spider_color.r + 0.3, spider_color.g + 0.3, spider_color.b + 0.3, 0.35)
	web_particles.position = Vector2(0, 6)
	add_child(web_particles)

func _process(_delta: float) -> void:
	if is_spider:
		queue_redraw()

func _draw() -> void:
	if not is_spider:
		return
	var t := Time.get_ticks_msec() * 0.001
	var bob: float = sin(t * 6.0) * 1.5
	var body_center := Vector2(0, bob)

	# 10 legs, 5 per side, animated in an alternating tripod-ish gait
	# (odd legs and even legs swing in opposite phase).
	for i in range(5):
		var side_t: float = float(i) / 4.0
		var base_ang: float = lerp(-0.85, 0.95, side_t)
		var swing: float = sin(leg_phase + (i % 2) * PI) * 0.35
		for side in [-1, 1]:
			var ang: float = (PI if side < 0 else 0.0) + base_ang + swing
			var start := body_center
			var knee := start + Vector2(cos(ang), sin(ang) * 0.6) * 11.0 + Vector2(0, 3)
			var foot := knee + Vector2(cos(ang + 0.4 * side), sin(ang + 0.4 * side) * 0.6 + 0.5) * 9.0
			draw_line(start, knee, spider_color, 2.2)
			draw_line(knee, foot, spider_color, 1.8)

	# Abdomen (rear, larger) and cephalothorax (front, smaller) - the
	# classic two-part spider body silhouette.
	draw_circle(body_center + Vector2(-4, 0), 8.5, spider_color)
	draw_circle(body_center + Vector2(6, -1), 5.5, spider_color)
	# A faint sheen so the body doesn't read as a flat silhouette.
	draw_circle(body_center + Vector2(-6, -3), 3.0, Color(spider_color.r + 0.15, spider_color.g + 0.15, spider_color.b + 0.2, 0.35))
	# Eyes - small cluster, glinting red.
	for ex in [4.0, 7.0, 10.0]:
		draw_circle(body_center + Vector2(ex, -2), 0.9, Color(0.85, 0.15, 0.2, 0.85))

	leg_phase += 0.22

func _pick_new_roam_target() -> void:
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(35.0, ROAM_RADIUS)
	roam_target = Vector2(cos(ang), sin(ang)) * dist
	roam_timer = randf_range(2.5, 5.0)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Wanders loosely around the player instead of locking to one exact
	# spot beside them - re-picks a new nearby point every few seconds,
	# or sooner if it's fighting something or has drifted too far.
	roam_timer -= delta
	var target := player.global_position + roam_target
	var dist_to_player := global_position.distance_to(player.global_position)
	if roam_timer <= 0.0 or dist_to_player > MAX_LEASH_DISTANCE:
		_pick_new_roam_target()
		target = player.global_position + roam_target
	if dist_to_player > MAX_LEASH_DISTANCE:
		target = player.global_position

	var dist := global_position.distance_to(target)
	var speed := BASE_SPEED * speed_mult
	if dist > 16.0:
		var dir := (target - global_position).normalized()
		velocity = velocity.lerp(dir * speed * clamp(dist / 80.0, 0.3, 1.5), clamp(delta * 8.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 8.0, 0.0, 1.0))
	move_and_slide()
	if not is_spider:
		body.position.y = sin(Time.get_ticks_msec() * 0.006) * 2.0

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		_try_attack()

func _try_attack() -> void:
	var nearest: Node2D = null
	var nearest_dist := ATTACK_RANGE
	for group_name in ["enemy", "gauntlet_enemy", "gauntlet_boss"]:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(enemy):
				continue
			var d := global_position.distance_to(enemy.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
	if nearest == null:
		return
	if nearest.has_method("take_damage"):
		nearest.take_damage(ATTACK_DAMAGE)
		_flash_attack(nearest.global_position)
		_maybe_chat()

func _flash_attack(target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.0
	var flash_color: Color = spider_color if is_spider else body.color
	line.default_color = Color(flash_color.r, flash_color.g, flash_color.b, 0.8)
	get_parent().add_child(line)
	line.add_point(global_position)
	line.add_point(target_pos)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)

func _maybe_chat() -> void:
	if Time.get_ticks_msec() < chat_cooldown_until_ms:
		return
	chat_cooldown_until_ms = Time.get_ticks_msec() + 60000
	var bubble := Label.new()
	bubble.text = CHAT_LINES[randi() % CHAT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -50)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
