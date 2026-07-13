extends "res://scripts/Enemy.gd"

# Spike, the boss. Reuses Enemy.gd's movement/detection/line-of-sight AI via
# `super`, and adds on top of it: a ring of spinning spikes that punish
# getting in close, periodic grenade throws, and a bigger/cooler purple
# bolt instead of the regular enemy pistol shot.

@export var spike_count: int = 6
@export var spike_radius: float = 74.0
@export var spike_damage: int = 16
@export var grenade_cooldown: float = 4.5

var spike_angle: float = 0.0
var grenade_timer: float = 2.0
var spike_hit_cooldown: float = 0.0
var spike_nodes: Array = []

const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")

func _ready() -> void:
	is_boss = true
	super._ready()
	add_to_group("boss")
	add_to_group("spike")
	scale = Vector2(2.3, 2.3)
	torso.color = Color(0.42, 0.06, 0.08, 1)
	chest_strap.color = Color(0.14, 0.02, 0.02, 1)
	name_tag.visible = true
	name_tag.text = "SPIKE"
	name_tag.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1))
	name_tag.add_theme_font_size_override("font_size", 14)
	# Counter-scale the UI elements so they read at a normal size instead
	# of ballooning up with the boss's 2.3x body scale.
	var ui_counter_scale := 1.0 / 2.3
	name_tag.scale = Vector2(ui_counter_scale, ui_counter_scale)
	name_tag.position = Vector2(-50, -34) * ui_counter_scale
	health_bar.scale = Vector2(ui_counter_scale, ui_counter_scale)
	health_bar.position = Vector2(-24, -30) * ui_counter_scale
	_build_spike_ring()

func _build_spike_ring() -> void:
	for i in range(spike_count):
		var spike := Polygon2D.new()
		spike.polygon = PackedVector2Array([Vector2(0, -10), Vector2(4, 5), Vector2(-4, 5)])
		spike.color = Color(0.7, 0.1, 0.15, 1)
		add_child(spike)
		spike_nodes.append(spike)

# The base Enemy AI stops advancing at 60% of attack_range (156px here,
# since Spike doesn't override attack_range) - fine for a normal enemy,
# but Spike's whole kit is built around being right on top of the
# player (the spinning ring only actually hits within spike_radius+16,
# ~90px). Without this override Spike just hangs back at 156px forever,
# taking free shots and throwing grenades but never close enough for
# its own signature mechanic to ever come into play. Keep closing in
# until it's essentially on top of the player instead.
func _hold_distance() -> float:
	return spike_radius * 0.4

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_spin_spikes(delta)
	# super._physics_process() only stops movement/shooting while stunned -
	# without this check the ring kept dealing damage and grenades kept
	# launching on schedule regardless of being "stunned".
	if Time.get_ticks_msec() >= stunned_until_ms:
		_check_spike_damage(delta)
		_handle_grenade(delta)

func _spin_spikes(delta: float) -> void:
	spike_angle += delta * 2.0
	for i in range(spike_nodes.size()):
		var ang: float = spike_angle + TAU * float(i) / float(spike_nodes.size())
		spike_nodes[i].position = Vector2(cos(ang), sin(ang)) * spike_radius
		spike_nodes[i].rotation = ang + PI / 2.0

func _check_spike_damage(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	spike_hit_cooldown -= delta
	if spike_hit_cooldown > 0.0:
		return
	if global_position.distance_to(player.global_position) <= spike_radius + 16.0:
		player.take_damage(spike_damage)
		spike_hit_cooldown = 0.6

func _handle_grenade(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	grenade_timer -= delta
	if grenade_timer <= 0.0 and global_position.distance_to(player.global_position) <= detection_range and _has_line_of_sight_to_player():
		_throw_grenade_at_player()
		grenade_timer = grenade_cooldown

func _throw_grenade_at_player() -> void:
	var g = GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(g)
	g.global_position = global_position
	g.target_position = player.global_position
	g.damage = 80
	g.radius = 95.0
	g.is_enemy_grenade = true

# A bigger, purple, higher-damage bolt instead of the regular pistol shot.
func _shoot() -> void:
	can_shoot = false
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = (player.global_position - muzzle.global_position).normalized()
	bullet.is_enemy_bullet = true
	bullet.damage = 36
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.modulate = Color(0.78, 0.25, 0.95, 1)
	bullet.scale = Vector2(1.7, 1.7)
	recoil = -6.0
	_flash_muzzle()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# Boss kill: guaranteed Exotic + 2 Mythics + blueprint + attachments +
# a big pile of extra loot and currency - a real reward for the fight.
func die() -> void:
	died.emit()
	GameManager.notify_event("kill_enemy")
	GameManager.record_kill()
	GameManager.notify_event("kill_spike")
	var death_pos := global_position
	var loot_data: Dictionary = GameManager.roll_corpse_loot(false, "", "", 1.0)
	var items: Array = loot_data.get("items", [])
	items.append(GameManager.roll_blueprint())
	items.append(GameManager.roll_attachment())
	items.append(GameManager.roll_attachment())

	# Guaranteed 1 Exotic + 2 Mythics from the top-tier gear pool.
	var exotics: Array = []
	var mythics: Array = []
	for pool_item in GameManager.LOOT_BAG_GEAR_POOL:
		if pool_item.get("rarity", "") == "exotic":
			exotics.append(pool_item)
		elif pool_item.get("rarity", "") == "mythic":
			mythics.append(pool_item)
	if exotics.size() > 0:
		items.append(GameManager.finalize_rolled_item(exotics[randi() % exotics.size()].duplicate(true)))
	mythics.shuffle()
	for i in range(min(2, mythics.size())):
		items.append(GameManager.finalize_rolled_item(mythics[i].duplicate(true)))

	# A big pile of extra random loot on top.
	for i in range(5):
		items.append(GameManager.roll_enemy_loot())
	for i in range(3):
		items.append(GameManager.roll_valuable())
	items.append(GameManager.roll_ruble_item())
	items.append(GameManager.roll_ruble_item())

	var currency: Dictionary = {
		"rubles": randi_range(400, 700),
		"artifacts": randi_range(10, 20),
		"junk": randi_range(30, 60),
		"alloys": randi_range(15, 30),
	}
	call_deferred("_spawn_corpse_boss", death_pos, items, currency)
	call_deferred("_spawn_kill_burst", death_pos)
	queue_free()

func _spawn_corpse_boss(pos: Vector2, items: Array, currency: Dictionary) -> void:
	var corpse = CORPSE_SCENE.instantiate()
	corpse.loot_items = items
	corpse.currency_drops = currency
	corpse.is_real_player = false
	get_tree().current_scene.add_child(corpse)
	corpse.global_position = pos
