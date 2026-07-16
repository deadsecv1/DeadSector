extends "res://scripts/Enemy.gd"

# A small glowing wisp - the enemy that spawns in Commune's wave
# survival. Weaker than regular raiders but drops Souls on death.
#
# use_external_sprite was never set on this scene at all, so it silently
# defaulted to true with no enemy_type_id to match either - meaning this
# rendered as the plain, completely UNTINTED generic human sprite (all of
# the recoloring below was dead code, hiding behind it). Now forced onto
# the vector path, but the shared humanoid rig needs the same treatment
# NoxiousBat.gd got: hide everything human-shaped (gun rig, strap, cap,
# outlines) instead of just recoloring it, and add a soft outer glow so
# it actually reads as a small light rather than a person.

signal wisp_died

@onready var head: Polygon2D = $Visuals/Head
@onready var head_outline: Line2D = $Visuals/HeadOutline
@onready var torso_outline: Line2D = $Visuals/TorsoOutline
var glow: Polygon2D

func _ready() -> void:
	super._ready()
	add_to_group("wisp")
	torso.color = Color(0.45, 0.95, 0.8, 0.9)
	head.color = Color(0.6, 1.0, 0.9, 0.85)
	head.position = Vector2(0, -3)
	# A glow has no hard dark edge - the shared rig's outlines are meant
	# to define a solid human silhouette, exactly the opposite of what
	# this creature should look like.
	torso_outline.visible = false
	head_outline.visible = false
	chest_strap.visible = false
	mask.visible = false
	cap.visible = false
	left_leg.visible = false
	right_leg.visible = false
	gun_visual.visible = false
	modulate.a = 0.9
	_build_glow()

func _build_glow() -> void:
	glow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var ang: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * 20.0)
	glow.polygon = pts
	glow.color = Color(0.55, 0.95, 0.85, 0.28)
	visuals.add_child(glow)
	visuals.move_child(glow, torso.get_index())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# A slow pulse - reads as a light breathing/flickering rather than a
	# static shape, the same spirit as NoxiousBat's constant wing flap.
	var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	glow.scale = Vector2(pulse, pulse)

func die() -> void:
	# Same is_dead guard base Enemy.gd's die() has - lost by overriding
	# die() entirely. Without it, a shotgun/burst weapon's several bullets
	# landing in the same frame (queue_free() doesn't remove the node until
	# end-of-frame) could each independently re-emit wisp_died, and
	# SoulRealm.gd's wave-clear counter only expects exactly one emit per
	# real death - a double-emit from one overkilled Wisp could end a
	# Commune wave (or trigger the Wave 20 finale) while real Wisps are
	# still alive.
	if is_dead:
		return
	is_dead = true
	wisp_died.emit()
	var souls_amount: int = randi_range(3, 8)
	GameManager.add_currency("souls", souls_amount)
	died.emit()
	GameManager.notify_event("kill_enemy")
	GameManager.record_kill("Wisp")
	GameManager.mark_enemy_discovered("wisp")
	var death_pos := global_position
	call_deferred("_spawn_kill_burst", death_pos)
	queue_free()
