extends Area2D

# A generic glowing collectible plant/object. Pulsates gently at rest;
# when the player gets close, more particles kick up and it pulses
# faster. Press F to collect. Used for Blossoms, Rust Shards, and
# Static Motes - just reconfigure the exports per scene.

@export var collectible_id: String = "blossom"
@export var currency_type: String = "blossoms"
@export var amount: int = 3
@export var particle_color: Color = Color(0.35, 0.55, 0.95, 0.6)

var player_in_range: bool = false
var player_nearby: bool = false
var collected: bool = false
var f_was_down: bool = false
var pulse_phase: float = 0.0
var particles: Array = []
const PARTICLE_COUNT_IDLE := 5
const PARTICLE_COUNT_NEAR := 14

@onready var petals: Polygon2D = $Petals
@onready var glow: Polygon2D = $Glow
@onready var interact_zone: Area2D = $InteractZone
@onready var particle_layer: Control = $ParticleLayer
@onready var prompt: Label = $Prompt

func _ready() -> void:
	add_to_group("collectible_plant")
	prompt.visible = false
	pulse_phase = randf_range(0.0, TAU)
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)
	particle_layer.draw.connect(_on_particle_draw)
	for i in range(PARTICLE_COUNT_NEAR):
		particles.append(_make_particle())
	GameManager.mark_collectible_seen(collectible_id)

func _make_particle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(10.0, 30.0),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.0, 2.2),
	}

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and not collected:
		player_in_range = true
		player_nearby = true
		prompt.text = GameManager.format_prompt("Press F to collect")
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_nearby = false
		prompt.visible = false

func _process(delta: float) -> void:
	if collected:
		return
	pulse_phase += delta * (3.0 if player_nearby else 1.4)
	var pulse: float = 0.85 + 0.15 * sin(pulse_phase)
	petals.scale = Vector2(pulse, pulse)
	glow.modulate.a = (0.35 if not player_nearby else 0.55) + 0.15 * sin(pulse_phase * 1.3)
	particle_layer.queue_redraw()

	if not player_in_range:
		return
	var f_down := GameManager.is_action_pressed("interact")
	if f_down and not f_was_down:
		_collect()
	f_was_down = f_down

func _collect() -> void:
	collected = true
	prompt.visible = false
	if currency_type == "xp":
		GameManager.grant_xp(amount)
	else:
		GameManager.add_currency(currency_type, amount)
	Sfx.play_heal()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.5).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	queue_free()

func _on_particle_draw() -> void:
	var count: int = PARTICLE_COUNT_NEAR if player_nearby else PARTICLE_COUNT_IDLE
	var t := Time.get_ticks_msec() * 0.001
	for i in range(count):
		var p = particles[i]
		var ang: float = p["ang"] + t * p["speed"]
		var d: float = p["dist"] * (1.0 if not player_nearby else 1.6)
		var bob: float = sin(t * 2.0 + p["phase"]) * 4.0
		var pos := Vector2(cos(ang) * d, sin(ang) * d - abs(bob))
		var flicker: float = 0.4 + 0.6 * sin(t * 3.0 + p["phase"])
		particle_layer.draw_circle(pos, p["r"] * (0.6 + flicker * 0.5), Color(particle_color.r, particle_color.g, particle_color.b, particle_color.a * flicker))
