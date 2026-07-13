extends "res://scripts/GauntletEnemy.gd"

# The level's boss - same movement/combat AI as a regular Gauntlet
# enemy (chases, deals contact damage), just much tankier, hits
# harder, and always drops a real haul plus a guaranteed engram when
# it finally goes down. On top of that it also periodically winds up
# and fires a telegraphed 3-shot spread at the player, so there's a
# real ranged threat to dodge instead of just tanking contact damage.

const BOSS_PROJECTILE_SCENE := preload("res://scenes/GauntletBossProjectile.tscn")
const SHOOT_RANGE := 620.0
const SHOOT_COOLDOWN := 1.0
const TELEGRAPH_TIME := 0.45
const SPREAD_ANGLES := [-0.22, 0.0, 0.22]

var shoot_timer: float = 1.2
var is_telegraphing: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("gauntlet_boss")
	scale = Vector2(1.8, 1.8)
	max_health = int(max_health * 3.5)
	health = max_health
	hp_bar.max_value = max_health
	hp_bar.value = health
	shoot_timer = randf_range(1.0, SHOOT_COOLDOWN)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_telegraphing or health <= 0:
		return
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if global_position.distance_to(player_ref.global_position) > SHOOT_RANGE:
		return
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = SHOOT_COOLDOWN
		_telegraph_and_fire()

func _telegraph_and_fire() -> void:
	is_telegraphing = true
	# A clear windup flash - bright violet pulse - gives the player a
	# real beat to react and get out of the line of fire before the
	# spread actually launches.
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.7, 0.6, 1.9, 1), TELEGRAPH_TIME * 0.5)
	flash.tween_property(sprite, "modulate", Color(1, 1, 1, 1), TELEGRAPH_TIME * 0.5)
	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not is_instance_valid(self) or health <= 0:
		return
	_fire_spread()
	is_telegraphing = false

func _fire_spread() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var base_dir: Vector2 = (player_ref.global_position - global_position).normalized()
	for a in SPREAD_ANGLES:
		var dir: Vector2 = base_dir.rotated(a)
		var proj = BOSS_PROJECTILE_SCENE.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector2(0, -14 * scale.y / 1.8)
		proj.direction = dir
		proj.rotation = dir.angle()
		proj.damage = int(48 * difficulty)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_spawn_death_particles(Color(0.8, 0.25, 0.95, 1))
	GameManager.mark_enemy_discovered("gauntlet_boss")
	GameManager.grant_salvaged_beasts_tickets(randi_range(4, 8))
	if randf() < 0.08:
		var rare_pet_rarity: String = ["epic", "legendary", "mythic"][randi() % 3]
		var pet_instance_id := GameManager.hatch_egg(rare_pet_rarity)
		var pet_data := GameManager.get_pet_data(pet_instance_id)
		GameManager.toast_requested.emit("A wild %s followed you home!" % pet_data.get("name", "creature"))
	for i in range(14):
		var item := GameManager.roll_gauntlet_loot()
		var loot = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", loot)
		loot.call_deferred("setup", item)
		var spawn_pos: Vector2 = global_position + Vector2(randf_range(-60, 60), randf_range(-30, 10))
		loot.set_deferred("global_position", spawn_pos)
	# A real shot at the two highest rarity tiers as a boss-only bonus
	# drop - the boss is the big reward moment of the level, so it's
	# worth a better-than-normal chance at Mythic/Multiversal gear.
	if randf() < 0.18:
		var top_pool: Array = GameManager.SOUL_ITEM_POOL.filter(func(i): return i.get("rarity", "") in ["mythic", "multiversal"])
		if not top_pool.is_empty():
			var bonus_item: Dictionary = GameManager.finalize_rolled_item(top_pool[randi() % top_pool.size()].duplicate(true))
			var bonus_loot = LOOT_SCENE.instantiate()
			get_parent().call_deferred("add_child", bonus_loot)
			bonus_loot.call_deferred("setup", bonus_item)
			bonus_loot.set_deferred("global_position", global_position + Vector2(0, -20))
	# Bosses always drop an engram, ignoring the usual 50% coin flip.
	var engram: Dictionary = GameManager.roll_gauntlet_engram()
	if engram.is_empty():
		engram = {"rarity": "rare", "name": "Rare Engram"}
	GameManager.add_engram(engram)
	GameManager.notify_event("gauntlet_boss_kill")
	queue_free()
