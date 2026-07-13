extends "res://scripts/Enemy.gd"

# Rattles, the Boneclock boss. Same structure as Spike (spinning aura +
# periodic thrown projectile + a bigger bolt), reskinned as a rattling
# bone construct - and tuned a bit tougher across the board.

@export var bone_count: int = 7
@export var bone_radius: float = 78.0
@export var bone_damage: int = 18
@export var throw_cooldown: float = 4.2

var bone_angle: float = 0.0
var throw_timer: float = 2.0
var bone_hit_cooldown: float = 0.0
var bone_nodes: Array = []

const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")

func _ready() -> void:
	is_boss = true
	super._ready()
	add_to_group("boss")
	add_to_group("rattles")
	scale = Vector2(2.4, 2.4)
	torso.color = Color(0.85, 0.82, 0.72, 1)
	chest_strap.color = Color(0.45, 0.42, 0.35, 1)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.9, 0.87, 0.78, 1)
	name_tag.visible = true
	name_tag.text = "RATTLES"
	name_tag.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	name_tag.add_theme_font_size_override("font_size", 14)
	# Counter-scale the UI elements so they read at a normal size instead
	# of ballooning up with the boss's 2.4x body scale.
	var ui_counter_scale := 1.0 / 2.4
	name_tag.scale = Vector2(ui_counter_scale, ui_counter_scale)
	name_tag.position = Vector2(-50, -34) * ui_counter_scale
	health_bar.scale = Vector2(ui_counter_scale, ui_counter_scale)
	health_bar.position = Vector2(-24, -30) * ui_counter_scale
	_build_bone_ring()

func _build_bone_ring() -> void:
	for i in range(bone_count):
		var bone := Polygon2D.new()
		bone.polygon = PackedVector2Array([Vector2(0, -9), Vector2(3, -3), Vector2(3, 3), Vector2(0, 9), Vector2(-3, 3), Vector2(-3, -3)])
		bone.color = Color(0.88, 0.85, 0.75, 1)
		add_child(bone)
		bone_nodes.append(bone)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_spin_bones(delta)
	# super._physics_process() only stops movement/shooting while stunned -
	# without this check the ring kept dealing damage and bones kept
	# launching on schedule regardless of being "stunned".
	if Time.get_ticks_msec() >= stunned_until_ms:
		_check_bone_damage(delta)
		_handle_throw(delta)

func _spin_bones(delta: float) -> void:
	bone_angle += delta * 2.3
	for i in range(bone_nodes.size()):
		var ang: float = bone_angle + TAU * float(i) / float(bone_nodes.size())
		bone_nodes[i].position = Vector2(cos(ang), sin(ang)) * bone_radius
		bone_nodes[i].rotation = ang + PI / 2.0

func _check_bone_damage(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	bone_hit_cooldown -= delta
	if bone_hit_cooldown > 0.0:
		return
	if global_position.distance_to(player.global_position) <= bone_radius + 16.0:
		player.take_damage(bone_damage)
		bone_hit_cooldown = 0.6

func _handle_throw(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	throw_timer -= delta
	if throw_timer <= 0.0 and global_position.distance_to(player.global_position) <= detection_range and _has_line_of_sight_to_player():
		_throw_bone_at_player()
		throw_timer = throw_cooldown

func _throw_bone_at_player() -> void:
	var g = GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(g)
	g.global_position = global_position
	g.target_position = player.global_position
	g.damage = 90
	g.radius = 95.0
	g.is_enemy_grenade = true

# A bigger, bone-white bolt instead of the regular pistol shot.
func _shoot() -> void:
	can_shoot = false
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = (player.global_position - muzzle.global_position).normalized()
	bullet.is_enemy_bullet = true
	bullet.damage = 42
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.modulate = Color(0.92, 0.9, 0.8, 1)
	bullet.scale = Vector2(1.75, 1.75)
	recoil = -6.0
	_flash_muzzle()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# Boss kill: guaranteed 2 Exotics + 5 Mythics + blueprint + attachments +
# a big pile of extra loot and currency.
func die() -> void:
	died.emit()
	GameManager.notify_event("kill_enemy")
	GameManager.notify_event("kill_rattles")
	GameManager.record_kill()
	var death_pos := global_position
	var loot_data: Dictionary = GameManager.roll_corpse_loot(false, "", "", 1.0)
	var items: Array = loot_data.get("items", [])
	items.append(GameManager.roll_blueprint())
	items.append(GameManager.roll_attachment())
	items.append(GameManager.roll_attachment())

	var exotics: Array = []
	var mythics: Array = []
	for pool_item in GameManager.LOOT_BAG_GEAR_POOL:
		if pool_item.get("rarity", "") == "exotic":
			exotics.append(pool_item)
		elif pool_item.get("rarity", "") == "mythic":
			mythics.append(pool_item)
	exotics.shuffle()
	for i in range(2):
		if exotics.size() > 0:
			items.append(GameManager.finalize_rolled_item(exotics[i % exotics.size()].duplicate(true)))
	mythics.shuffle()
	for i in range(5):
		if mythics.size() > 0:
			items.append(GameManager.finalize_rolled_item(mythics[i % mythics.size()].duplicate(true)))

	# A big pile of extra random loot on top.
	for i in range(6):
		items.append(GameManager.roll_enemy_loot())
	for i in range(4):
		items.append(GameManager.roll_valuable())
	items.append(GameManager.roll_ruble_item())
	items.append(GameManager.roll_ruble_item())

	var currency: Dictionary = {
		"rubles": randi_range(500, 800),
		"artifacts": randi_range(12, 22),
		"junk": randi_range(35, 65),
		"alloys": randi_range(18, 32),
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
